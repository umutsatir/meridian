import Foundation
import MeridianCore
import MeridianCruise

/// The five states of the menu bar item, popover and mini map (M01B).
enum SystemFlightKind: Equatable { case idle, boarding, flight, last, landed }

/// Everything the system surfaces (menu bar, popover, mini map, Seat TV, Dock tile) draw, derived from the
/// active flight. The design artboards build the same value with `preview(...)` so that the live views and the
/// artboards share one code path.
struct SystemFlightInfo: Equatable {
    var kind: SystemFlightKind = .idle
    var progress: Double = 0
    /// Seconds left (elapsed seconds for a free flight).
    var timeSec: TimeInterval = 0
    var isFreeFlight = false
    var paused = false
    var flightNumber = "MR 0142"
    var origin: Coordinate?
    var destination: Coordinate?
    var originCode = "LHR"
    var destinationCode = "CDG"
    var originName = "Heathrow"
    var destinationName = "Charles de Gaulle"
    var destinationCity = "Paris"
    var originCity = "London"
    var phaseTitle = "Cruise"
    var phaseSub = "812 km/h · 11,280 m"
    var timeLabel = "Time remaining"
    var groundSpeedKmh = 812
    var altitudeM = 11_280
    var outsideAirC = -48
    var distanceToGoKm = 192
    var gate = "A12"
    var departedText = "10:06"
    var landsText = "11:42 local"
    var clockLine = "10:24 London · 11:24 Paris"
    var landedKm = 348
    var eta: Date?

    var route: String { kind == .idle ? "" : "\(flightNumber) · \(originCode) → \(destinationCode)" }
    var timeString: String { Self.mmss(timeSec) }

    /// "42:18"; "1:02:18" from one hour on.
    static func mmss(_ sec: TimeInterval) -> String {
        let s = max(0, Int(sec.rounded()))
        if s >= 3600 { return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60) }
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    // MARK: Design data (K.arc('LHR','CDG'), 42 minute flight)

    static let lhr = Coordinate(latitude: 51.47, longitude: -0.4543)
    static let cdg = Coordinate(latitude: 49.0097, longitude: 2.5479)

    /// The artboard data: MR 0142, LHR to CDG, 42 minutes. `p` is the progress the artboard shows.
    static func preview(_ kind: SystemFlightKind, p: Double = 0.55, paused: Bool = false) -> SystemFlightInfo {
        var i = SystemFlightInfo()
        i.kind = kind
        i.origin = lhr
        i.destination = cdg
        i.paused = paused
        let prog: Double
        switch kind {
        case .boarding: prog = 0.02
        case .landed: prog = 1
        case .last: prog = 0.9
        default: prog = p
        }
        i.progress = prog
        let rem = TimeInterval(((1 - prog) * 42 * 60).rounded())
        switch kind {
        case .idle: i.timeSec = 0
        case .boarding: i.timeSec = 252; i.timeLabel = "Gate opens in"; i.phaseTitle = "Gate A12"; i.phaseSub = "Boarding pass printed"
        case .flight: i.timeSec = rem
        case .last: i.timeSec = 252; i.phaseTitle = "Prepare for landing"
        case .landed: i.timeSec = 2520; i.timeLabel = "Time focused"; i.phaseTitle = "Welcome to Paris"; i.phaseSub = "+348 km"
        }
        i.distanceToGoKm = Int(((1 - prog) * 348).rounded())
        return i
    }

    // MARK: Live

    /// State derived from the model at `now`. A flight that landed in the last ten minutes keeps the "Landed"
    /// state in the menu bar item, then the item goes back to idle.
    @MainActor
    static func live(model: AppModel, now: Date = .now) -> SystemFlightInfo {
        if let flight = model.activeFlight {
            return live(flight: flight, model: model, now: now)
        }
        if let landed = model.lastLanded, let ended = landed.endedAt, now.timeIntervalSince(ended) < 600 {
            var info = live(flight: landed, model: model, now: ended)
            info.kind = .landed
            info.progress = 1
            info.timeLabel = "Time focused"
            info.timeSec = landed.finalFocusedSec ?? landed.elapsedSec(at: ended)
            info.phaseTitle = "Welcome to \(info.destinationCity)"
            info.phaseSub = "+\(Int(landed.creditedKm.rounded())) km"
            info.landedKm = Int(landed.creditedKm.rounded())
            return info
        }
        return SystemFlightInfo()
    }

    @MainActor
    private static func live(flight: Flight, model: AppModel, now: Date) -> SystemFlightInfo {
        var i = SystemFlightInfo()
        let origin = model.airport(flight.originIata)
        let dest = model.airport(flight.destinationIata)
        i.origin = origin?.coordinate
        i.destination = dest?.coordinate
        i.originCode = flight.originIata
        i.destinationCode = flight.destinationIata ?? "—"
        i.originCity = origin?.city ?? flight.originIata
        i.originName = origin?.city ?? flight.originIata
        i.destinationCity = dest?.city ?? "your destination"
        i.destinationName = dest?.city ?? "Free flight"
        i.isFreeFlight = flight.isFreeFlight
        i.paused = flight.isHeld
        let identity = TicketIdentity(seed: flight.seed)
        i.flightNumber = identity.flightNumber.replacingOccurrences(of: "MR", with: "MR ")
        i.gate = identity.gate
        switch flight.status {
        case .planned, .boarding:
            i.kind = .boarding
            i.timeLabel = "Gate opens in"
            i.phaseTitle = "Gate \(identity.gate)"
            i.phaseSub = "Boarding pass printed"
            i.timeSec = 0
        default:
            i.kind = LandingAlert.level(for: flight, at: now) >= .prepare ? .last : .flight
            i.timeLabel = flight.isFreeFlight ? "Time in flight" : "Time remaining"
            i.timeSec = flight.remainingSec(at: now) ?? flight.elapsedSec(at: now)
        }
        i.progress = flight.progress(at: now) ?? 0
        i.eta = flight.eta(at: now)
        if let origin, flight.status != .planned {
            let snap = CruiseSnapshot(flight: flight, origin: origin, destination: dest, now: now)
            i.groundSpeedKmh = Int(snap.groundSpeedKmh.rounded())
            i.altitudeM = Int((snap.altitudeFt * 0.3048).rounded())
            i.distanceToGoKm = Int((snap.remainingDistanceKm ?? 0).rounded())
            i.phaseTitle = i.kind == .last ? "Prepare for landing" : snap.phase.rawValue.capitalized
            if i.kind != .boarding {
                i.phaseSub = "\(Self.grouped(i.groundSpeedKmh)) km/h · \(Self.grouped(i.altitudeM)) m"
            }
            let altKm = min(Double(i.altitudeM) / 1000, 11)
            i.outsideAirC = Int((15 - 6.5 * altKm).rounded())
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            f.timeZone = .current
            i.departedText = flight.startedAt.map { f.string(from: $0) } ?? "—"
            let here = f.string(from: now)
            f.timeZone = snap.destinationTimeZone
            i.landsText = "\(i.eta.map { f.string(from: $0) } ?? "—") local"
            i.clockLine = "\(here) \(i.originCity) · \(f.string(from: now)) \(i.destinationCity)"
        }
        return i
    }

    private static func grouped(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        return f.string(from: NSNumber(value: n)) ?? String(n)
    }
}

/// Great-circle samples (`K.arc`): n + 1 points from `a` to `b`.
func systemArc(from a: Coordinate, to b: Coordinate, steps n: Int = 60) -> [Coordinate] {
    (0...n).map { Geo.interpolate(from: a, to: b, fraction: Double($0) / Double(n)) }
}
