import Foundation

/// Converts between distance and flight time (PRD §7.1).
///
/// Long flights: `minutes = 15 + km / 12.9`. Short flights scale the 15-minute
/// overhead down (`min(15, d / 2)`) so a 10-minute flight still has destinations.
/// The two regimes meet at 30 minutes / 193.5 km.
public enum FlightTiming {
    public static let kmPerMinute = 12.9
    public static let maxOverheadMinutes = 15.0
    public static let minDurationMinutes = 10
    public static let maxDurationMinutes = 360

    private static let breakpointKm = maxOverheadMinutes * kmPerMinute

    public static func minutes(forKm km: Double) -> Int {
        let d = max(0, km)
        if d <= breakpointKm { return Int((2 * d / kmPerMinute).rounded()) }
        return Int((maxOverheadMinutes + d / kmPerMinute).rounded())
    }

    public static func km(forMinutes minutes: Double) -> Double {
        let m = max(0, minutes)
        let overhead = min(maxOverheadMinutes, m / 2)
        return (m - overhead) * kmPerMinute
    }

    public static func isValidDuration(minutes: Int) -> Bool {
        (minDurationMinutes...maxDurationMinutes).contains(minutes)
    }
}
