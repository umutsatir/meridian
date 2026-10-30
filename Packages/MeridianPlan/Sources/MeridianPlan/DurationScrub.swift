import Foundation
import MeridianCore

/// Pure logic of the duration ruler gesture, copied from the canvas (`Planner.dc.html`):
/// `PX = 3.6` points per minute, `setMin` clamps to the ruler ends, crossing a 5-minute
/// detent fires a haptic tick, values past 366 mean "Free flight", and releasing snaps to the
/// detent (free snaps to its stop at 372). ADR 0008 raises the lower end from 10 to 30.
///
/// The view owns the pointer/scroll events and forwards pixel deltas; this struct returns what
/// to show and whether to tick.
public struct DurationScrub: Sendable, Equatable {
    /// Ruler scale: points per minute (canvas `PX`).
    public static let pixelsPerMinute = 3.6
    public static let detentMinutes = 5
    public static let minMinutes = Double(FlightTiming.minDurationMinutes)
    public static let maxMinutes = Double(FlightTiming.maxDurationMinutes)
    /// Where the ruler ends: the "∞" stop. Anything above `freeThreshold` is a free flight.
    public static let freeStop = 372.0
    public static let freeThreshold = 366.0
    /// Shift+arrow step in minutes (canvas `rKey`).
    public static let shiftKeyStepMinutes = 30
    /// Two-finger scroll speed-up: 1x up to `accelerationStartPx` per event, growing linearly to
    /// `maxAcceleration` at `accelerationFullPx`. Dragging with a pointer is never accelerated.
    public static let accelerationStartPx = 4.0
    public static let accelerationFullPx = 40.0
    public static let maxAcceleration = 3.0

    /// Unsnapped position on the ruler in minutes, `minMinutes...freeStop`.
    public private(set) var rawMinutes: Double
    private var dragOriginX: Double?
    private var dragOriginMinutes: Double = 0

    public init(rawMinutes: Double) {
        self.rawMinutes = Self.clamp(rawMinutes)
    }

    public init(duration: PlanDuration) {
        switch duration {
        case .minutes(let m): self.init(rawMinutes: Double(m))
        case .free: self.init(rawMinutes: Self.freeStop)
        }
    }

    public static func clamp(_ minutes: Double) -> Double {
        min(freeStop, max(minMinutes, minutes))
    }

    // MARK: Read

    public var isFree: Bool { rawMinutes > Self.freeThreshold }

    /// The 5-minute detent the ruler currently points at (what the flag shows while dragging).
    public var detentMinutes: Int {
        let snapped = Int((rawMinutes / Double(Self.detentMinutes)).rounded()) * Self.detentMinutes
        return min(Int(Self.maxMinutes), max(Int(Self.minMinutes), snapped))
    }

    /// The value to commit at the current position (free past the threshold).
    public var detentDuration: PlanDuration { isFree ? .free : .minutes(detentMinutes) }

    /// Canvas `rUp`: where the track settles after release.
    public var releasedRawMinutes: Double { isFree ? Self.freeStop : Double(detentMinutes) }

    /// Minute value at x = 0 of the ruler track. The canvas draws ticks from 10 minutes, so the
    /// artwork keeps that origin even though the selectable minimum is 30.
    public static let trackOriginMinutes = 10.0

    /// Ruler track `left` offset in points relative to the ruler's centre mark
    /// (canvas: `rulerW / 2 - (min(minutes, 380) - 10) * PX`; add `rulerW / 2` for `left`).
    public static func trackOffset(forMinutes minutes: Double) -> Double {
        -(min(minutes, 380) - trackOriginMinutes) * pixelsPerMinute
    }

    /// x position of a label/tick for `minutes` on the track (canvas: `(m - 10) * PX`).
    public static func trackX(forMinutes minutes: Double) -> Double {
        (minutes - trackOriginMinutes) * pixelsPerMinute
    }

    // MARK: Input

    /// Result of one input event.
    public struct Step: Sendable, Equatable {
        /// A 5-minute detent (or the free stop) was crossed: play the haptic tick.
        public var crossedDetent: Bool
        public var changed: Bool
    }

    /// Pointer down. `x` is the pointer position in points.
    public mutating func beginDrag(atX x: Double) {
        dragOriginX = x
        dragOriginMinutes = min(rawMinutes, Self.freeStop)
    }

    /// Pointer move while dragging. Dragging left moves later (canvas: `m0 - dx / PX`).
    @discardableResult
    public mutating func drag(toX x: Double) -> Step {
        guard let originX = dragOriginX else { return Step(crossedDetent: false, changed: false) }
        return move(to: dragOriginMinutes - (x - originX) / Self.pixelsPerMinute)
    }

    /// Pointer up / cancel / scroll end: snaps to the detent (or the free stop).
    /// Returns true if the position moved.
    @discardableResult
    public mutating func endGesture() -> Bool {
        dragOriginX = nil
        let target = releasedRawMinutes
        let moved = target != rawMinutes
        rawMinutes = target
        return moved
    }

    /// Two-finger scroll. `deltaPx` is the scroll delta in content direction (positive = content
    /// moves right, like a drag to the right, so minutes decrease). Slow scrolling is 1:1 with
    /// dragging; fast scrolling is accelerated.
    @discardableResult
    public mutating func scroll(deltaPx: Double) -> Step {
        move(to: rawMinutes - deltaPx * Self.acceleration(forDeltaPx: deltaPx) / Self.pixelsPerMinute)
    }

    /// Picks the dominant axis of a scroll event; a vertical swipe up reads as "forward".
    public static func dominantScrollDelta(dx: Double, dy: Double) -> Double {
        abs(dx) >= abs(dy) ? dx : -dy
    }

    public static func acceleration(forDeltaPx deltaPx: Double) -> Double {
        let d = abs(deltaPx)
        guard d > accelerationStartPx else { return 1 }
        let t = min(1, (d - accelerationStartPx) / (accelerationFullPx - accelerationStartPx))
        return 1 + t * (maxAcceleration - 1)
    }

    /// ←/→ (`direction` -1 / +1): moves one detent from the current detent, or 30 minutes with
    /// `shift`. Past the 6 h end, → goes to Free flight; from Free, ← returns to 6 h.
    @discardableResult
    public mutating func step(_ direction: Int, shift: Bool = false) -> Step {
        guard direction != 0 else { return Step(crossedDetent: false, changed: false) }
        if isFree {
            return direction < 0 ? move(to: Self.maxMinutes) : Step(crossedDetent: false, changed: false)
        }
        let size = shift ? Self.shiftKeyStepMinutes : Self.detentMinutes
        let target = Double(detentMinutes + direction.signum() * size)
        // Anything past 6 h lands on the free stop.
        return move(to: target > Self.maxMinutes ? Self.freeStop : target)
    }

    private mutating func move(to minutes: Double) -> Step {
        let old = rawMinutes
        let new = Self.clamp(minutes)
        rawMinutes = new
        let crossed = Self.detentIndex(new) != Self.detentIndex(old) || (new > Self.freeThreshold) != (old > Self.freeThreshold)
        return Step(crossedDetent: crossed, changed: new != old)
    }

    private static func detentIndex(_ minutes: Double) -> Int {
        Int((minutes / Double(detentMinutes)).rounded())
    }
}
