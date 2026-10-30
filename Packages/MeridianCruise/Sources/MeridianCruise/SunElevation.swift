import Foundation
import MeridianCore

/// Solar elevation from the NOAA general solar position formulas (Meeus).
/// Geometric elevation, no atmospheric refraction; accurate to well under a
/// degree, which is plenty for choosing a window scene.
public enum SunElevation {
    /// Elevation of the sun above the horizon in degrees (negative = below).
    public static func degrees(at date: Date, coordinate: Coordinate) -> Double {
        let rad = Double.pi / 180
        let jd = date.timeIntervalSince1970 / 86_400 + 2_440_587.5
        let t = (jd - 2_451_545) / 36_525

        let l0 = (280.46646 + t * (36_000.76983 + t * 0.0003032)).truncatingRemainder(dividingBy: 360)
        let m = 357.52911 + t * (35_999.05029 - 0.0001537 * t)
        let e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
        let center = sin(m * rad) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(2 * m * rad) * (0.019993 - 0.000101 * t)
            + sin(3 * m * rad) * 0.000289
        let omega = 125.04 - 1_934.136 * t
        let lambda = l0 + center - 0.00569 - 0.00478 * sin(omega * rad)
        let obliquity = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
            + 0.00256 * cos(omega * rad)
        let declination = asin(sin(obliquity * rad) * sin(lambda * rad))

        let y = pow(tan(obliquity * rad / 2), 2)
        let equationOfTimeMin = 4 / rad * (
            y * sin(2 * l0 * rad)
            - 2 * e * sin(m * rad)
            + 4 * e * y * sin(m * rad) * cos(2 * l0 * rad)
            - 0.5 * y * y * sin(4 * l0 * rad)
            - 1.25 * e * e * sin(2 * m * rad)
        )

        let utcMinutes = ((jd + 0.5).truncatingRemainder(dividingBy: 1)) * 1440
        var solarTime = (utcMinutes + equationOfTimeMin + 4 * coordinate.longitude).truncatingRemainder(dividingBy: 1440)
        if solarTime < 0 { solarTime += 1440 }
        let hourAngle = (solarTime / 4 - 180) * rad

        let lat = coordinate.latitude * rad
        let sinElevation = sin(lat) * sin(declination) + cos(lat) * cos(declination) * cos(hourAngle)
        return asin(max(-1, min(1, sinElevation))) / rad
    }
}

/// Scenes of the oval window (PRD FLY-5), chosen by the real sun elevation at
/// the aircraft's position.
public enum WindowScene: String, Sendable, Codable, CaseIterable {
    case day, sunset, blueHour, night, rain

    /// Elevation bands, in degrees. Sunset covers the golden hour and the sun
    /// at the horizon; blue hour is the twilight after it.
    public enum Threshold {
        public static let day = 8.0
        public static let sunset = -1.0
        public static let blueHour = -9.0
    }

    /// Half-width of the crossfade around each threshold, in degrees.
    public static let crossfadeHalfWidth = 2.0

    /// The scene for a single elevation. Rain replaces every scene except
    /// night, where the glass is dark either way.
    public static func scene(elevation: Double, isRaining: Bool = false) -> WindowScene {
        let base: WindowScene
        switch elevation {
        case Threshold.day...: base = .day
        case Threshold.sunset..<Threshold.day: base = .sunset
        case Threshold.blueHour..<Threshold.sunset: base = .blueHour
        default: base = .night
        }
        return isRaining && base != .night ? .rain : base
    }
}

/// A scene transition: `weight` 0 is fully `from`, 1 is fully `to`.
public struct WindowBlend: Sendable, Equatable {
    public var from: WindowScene
    public var to: WindowScene
    public var weight: Double

    public var isTransitioning: Bool { from != to && weight > 0 && weight < 1 }
    /// The scene that dominates right now.
    public var dominant: WindowScene { weight < 0.5 ? from : to }

    public init(from: WindowScene, to: WindowScene, weight: Double) {
        self.from = from
        self.to = to
        self.weight = weight
    }

    /// Scenes cross-fade inside ±`crossfadeHalfWidth` degrees of a threshold,
    /// with a smoothstep so the change eases in and out.
    public static func blend(elevation: Double, isRaining: Bool = false) -> WindowBlend {
        let h = WindowScene.crossfadeHalfWidth
        let steps: [(threshold: Double, lower: WindowScene, upper: WindowScene)] = [
            (WindowScene.Threshold.blueHour, .night, .blueHour),
            (WindowScene.Threshold.sunset, .blueHour, .sunset),
            (WindowScene.Threshold.day, .sunset, .day),
        ]
        func resolved(_ s: WindowScene) -> WindowScene { isRaining && s != .night ? .rain : s }
        for step in steps where abs(elevation - step.threshold) < h {
            let x = (elevation - (step.threshold - h)) / (2 * h)
            let weight = x * x * (3 - 2 * x)
            return WindowBlend(from: resolved(step.lower), to: resolved(step.upper), weight: weight)
        }
        let scene = WindowScene.scene(elevation: elevation, isRaining: isRaining)
        return WindowBlend(from: scene, to: scene, weight: 0)
    }
}

public struct WindowSample: Sendable, Equatable {
    /// Fraction of the route flown, 0...1.
    public var routeFraction: Double
    public var date: Date
    public var position: Coordinate
    public var sunElevation: Double
    public var blend: WindowBlend
}

public enum WindowSampler {
    /// Samples the window along a planned route, assuming no breaks: sample `i`
    /// is at `departure + fraction × duration`. Useful to preview when the
    /// sun will set during a flight.
    public static func samples(
        from origin: Coordinate,
        to destination: Coordinate,
        departure: Date,
        durationSec: TimeInterval,
        count: Int = 25,
        isRaining: Bool = false
    ) -> [WindowSample] {
        let n = max(2, count)
        return (0..<n).map { i in
            let f = Double(i) / Double(n - 1)
            let date = departure.addingTimeInterval(f * durationSec)
            let position = Geo.interpolate(from: origin, to: destination, fraction: f)
            let elevation = SunElevation.degrees(at: date, coordinate: position)
            return WindowSample(
                routeFraction: f, date: date, position: position, sunElevation: elevation,
                blend: .blend(elevation: elevation, isRaining: isRaining)
            )
        }
    }
}
