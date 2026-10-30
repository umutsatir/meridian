import Foundation
import MeridianCore

public struct PhaseSpan: Sendable, Equatable {
    public var phase: FlightPhase
    public var startSec: TimeInterval
    /// `.infinity` for the open-ended cruise of a free flight.
    public var endSec: TimeInterval

    /// Position inside the span, 0...1. Open-ended spans stay at 0.
    public func fraction(at elapsed: TimeInterval) -> Double {
        guard endSec.isFinite, endSec > startSec else { return 0 }
        return min(1, max(0, (elapsed - startSec) / (endSec - startSec)))
    }
}

public enum PhaseTimeline {
    private static let order: [FlightPhase] = [.taxi, .takeoff, .climb, .cruise, .descent, .landing]
    private static let freeFlightSearchLimit: TimeInterval = 2 * 3600

    /// Phase boundaries in elapsed focus seconds. `MeridianCore` only exposes
    /// `FlightPhase.at(elapsed:duration:)`, so the boundaries are found by
    /// bisection instead of duplicating its constants here; phases that do not
    /// occur (a free flight has no taxi) are left out.
    public static func spans(durationSec: TimeInterval?) -> [PhaseSpan] {
        let upper = durationSec ?? freeFlightSearchLimit
        func index(_ x: TimeInterval) -> Int { order.firstIndex(of: FlightPhase.at(elapsed: x, duration: durationSec))! }

        var spans: [PhaseSpan] = []
        var start: TimeInterval = 0
        for (i, phase) in order.enumerated() {
            let end: TimeInterval
            if index(upper) <= i {
                end = durationSec ?? .infinity
            } else if index(start) > i {
                continue
            } else {
                var lo = start, hi = upper
                for _ in 0..<48 {
                    let mid = (lo + hi) / 2
                    if index(mid) > i { hi = mid } else { lo = mid }
                }
                end = hi
            }
            if end - start > 1e-6 { spans.append(PhaseSpan(phase: phase, startSec: start, endSec: end)) }
            start = end
            if !end.isFinite { break }
        }
        return spans
    }
}
