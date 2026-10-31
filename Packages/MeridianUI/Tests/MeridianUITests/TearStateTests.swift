import Testing
@testable import MeridianUI

@Suite struct TearStateTests {
    @Test func startsAttached() {
        let s = TearState()
        #expect(s.progress == 0 && !s.isTorn && s.stubAngleDegrees == 0)
    }

    @Test func resistanceIsEaseInCubicForTheFirstTenPercent() {
        #expect(abs(TearState.progress(forRawDrag: 0.05) - 0.1 * 0.125) < 1e-12)   // 0.1 * (0.5)^3
        #expect(abs(TearState.progress(forRawDrag: 0.1) - 0.1) < 1e-12)
        #expect(TearState.progress(forRawDrag: 0.5) == 0.5)                         // 1:1 afterwards
        #expect(TearState.progress(forRawDrag: -3) == 0 && TearState.progress(forRawDrag: 7) == 1)
    }

    @Test func rawInverseRoundTrips() {
        for p in [0.0, 0.01, 0.05, 0.1, 0.4, 0.9] {
            #expect(abs(TearState.progress(forRawDrag: TearState.rawDrag(forProgress: p)) - p) < 1e-9)
        }
    }

    @Test func frontFollowsThePointerBothWaysWhileDragging() {
        var s = TearState()
        s.drag(to: 0.5)
        s.drag(to: 0.3)
        #expect(s.progress == 0.3)
    }

    @Test func releaseBelowThresholdKeepsPartialTear() {
        var s = TearState()
        s.drag(to: 0.4)
        let r = s.release()
        #expect(!r)
        #expect(!s.isTorn && s.progress == 0.4)
        s.drag(to: 0.5)   // picks up again from where it stopped
        #expect(s.progress == 0.5)
    }

    @Test func thresholdIsSeventyTwoPercentInclusive() {
        var s = TearState()
        s.drag(to: 0.72)
        #expect(s.hasPassedThreshold)
        let done = s.release()
        #expect(done && s.isTorn && s.progress == 1)
        var below = TearState()
        below.drag(to: 0.7199)
        let r2 = below.release()
        #expect(!r2)
    }

    @Test func buttonAndKeyboardPathTearsInOneStep() {
        var s = TearState()
        s.complete()
        #expect(s.isTorn && s.progress == 1)
        #expect(abs(s.stubAngleDegrees - 25) < 1e-9)
    }

    @Test func hapticTickEverySixPercent() {
        #expect(TearState.tickCount(atProgress: 0.05) == 0)
        #expect(TearState.tickCount(atProgress: 0.06) == 1)
        #expect(TearState.tickCount(atProgress: 0.18) == 3)
        var s = TearState()
        var total = 0
        for i in 1...100 { total += s.drag(to: Double(i) / 100) }
        #expect(total >= TearState.tickCount(atProgress: 1) - 1 && total <= TearState.tickCount(atProgress: 1) + 1)
        let last = s.drag(to: 1)
        #expect(last == 0)
    }

    @Test func tornStubIgnoresFurtherDragging() {
        var s = TearState()
        s.complete()
        let t = s.drag(to: 0.1)
        let r = s.release()
        #expect(t == 0 && s.progress == 1 && r)
    }

    @Test func stubAngleCurveIsTwentyFiveTimesOneMinusOneMinusPToTheOnePointSix() {
        #expect(abs(TearState.stubAngle(atProgress: 0.5) - 25 * (1 - pow(0.5, 1.6))) < 1e-9)
        #expect(TearState.stubAngle(atProgress: 1) == 25 && TearState.stubAngle(atProgress: 0) == 0)
    }

    @Test func velocitySmoothingAndGate() {
        let v = TearState.smoothedVelocity(previous: 0, dx: 16, dtMs: 10)   // 1.6 pt/ms saturates
        #expect(abs(v - 0.6) < 1e-9)
        #expect(TearState.decayedVelocity(1, idleMs: 50) == 1)
        #expect(abs(TearState.decayedVelocity(1, idleMs: 80) - 0.82) < 1e-12)
    }
}

import Foundation
