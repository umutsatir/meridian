import Foundation

/// Continuous day / golden hour / blue hour / night weights from the real sun elevation, used to grade the live
/// window scene. Unlike `WindowScene` (discrete scenes with a short crossfade) every quantity here is a smooth
/// function of the elevation, so the light changes without a visible step.
public struct DayNightGrade: Sendable, Equatable {
    public var day: Double
    public var golden: Double
    public var blue: Double
    public var night: Double

    /// Breakpoints in degrees of solar elevation: below `nightEnd` it is night, above `dayStart` full day.
    public enum Edge {
        public static let nightEnd = -12.0
        public static let blueMid = -5.0
        public static let goldenMid = 1.0
        public static let dayStart = 10.0
    }

    public init(day: Double, golden: Double, blue: Double, night: Double) {
        self.day = day; self.golden = golden; self.blue = blue; self.night = night
    }

    public static func smoothstep(_ x: Double) -> Double {
        let t = min(1, max(0, x))
        return t * t * (3 - 2 * t)
    }

    /// Weights always sum to 1; two neighbouring bands share the weight inside a transition.
    public static func weights(elevation e: Double) -> DayNightGrade {
        if e <= Edge.nightEnd { return .init(day: 0, golden: 0, blue: 0, night: 1) }
        if e < Edge.blueMid {
            let t = smoothstep((e - Edge.nightEnd) / (Edge.blueMid - Edge.nightEnd))
            return .init(day: 0, golden: 0, blue: t, night: 1 - t)
        }
        if e < Edge.goldenMid {
            let t = smoothstep((e - Edge.blueMid) / (Edge.goldenMid - Edge.blueMid))
            return .init(day: 0, golden: t, blue: 1 - t, night: 0)
        }
        if e < Edge.dayStart {
            let t = smoothstep((e - Edge.goldenMid) / (Edge.dayStart - Edge.goldenMid))
            return .init(day: t, golden: 1 - t, blue: 0, night: 0)
        }
        return .init(day: 1, golden: 0, blue: 0, night: 0)
    }

    public var total: Double { day + golden + blue + night }

    public struct RGBA: Sendable, Equatable { public var r, g, b, a: Double }

    /// Colour laid over the (daytime) satellite imagery: nothing by day, warm at golden hour, indigo at blue hour,
    /// deep navy at night. `a` is the strength of the layer.
    public var groundTint: RGBA {
        let table: [(Double, (Double, Double, Double, Double))] = [
            (day, (255, 255, 255, 0)), (golden, (255, 150, 70, 0.26)), (blue, (46, 58, 130, 0.50)), (night, (6, 10, 30, 0.84)),
        ]
        var a = 0.0, r = 0.0, g = 0.0, b = 0.0
        for (w, c) in table { a += w * c.3; r += w * c.3 * c.0; g += w * c.3 * c.1; b += w * c.3 * c.2 }
        guard a > 0.0001 else { return .init(r: 255, g: 255, b: 255, a: 0) }
        return .init(r: r / a, g: g / a, b: b / a, a: a)
    }

    /// Sky colour at the top of the pane (haze) by band.
    public var skyColor: RGBA {
        let table: [(Double, (Double, Double, Double))] = [
            (day, (172, 205, 238)), (golden, (246, 178, 132)), (blue, (74, 92, 160)), (night, (8, 12, 28)),
        ]
        var r = 0.0, g = 0.0, b = 0.0
        for (w, c) in table { r += w * c.0; g += w * c.1; b += w * c.2 }
        return .init(r: r, g: g, b: b, a: 1)
    }

    /// 0...1 strength of the city lights: invisible by day, fully lit at night.
    public var lights: Double { min(1, night + blue * 0.6 + golden * 0.04) }
    /// 0...1 strength of the warm low-sun glow near the horizon.
    public var glow: Double { min(1, golden + blue * 0.35) }
}

/// Where the sun is relative to the window.
public enum SunGlare {
    /// Azimuth of the sun relative to the viewing direction, in -180...180 (negative = to the left).
    public static func relativeAzimuth(sun: Double, viewHeading: Double) -> Double {
        var d = (sun - viewHeading).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return d
    }
}
