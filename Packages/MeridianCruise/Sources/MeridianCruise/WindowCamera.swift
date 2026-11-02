import Foundation
import MeridianCore

/// Which side of the aircraft the window is on (seat A = left, seat F = right).
public enum WindowSide: String, Sendable, Codable, CaseIterable {
    case left, right
    public init(seat: String) {
        let s = seat.uppercased()
        self = s.hasSuffix("F") || s.hasSuffix("K") ? .right : .left
    }
    /// Degrees added to the heading to look out of the window.
    public var headingOffset: Double { self == .left ? -90 : 90 }
}

/// Camera for the live window: eye above the aircraft looking sideways and down at the terrain.
public struct WindowCameraSpec: Sendable, Equatable {
    public var center: Coordinate
    public var eyeAltitudeM: Double
    public var distanceM: Double
    public var pitch: Double
    public var heading: Double
}

public enum WindowCamera {
    /// Canvas phase boundaries (`B_` of `Flight.dc.html`): boarding, taxi, take-off, climb, cruise, descent, landing.
    static let bounds: [Double] = [0, 0.01, 0.04, 0.07, 0.2, 0.84, 0.96, 1]

    public static func cruiseAltitudeFt(routeKm: Double) -> Double {
        CruiseSnapshot.cruiseAltitudeFt(routeKm: routeKm, isFreeFlight: false)
    }

    /// Altitude along the route from the canvas phase boundaries: ground, climb to cruise, descent to 2,000 ft, ground.
    public static func altitudeFt(progress p: Double, cruiseFt: Double) -> Double {
        func lerp(_ a: Double, _ b: Double, _ lo: Double, _ hi: Double) -> Double { a + (b - a) * min(1, max(0, (p - lo) / (hi - lo))) }
        switch p {
        case ..<bounds[2]: return 0
        case ..<bounds[3]: return lerp(0, 1_500, bounds[2], bounds[3])
        case ..<bounds[4]: return lerp(1_500, cruiseFt, bounds[3], bounds[4])
        case ..<bounds[5]: return cruiseFt
        case ..<bounds[6]: return lerp(cruiseFt, 2_000, bounds[5], bounds[6])
        default: return lerp(2_000, 0, bounds[6], 1)
        }
    }

    /// Point `km` from `a` along initial bearing `bearing` (degrees).
    public static func offset(_ a: Coordinate, bearing: Double, km: Double) -> Coordinate {
        let δ = km / Geo.earthRadiusKm, θ = bearing * .pi / 180
        let φ1 = a.latitude * .pi / 180, λ1 = a.longitude * .pi / 180
        let φ2 = asin(sin(φ1) * cos(δ) + cos(φ1) * sin(δ) * cos(θ))
        let λ2 = λ1 + atan2(sin(θ) * sin(δ) * cos(φ1), cos(δ) - sin(φ1) * sin(φ2))
        return Coordinate(latitude: φ2 * 180 / .pi, longitude: (λ2 * 180 / .pi + 540).truncatingRemainder(dividingBy: 360) - 180)
    }

    /// The eye hangs above `position` at `max(minAltitude, altitude)`, looks to `side` of the heading and down at
    /// `pitch` degrees from the nadir. The map camera's centre is the ground point the eye looks at.
    public static func spec(position: Coordinate, heading: Double, side: WindowSide, altitudeFt: Double, pitch: Double = 72,
                            minAltitudeM: Double = 450) -> WindowCameraSpec {
        let alt = max(minAltitudeM, altitudeFt * 0.3048)
        let look = (heading + side.headingOffset + 360).truncatingRemainder(dividingBy: 360)
        let ground = alt * tan(pitch * .pi / 180)
        let center = offset(position, bearing: look, km: ground / 1000)
        return WindowCameraSpec(center: center, eyeAltitudeM: alt, distanceM: alt / cos(pitch * .pi / 180), pitch: pitch, heading: look)
    }
}
