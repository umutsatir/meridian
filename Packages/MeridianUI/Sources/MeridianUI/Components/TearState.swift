import Foundation

/// Pure logic of tearing off the boarding-pass stub (C03 "Tear-off stub", Ritual.dc.html).
///
/// The tear front follows the pointer: `raw` is the drag distance projected on the perforation divided by `dragSpan`
/// (the perforation is already weakened, so the drag needed is well under the ticket width).
/// `progress` is the resisted value: a light ease-in quadratic over the first 6 %, then 1:1. The front can retreat while the pointer is
/// down; on release below `completionThreshold` (55 %) the partial tear stays and can be picked up again.
public struct TearState: Equatable, Sendable {
    public static let completionThreshold = 0.55
    /// A haptic tick fires every 6 % of progress.
    public static let tickInterval = 0.06
    public static let maxStubAngleDegrees = 25.0
    /// Resistance zone: ease-in quadratic below this progress (light: the first bridge gives after about 11 pt of drag).
    public static let resistanceZone = 0.06
    /// Drag distance in points that tears the whole 360 pt perforation (the original design needed 360).
    public static let dragSpan: Double = 250

    public private(set) var raw: Double = 0
    public private(set) var isTorn = false
    /// Tick bucket the front is currently in (`floor(progress / 6 %)`).
    public private(set) var bucket = 0

    public init() {}

    public var progress: Double { isTorn ? 1 : Self.progress(forRawDrag: raw) }
    public var hasPassedThreshold: Bool { progress >= Self.completionThreshold }

    /// Stub rotation about the tear front: `25 * (1 - (1 - p)^1.6)` degrees (R03/C03 mechanics).
    public var stubAngleDegrees: Double { Self.stubAngle(atProgress: progress) }
    public static func stubAngle(atProgress p: Double) -> Double { maxStubAngleDegrees * (1 - pow(1 - min(1, max(0, p)), 1.6)) }

    public static func progress(forRawDrag raw: Double) -> Double {
        let p = min(1, max(0, raw))
        return p < resistanceZone ? resistanceZone * pow(p / resistanceZone, 2) : p
    }

    /// Inverse of `progress(forRawDrag:)`, to resume a partial tear from where it stopped.
    public static func rawDrag(forProgress p: Double) -> Double {
        let q = min(1, max(0, p))
        return q < resistanceZone ? resistanceZone * (q / resistanceZone).squareRoot() : q
    }

    public static func tickCount(atProgress progress: Double) -> Int {
        Int((progress / tickInterval + 1e-9).rounded(.down))
    }

    /// Moves the front to a raw drag value. Returns how many haptic ticks to play (0 when the bucket did not change).
    @discardableResult
    public mutating func drag(to rawFraction: Double) -> Int {
        guard !isTorn else { return 0 }
        raw = min(1, max(0, rawFraction))
        let b = Self.tickCount(atProgress: progress)
        let n = abs(b - bucket)
        bucket = b
        return n
    }

    /// Call when the pointer goes up. Returns whether the stub came off (>= 55 %).
    @discardableResult
    public mutating func release() -> Bool {
        guard !isTorn else { return true }
        if hasPassedThreshold { complete() }
        return isTorn
    }

    /// Button, Space/Return and VoiceOver path, and the end of the auto-finish: the stub comes off.
    public mutating func complete() {
        raw = 1
        isTorn = true
    }

    /// Smoothed pointer speed for the rip sound: `v = min(1, vx / 1.6) * 0.6 + v * 0.4` (vx in points per millisecond).
    public static func smoothedVelocity(previous: Double, dx: Double, dtMs: Double) -> Double {
        let vx = abs(dx) / max(8, dtMs)
        return min(1, vx / 1.6) * 0.6 + previous * 0.4
    }

    /// While the pointer rests the rip decays: x 0.82 per frame once idle for more than 70 ms (gate to 0).
    public static func decayedVelocity(_ v: Double, idleMs: Double) -> Double { idleMs > 70 ? v * 0.82 : v }
}
