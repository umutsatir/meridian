import Foundation

public struct Coordinate: Sendable, Hashable, Codable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public enum Geo {
    public static let earthRadiusKm = 6371.0088
    /// Equatorial circumference, the "once around the world" card threshold.
    public static let equatorKm = 40_075.0

    /// Great-circle distance in kilometres.
    public static func distanceKm(from a: Coordinate, to b: Coordinate) -> Double {
        let φ1 = a.latitude * .pi / 180
        let φ2 = b.latitude * .pi / 180
        let dφ = φ2 - φ1
        let dλ = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dφ / 2) * sin(dφ / 2) + cos(φ1) * cos(φ2) * sin(dλ / 2) * sin(dλ / 2)
        return 2 * earthRadiusKm * asin(min(1, sqrt(h)))
    }

    /// Point at `fraction` (0...1) along the great circle from `a` to `b`.
    public static func interpolate(from a: Coordinate, to b: Coordinate, fraction: Double) -> Coordinate {
        let f = min(1, max(0, fraction))
        let φ1 = a.latitude * .pi / 180, λ1 = a.longitude * .pi / 180
        let φ2 = b.latitude * .pi / 180, λ2 = b.longitude * .pi / 180
        let δ = distanceKm(from: a, to: b) / earthRadiusKm
        guard δ > 1e-9 else { return a }
        let s1 = sin((1 - f) * δ) / sin(δ)
        let s2 = sin(f * δ) / sin(δ)
        let x = s1 * cos(φ1) * cos(λ1) + s2 * cos(φ2) * cos(λ2)
        let y = s1 * cos(φ1) * sin(λ1) + s2 * cos(φ2) * sin(λ2)
        let z = s1 * sin(φ1) + s2 * sin(φ2)
        return Coordinate(
            latitude: atan2(z, sqrt(x * x + y * y)) * 180 / .pi,
            longitude: atan2(y, x) * 180 / .pi
        )
    }

    /// Initial bearing in degrees (0 = north, clockwise).
    public static func bearing(from a: Coordinate, to b: Coordinate) -> Double {
        let φ1 = a.latitude * .pi / 180, φ2 = b.latitude * .pi / 180
        let dλ = (b.longitude - a.longitude) * .pi / 180
        let y = sin(dλ) * cos(φ2)
        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(dλ)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }
}
