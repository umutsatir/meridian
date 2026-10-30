import AVFoundation
import Foundation

// MARK: - Announcements (SND-2, A01, Mixer "Announcements" section)
//
// Announcements are pre-rendered voice recordings in the final product (NOT text-to-speech: AVSpeechSynthesizer is never
// used). Because real recordings carry licensing risk they are not bundled yet. Until a recording is registered in
// `AnnouncementLibrary`, each announcement plays its chime-only fallback (or nothing, for ATC).

/// The independent switches of the Mixer "Announcements" section.
nonisolated enum AnnouncementGroup: String, CaseIterable, Sendable, Hashable, Identifiable {
    case captain, crew, seatbelt, headsUp, atc
    var id: String { rawValue }

    /// Title and subtitle exactly as drawn on the Mixer artboard.
    var title: String {
        switch self {
        case .captain: "Captain announcements"
        case .crew: "Cabin crew chimes"
        case .seatbelt: "Seatbelt sign"
        case .headsUp: "Landing heads-up (5 min before)"
        case .atc: "ATC chatter"
        }
    }
    var subtitle: String {
        switch self {
        case .captain: "Short, warm, never more than three a flight."
        case .crew: "A soft two-note chime at phase changes."
        case .seatbelt: "Chime and light when the plane takes off and lands."
        case .headsUp: "A quiet notice before descent so you can wrap up."
        case .atc: "Faint radio murmur in the background."
        }
    }
    /// Mixer defaults: everything on except ATC chatter.
    var defaultEnabled: Bool { self != .atc }
}

/// One announcement cue. The text is the script for the future recording and is shown as the caption/accessibility label.
nonisolated enum Announcement: String, CaseIterable, Sendable, Hashable, Identifiable {
    case captainWelcome, captainCruise, captainDescent
    case crewPhaseChime
    case seatbeltSign
    case landingHeadsUp
    case atcChatter

    var id: String { rawValue }

    var group: AnnouncementGroup {
        switch self {
        case .captainWelcome, .captainCruise, .captainDescent: .captain
        case .crewPhaseChime: .crew
        case .seatbeltSign: .seatbelt
        case .landingHeadsUp: .headsUp
        case .atcChatter: .atc
        }
    }

    /// Script (original wording) for the recording and the on-screen caption.
    var text: String {
        switch self {
        case .captainWelcome: "Good morning, this is your captain speaking. Welcome aboard. Settle in, the sky is yours for the next stretch."
        case .captainCruise: "We have reached our cruising altitude. Smooth air ahead. Keep going, you are doing great."
        case .captainDescent: "We have begun our descent. Time to wrap up what you are working on."
        case .crewPhaseChime: "Cabin crew chime."
        case .seatbeltSign: "The seatbelt sign is now on."
        case .landingHeadsUp: "We will be landing in about five minutes. Start wrapping up."
        case .atcChatter: "Meridian four-two, descend and maintain flight level one-two-zero."
        }
    }

    /// What plays while no recording is registered. `nil` = silent (ATC chatter is only worth playing as a recording).
    var fallbackCue: MRCue? {
        switch self {
        case .captainWelcome: .chime(.board)
        case .captainCruise: .crewChime
        case .captainDescent: .chime(.land)
        case .crewPhaseChime: .crewChime
        case .seatbeltSign: .seatbelt
        case .landingHeadsUp: .chime(.land)
        case .atcChatter: nil
        }
    }
}

/// Registry of recordings. Files are added later by dropping `Announcements/<announcement.rawValue>.(caf|m4a|wav|mp3)`
/// into the app bundle, or at runtime with `register(_:url:)`.
@MainActor
final class AnnouncementLibrary {
    static let fileExtensions = ["caf", "m4a", "wav", "mp3"]

    private var registered: [Announcement: URL] = [:]
    private let bundle: Bundle

    init(bundle: Bundle = .main) { self.bundle = bundle }

    func register(_ announcement: Announcement, url: URL) { registered[announcement] = url }
    func unregister(_ announcement: Announcement) { registered[announcement] = nil }

    /// The recording to play, if any.
    func recording(for announcement: Announcement) -> URL? {
        if let url = registered[announcement], FileManager.default.fileExists(atPath: url.path) { return url }
        for ext in Self.fileExtensions {
            if let url = bundle.url(forResource: announcement.rawValue, withExtension: ext, subdirectory: "Announcements")
                ?? bundle.url(forResource: announcement.rawValue, withExtension: ext) { return url }
        }
        return nil
    }

    func hasRecording(for announcement: Announcement) -> Bool { recording(for: announcement) != nil }
}
