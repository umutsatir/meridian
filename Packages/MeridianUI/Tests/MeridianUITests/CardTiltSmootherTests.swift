import CoreGraphics
import Testing
@testable import MeridianUI

@Suite struct CardTiltSmootherTests {
    private func run(_ s: inout CardTiltSmoother, seconds: Double, fps: Double = 60) -> [CardTiltSmoother] {
        var out: [CardTiltSmoother] = []
        for _ in 0..<Int(seconds * fps) { s.step(1 / fps); out.append(s) }
        return out
    }

    @Test func stepResponseIsMonotoneWithoutOvershoot() {
        var s = CardTiltSmoother()
        s.setTarget(CGPoint(x: 0.5, y: -0.4))
        var px = 0.0, py = 0.0, ph = 0.0
        for f in run(&s, seconds: 2) {
            #expect(f.x >= px - 1e-12 && f.x <= 0.5 + 1e-12)
            #expect(f.y <= py + 1e-12 && f.y >= -0.4 - 1e-12)
            #expect(f.hover >= ph - 1e-12 && f.hover <= 1 + 1e-12)
            px = f.x; py = f.y; ph = f.hover
        }
    }

    @Test func firstFrameDoesNotJump() {
        var s = CardTiltSmoother()
        s.setTarget(CGPoint(x: 0.5, y: 0.5))
        s.step(1 / 60)
        #expect(s.x < 0.05 && s.hover < 0.02)   // a 14 degree edge pose is < 0.7 degrees after one frame
    }

    @Test func convergesToAFixedTargetAndSettles() {
        var s = CardTiltSmoother()
        s.setTarget(CGPoint(x: -0.3, y: 0.2))
        _ = run(&s, seconds: 2)
        #expect(abs(s.x + 0.3) < 1e-3 && abs(s.y - 0.2) < 1e-3 && abs(s.hover - 1) < 1e-3)
        #expect(s.isSettled)
        s.setTarget(nil)
        _ = run(&s, seconds: 2)
        #expect(abs(s.x) < 1e-3 && abs(s.hover) < 1e-3 && s.isSettled)
    }

    @Test func entryTakesAboutHalfASecond() {
        var s = CardTiltSmoother()
        s.setTarget(CGPoint(x: 0.5, y: 0))
        let frames = run(&s, seconds: 1.5)
        let t95 = Double(frames.firstIndex { $0.hover >= 0.95 }! + 1) / 60
        #expect(t95 > 0.35 && t95 < 0.9)
    }

    @Test func frameRateIndependent() {
        var a = CardTiltSmoother(), b = CardTiltSmoother()
        a.setTarget(CGPoint(x: 0.4, y: 0.4)); b.setTarget(CGPoint(x: 0.4, y: 0.4))
        _ = run(&a, seconds: 0.4, fps: 30); _ = run(&b, seconds: 0.4, fps: 120)
        #expect(abs(a.x - b.x) < 1e-9)
    }

    @Test func stalledFrameIsClamped() {
        var s = CardTiltSmoother()
        s.setTarget(CGPoint(x: 0.5, y: 0.5))
        s.step(5)
        #expect(s.x < 0.2)
    }

    @Test func retargetMidFlightStaysBounded() {
        var s = CardTiltSmoother()
        s.setTarget(CGPoint(x: 0.5, y: 0))
        _ = run(&s, seconds: 0.2)
        s.setTarget(CGPoint(x: -0.5, y: 0))
        for f in run(&s, seconds: 2) { #expect(abs(f.x) <= 0.5 + 1e-9) }
    }
}
