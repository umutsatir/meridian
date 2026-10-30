import Foundation
import MeridianCore

/// What the flight HUD shows (PRD FLY-3). Everything is derived from the
/// flight's timestamps and the route, so the numbers stay consistent after
/// quit, sleep and crash and need no network (ADR 0002).
public struct CruiseSnapshot: Sendable, Equatable {
    public let now: Date
    public let status: FlightStatus
    public let phase: FlightPhase
    public let phaseTimeline: [PhaseSpan]
    public let elapsedSec: TimeInterval
    /// `nil` for a free flight.
    public let remainingSec: TimeInterval?
    public let progress: Double?
    public let eta: Date?
    public let schedule: ScheduleStatus
    /// How far breaks and pauses have slid the ETA, in seconds. Neutral
    /// information, never shown as a delay.
    public let etaShiftSec: TimeInterval
    /// Remaining route distance; `nil` for a free flight.
    public let remainingDistanceKm: Double?
    public let groundSpeedKmh: Double
    public let altitudeFt: Double
    public let position: Coordinate
    /// Degrees clockwise from north; `nil` without a destination.
    public let headingDegrees: Double?
    public let destinationTimeZone: TimeZone
    public let sunElevationDegrees: Double
    public let window: WindowBlend

    public init(
        flight: Flight,
        origin: Airport,
        destination: Airport?,
        now: Date,
        destinationTimeZone: TimeZone? = nil,
        isRaining: Bool = false
    ) {
        self.now = now
        status = flight.status
        phase = flight.phase(at: now)
        let timeline = PhaseTimeline.spans(durationSec: flight.durationSec)
        phaseTimeline = timeline

        let elapsed = flight.elapsedSec(at: now)
        elapsedSec = elapsed
        remainingSec = flight.remainingSec(at: now)
        let progress = flight.progress(at: now)
        self.progress = progress
        eta = flight.isFinished ? flight.endedAt : flight.eta(at: now)
        schedule = ScheduleStatus(flight: flight, now: now)

        let reference = flight.endedAt ?? now
        if let startedAt = flight.startedAt {
            etaShiftSec = max(0, reference.timeIntervalSince(startedAt) - elapsed)
        } else {
            etaShiftSec = 0
        }

        remainingDistanceKm = progress.map { flight.routeDistanceKm * (1 - $0) }

        if let destination {
            let fraction = progress ?? 0
            let position = Geo.interpolate(from: origin.coordinate, to: destination.coordinate, fraction: fraction)
            self.position = position
            let ahead = Geo.distanceKm(from: position, to: destination.coordinate) > 0.5
            headingDegrees = ahead
                ? Geo.bearing(from: position, to: destination.coordinate)
                : Geo.bearing(from: origin.coordinate, to: destination.coordinate)
        } else {
            position = origin.coordinate
            headingDegrees = nil
        }

        self.destinationTimeZone = destinationTimeZone
            ?? Self.estimatedTimeZone(longitude: (destination ?? origin).coordinate.longitude)

        let cruiseAltitude = Self.cruiseAltitudeFt(routeKm: flight.routeDistanceKm, isFreeFlight: flight.isFreeFlight)
        let span = timeline.first { $0.phase == flight.phase(at: now) }
        let profile: (kmh: Double, ft: Double)
        switch flight.status {
        case .planned, .boarding, .landed, .diverted:
            profile = (0, 0)
        case .inFlight, .onBreak:
            profile = Self.profile(phase: phase, fraction: span?.fraction(at: elapsed) ?? 0, cruiseAltitudeFt: cruiseAltitude)
        }
        groundSpeedKmh = profile.kmh
        altitudeFt = profile.ft

        let sun = SunElevation.degrees(at: now, coordinate: position)
        sunElevationDegrees = sun
        window = .blend(elevation: sun, isRaining: isRaining)
    }

    /// Wall-clock components at the destination.
    public func destinationLocalTime(calendar: Calendar = Calendar(identifier: .gregorian)) -> DateComponents {
        var calendar = calendar
        calendar.timeZone = destinationTimeZone
        return calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
    }

    /// Fallback when the app has no time zone for the airport: the nominal
    /// zone for the longitude (15° per hour).
    static func estimatedTimeZone(longitude: Double) -> TimeZone {
        TimeZone(secondsFromGMT: Int((longitude / 15).rounded()) * 3600) ?? .gmt
    }

    static func cruiseAltitudeFt(routeKm: Double, isFreeFlight: Bool) -> Double {
        if isFreeFlight { return 37_000 }
        switch routeKm {
        case ..<250: return 20_000
        case ..<600: return 28_000
        case ..<1_500: return 34_000
        default: return 37_000
        }
    }

    /// A believable, deterministic speed and altitude profile per phase.
    static func profile(phase: FlightPhase, fraction f: Double, cruiseAltitudeFt cruise: Double) -> (kmh: Double, ft: Double) {
        func lerp(_ a: Double, _ b: Double) -> Double { a + (b - a) * f }
        switch phase {
        case .boarding: return (0, 0)
        case .taxi: return (lerp(0, 40), 0)
        case .takeoff: return (lerp(40, 280), lerp(0, 1_500))
        case .climb: return (lerp(280, 830), lerp(1_500, cruise))
        case .cruise: return (830, cruise)
        case .descent: return (lerp(830, 300), lerp(cruise, 2_000))
        case .landing: return (lerp(300, 0), lerp(2_000, 0))
        }
    }
}

/// The "ON TIME" pill (PRD FLY-3).
///
/// The PRD only defines an ON TIME pill and says a break "slides the ETA".
/// It never defines a late state, and the principles forbid countdown
/// pressure and shaming. So a break is not a delay: while the plane is
/// airborne and the clock runs the pill says ON TIME, while the clock is held
/// it says so neutrally, and the slide is exposed as `etaShiftSec`.
public enum ScheduleStatus: Sendable, Equatable {
    case scheduled
    case onTime
    case clockHeld(Flight.HoldKind)
    case arrived

    public init(flight: Flight, now: Date) {
        switch flight.status {
        case .planned, .boarding: self = .scheduled
        case .landed, .diverted: self = .arrived
        case .inFlight, .onBreak:
            if flight.isClockHeld(at: now), let kind = flight.hold?.kind { self = .clockHeld(kind) } else { self = .onTime }
        }
    }
}

public extension Flight {
    /// Whether the focus clock is actually stopped. A flexible pause whose
    /// 10-minute budget ran out still has an open hold, but the clock runs.
    func isClockHeld(at now: Date) -> Bool {
        guard let hold else { return false }
        switch hold.kind {
        case .meal: return true
        case .pause: return pauseBudgetRemaining(at: now) > 0
        }
    }
}
