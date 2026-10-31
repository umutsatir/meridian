import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

// MARK: - Availability (single switch)

/// The only place that turns the Together section on or off. `false` keeps the "Coming in v1.5" placeholder
/// (`ComingSoonView`). Default is ON so the designed screens are reachable (PRD §9.8, owner decision).
enum TogetherAvailability {
    nonisolated(unsafe) static var isEnabled = true
    /// There is no backend yet (PRD §11.1): the fake in-memory service is the only implementation. Debug builds show
    /// a small badge so nobody mistakes it for a real server; release builds never draw it.
    static let isPreviewBackend = true
}

// MARK: - Domain (privacy by construction: no task, no location, no chat field exists)

enum TGPresence: Sendable, Hashable { case inFlight, atGate, idle, landed }

struct TGFriend: Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var initial: String
    var tintHex: String
    var presence: TGPresence
    /// Status line, e.g. "Focusing · in flight to Paris". Status only, never the task.
    var status: String
    var trailing: String = ""
    var canJoin: Bool = false
    var isBlocked = false
}

struct TGRequest: Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var initial: String
    var tintHex: String
    var hint: String
}

struct TGMember: Identifiable, Hashable, Sendable {
    let id: String
    var name: String        // "You", "Anna"
    var fullName: String    // "ELIF KAYA"
    var initial: String
    var tintHex: String
    var seat: String
}

struct TGRoomConfig: Hashable, Sendable {
    var from = "LHR", to = "CDG", fromCity = "London", toCity = "Paris"
    var minutes = 42
    var gateMinutes = 10
    var size = 4
    var isPublic = false
    var km = 348
}

struct TGInvite: Hashable, Sendable {
    var link: String
    var code: String
    var expiresAt: Date
    var isRevoked = false
    var isValid: Bool { !isRevoked && expiresAt > Date() }
}

struct TGRoom: Identifiable, Sendable {
    let id: String
    var flight: String
    var config: TGRoomConfig
    var members: [TGMember]
    var invite: TGInvite
    /// Script time (ms) at which a member reached the gate / started tearing the stub.
    var arrivedAt: [String: Int] = [:]
    var tearAt: [String: Int] = [:]
    var boarded = false
}

enum TGEvent: Sendable {
    case arrived(memberID: String, at: Int)
    case tearStarted(memberID: String, at: Int)
    case boarded
    case memberLanded(memberID: String)
    case friendPresence(friendID: String, presence: TGPresence, status: String)
}

struct TGPublicFlight: Identifiable, Hashable, Sendable {
    enum Status: Hashable, Sendable { case boardingIn(Int), boarding, departed }
    let id: String
    var route: String
    var minutes: Int
    var aboard: Int
    var status: Status
}

enum TGReportReason: String, CaseIterable, Sendable {
    case harassment = "Harassment or hate"
    case inappropriate = "Inappropriate name or picture"
    case spam = "Spam or repeated invites"
    case underage = "Looks under the age limit"
    case other = "Something else"
}

enum TGServiceError: Error, Equatable { case rateLimited, unknownUser, notOldEnough, inviteExpired }

// MARK: - Service

/// Backend seam. The real implementation (CloudKit or a server, PRD §11.1) does not exist yet; everything the UI needs
/// goes through this protocol so it can be swapped without touching a view.
@MainActor
protocol TogetherService: AnyObject {
    var friends: [TGFriend] { get }
    var requests: [TGRequest] { get }
    var publicFlights: [TGPublicFlight] { get }
    var events: AsyncStream<TGEvent> { get }

    func sendRequest(username: String) throws
    func accept(_ id: String)
    func decline(_ id: String)
    func block(_ friendID: String)
    func unblock(_ friendID: String)
    func report(_ friendID: String, reason: TGReportReason)

    /// Creates a room and starts its event stream. `snapshotMs` plays the script instantly up to that time (harness).
    func createRoom(_ config: TGRoomConfig, snapshotMs: Int?) throws -> TGRoom
    func revokeInvite()
    func leaveRoom()
}

// MARK: - Age gate (TOG-8)

enum TGAgeGate {
    static let minimumAge = 13
    private static let key = "together.ageConfirmed"
    static var isConfirmed: Bool { UserDefaults.standard.bool(forKey: key) }
    static func confirm(birthYear: Int, now: Date = Date()) throws {
        let year = Calendar.current.component(.year, from: now)
        guard year - birthYear >= minimumAge else { throw TGServiceError.notOldEnough }
        UserDefaults.standard.set(true, forKey: key)
    }
}

// MARK: - QR (CoreImage)

enum TGQR {
    /// Square module matrix of a real QR code for `text`.
    static func matrix(_ text: String) -> [[Bool]] {
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(text.utf8)
        f.correctionLevel = "M"
        guard let img = f.outputImage else { return [] }
        let ctx = CIContext(options: [.useSoftwareRenderer: true])
        let w = Int(img.extent.width), h = Int(img.extent.height)
        guard let cg = ctx.createCGImage(img, from: img.extent),
              let data = cg.dataProvider?.data, let ptr = CFDataGetBytePtr(data) else { return [] }
        let bpp = cg.bitsPerPixel / 8, bpr = cg.bytesPerRow
        return (0..<h).map { y in (0..<w).map { x in ptr[y * bpr + x * bpp] < 128 } }
    }
}

// MARK: - In-memory implementation (preview backend)

@MainActor
final class InMemoryTogetherService: TogetherService {
    private(set) var friends: [TGFriend]
    private(set) var requests: [TGRequest]
    let publicFlights: [TGPublicFlight]
    let events: AsyncStream<TGEvent>
    private let continuation: AsyncStream<TGEvent>.Continuation
    private var script: Task<Void, Never>?
    private var inviteTimes: [Date] = []
    private(set) var reports: [(friend: String, reason: TGReportReason)] = []
    private var room: TGRoom?

    init() {
        var c: AsyncStream<TGEvent>.Continuation!
        events = AsyncStream { c = $0 }
        continuation = c
        friends = [
            TGFriend(id: "anna", name: "Anna Svensson", initial: "A", tintHex: "#FF8FB1", presence: .inFlight, status: "Focusing · in flight to Paris", trailing: "18 min left", canJoin: true),
            TGFriend(id: "mert", name: "Mert Demir", initial: "M", tintHex: "#7ADDB2", presence: .idle, status: "Idle · last flew 2 h ago"),
            TGFriend(id: "jo", name: "Jo Park", initial: "J", tintHex: "#FFB86B", presence: .atGate, status: "At the gate · MR 0211 boarding", canJoin: true),
            TGFriend(id: "selin", name: "Selin Aydın", initial: "S", tintHex: "#B49CFF", presence: .idle, status: "Idle"),
            TGFriend(id: "daniel", name: "Daniel Ortiz", initial: "D", tintHex: "#7AA2FF", presence: .landed, status: "Landed in Madrid · 12 min ago"),
            TGFriend(id: "kaito", name: "Kaito Mori", initial: "K", tintHex: "#8BF3D8", presence: .idle, status: "Idle · last flew yesterday"),
        ]
        requests = [
            TGRequest(id: "ayse", name: "Ayşe Yılmaz", initial: "Y", tintHex: "#FFB86B", hint: "@ayse · 3 mutual friends"),
            TGRequest(id: "tom", name: "Tom Becker", initial: "T", tintHex: "#7ADDB2", hint: "@tomb · via invite link"),
        ]
        publicFlights = [
            .init(id: "TK 0900", route: "IST → NRT", minutes: 50, aboard: 128, status: .boardingIn(372)),
            .init(id: "MR 0211", route: "LHR → CDG", minutes: 42, aboard: 64, status: .boarding),
            .init(id: "MR 0304", route: "JFK → LAX", minutes: 25, aboard: 37, status: .boardingIn(760)),
            .init(id: "MR 0177", route: "HEL → ARN", minutes: 25, aboard: 21, status: .boardingIn(1085)),
            .init(id: "MR 0412", route: "AMS → DUB", minutes: 60, aboard: 52, status: .boardingIn(1470)),
            .init(id: "MR 0098", route: "SYD → SIN", minutes: 90, aboard: 14, status: .boardingIn(1860)),
            .init(id: "MR 0066", route: "FRA → ZRH", minutes: 25, aboard: 9, status: .departed),
        ]
    }

    func sendRequest(username: String) throws {
        let name = username.trimmingCharacters(in: CharacterSet(charactersIn: "@ ").union(.whitespaces))
        guard !name.isEmpty else { throw TGServiceError.unknownUser }
    }

    func accept(_ id: String) {
        guard let r = requests.first(where: { $0.id == id }) else { return }
        requests.removeAll { $0.id == id }
        friends.append(TGFriend(id: r.id, name: r.name, initial: r.initial, tintHex: r.tintHex, presence: .idle, status: "Idle"))
    }

    func decline(_ id: String) { requests.removeAll { $0.id == id } }

    func block(_ friendID: String) {
        // Blocking removes the friendship and hides presence both ways.
        friends.removeAll { $0.id == friendID }
        requests.removeAll { $0.id == friendID }
    }

    func unblock(_ friendID: String) {}

    func report(_ friendID: String, reason: TGReportReason) { reports.append((friendID, reason)) }

    func createRoom(_ config: TGRoomConfig, snapshotMs: Int? = nil) throws -> TGRoom {
        // Rate limit: at most 5 invites per hour (TOG-8).
        inviteTimes = inviteTimes.filter { Date().timeIntervalSince($0) < 3600 }
        guard inviteTimes.count < 5 else { throw TGServiceError.rateLimited }
        inviteTimes.append(Date())

        let cast: [TGMember] = [
            TGMember(id: "me", name: "You", fullName: "ELIF KAYA", initial: "E", tintHex: "#7AA2FF", seat: "1A"),
            TGMember(id: "anna", name: "Anna", fullName: "ANNA SVENSSON", initial: "A", tintHex: "#FF8FB1", seat: "1C"),
            TGMember(id: "mert", name: "Mert", fullName: "MERT DEMIR", initial: "M", tintHex: "#7ADDB2", seat: "2A"),
            TGMember(id: "jo", name: "Jo", fullName: "JO PARK", initial: "J", tintHex: "#FFB86B", seat: "2C"),
        ]
        let members = Array(cast.prefix(max(1, min(config.size, cast.count))))
        let r = TGRoom(id: "MR0142", flight: "MR 0142", config: config, members: members,
                       invite: TGInvite(link: "meridian.fly/MR0142-x7q", code: "X7Q-142", expiresAt: Date().addingTimeInterval(24 * 3600)))
        room = r
        script?.cancel()
        let arr = [("me", 0, 800), ("anna", 700, 1700), ("mert", 1500, 2600), ("jo", 2300, 3500)]
        var timeline: [(Int, TGEvent)] = []
        for (id, a, t) in arr where members.contains(where: { $0.id == id }) {
            timeline.append((a, .arrived(memberID: id, at: a)))
            timeline.append((t, .tearStarted(memberID: id, at: t)))
        }
        timeline.append((5600, .boarded))
        timeline.sort { $0.0 < $1.0 }
        let cont = continuation
        if let snapshotMs {
            for (t, e) in timeline where t <= snapshotMs { cont.yield(e) }
        } else {
            script = Task { @MainActor in
                var last = 0
                for (t, e) in timeline {
                    try? await Task.sleep(for: .milliseconds(max(0, t - last)))
                    if Task.isCancelled { return }
                    last = t
                    cont.yield(e)
                }
            }
        }
        return r
    }

    func revokeInvite() { room?.invite.isRevoked = true }

    func leaveRoom() { script?.cancel(); room = nil }
}
