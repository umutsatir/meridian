import Foundation
import MeridianCore

public enum OverlayAction: String, Sendable, Codable, Hashable {
    case returnToFocus, takeBreak, landEarly
}

public struct NudgeToast: Sendable, Hashable {
    public var appName: String
    public var destinationName: String?
    public var remainingMinutes: Int?
}

public struct BlockOverlay: Sendable, Hashable {
    public var appName: String
    public var destinationName: String?
    /// Whole minutes left, rounded up; `nil` on a free flight.
    public var remainingMinutes: Int?
    /// Always has `returnToFocus` and `takeBreak`; `landEarly` only when the
    /// flight may land early.
    public var actions: [OverlayAction]
}

public enum Intervention: Sendable, Hashable {
    case none
    case nudge(NudgeToast)
    /// "You're in flight to Paris — 18 min left". This is a window of our own:
    /// Meridian never closes, hides or controls another app (PRD BLK-1).
    case overlay(BlockOverlay)
}

/// Decides what to show when a listed app comes to the front (PRD BLK-1…3).
///
/// Call ``evaluate(flight:destinationName:app:now:)`` once per app activation.
/// Every activation of a listed app during an active flight counts as a
/// violation; the cooldown only limits how often the user is interrupted.
public struct FocusEnforcer: Sendable {
    public var mode: BlockMode
    public var list: BlockList
    public var cooldown: TimeInterval
    /// Our own bundle IDs; never intervened on.
    public var ownBundleIDs: Set<String>

    public private(set) var violationCount = 0
    public private(set) var violationsByApp: [String: Int] = [:]

    private var lastIntervention: [String: Date] = [:]
    private var trackedFlight: UUID?

    /// System surfaces that are never blocked, even if listed by mistake.
    public static let systemBundleIDs: Set<String> = [
        "com.apple.dock", "com.apple.systemuiserver", "com.apple.controlcenter",
        "com.apple.notificationcenterui", "com.apple.loginwindow",
        "com.apple.WindowManager", "com.apple.Spotlight",
    ]

    public init(
        mode: BlockMode,
        list: BlockList,
        cooldown: TimeInterval = 60,
        ownBundleIDs: Set<String> = []
    ) {
        self.mode = mode
        self.list = list
        self.cooldown = cooldown
        self.ownBundleIDs = ownBundleIDs
    }

    public mutating func evaluate(
        flight: Flight,
        destinationName: String?,
        app: AppInfo,
        now: Date
    ) -> Intervention {
        if trackedFlight != flight.id { reset(for: flight.id) }

        guard mode != .off,
              flight.status == .inFlight, !flight.isHeld, // pause, break, landed: silent
              !ownBundleIDs.contains(app.bundleID),
              !Self.systemBundleIDs.contains(app.bundleID),
              list.blocksApp(bundleID: app.bundleID)
        else { return .none }

        violationCount += 1
        violationsByApp[app.bundleID, default: 0] += 1

        if let last = lastIntervention[app.bundleID], now.timeIntervalSince(last) < cooldown {
            return .none
        }
        lastIntervention[app.bundleID] = now

        let minutes = flight.remainingSec(at: now).map { Int(($0 / 60).rounded(.up)) }
        switch mode {
        case .off:
            return .none
        case .nudge:
            return .nudge(NudgeToast(appName: app.name, destinationName: destinationName, remainingMinutes: minutes))
        case .strictOverlay:
            var actions: [OverlayAction] = [.returnToFocus, .takeBreak]
            // Same rule as Flight.landEarly: a free flight can always land.
            if flight.policy.allowsEarlyLanding || flight.isFreeFlight { actions.append(.landEarly) }
            return .overlay(BlockOverlay(appName: app.name, destinationName: destinationName,
                                         remainingMinutes: minutes, actions: actions))
        }
    }

    private mutating func reset(for flightID: UUID) {
        trackedFlight = flightID
        violationCount = 0
        violationsByApp = [:]
        lastIntervention = [:]
    }
}
