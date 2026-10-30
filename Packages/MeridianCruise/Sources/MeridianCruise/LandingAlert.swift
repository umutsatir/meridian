import Foundation
import MeridianCore

/// "Prepare for landing" (PRD LND-1): a heads-up at T-5 minutes with the
/// seatbelt chime, and an amber HUD in the last minute.
public struct LandingAlert: Sendable, Equatable, Codable {
    public static let leadTimeSec: TimeInterval = 5 * 60
    public static let lastMinuteSec: TimeInterval = 60

    public enum Level: Int, Sendable, Comparable {
        case none, prepare, lastMinute
        public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
    }

    public struct Trigger: Sendable, Equatable {
        public var flightID: UUID
        public var remainingSec: TimeInterval
    }

    /// Flights whose heads-up has already fired. Persist it with the app state
    /// so a relaunch does not chime twice.
    public private(set) var firedFlightIDs: Set<UUID> = []

    public init() {}

    /// HUD level. Independent of the "prepare for landing" setting: amber in
    /// the last minute is part of the HUD, the setting only silences the toast
    /// and the chime.
    public static func level(for flight: Flight, at now: Date) -> Level {
        guard flight.status == .inFlight || flight.status == .onBreak,
              let remaining = flight.remainingSec(at: now), remaining > 0 else { return .none }
        if remaining <= lastMinuteSec { return .lastMinute }
        if remaining <= leadTimeSec { return .prepare }
        return .none
    }

    /// Call on every tick, launch and wake. Returns a trigger at most once per
    /// flight. It stays silent when the setting is off (the flight is then not
    /// marked as fired) and while the clock is held by a break or pause, so
    /// the chime never interrupts a meal break.
    public mutating func poll(flight: Flight, at now: Date, isEnabled: Bool) -> Trigger? {
        guard isEnabled, !firedFlightIDs.contains(flight.id),
              Self.level(for: flight, at: now) >= .prepare,
              !flight.isClockHeld(at: now),
              let remaining = flight.remainingSec(at: now) else { return nil }
        firedFlightIDs.insert(flight.id)
        return Trigger(flightID: flight.id, remainingSec: remaining)
    }

    /// When to schedule the Time Sensitive notification for a backgrounded
    /// app. `nil` if the moment has passed or the clock is held (the ETA is
    /// unknown until it resumes, so reschedule on resume).
    public static func notificationDate(for flight: Flight, at now: Date) -> Date? {
        guard flight.status == .inFlight, !flight.isClockHeld(at: now),
              let eta = flight.eta(at: now) else { return nil }
        let date = eta.addingTimeInterval(-leadTimeSec)
        return date > now ? date : nil
    }

    /// Drops finished flights so the set does not grow forever.
    public mutating func forget(flightID: UUID) { firedFlightIDs.remove(flightID) }
}
