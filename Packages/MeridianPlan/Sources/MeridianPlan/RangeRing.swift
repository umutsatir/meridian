import Foundation
import MeridianCore

/// The range ring drawn around the origin (PLAN-3): every airport whose flight
/// time is within `toleranceMinutes` of `minutes` sits in the band between
/// `innerRadiusKm` and `outerRadiusKm`.
public struct RangeRing: Sendable, Hashable {
    public static let defaultToleranceMinutes = 3

    public var center: Coordinate
    public var minutes: Int
    public var toleranceMinutes: Int

    public init(center: Coordinate, minutes: Int, toleranceMinutes: Int = RangeRing.defaultToleranceMinutes) {
        self.center = center
        self.minutes = minutes
        self.toleranceMinutes = toleranceMinutes
    }

    /// Ring radius for exactly `minutes`.
    public var radiusKm: Double { FlightTiming.km(forMinutes: Double(minutes)) }
    public var innerRadiusKm: Double { FlightTiming.km(forMinutes: Double(max(0, minutes - toleranceMinutes))) }
    public var outerRadiusKm: Double { FlightTiming.km(forMinutes: Double(minutes + toleranceMinutes)) }

    /// Same rule as `AirportIndex.destinations`, so tags and cards always agree.
    public func contains(_ airport: Airport) -> Bool {
        let t = FlightTiming.minutes(forKm: Geo.distanceKm(from: center, to: airport.coordinate))
        return abs(t - minutes) <= toleranceMinutes
    }
}
