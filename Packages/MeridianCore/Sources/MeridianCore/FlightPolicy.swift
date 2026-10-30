import Foundation

/// How much control the user has once the plane has left the gate (PRD §7.3).
public enum PausePolicy: String, Sendable, Codable, CaseIterable {
    /// No pause, no early landing.
    case strict
    /// No pause; land early by holding, partial flight is saved.
    case normal
    /// Pause up to `flexiblePauseBudgetSec` in total; land early allowed.
    case flexible

    public static let flexiblePauseBudgetSec: TimeInterval = 10 * 60

    public var allowsEarlyLanding: Bool { self != .strict }
    public var allowsPause: Bool { self == .flexible }
}

public enum FlightPhase: String, Sendable, Codable, CaseIterable {
    case boarding, taxi, takeoff, climb, cruise, descent, landing
}

public enum FlightStatus: String, Sendable, Codable {
    case planned
    case boarding
    case inFlight
    case onBreak
    case landed
    /// Landed early; the partial flight is saved and stamped "Diverted".
    case diverted
}
