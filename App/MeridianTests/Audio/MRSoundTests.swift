import XCTest
import AVFoundation
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

    func testBoardingChimeIsTwoNotesAndLandingIsOne() {
        let board = MRCueRenderer.render(.chime(.board)), land = MRCueRenderer.render(.chime(.land))
        let sr = board.sampleRate
        func win(_ b: MRStereoBuffer, _ t: Double) -> Float { rms(b.left, from: Int(t * sr), to: Int((t + 0.05) * sr)) }
        XCTAssertGreaterThan(win(board, 0.6), win(land, 0.6), "boarding has a second note")
        XCTAssertLessThanOrEqual(board.duration, 3.2); XCTAssertLessThanOrEqual(land.duration, 3.0)
    }

    func testOneShotEdgesAreSoft() {
        for cue in allCues where MRCueRenderer.usesEdgeFades(cue) {
            let b = MRCueRenderer.render(cue)
            XCTAssertEqual(b.left[0], 0, accuracy: 1e-6, "\(cue) starts with a click")
            XCTAssertEqual(b.left[b.frames - 1], 0, accuracy: 1e-6, "\(cue) ends with a click")
            XCTAssertEqual(b.right[b.frames - 1], 0, accuracy: 1e-6)
            let ms = Int(b.sampleRate / 1000)
            let first = b.left[0..<ms].map(abs).max() ?? 0, later = b.left[(4 * ms)..<(5 * ms)].map(abs).max() ?? 0
            XCTAssertLessThanOrEqual(first, later + 1e-6, "\(cue)")
        }
        XCTAssertFalse(MRCueRenderer.usesEdgeFades(.click)); XCTAssertFalse(MRCueRenderer.usesEdgeFades(.tick(heavy: false)))
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
            sound.setFlightActive(true)
            let out = try XCTUnwrap(sound.renderOffline(seconds: 3.5))
            XCTAssertFalse(out.hasNonFinite, "\(layer)")
            XCTAssertLessThan(out.peak, 1, "\(layer)")
            XCTAssertGreaterThan(rms(out.left, from: 120_000), 0.0005, "\(layer) is silent")
        }
    }

    func testAllLayersAtFullStayBelowFullScale() throws {
        let sound = makeSound()
        sound.setMaster(1)
        for l in MRLayer.allCases { sound.setLevel(l, 1) }
        sound.setFlightActive(true)
        let out = try XCTUnwrap(sound.renderOffline(seconds: 3))
        XCTAssertFalse(out.hasNonFinite); XCTAssertLessThan(out.peak, 1)
    }

    func testPresetsAndLayersOff() throws {
        let sound = makeSound()
        sound.applyPreset(.rainyRead)
        XCTAssertEqual(sound.level(of: .rain), 0.64, accuracy: 1e-9)
        XCTAssertEqual(sound.settings.master, 0.68, accuracy: 1e-9)
        XCTAssertEqual(MRSoundPreset.named("rain"), .rainyRead)
        sound.setFlightActive(true)
        let on = try XCTUnwrap(sound.renderOffline(seconds: 3))
        XCTAssertGreaterThan(rms(on.left, from: 120_000), 0.0005)
        sound.layersOff()
        _ = sound.renderOffline(seconds: 2)
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


// MARK: - Cabin sound lifecycle and fades

@MainActor
final class MRCabinSoundTests: XCTestCase {
    private func makeSound(_ configure: (MRSoundSettings) -> Void = { _ in }) -> MRSound {
        let suite = "meridian.test.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        let s = MRSoundSettings(defaults: d)
        configure(s)
        let sound = MRSound(settings: s, library: AnnouncementLibrary(bundle: Bundle(for: MRCabinSoundTests.self)), mode: .offline)
        sound.isDoNotDisturbActive = { false }
        return sound
    }
    private func energy(_ b: MRStereoBuffer, from t: Double, to u: Double) -> Float {
        rms(b.left, from: Int(t * b.sampleRate), to: Int(u * b.sampleRate))
    }

    func testCabinSoundIsOnByDefaultAndNothingPlaysBeforeAFlight() throws {
        let sound = makeSound()
        XCTAssertTrue(sound.settings.cabinSoundEnabled)
        XCTAssertFalse(sound.ambientEnabled)
        let idle = try XCTUnwrap(sound.renderOffline(seconds: 1))
        XCTAssertEqual(idle.peak, 0, "plan / ritual screens have no ambient")
    }

    func testFlightStartMakesTheHumAudibleAndLayerGainPositive() throws {
        let sound = makeSound()
        sound.setFlightActive(true)
        XCTAssertTrue(sound.ambientEnabled)
        let hum = MRLayer.hum.index
        XCTAssertGreaterThan(sound.ambientParams.gain[hum], 0)
        XCTAssertGreaterThan(sound.ambientParams.level[hum], 0)
        XCTAssertEqual(sound.ambientParams.fadeTarget, 1)
        let out = try XCTUnwrap(sound.renderOffline(seconds: 4))
        XCTAssertFalse(out.hasNonFinite); XCTAssertLessThan(out.peak, 1)
        XCTAssertGreaterThan(energy(out, from: 3, to: 4), 0.001, "cabin hum must be audible once the fade-in is done")
        XCTAssertLessThan(energy(out, from: 0, to: 0.05), energy(out, from: 3, to: 4), "starts from silence")
    }

    func testFinishLandedAndDeletedFadeTheBedOutAndItStaysOff() throws {
        // finish / landed-while-away / early landing / delete all reach the engine as setFlightActive(false)
        for _ in 0..<2 {
            let sound = makeSound()
            sound.setFlightActive(true)
            _ = sound.renderOffline(seconds: 3)
            sound.setFlightActive(false)
            XCTAssertFalse(sound.ambientEnabled)
            let fadeOut = try XCTUnwrap(sound.renderOffline(seconds: 1.5))
            XCTAssertGreaterThan(energy(fadeOut, from: 0, to: 0.3), energy(fadeOut, from: 1.2, to: 1.5), "fading, not cut")
            XCTAssertGreaterThan(energy(fadeOut, from: 0, to: 0.1), 0.0005, "not an instant cut")
            let after = try XCTUnwrap(sound.renderOffline(seconds: 2))
            XCTAssertLessThan(after.peak, 1e-4)
            // a slider in the ritual does not bring it back
            sound.setMaster(0.9); sound.setLevel(.rain, 0.5)
            XCTAssertLessThan(try XCTUnwrap(sound.renderOffline(seconds: 1)).peak, 1e-4)
            // a new flight brings it back
            sound.setFlightActive(true)
            XCTAssertGreaterThan(energy(try XCTUnwrap(sound.renderOffline(seconds: 4)), from: 3, to: 4), 0.001)
        }
    }

    func testUserSwitchIsRespectedAndRemembered() throws {
        let suite = "meridian.test.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        let sound = MRSound(settings: MRSoundSettings(defaults: d), library: AnnouncementLibrary(bundle: Bundle(for: MRCabinSoundTests.self)), mode: .offline)
        sound.setFlightActive(true)
        _ = sound.renderOffline(seconds: 3)
        sound.setCabinSound(false)
        _ = sound.renderOffline(seconds: 2)
        XCTAssertLessThan(try XCTUnwrap(sound.renderOffline(seconds: 0.5)).peak, 1e-4)
        XCTAssertFalse(MRSoundSettings(defaults: d).cabinSoundEnabled, "choice is stored")
        sound.setCabinSound(true)
        XCTAssertGreaterThan(energy(try XCTUnwrap(sound.renderOffline(seconds: 4)), from: 3, to: 4), 0.001)
        // a new flight with the switch off stays silent
        sound.setCabinSound(false); sound.setFlightActive(false); _ = sound.renderOffline(seconds: 2)
        sound.setFlightActive(true)
        XCTAssertLessThan(try XCTUnwrap(sound.renderOffline(seconds: 2)).peak, 1e-4)
        d.removePersistentDomain(forName: suite)
    }

    func testAmbientFadeCurveIsMonotonicEqualPowerAndTimed() throws {
        let dsp = MRAmbientDSP(sampleRate: 48_000)
        dsp.update { $0.gain[MRLayer.hum.index] = 0.1; $0.level[MRLayer.hum.index] = 0.5; $0.fadeTarget = 1; $0.fadeSeconds = MRFade.ambientIn }
        var buf = [Float](repeating: 0, count: 480)
        var inCurve: [Double] = []
        for _ in 0..<(48_000 * 2 / 480) {
            buf.withUnsafeMutableBufferPointer { dsp.render(frames: 480, into: $0.baseAddress!) }
            XCTAssertFalse(buf.contains { !$0.isFinite }); XCTAssertLessThan(buf.map(abs).max() ?? 0, 1)
            inCurve.append(dsp.fadePosition)
        }
        XCTAssertEqual(inCurve, inCurve.sorted(), "fade-in is monotonic")
        XCTAssertEqual(try XCTUnwrap(inCurve.last), 1, accuracy: 1e-9)
        let half = try XCTUnwrap(inCurve.firstIndex { $0 >= 0.5 })
        XCTAssertEqual(Double(half + 1) * 0.01, MRFade.ambientIn / 2, accuracy: 0.05)
        XCTAssertGreaterThan(MRFade.ambientIn, 1.4); XCTAssertLessThan(MRFade.ambientIn, 2.1)
        for p in stride(from: 0.0, through: 1.0, by: 0.1) {
            XCTAssertEqual(MRFade.equalPower(p) * MRFade.equalPower(p) + MRFade.equalPower(1 - p) * MRFade.equalPower(1 - p), 1, accuracy: 1e-9)
        }
        dsp.update { $0.fadeTarget = 0; $0.fadeSeconds = MRFade.ambientOut }
        var outCurve: [Double] = []
        for _ in 0..<(48_000 * 2 / 480) {
            buf.withUnsafeMutableBufferPointer { dsp.render(frames: 480, into: $0.baseAddress!) }
            outCurve.append(dsp.fadePosition)
        }
        XCTAssertEqual(outCurve, outCurve.sorted(by: >), "fade-out is monotonic")
        XCTAssertEqual(try XCTUnwrap(outCurve.last), 0, accuracy: 1e-9)
    }

    func testMasterChangeRampsInsteadOfJumping() throws {
        let sound = makeSound()
        sound.setFlightActive(true)
        _ = sound.renderOffline(seconds: 4)
        sound.setMaster(0.1)
        let ramp = try XCTUnwrap(sound.renderOffline(seconds: 1.2))
        let a = energy(ramp, from: 0, to: 0.03), c = energy(ramp, from: 0.9, to: 1.2)
        XCTAssertGreaterThan(a, c * 2, "starts loud, ends quiet")
        // no jump: the first 30 ms are still near the old level (a hard cut would drop immediately)
        XCTAssertGreaterThan(a, c * 3)
        XCTAssertFalse(ramp.hasNonFinite); XCTAssertLessThan(ramp.peak, 1)
    }

    func testChimeFileOverridesSynthesis() throws {
        let sound = makeSound()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-chime-\(UUID().uuidString).caf")
        let samples = (0..<24_000).map { Float(0.3 * sin(2 * .pi * 880 * Double($0) / 48_000)) }
        let tone = MRStereoBuffer(left: samples, right: samples, sampleRate: 48_000)
        do {
            let file = try AVAudioFile(forWriting: url, settings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 48_000,
                                                                   AVNumberOfChannelsKey: 2, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true])
            try file.write(from: MRSound.pcm(tone))
        }
        sound.library.registerChime(.board, url: url)
        let loaded = try XCTUnwrap(MRSound.loadChime(url, sampleRate: 48_000))
        XCTAssertEqual(loaded.duration, 0.5, accuracy: 0.05)
        XCTAssertFalse(loaded.hasNonFinite)
        sound.play(.chime(.board))
        let out = try XCTUnwrap(sound.renderOffline(seconds: 0.8))
        XCTAssertGreaterThan(out.peak, 0.05)
        try? FileManager.default.removeItem(at: url)
    }
}
