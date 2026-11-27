import Foundation

// MARK: - Fixed sounds ("cues")

/// Kind of chime, see `A.chime` in meridian-audio.js.
nonisolated enum MRChime: String, Sendable, Hashable, CaseIterable {
    /// Airport PA "ding-dong": E5 then C5, soft bell (boarding).
    case board
    /// A single soft "ding" (E5), the end-of-flight counterpart.
    case land
}

/// Every pre-rendered sound of the app. Play with `MRSound.shared.play(_:)`.
nonisolated enum MRCue: Hashable, Sendable {
    /// Ticket printer feed step `i` (0-based): one short burst of a thermal printer, the head hissing over the paper
    /// with the stepper underneath. All steps are the same machine; they differ a little so the run does not sound looped.
    case printerStep(Int)
    /// 1.6 s of paper sliding out of the slot: the bed under the feed steps.
    case paperSlide
    /// The cutter at the end of a print: blade down, a low knock from the mechanism, blade back.
    case printerCut
    /// Short trackpad-style tick; `heavy` is the settle tick.
    case tick(heavy: Bool)
    case click
    /// Soft wallet thud.
    case thump
    case stamp
    case chime(MRChime)
    /// Two sine tones 880 then 660 Hz.
    case seatbelt
    /// Card flip noise sweep 400 to 1200 Hz.
    case whoosh
    /// Split-flap clack.
    case flap
    /// End of a paper rip: noise burst, crackle and 150 Hz thump (`MRSound.shared.rip.finish()` plays it).
    case ripFinish
    /// Soft two-note cabin crew chime (fallback of the cabin crew announcement, not in the web prototype).
    case crewChime

    /// Announcement-class cues follow the "Announcements" switch, everything else follows "UI sounds" (SoundSpec A01).
    var isAnnouncementClass: Bool {
        switch self {
        case .chime, .seatbelt, .crewChime: true
        default: false
        }
    }

    /// Plausible rendered length in seconds (including reverb tail), used by the tests.
    var expectedDuration: ClosedRange<Double> {
        switch self {
        case .printerStep: 0.08...0.2
        case .paperSlide: 1.6...1.8
        case .printerCut: 0.1...0.4
        case .tick: 0.05...0.15
        case .click: 0.02...0.1
        case .thump: 0.25...0.5
        case .stamp: 1.0...2.4
        case .chime(.board): 1.8...3.2
        case .chime(.land): 1.2...3.0
        case .seatbelt: 1.4...2.4
        case .whoosh: 0.25...0.5
        case .flap: 0.03...0.1
        case .ripFinish: 0.3...0.6
        case .crewChime: 2.0...4.0
        }
    }
}

/// Stereo float samples at `sampleRate`.
nonisolated struct MRStereoBuffer: Sendable {
    var left: [Float]
    var right: [Float]
    var sampleRate: Double
    var frames: Int { left.count }
    var duration: Double { Double(frames) / sampleRate }
    var peak: Float {
        var p: Float = 0
        for v in left { p = max(p, abs(v)) }
        for v in right { p = max(p, abs(v)) }
        return p
    }
    var hasNonFinite: Bool { left.contains { !$0.isFinite } || right.contains { !$0.isFinite } }
}

// MARK: - Renderer

nonisolated enum MRCueRenderer {
    static let sampleRate: Double = 48_000

    /// Renders a cue once. Deterministic (seeded noise), safe to call from any thread.
    static func render(_ cue: MRCue, sampleRate sr: Double = sampleRate) -> MRStereoBuffer {
        let s = MRSynth(sampleRate: sr, seed: 0xA11CE)
        switch cue {
        case .printerStep(let i): printer(s, max(0, i), D: 0.084)
        case .paperSlide: paperSlide(s, 1.6)
        case .printerCut: printerCut(s)
        case .tick(let heavy): tick(s, heavy)
        case .click: click(s)
        case .thump: thump(s)
        case .stamp: stamp(s)
        case .chime(let k): chime(s, k)
        case .seatbelt: seatbelt(s)
        case .whoosh: whoosh(s)
        case .flap: flap(s)
        case .ripFinish: ripFinish(s)
        case .crewChime: crewChime(s)
        }
        var out = s.finish()
        applyEdges(&out, cue)
        return out
    }

    /// Cues whose own envelope is already a click-sized transient (ticks, clicks, clacks, printer chirps) keep their attack.
    static func usesEdgeFades(_ cue: MRCue) -> Bool {
        switch cue {
        case .tick, .click, .flap, .printerStep, .printerCut: false
        default: true
        }
    }

    /// Click-free edges: 5 ms raised-cosine fade-in, and a fade-out (30 ms; soft 250 ms tail for cues of 1 s or more).
    static func applyEdges(_ b: inout MRStereoBuffer, _ cue: MRCue) {
        guard usesEdgeFades(cue) else { return }
        edgeFade(&b, fadeIn: 0.005, fadeOut: b.duration >= 1 ? 0.25 : 0.03)
    }

    static func edgeFade(_ b: inout MRStereoBuffer, fadeIn: Double, fadeOut: Double) {
        let n = b.frames
        guard n > 1 else { return }
        let a = min(n / 2, max(1, Int(fadeIn * b.sampleRate))), r = min(n / 2, max(1, Int(fadeOut * b.sampleRate)))
        for i in 0..<a {
            let g = Float(MRFade.raisedCosine(Double(i) / Double(a)))
            b.left[i] *= g; b.right[i] *= g
        }
        for i in 0..<r {
            let g = Float(MRFade.raisedCosine(Double(i) / Double(r)))
            b.left[n - 1 - i] *= g; b.right[n - 1 - i] *= g
        }
    }

    // Thermal printer, one feed step: no tone to speak of. The sound of such a printer is the head and the platen roller
    // dragging paper (band-limited hiss, rippled at the stepper rate) over a quiet motor hum, with a small mechanical
    // tick as the step engages. The previous square-wave chirp read as a buzzer; this is soft and dry.
    private static func printer(_ s: MRSynth, _ i: Int, D: Double) {
        let step = 236.0 * (1 + 0.035 * sin(Double(i) * 2.1))          // micro-steps per second, a touch uneven from step to step
        let level = 1 + 0.12 * sin(Double(i) * 1.3)
        // an envelope that ripples at the stepper rate: swell 10 ms, hold, let go over the last 30 ms
        func ripple(_ peak: Double, depth: Double) -> MRParam {
            var g = MRParam(0); g.set(0, at: 0)
            var k = 0
            while Double(k) / step < D + 0.02 {
                let t = Double(k) / step
                let env = min(1, t / 0.010) * min(1, max(0, (D + 0.02 - t) / 0.030))
                g.linear(peak * env, at: t + 0.25 / step)
                g.linear(peak * env * (1 - depth), at: t + 0.75 / step)
                k += 1
            }
            g.linear(0, at: D + 0.03)
            return g
        }
        var hiss = s.noise(start: 0, stop: D + 0.035, offset: s.random())
        s.filter(&hiss, .bandpass, 2500 + Double(i % 4) * 90, q: 0.7)
        s.gain(&hiss, ripple(0.085 * level, depth: 0.5)); s.out(hiss)
        var air = s.noise(start: 0, stop: D + 0.035, offset: s.random())
        s.filter(&air, .highpass, 5200)
        s.gain(&air, ripple(0.022 * level, depth: 0.3)); s.out(air)
        var hum = s.osc(.triangle, MRParam(step), start: 0, stop: D + 0.035)
        s.filter(&hum, .lowpass, 700)
        s.gain(&hum, ripple(0.015, depth: 0)); s.out(hum)
        var tick = s.noise(start: 0, stop: 0.012, offset: s.random())
        s.filter(&tick, .bandpass, 1900, q: 1.1)
        s.gain(&tick, .envelope(at: 0, attack: 0.001, peak: 0.05, decay: 0.004, release: 0.005)); s.out(tick)
    }

    // The cutter: a dry snip (blade through paper), the knock of the mechanism under it, and the blade springing back.
    private static func printerCut(_ s: MRSynth) {
        var snip = s.noise(start: 0, stop: 0.03, offset: s.random())
        s.filter(&snip, .bandpass, 2300, q: 0.8)
        s.gain(&snip, .envelope(at: 0, attack: 0.001, peak: 0.2, decay: 0.008, release: 0.012)); s.out(snip)
        var f = MRParam(150); f.set(150, at: 0); f.exp(85, at: 0.05)
        var knock = s.osc(.sine, f, start: 0, stop: 0.12)
        s.gain(&knock, .envelope(at: 0, attack: 0.002, peak: 0.2, decay: 0.03, release: 0.05)); s.out(knock)
        var back = s.noise(start: 0.062, stop: 0.085, offset: s.random())
        s.filter(&back, .bandpass, 1500, q: 1)
        s.gain(&back, .envelope(at: 0.062, attack: 0.001, peak: 0.07, decay: 0.005, release: 0.008)); s.out(back)
    }

    // Paper sliding out: a quiet low-passed noise swell, a bed under the chirps.
    private static func paperSlide(_ s: MRSynth, _ L: Double) {
        var n = s.noise(start: 0, stop: L + 0.05, offset: 0, loop: true)
        var f = MRParam(900); f.set(900, at: 0); f.linear(1500, at: L)
        s.filter(&n, .bandpass, f, q: 0.5)
        var g = MRParam(1); g.set(0, at: 0); g.linear(0.05, at: 0.25); g.set(0.05, at: L - 0.2); g.linear(0, at: L)
        s.gain(&n, g); s.out(n)
    }

    private static func tick(_ s: MRSynth, _ heavy: Bool) {
        var f = MRParam(heavy ? 1500 : 2400); f.set(heavy ? 1500 : 2400, at: 0); f.exp(heavy ? 700 : 1400, at: 0.03)
        var o = s.osc(.sine, f, start: 0, stop: 0.08)
        s.gain(&o, .envelope(at: 0, attack: 0.001, peak: heavy ? 0.12 : 0.06, decay: 0.02, release: 0.03)); s.out(o)
    }

    private static func click(_ s: MRSynth) {
        var n = s.noise(start: 0, stop: 0.02, offset: s.random())
        s.filter(&n, .highpass, 2200)
        s.gain(&n, .envelope(at: 0, attack: 0.001, peak: 0.035, decay: 0.006, release: 0.005)); s.out(n)
    }

    private static func thump(_ s: MRSynth) {
        var f = MRParam(110); f.set(110, at: 0); f.exp(60, at: 0.12)
        var o = s.osc(.sine, f, start: 0, stop: 0.3)
        s.gain(&o, .envelope(at: 0, attack: 0.003, peak: 0.3, decay: 0.08, release: 0.12)); s.out(o)
    }

    // Stamp: 80 -> 45 Hz sine drop over 120 ms + 3 ms noise click + room tail.
    private static func stamp(_ s: MRSynth) {
        var f = MRParam(80); f.set(80, at: 0); f.exp(45, at: 0.12)
        var o = s.osc(.sine, f, start: 0, stop: 0.5)
        s.gain(&o, .envelope(at: 0, attack: 0.002, peak: 0.55, decay: 0.1, release: 0.22)); s.out(o, send: 0.35)
        var n = s.noise(start: 0, stop: 0.02, offset: s.random())
        s.filter(&n, .bandpass, 1400, q: 0.9)
        s.gain(&n, .envelope(at: 0, attack: 0.0006, peak: 0.22, decay: 0.003, release: 0.004)); s.out(n, send: 0.4)
    }

    private static func bell(_ s: MRSynth, _ f: Double, _ t: Double, _ peak: Double, _ dec: Double) {
        for (mult, amp) in [(1.0, 1.0), (2.76, 0.28), (5.4, 0.1)] {
            var o = s.osc(.sine, MRParam(f * mult), start: t, stop: t + dec + 0.4)
            s.gain(&o, .envelope(at: t, attack: 0.006, peak: peak * amp, decay: dec * (mult > 1 ? 0.55 : 1), release: 0.1))
            s.out(o, send: 0.5)
        }
    }

    // Airport PA "ding-dong": a soft bell, two notes (E5 then C5, 0.5 s apart) for boarding, one E5 "ding" for landing.
    // Partials 1 / 2.76 / 5.4 (bell-like), a slow-ish 25 ms swell instead of a hard strike, light room send.
    private static func chime(_ s: MRSynth, _ kind: MRChime) {
        switch kind {
        case .board:
            paBell(s, 659.25, 0, 0.17, 1.15)
            paBell(s, 523.25, 0.52, 0.17, 1.35)
        case .land:
            paBell(s, 659.25, 0, 0.15, 1.3)
        }
    }

    private static func paBell(_ s: MRSynth, _ f: Double, _ t: Double, _ peak: Double, _ dec: Double) {
        for (mult, amp) in [(1.0, 1.0), (2.76, 0.22), (5.4, 0.06)] {
            var o = s.osc(.sine, MRParam(f * mult), start: t, stop: t + dec + 0.5)
            s.gain(&o, .envelope(at: t, attack: 0.025, peak: peak * amp, decay: dec * (mult > 1 ? 0.45 : 1), release: 0.25))
            s.out(o, send: 0.35)
        }
    }

    private static func crewChime(_ s: MRSynth) {
        bell(s, 523.25, 0, 0.1, 1.0)
        bell(s, 783.99, 0.2, 0.1, 1.0)
    }

    // Two sine tones 880 then 660, 180 ms each.
    private static func seatbelt(_ s: MRSynth) {
        for (f, t) in [(880.0, 0.0), (660.0, 0.2)] {
            var o = s.osc(.sine, MRParam(f), start: t, stop: t + 0.45)
            s.gain(&o, .envelope(at: t, attack: 0.012, peak: 0.13, decay: 0.12, release: 0.14)); s.out(o, send: 0.55)
        }
    }

    // Card flip: filtered noise sweep 400 -> 1200 Hz, 250 ms.
    private static func whoosh(_ s: MRSynth) {
        var n = s.noise(start: 0, stop: 0.3, offset: s.random())
        var f = MRParam(400); f.set(400, at: 0); f.exp(1200, at: 0.25)
        s.filter(&n, .bandpass, f, q: 1.1)
        s.gain(&n, .envelope(at: 0, attack: 0.06, peak: 0.12, decay: 0.1, release: 0.12)); s.out(n)
    }

    // Split-flap clack.
    private static func flap(_ s: MRSynth) {
        var n = s.noise(start: 0, stop: 0.03, offset: s.random() * 1.8)
        s.filter(&n, .bandpass, 2600, q: 2.2)
        s.gain(&n, .envelope(at: 0, attack: 0.0008, peak: 0.07, decay: 0.006, release: 0.008)); s.out(n)
    }

    // Rip finish: rising band-pass sweep, 18 crackles and a 150 Hz thump at 200 ms.
    private static func ripFinish(_ s: MRSynth) {
        var n = s.noise(start: 0, stop: 0.36, offset: 0, loop: true)
        var f = MRParam(1800); f.set(1800, at: 0); f.linear(4000, at: 0.2)
        s.filter(&n, .bandpass, f, q: 0.8)
        var g = MRParam(1); g.set(0.12, at: 0); g.linear(0.5, at: 0.18); g.linear(0, at: 0.24)
        s.gain(&n, g); s.out(n)
        for k in 0..<18 { crackle(s, at: Double(k) * 0.012, v: 1) }
        var th = s.osc(.sine, MRParam(150), start: 0.2, stop: 0.45)
        s.gain(&th, .envelope(at: 0.2, attack: 0.004, peak: 0.3, decay: 0.08, release: 0.1)); s.out(th)
    }

    private static func crackle(_ s: MRSynth, at t: Double, v: Double) {
        let d = 0.002 + s.random() * 0.006
        var c = s.noise(start: t, stop: t + d + 0.01, offset: s.random() * 1.8)
        s.filter(&c, .highpass, 1800 + s.random() * 2400)
        s.gain(&c, .envelope(at: t, attack: 0.0005, peak: 0.06 + v * 0.12, decay: d, release: 0.002)); s.out(c)
    }
}

// MARK: - Offline graph emulation

/// A tiny offline "Web Audio context": oscillator / noise sources, filters, gain automation, a dry bus and a reverb send.
nonisolated final class MRSynth {
    struct Seg { var start: Int; var x: [Float] }

    let sr: Double
    private var rng: MRRandom
    private let noiseBuf: [Float]
    private var dry: [Float] = []
    private var wet: [Float] = []
    private var end = 0
    private var usesReverb = false

    init(sampleRate: Double, seed: UInt64) {
        sr = sampleRate
        rng = MRRandom(seed: seed)
        var r = MRRandom(seed: 0x5EED)
        noiseBuf = (0..<Int(sampleRate * 2)).map { _ in Float(r.signed()) }
    }

    func random() -> Double { rng.next() }
    private func idx(_ t: Double) -> Int { max(0, Int((t * sr).rounded())) }

    func osc(_ wave: MRWave, _ freq: MRParam, start: Double, stop: Double) -> Seg {
        let a = idx(start), b = idx(stop), n = max(0, b - a)
        let f = freq.values(first: a, count: n, sampleRate: sr)
        var out = [Float](repeating: 0, count: n)
        var phase = 0.0
        for i in 0..<n {
            out[i] = Float(mrWave(wave, phase))
            phase += Double(f[i]) / sr
            phase -= phase.rounded(.down)
        }
        return Seg(start: a, x: out)
    }

    /// White noise read from the 2 s buffer starting `offset` seconds in (looping if requested, else silent after its end).
    func noise(start: Double, stop: Double, offset: Double, loop: Bool = false) -> Seg {
        let a = idx(start), b = idx(stop), n = max(0, b - a), o = idx(offset), m = noiseBuf.count
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let j = o + i
            if loop { out[i] = noiseBuf[j % m] } else if j < m { out[i] = noiseBuf[j] }
        }
        return Seg(start: a, x: out)
    }

    func filter(_ seg: inout Seg, _ type: MRFilterType, _ freq: Double, q: Double? = nil) {
        var bq = MRBiquad(type, frequency: freq, q: q, sampleRate: sr)
        for i in 0..<seg.x.count { seg.x[i] = Float(bq.process(Double(seg.x[i]))) }
    }

    func filter(_ seg: inout Seg, _ type: MRFilterType, _ freq: MRParam, q: Double? = nil) {
        let f = freq.values(first: seg.start, count: seg.x.count, sampleRate: sr)
        var bq = MRBiquad(type, frequency: Double(f.first ?? 1000), q: q, sampleRate: sr)
        for i in 0..<seg.x.count {
            if i % 16 == 0 { bq.set(type, frequency: Double(f[i]), q: q, sampleRate: sr) }
            seg.x[i] = Float(bq.process(Double(seg.x[i])))
        }
    }

    func gain(_ seg: inout Seg, _ g: MRParam) {
        let v = g.values(first: seg.start, count: seg.x.count, sampleRate: sr)
        for i in 0..<seg.x.count { seg.x[i] *= v[i] }
    }

    /// Adds the segment to the master bus; `send` additionally feeds the reverb.
    func out(_ seg: Seg, send: Double? = nil) {
        let e = seg.start + seg.x.count
        if e > dry.count { dry += [Float](repeating: 0, count: e - dry.count) }
        for i in 0..<seg.x.count { dry[seg.start + i] += seg.x[i] }
        end = max(end, e)
        if let send {
            usesReverb = true
            if e > wet.count { wet += [Float](repeating: 0, count: e - wet.count) }
            let k = Float(send)
            for i in 0..<seg.x.count { wet[seg.start + i] += seg.x[i] * k }
        }
    }

    // 1.3 s decaying stereo noise impulse ("soft room"), wet level 0.55.
    private static func impulse(sampleRate sr: Double) -> (l: [Float], r: [Float]) {
        let n = Int(sr * 1.3)
        func chan(_ seed: UInt64) -> [Float] {
            var r = MRRandom(seed: seed)
            return (0..<n).map { i in Float(r.signed() * pow(1 - Double(i) / Double(n), 2.6)) }
        }
        return (chan(0x1E_F7), chan(0x1E_F8))
    }

    /// Mixes the dry bus and the reverb, applies the master gain (0.85) and the compressor (-16 dB, 3:1), returns stereo.
    func finish() -> MRStereoBuffer {
        var l = dry, r = dry
        if usesReverb {
            let ir = Self.impulse(sampleRate: sr)
            let wl = MRFFT.convolve(wet, ir.l), wr = MRFFT.convolve(wet, ir.r)
            let n = max(wl.count, l.count)
            // Like a Web Audio ConvolverNode (normalize = true): scale the IR to unit energy, then the 0.55 wet gain.
            let energy = ir.l.reduce(0.0) { $0 + Double($1 * $1) }
            let norm: Float = 0.55 * Float(1.0 / max(energy, 1e-9).squareRoot())
            l += [Float](repeating: 0, count: n - l.count); r += [Float](repeating: 0, count: n - r.count)
            for i in 0..<wl.count { l[i] += wl[i] * norm; r[i] += wr[i] * norm }
        }
        // Tail trim: drop trailing near-silence but keep a little air.
        var last = l.count
        while last > 1, abs(l[last - 1]) < 1e-5, abs(r[last - 1]) < 1e-5 { last -= 1 }
        let keep = min(l.count, max(last + Int(sr * 0.02), end))
        l = Array(l[0..<keep]); r = Array(r[0..<keep])
        Self.master(&l, &r, sampleRate: sr)
        return MRStereoBuffer(left: l, right: r, sampleRate: sr)
    }

    private static func master(_ l: inout [Float], _ r: inout [Float], sampleRate sr: Double) {
        let thresh = -16.0, ratio = 3.0, knee = 30.0
        let atk = 1 - exp(-1 / (0.003 * sr)), rel = 1 - exp(-1 / (0.25 * sr))
        var env = 0.0
        for i in 0..<l.count {
            let x = Double(max(abs(l[i]), abs(r[i])))
            env += (x > env ? atk : rel) * (x - env)
            let db = 20 * log10(max(env, 1e-9))
            var over = 0.0
            if 2 * (db - thresh) < -knee { over = 0 }
            else if 2 * abs(db - thresh) <= knee { let u = db - thresh + knee / 2; over = (1 - 1 / ratio) * u * u / (2 * knee) }
            else { over = (1 - 1 / ratio) * (db - thresh) }
            let g = Float(pow(10, -over / 20)) * 0.85
            l[i] *= g; r[i] *= g
        }
        // Safety: never exceed full scale.
        var peak: Float = 0
        for i in 0..<l.count { peak = max(peak, abs(l[i]), abs(r[i])) }
        if peak > 0.98 { let k = 0.98 / peak; for i in 0..<l.count { l[i] *= k; r[i] *= k } }
    }
}
