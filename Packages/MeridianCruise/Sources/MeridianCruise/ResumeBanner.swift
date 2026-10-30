import Foundation
import MeridianCore

public enum ResumeCause: Sendable { case launch, wake }

/// The "Flight resumed" banners (PRD §9.14, S54). Text is a localization key
/// plus arguments, never a literal string.
public struct ResumeBanner: Sendable, Equatable {
    public enum Kind: Sendable, Equatable { case afterQuit, afterSleep, landedWhileAway }

    public enum Argument: Sendable, Equatable {
        case text(String)
        case minutes(Int)
    }

    public static let autoDismissAfterSec: TimeInterval = 8
    /// Banners never steal focus and VoiceOver reads each one once.
    public static let stealsFocus = false
    public static let voiceOverReadsOnce = true
    /// A gap shorter than this is not worth a banner (spurious wake events).
    public static let minimumGapSec: TimeInterval = 5

    public var kind: Kind
    public var titleKey: String
    public var bodyKey: String
    public var arguments: [Argument]

    public init(kind: Kind, titleKey: String, bodyKey: String, arguments: [Argument]) {
        self.kind = kind; self.titleKey = titleKey; self.bodyKey = bodyKey; self.arguments = arguments
    }

    /// Picks the banner for a flight that was just settled on launch or wake.
    ///
    /// - Parameters:
    ///   - lastActiveAt: when the app last ran (last tick or heartbeat).
    ///   - destinationCity: name for the "Landed in Paris" copy.
    public static func select(
        flight: Flight,
        cause: ResumeCause,
        lastActiveAt: Date,
        now: Date,
        destinationCity: String?
    ) -> ResumeBanner? {
        switch flight.status {
        case .planned, .boarding:
            return nil
        case .inFlight, .onBreak:
            guard now.timeIntervalSince(lastActiveAt) >= minimumGapSec else { return nil }
            let kind: Kind = cause == .launch ? .afterQuit : .afterSleep
            let stem = kind == .afterQuit ? "flight.resumed.afterQuit" : "flight.resumed.afterSleep"
            var arguments: [Argument] = []
            let body: String
            if let remaining = flight.remainingSec(at: now) {
                body = stem + ".body"
                arguments.append(.minutes(Int((remaining / 60).rounded(.up))))
            } else {
                body = stem + ".openEnded.body"
                arguments.append(.minutes(Int(flight.elapsedSec(at: now) / 60)))
            }
            return ResumeBanner(kind: kind, titleKey: "flight.resumed.title", bodyKey: body, arguments: arguments)
        case .landed, .diverted:
            // Only a landing that happened while the app was away counts.
            guard let endedAt = flight.endedAt, endedAt > lastActiveAt else { return nil }
            if let destinationCity {
                return ResumeBanner(kind: .landedWhileAway, titleKey: "flight.landedWhileAway.title",
                                    bodyKey: "flight.landedWhileAway.body", arguments: [.text(destinationCity)])
            }
            return ResumeBanner(kind: .landedWhileAway, titleKey: "flight.landedWhileAway.title",
                                bodyKey: "flight.landedWhileAway.openEnded.body", arguments: [])
        }
    }
}
