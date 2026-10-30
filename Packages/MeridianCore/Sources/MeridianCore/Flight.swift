import Foundation

public enum FlightError: Error, Sendable, Equatable {
    case invalidTransition(from: FlightStatus)
    case pauseNotAllowed
    case pauseBudgetExhausted
    case earlyLandingNotAllowed
    case alreadyHeld
    case notHeld
}

/// One focus session. Progress is computed from timestamps, never ticked
/// (PRD §7.2), so quit, sleep and crash cannot change the result.
public struct Flight: Sendable, Hashable, Codable, Identifiable {
    public enum HoldKind: String, Sendable, Codable { case pause, meal }

    public struct Hold: Sendable, Hashable, Codable {
        public var kind: HoldKind
        public var startedAt: Date
        public init(kind: HoldKind, startedAt: Date) {
            self.kind = kind
            self.startedAt = startedAt
        }
    }

    public var id: UUID
    public var originIata: String
    /// `nil` for a free flight (open-ended, no destination).
    public var destinationIata: String?
    public var scenarioID: String
    public var topic: String
    public var notes: String
    public var policy: PausePolicy
    /// Planned duration; `nil` means free flight.
    public var durationSec: TimeInterval?
    /// Great-circle distance of the planned route in km (0 for free flights).
    public var routeDistanceKm: Double
    /// Drives flight number, gate and torn-edge shape deterministically.
    public var seed: UInt64

    public private(set) var status: FlightStatus
    public private(set) var startedAt: Date?
    public private(set) var endedAt: Date?
    /// Clock time spent paused, closed holds only.
    public private(set) var pausedTotalSec: TimeInterval
    /// Clock time spent on meal breaks, closed holds only.
    public private(set) var breakTotalSec: TimeInterval
    public private(set) var hold: Hold?
    /// Focused seconds frozen at landing.
    public private(set) var finalFocusedSec: TimeInterval?

    public init(
        id: UUID = UUID(),
        originIata: String,
        destinationIata: String?,
        scenarioID: String,
        topic: String = "",
        policy: PausePolicy = .normal,
        durationSec: TimeInterval?,
        routeDistanceKm: Double,
        seed: UInt64 = UInt64.random(in: .min ... .max)
    ) {
        self.id = id
        self.originIata = originIata
        self.destinationIata = destinationIata
        self.scenarioID = scenarioID
        self.topic = topic
        self.notes = ""
        self.policy = policy
        self.durationSec = durationSec
        self.routeDistanceKm = routeDistanceKm
        self.seed = seed
        self.status = .planned
        self.pausedTotalSec = 0
        self.breakTotalSec = 0
    }

    public var isFreeFlight: Bool { durationSec == nil }
    public var isFinished: Bool { status == .landed || status == .diverted }
    public var isHeld: Bool { hold != nil }

    // MARK: Transitions

    public mutating func board() throws {
        guard status == .planned else { throw FlightError.invalidTransition(from: status) }
        status = .boarding
    }

    public mutating func takeOff(at now: Date) throws {
        guard status == .boarding else { throw FlightError.invalidTransition(from: status) }
        startedAt = now
        status = .inFlight
    }

    public mutating func startPause(at now: Date) throws {
        try requireActive(at: now)
        guard policy.allowsPause else { throw FlightError.pauseNotAllowed }
        guard hold == nil else { throw FlightError.alreadyHeld }
        guard pauseBudgetRemaining(at: now) > 0 else { throw FlightError.pauseBudgetExhausted }
        hold = Hold(kind: .pause, startedAt: now)
    }

    /// A meal break holds the clock; allowed under every policy (PRD §7.4).
    public mutating func startBreak(at now: Date) throws {
        try requireActive(at: now)
        guard hold == nil else { throw FlightError.alreadyHeld }
        hold = Hold(kind: .meal, startedAt: now)
        status = .onBreak
    }

    public mutating func resume(at now: Date) throws {
        guard status == .inFlight || status == .onBreak else { throw FlightError.invalidTransition(from: status) }
        guard let hold else { throw FlightError.notHeld }
        let held = max(0, effectiveHoldEnd(hold, at: now).timeIntervalSince(hold.startedAt))
        switch hold.kind {
        case .pause: pausedTotalSec += held
        case .meal: breakTotalSec += held
        }
        self.hold = nil
        status = .inFlight
    }

    /// Lands early and saves the partial flight. Free flights always land.
    public mutating func landEarly(at now: Date) throws {
        try requireActive(at: now)
        guard policy.allowsEarlyLanding || isFreeFlight else { throw FlightError.earlyLandingNotAllowed }
        try closeHold(at: now)
        finish(at: now, status: isFreeFlight ? .landed : .diverted)
    }

    /// Lands the plane if the planned duration has elapsed. Safe to call on
    /// every launch, wake and tick; returns whether the flight is now finished.
    @discardableResult
    public mutating func settle(at now: Date) -> Bool {
        guard status == .inFlight || status == .onBreak, let startedAt, let durationSec else { return isFinished }
        guard elapsedSec(at: now) >= durationSec else { return false }
        try? closeHold(at: now)
        // Landing moment is when focus time reached the duration, not `now`.
        let landing = startedAt.addingTimeInterval(durationSec + pausedTotalSec + breakTotalSec)
        finish(at: min(landing, now), status: .landed)
        return true
    }

    // MARK: Derived values

    /// Focused seconds so far. Frozen after landing.
    public func elapsedSec(at now: Date) -> TimeInterval {
        if let finalFocusedSec { return finalFocusedSec }
        guard let startedAt, status != .planned, status != .boarding else { return 0 }
        let raw = now.timeIntervalSince(startedAt) - heldSec(at: now)
        let clamped = max(0, raw)
        return durationSec.map { min($0, clamped) } ?? clamped
    }

    public func remainingSec(at now: Date) -> TimeInterval? {
        durationSec.map { max(0, $0 - elapsedSec(at: now)) }
    }

    /// 0...1 for timed flights; `nil` for free flights.
    public func progress(at now: Date) -> Double? {
        guard let durationSec, durationSec > 0 else { return nil }
        return min(1, elapsedSec(at: now) / durationSec)
    }

    /// Estimated arrival. Slides forward while the clock is held.
    public func eta(at now: Date) -> Date? {
        remainingSec(at: now).map { now.addingTimeInterval($0) }
    }

    public func pauseBudgetRemaining(at now: Date) -> TimeInterval {
        guard policy.allowsPause else { return 0 }
        var used = pausedTotalSec
        if let hold, hold.kind == .pause { used += max(0, effectiveHoldEnd(hold, at: now).timeIntervalSince(hold.startedAt)) }
        return max(0, PausePolicy.flexiblePauseBudgetSec - used)
    }

    /// Share of the planned flight that counts. Landed = 1, diverted = elapsed share.
    public var focusedFraction: Double {
        guard let finalFocusedSec else { return 0 }
        guard let durationSec, durationSec > 0 else { return 1 }
        return min(1, finalFocusedSec / durationSec)
    }

    /// Kilometres credited toward miles and cards (PRD §7.5). Only focused
    /// minutes count; breaks and pauses never do.
    public var creditedKm: Double {
        guard finalFocusedSec != nil else { return 0 }
        if isFreeFlight { return FlightTiming.km(forMinutes: (finalFocusedSec ?? 0) / 60) }
        return routeDistanceKm * focusedFraction
    }

    public func phase(at now: Date) -> FlightPhase {
        switch status {
        case .planned: return .boarding
        case .boarding: return .boarding
        case .landed, .diverted: return .landing
        case .inFlight, .onBreak: return FlightPhase.at(elapsed: elapsedSec(at: now), duration: durationSec)
        }
    }

    // MARK: Helpers

    /// Lands a completed flight first, so nothing can start a hold after the planned end.
    private mutating func requireActive(at now: Date) throws {
        settle(at: now)
        guard status == .inFlight || status == .onBreak else { throw FlightError.invalidTransition(from: status) }
    }

    private mutating func closeHold(at now: Date) throws {
        if hold != nil { try resume(at: now) }
    }

    private mutating func finish(at now: Date, status: FlightStatus) {
        finalFocusedSec = elapsedSec(at: now)
        endedAt = now
        self.status = status
    }

    /// Pause holds stop counting once the budget is spent (the clock resumes
    /// on its own); meal breaks last as long as the user wants.
    private func effectiveHoldEnd(_ hold: Hold, at now: Date) -> Date {
        guard hold.kind == .pause else { return now }
        let allowed = max(0, PausePolicy.flexiblePauseBudgetSec - pausedTotalSec)
        return min(now, hold.startedAt.addingTimeInterval(allowed))
    }

    private func heldSec(at now: Date) -> TimeInterval {
        var total = pausedTotalSec + breakTotalSec
        if let hold { total += max(0, effectiveHoldEnd(hold, at: now).timeIntervalSince(hold.startedAt)) }
        return total
    }
}

public extension FlightPhase {
    /// Phase boundaries are proportional with caps so a 6-hour flight does not
    /// spend an hour climbing. Take-off and landing are cosmetic (PRD §7.1).
    static func at(elapsed: TimeInterval, duration: TimeInterval?) -> FlightPhase {
        guard let duration, duration > 0 else {
            return elapsed < 60 ? .takeoff : (elapsed < 15 * 60 ? .climb : .cruise)
        }
        func span(_ fraction: Double, cap: TimeInterval) -> TimeInterval { min(duration * fraction, cap) }
        let taxi = span(0.02, cap: 60)
        let takeoff = taxi + span(0.03, cap: 90)
        let climb = takeoff + span(0.10, cap: 15 * 60)
        let landing = duration - span(0.02, cap: 90)
        let descent = landing - span(0.12, cap: 20 * 60)
        switch elapsed {
        case ..<taxi: return .taxi
        case ..<takeoff: return .takeoff
        case ..<climb: return .climb
        case ..<descent: return .cruise
        case ..<landing: return .descent
        default: return .landing
        }
    }
}
