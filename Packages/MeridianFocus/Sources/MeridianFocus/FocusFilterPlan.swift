import Foundation
import MeridianCore

public enum FocusFilterAction: Sendable, Hashable {
    case activate(focusID: String)
    case deactivate(focusID: String)
}

/// Turns a chosen macOS Focus on at take-off and off at landing (PRD BLK-4).
public struct FocusFilterPlan: Sendable, Hashable, Codable {
    public var isEnabled: Bool
    /// Identifier of the Focus the user picked; `nil` until they pick one.
    public var focusID: String?

    public init(isEnabled: Bool = false, focusID: String? = nil) {
        self.isEnabled = isEnabled
        self.focusID = focusID
    }

    /// What to do when a flight moves from `from` to `to`. `optedOut` is the
    /// per-flight opt-out. Breaks keep the Focus on; a relaunch into an
    /// in-flight state does not activate it a second time.
    public func action(from: FlightStatus, to: FlightStatus, optedOut: Bool) -> FocusFilterAction? {
        guard isEnabled, !optedOut, let focusID else { return nil }
        switch (from, to) {
        case (.boarding, .inFlight):
            return .activate(focusID: focusID)
        case (.inFlight, .landed), (.inFlight, .diverted), (.onBreak, .landed), (.onBreak, .diverted):
            return .deactivate(focusID: focusID)
        default:
            return nil
        }
    }
}

/// Everything the Settings > Focus and blocking screen edits (PRD S51).
public struct FocusSettings: Sendable, Hashable, Codable {
    public var mode: BlockMode
    public var list: BlockList
    public var filter: FocusFilterPlan

    public init(mode: BlockMode = .off, list: BlockList = BlockList(), filter: FocusFilterPlan = FocusFilterPlan()) {
        self.mode = mode
        self.list = list
        self.filter = filter
    }
}
