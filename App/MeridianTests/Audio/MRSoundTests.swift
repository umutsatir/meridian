import XCTest
#if canImport(MRAudio)
@testable import MRAudio
#else
@testable import Meridian
#endif

private let allCues: [MRCue] = [
    .printerStep(0), .printerStep(3), .printerStep(13), .paperSlide, .tick(heavy: false), .tick(heavy: true), .click,
    .thump, .stamp, .chime(.board), .chime(.land), .seatbelt, .whoosh, .flap, .ripFinish, .crewChime,
]

private func rms(_ x: [Float], from: Int = 0, to: Int? = nil) -> Float {
    let hi = min(to ?? x.count, x.count)
    guard from < hi else { return 0 }
    var s: Float = 0
    for i in from..<hi { s += x[i] * x[i] }
    return (s / Float(hi - from)).squareRoot()
}

final class MRCueRendererTests: XCTestCase {
    func testEveryCueIsFiniteBelowFullScaleAudibleAndRightLength() {
        for cue in allCues {
            let b = MRCueRenderer.render(cue)
            XCTAssertFalse(b.hasNonFinite, "\(cue) has NaN/inf")
            XCTAssertLessThan(b.peak, 1.0, "\(cue) clips")
            XCTAssertGreaterThan(b.peak, 0.01, "\(cue) is silent")
            XCTAssertTrue(cue.expectedDuration.contains(b.duration), "\(cue) lasts \(b.duration) s, expected \(cue.expectedDuration)")
            XCTAssertEqual(b.left.count, b.right.count)
        }
    }

    func testRenderingIsDeterministic() {
        let a = MRCueRenderer.render(.stamp), b = MRCueRenderer.render(.stamp)
        XCTAssertEqual(a.left, b.left)
    }

    func testPrinterPitchRisesWithStep() {
        func crossings(_ i: Int) -> Int {
            let b = MRCueRenderer.render(.printerStep(i)); var c = 0
            for k in 1..<min(b.frames, 4000) where (b.left[k - 1] < 0) != (b.left[k] < 0) { c += 1 }
            return c
        }
        XCTAssertGreaterThan(crossings(13), crossings(0))
    }

    func testStampHasReverbTail() {
        let b = MRCueRenderer.render(.stamp)
        let early = rms(b.left, from: 0, to: 4800), tail = rms(b.left, from: 24_000, to: 48_000)
        XCTAssertGreaterThan(early, tail)
        XCTAssertGreaterThan(tail, 1e-6, "the room tail must exist")
    }

    func testChimeLandingIsReversedBoarding() {
        func crossings(_ k: MRChime) -> Int {
            let b = MRCueRenderer.render(.chime(k)); var c = 0
            for i in 1..<4800 where (b.left[i - 1] < 0) != (b.left[i] < 0) { c += 1 }
            return c
        }
        XCTAssertGreaterThan(crossings(.land), crossings(.board))
    }
}

final class MRDSPTests: XCTestCase {
    func testFFTConvolutionMatchesDirect() {
        var r = MRRandom(seed: 3)
        let x = (0..<50).map { _ in Float(r.signed()) }, h = (0..<17).map { _ in Float(r.signed()) }
        var d = [Float](repeating: 0, count: x.count + h.count - 1)
        for i in 0..<x.count { for j in 0..<h.count { d[i + j] += x[i] * h[j] } }
        let f = MRFFT.convolve(x, h)
        XCTAssertEqual(f.count, d.count)
        for i in 0..<d.count { XCTAssertEqual(f[i], d[i], accuracy: 1e-4) }
    }

    func testEnvelopeShape() {
        let p = MRParam.envelope(at: 0.1, attack: 0.01, peak: 0.5, decay: 0.1, release: 0.1)
        let v = p.values(first: 0, count: 400, sampleRate: 1000)
        XCTAssertEqual(v[110], 0.5, accuracy: 0.03)
        XCTAssertLessThan(v[250], v[111])
        XCTAssertEqual(v[399], 0.0001, accuracy: 1e-3)
    }

    func testSetTargetApproachesGoal() {
        var p = MRParam(0); p.target(1, at: 0, tc: 0.1)
        let v = p.values(first: 0, count: 1000, sampleRate: 1000)
        XCTAssertEqual(v[100], Float(1 - exp(-1.0)), accuracy: 0.01)
        XCTAssertEqual(v[999], 1, accuracy: 0.001)
    }

    func testBiquadLowpassAttenuatesHighFrequencies() {
        var lp = MRBiquad(.lowpass, frequency: 500, sampleRate: 48_000)
        var lo = 0.0, hi = 0.0
        for i in 0..<4800 { lo = max(lo, abs(lp.process(sin(2 * .pi * 100 * Double(i) / 48_000)))) }
        lp = MRBiquad(.lowpass, frequency: 500, sampleRate: 48_000)
        for i in 0..<4800 { hi = max(hi, abs(lp.process(sin(2 * .pi * 8000 * Double(i) / 48_000)))) }
        XCTAssertGreaterThan(lo, 0.9); XCTAssertLessThan(hi, 0.05)
    }
}

@MainActor
final class MRSoundEngineTests: XCTestCase {
    private func makeSound(_ configure: (MRSoundSettings) -> Void = { _ in }) -> MRSound {
        let suite = "meridian.test.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        let s = MRSoundSettings(defaults: d)
        configure(s)
        let sound = MRSound(settings: s, library: AnnouncementLibrary(bundle: Bundle(for: MRSoundEngineTests.self)), mode: .offline)
        sound.isDoNotDisturbActive = { false }
        return sound
    }

    func testOfflineEnginePlaysACueCleanly() throws {
        let sound = makeSound()
        sound.play(.stamp)
        let out = try XCTUnwrap(sound.renderOffline(seconds: 1.0))
        XCTAssertFalse(out.hasNonFinite)
        XCTAssertGreaterThan(out.peak, 0.01)
        XCTAssertLessThan(out.peak, 1.0)
    }

    func testUISoundsSwitchSilencesEffectsButNotAnnouncements() throws {
        let sound = makeSound { $0.uiSoundsEnabled = false }
        sound.play(.stamp)
        XCTAssertEqual(try XCTUnwrap(sound.renderOffline(seconds: 0.5)).peak, 0)
        sound.play(.chime(.board))
        XCTAssertGreaterThan(try XCTUnwrap(sound.renderOffline(seconds: 0.5)).peak, 0.01)
    }

    func testDoNotDisturbBlocksUnlessAllowed() throws {
        let sound = makeSound()
        sound.isDoNotDisturbActive = { true }
        sound.play(.thump)
        XCTAssertEqual(try XCTUnwrap(sound.renderOffline(seconds: 0.4)).peak, 0)
        sound.settings.allowDuringDoNotDisturb = true
        sound.play(.thump)
        XCTAssertGreaterThan(try XCTUnwrap(sound.renderOffline(seconds: 0.4)).peak, 0.01)
    }

    func testAnnouncementsFallBackToChimeAndHonourSwitches() throws {
        let sound = makeSound { $0.setEnabled(.headsUp, false) }
        XCTAssertFalse(sound.library.hasRecording(for: .captainWelcome))
        sound.announce(.landingHeadsUp)
        XCTAssertEqual(try XCTUnwrap(sound.renderOffline(seconds: 0.4)).peak, 0)
        sound.announce(.atcChatter)                          // disabled by default, no fallback
        XCTAssertEqual(try XCTUnwrap(sound.renderOffline(seconds: 0.3)).peak, 0)
        sound.announce(.seatbeltSign)
        let out = try XCTUnwrap(sound.renderOffline(seconds: 1.0))
        XCTAssertGreaterThan(out.peak, 0.01); XCTAssertLessThan(out.peak, 1)
    }

    func testEveryAmbientLayerIsFiniteAudibleAndBounded() throws {
        for layer in MRLayer.allCases {
            let sound = makeSound()
            sound.settings.layerLevels = [:]
            sound.setMaster(1)
            sound.setLevel(layer, 1)
            let out = try XCTUnwrap(sound.renderOffline(seconds: 1.5))
            XCTAssertFalse(out.hasNonFinite, "\(layer)")
            XCTAssertLessThan(out.peak, 1, "\(layer)")
            XCTAssertGreaterThan(rms(out.left, from: 24_000), 0.0005, "\(layer) is silent")
        }
    }

    func testAllLayersAtFullStayBelowFullScale() throws {
        let sound = makeSound()
        sound.setMaster(1)
        for l in MRLayer.allCases { sound.setLevel(l, 1) }
        let out = try XCTUnwrap(sound.renderOffline(seconds: 3))
        XCTAssertFalse(out.hasNonFinite); XCTAssertLessThan(out.peak, 1)
    }

    func testPresetsAndLayersOff() throws {
        let sound = makeSound()
        sound.applyPreset(.rainyRead)
        XCTAssertEqual(sound.level(of: .rain), 0.64, accuracy: 1e-9)
        XCTAssertEqual(sound.settings.master, 0.68, accuracy: 1e-9)
        XCTAssertEqual(MRSoundPreset.named("rain"), .rainyRead)
        let on = try XCTUnwrap(sound.renderOffline(seconds: 1))
        XCTAssertGreaterThan(rms(on.left, from: 24_000), 0.0005)
        sound.layersOff()
        _ = sound.renderOffline(seconds: 1)
        let off = try XCTUnwrap(sound.renderOffline(seconds: 0.5))
        XCTAssertLessThan(rms(off.left), 1e-4)
        XCTAssertEqual(sound.level(of: .rain), 0.64, accuracy: 1e-9)
    }

    func testRipFollowsVelocityAndGatesAtZero() throws {
        let sound = makeSound()
        sound.rip.start()
        XCTAssertTrue(sound.rip.isActive)
        sound.rip.set(1.0)
        let loud = try XCTUnwrap(sound.renderOffline(seconds: 0.3))
        sound.rip.set(0.15)
        let soft = try XCTUnwrap(sound.renderOffline(seconds: 0.3))
        XCTAssertGreaterThan(rms(loud.left, from: 4800), rms(soft.left, from: 9600) * 1.5)
        sound.rip.set(0)
        _ = sound.renderOffline(seconds: 0.3)
        let still = try XCTUnwrap(sound.renderOffline(seconds: 0.2))
        XCTAssertLessThan(rms(still.left), 1e-3, "silent at zero velocity")
        XCTAssertFalse(loud.hasNonFinite); XCTAssertLessThan(loud.peak, 1)
        sound.rip.finish()
        XCTAssertFalse(sound.rip.isActive)
        XCTAssertGreaterThan(try XCTUnwrap(sound.renderOffline(seconds: 0.6)).peak, 0.01)
    }

    func testSettingsPersist() {
        let suite = "meridian.test.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        let a = MRSoundSettings(defaults: d)
        a.uiSoundsEnabled = false; a.master = 0.3; a.setEnabled(.atc, true); a.layerLevels[.rain] = 0.9; a.mutedLayers = [.hum]
        let b = MRSoundSettings(defaults: d)
        XCTAssertFalse(b.uiSoundsEnabled); XCTAssertEqual(b.master, 0.3, accuracy: 1e-9)
        XCTAssertTrue(b.isEnabled(.atc)); XCTAssertEqual(b.level(of: .rain), 0.9, accuracy: 1e-9)
        XCTAssertEqual(b.mutedLayers, [.hum])
        d.removePersistentDomain(forName: suite)
    }

    func testAnnouncementCatalogue() {
        for a in Announcement.allCases { XCTAssertFalse(a.text.isEmpty) }
        XCTAssertEqual(Set(Announcement.allCases.map(\.group)), Set(AnnouncementGroup.allCases))
        XCTAssertNil(Announcement.atcChatter.fallbackCue)
    }
}
