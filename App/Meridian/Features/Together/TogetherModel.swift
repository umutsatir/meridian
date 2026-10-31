import Foundation
import Observation

enum TGScreen: String, Sendable { case friends, create, lobby, inflight, landing, board }
enum TGAddTab: Hashable { case username, link, qr }

/// Harness / deep-link entry: the screen to open and an optional frozen state (canvas `t`, in-flight progress).
struct TGLaunch: Sendable {
    var screen: TGScreen
    var lobbyMs: Int? = nil
    var progress: Double? = nil
    var annaLanded = false
    var hoverFriend: String? = nil
}

@MainActor
@Observable
final class TogetherModel {
    /// Set by the harness routes before the section appears.
    nonisolated(unsafe) static var launch: TGLaunch?

    let service: TogetherService
    var screen: TGScreen = .friends

    // Friends
    private(set) var friends: [TGFriend] = []
    private(set) var requests: [TGRequest] = []
    var addTab: TGAddTab = .username
    var username = ""
    var notice: String?
    var hoveredFriend: String?

    // Create
    var config = TGRoomConfig()
    var createError: String?

    // Lobby
    private(set) var room: TGRoom?
    private(set) var lobbyStart = Date()
    var frozenMs: Int?

    // In flight / landing
    var boardedAt = Date()
    var frozenProgress: Double?
    var annaLanded = false
    var landed: [String: Int] = [:]

    // Public board
    var boardFilter = 0
    var boardScenario = "code"

    // Safety (TOG-8)
    var blockTarget: TGFriend?
    var reportTarget: TGFriend?
    var showsAgeGate = false

    private var pump: Task<Void, Never>?

    init(service: TogetherService = InMemoryTogetherService()) {
        self.service = service
        friends = service.friends
        requests = service.requests
        if let l = Self.launch { apply(l) }
        startPump()
    }

    // MARK: Navigation

    private func apply(_ l: TGLaunch) {
        screen = l.screen
        hoveredFriend = l.hoverFriend
        frozenProgress = l.progress
        annaLanded = l.annaLanded
        if l.screen == .lobby || l.screen == .inflight || l.screen == .landing {
            room = try? service.createRoom(config, snapshotMs: l.lobbyMs ?? 5600)
            frozenMs = l.lobbyMs
        }
    }

    func go(_ s: TGScreen) { screen = s }

    // MARK: Friends

    func refresh() { friends = service.friends; requests = service.requests }

    func accept(_ r: TGRequest) { service.accept(r.id); refresh() }
    func decline(_ r: TGRequest) { service.decline(r.id); refresh() }

    func sendRequest() {
        do { try service.sendRequest(username: username); notice = "Request sent."; username = "" }
        catch { notice = "No one with that username." }
    }

    func block(_ f: TGFriend) { service.block(f.id); blockTarget = nil; refresh() }
    func report(_ f: TGFriend, _ reason: TGReportReason) { service.report(f.id, reason: reason); reportTarget = nil }

    // MARK: Create / lobby

    var maxGroup: Int { 8 }

    func create() {
        guard TGAgeGate.isConfirmed else { showsAgeGate = true; return }
        do {
            room = try service.createRoom(config, snapshotMs: nil)
            lobbyStart = Date(); frozenMs = nil
            screen = .lobby
        } catch TGServiceError.rateLimited {
            createError = "You have sent a lot of invites. Try again in a while."
        } catch { createError = "Could not create the flight." }
    }

    func confirmAge(birthYear: Int) -> Bool {
        do { try TGAgeGate.confirm(birthYear: birthYear); showsAgeGate = false; return true }
        catch { return false }
    }

    func lobbyMs(at date: Date) -> Int { frozenMs ?? Int(date.timeIntervalSince(lobbyStart) * 1000) }

    func leaveRoom() { service.leaveRoom(); room = nil; screen = .friends }

    // MARK: Flight

    /// Prototype speed: 36x, like the canvas prototype.
    func progress(at date: Date) -> Double {
        if let f = frozenProgress { return f }
        return min(1, date.timeIntervalSince(boardedAt) * 36 / Double(config.minutes * 60))
    }

    private func startPump() {
        let stream = service.events
        pump = Task { [weak self] in
            for await e in stream {
                guard let self else { return }
                self.handle(e)
            }
        }
    }

    private func handle(_ e: TGEvent) {
        switch e {
        case .arrived(let id, let at): room?.arrivedAt[id] = at
        case .tearStarted(let id, let at): room?.tearAt[id] = at
        case .boarded:
            room?.boarded = true
            if screen == .lobby && frozenMs == nil { boardedAt = Date(); screen = .inflight }
        case .memberLanded(let id): landed[id] = 0
        case .friendPresence: refresh()
        }
    }
}
