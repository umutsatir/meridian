import Testing
@testable import MeridianUI

@Suite struct TearStateTests {
    @Test func startsAttached() {
        let s = TearState()
        #expect(s.progress == 0 && !s.isTorn && s.stubAngleDegrees == 0)
    }

    @Test func progressNeverMovesBackward() {
        var s = TearState()
        s.drag(to: 0.5)
        let p = s.progress
        s.drag(to: 0.2)
        #expect(s.progress == p)
    }

    @Test func resistanceMakesEarlyDragSlowerThanOneToOne() {
        #expect(TearState.progress(forRawDrag: 0.5) < 0.5)
        #expect(TearState.progress(forRawDrag: 1) == 1)
        #expect(TearState.progress(forRawDrag: 0) == 0)
        #expect(TearState.progress(forRawDrag: -3) == 0)
        #expect(TearState.progress(forRawDrag: 7) == 1)
    }

    @Test func releaseBelowThresholdKeepsPartialTear() {
        var s = TearState()
        s.drag(to: 0.5) // 0.5^1.25 ≈ 0.42
        let result = s.release()
        #expect(!result)
        #expect(!s.isTorn && s.progress > 0.3 && s.progress < TearState.completionThreshold)
    }

    @Test func releaseAtOrPastThresholdCompletesTheTear() {
        var s = TearState()
        s.drag(to: 0.8) // ≈ 0.757
        #expect(s.hasPassedThreshold)
        let result = s.release()
        #expect(result)
        #expect(s.isTorn && s.progress == 1)
    }

    @Test func thresholdBoundaryIsInclusive() {
        // Raw drag whose resisted progress is exactly 0.72.
        let raw = pow(TearState.completionThreshold, 1 / TearState.resistanceExponent)
        var s = TearState()
        s.drag(to: raw)
        #expect(abs(s.progress - 0.72) < 1e-9)
        #expect(s.hasPassedThreshold) // exactly 0.72 counts as passed
        let atThreshold = s.release()
        #expect(atThreshold)
        var below = TearState()
        below.drag(to: raw - 0.01)
        let belowResult = below.release()
        #expect(!belowResult)
    }

    @Test func buttonAndKeyboardPathTearsInOneStep() {
        var s = TearState()
        s.complete()
        #expect(s.isTorn && s.progress == 1 && s.stubAngleDegrees == 25)
    }

    @Test func hapticTicksFireEverySixPercentExactlyOnce() {
        #expect(TearState.tickCount(atProgress: 0.05) == 0)
        #expect(TearState.tickCount(atProgress: 0.06) == 1)
        #expect(TearState.tickCount(atProgress: 0.18) == 3)
        var s = TearState()
        var total = 0
        for i in 1...100 { total += s.drag(to: Double(i) / 100) }
        #expect(total == TearState.tickCount(atProgress: 1)) // 16
        #expect(s.ticksFired == total)
        let result = s.drag(to: 1)
        #expect(result == 0)
    }

    @Test func bigJumpFiresAllSkippedTicks() {
        var s = TearState()
        let result = s.drag(to: 0.9)
        #expect(result == TearState.tickCount(atProgress: TearState.progress(forRawDrag: 0.9)))
    }

    @Test func tornStubIgnoresFurtherDragging() {
        var s = TearState()
        s.complete()
        let result = s.drag(to: 0.1)
        #expect(result == 0)
        let result2 = s.release()
        #expect(s.progress == 1 && result2)
    }

    @Test func stubAngleScalesToTwentyFiveDegrees() {
        var s = TearState()
        s.drag(to: 1)
        #expect(abs(s.stubAngleDegrees - 25) < 1e-9)
    }
}

import Foundation
