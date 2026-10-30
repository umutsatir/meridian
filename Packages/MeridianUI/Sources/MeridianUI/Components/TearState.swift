import Foundation

/// Pure logic for tearing off the boarding-pass stub (PRD RIT-3).
///
/// Feed it the raw drag fraction (0...1 along the tear line). The tear front only
/// advances, so dragging back does not re-attach the stub. Releasing at or past
/// `completionThreshold` finishes the tear; below it the partial tear stays.
public struct TearState: Equatable, Sendable {
    public static let completionThreshold = 0.72
    /// A haptic tick fires every 6% of progress.
    public static let tickInterval = 0.06
    public static let maxStubAngleDegrees = 25.0
    /// Drag resistance: the first part of the drag moves the tear less than 1:1.
    static let resistanceExponent = 1.25

    public private(set) var progress: Double = 0
    public private(set) var isTorn = false
    public private(set) var ticksFired = 0

    public init() {}

    public var stubAngleDegrees: Double { Self.maxStubAngleDegrees * progress }
    public var hasPassedThreshold: Bool { progress >= Self.completionThreshold }

    public static func progress(forRawDrag raw: Double) -> Double {
        pow(min(1, max(0, raw)), resistanceExponent)
    }

    public static func tickCount(atProgress progress: Double) -> Int {
        Int((progress / tickInterval + 1e-9).rounded(.down))
    }

    /// Updates the tear and returns how many new haptic ticks to play.
    @discardableResult
    public mutating func drag(to rawFraction: Double) -> Int {
        guard !isTorn else { return 0 }
        progress = max(progress, Self.progress(forRawDrag: rawFraction))
        let total = Self.tickCount(atProgress: progress)
        let new = max(0, total - ticksFired)
        ticksFired += new
        return new
    }

    /// Call when the drag ends. Returns whether the stub came off.
    @discardableResult
    public mutating func release() -> Bool {
        guard !isTorn else { return true }
        if hasPassedThreshold { complete() }
        return isTorn
    }

    /// Button, Space/Return and VoiceOver path: tears the stub off in one step.
    public mutating func complete() {
        progress = 1
        isTorn = true
    }
}
