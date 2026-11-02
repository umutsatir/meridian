import XCTest
#if canImport(MRAudio)
@testable import MRAudio
#else
@testable import Meridian
#endif

/// The perforation-tear sounds are synthesised: they must be finite, below full scale, audible, the right length, and the clicks must be
/// bright (energy above 2 kHz dominates) and short.
final class MRPerforationSoundTests: XCTestCase {
    private func peak(_ x: [Float]) -> Float { x.reduce(0) { max($0, abs($1)) } }
    private func finite(_ x: [Float]) -> Bool { x.allSatisfy { $0.isFinite } }

    /// Energy of the first difference (a crude high-pass) over the energy of the signal: 2 for white noise, 2 - 2 cos(w) for a tone (0.11 at 2.4 kHz, 0.66 at 5.8 kHz), near 0 for a thud.
    private func brightness(_ x: [Float]) -> Float {
        var d: Float = 0, e: Float = 0
        for i in 1..<x.count { let v = x[i] - x[i - 1]; d += v * v; e += x[i] * x[i] }
        return d / max(e, 1e-12)
    }

    func testBridgeClicksAreShortBrightAndInRange() {
        let ticks = MRPerforationSynth.tickVariants()
        XCTAssertEqual(ticks.count, 6)
        for t in ticks {
            XCTAssertTrue(finite(t))
            XCTAssertGreaterThan(peak(t), 0.5)
            XCTAssertLessThanOrEqual(peak(t), 0.95)
            XCTAssertLessThan(Double(t.count) / MRPerforationSynth.sampleRate, 0.05)
            XCTAssertGreaterThan(brightness(t), 0.12, "a click must be bright, not a thud")   // a pure 2.4 kHz tone scores 0.11, 190 Hz scores 0.001
            // dies out: the last 10 ms are far below the peak
            let tail = t.suffix(Int(0.008 * MRPerforationSynth.sampleRate))
            XCTAssertLessThan(peak(Array(tail)), 0.1 * peak(t))
        }
    }

    func testSeparationIsAudibleBoundedAndDoesNotEndWithAClick() {
        let s = MRPerforationSynth.separation()
        XCTAssertTrue(finite(s))
        XCTAssertGreaterThan(peak(s), 0.5)
        XCTAssertLessThanOrEqual(peak(s), 0.85)
        XCTAssertEqual(Double(s.count) / MRPerforationSynth.sampleRate, 0.36, accuracy: 0.01)
        XCTAssertEqual(Double(s.last ?? 1), 0, accuracy: 1e-4)
    }

    func testWhooshIsQuietSmoothAndStartsAndEndsSilent() {
        let w = MRPerforationSynth.whoosh()
        XCTAssertTrue(finite(w))
        XCTAssertLessThanOrEqual(peak(w), 0.3)
        XCTAssertGreaterThan(peak(w), 0.1)
        XCTAssertLessThan(abs(w[0]), 0.01)
        XCTAssertLessThan(abs(w[w.count - 1]), 0.01)
    }

    @MainActor func testSilentWhenNotAllowedAndAtZeroSpeed() {
        let s = MRPerforationSound.shared
        s.isAllowed = { false }
        let before = s.recent.count
        s.bridges(4, speed: 0.9)
        s.separate(speed: 1)
        s.whoosh()
        XCTAssertEqual(s.recent.count, before, "UI sounds off: nothing plays")
        s.isAllowed = { true }
        s.bridges(4, speed: 0)
        XCTAssertEqual(s.recent.count, before, "speed 0 is silent")
    }
}
