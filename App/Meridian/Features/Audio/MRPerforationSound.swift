import AVFoundation
import Foundation

// MARK: - MRPerforationSound: tearing a ticket stub off its perforation (S14A).
//
//   MRPerforationSound.shared.begin()                     // pointer down: wakes the engine, nothing is audible yet
//   MRPerforationSound.shared.bridges(3, speed: 0.7)      // 3 bridges of the perforation broke ("tik-tik-tik"), speed = pull speed 0...1
//   MRPerforationSound.shared.separate(speed: 0.9)        // the last bridge goes: dry "tak" + a little paper
//   MRPerforationSound.shared.whoosh()                    // the freed stub flies to the wallet
//
// Everything is synthesised once at first use (no samples, no licences): every broken bridge is a very short, dry, high click
// (noise through a 2.4-5.8 kHz band-pass with a 2 ms decay, a damped sine and a tiny second fibre snap about 8 ms later);
// the separation is a sharper click, a short 190 Hz "pat" and a 180 ms rustle; the whoosh is band-passed noise that sweeps up and down.
// Nothing sounds without a bridge breaking, so a hand at rest is silent. It has its own small engine so it does not depend on `MRSound`'s
// buffers, but it follows the same gates (UI sounds switch, Do Not Disturb, master level).
@MainActor
final class MRPerforationSound {
    static let shared = MRPerforationSound()

    /// Overridable for tests.
    var isAllowed: () -> Bool = { MRSound.shared.uiSoundsAllowed }
    var masterLevel: () -> Double = { MRSound.shared.settings.master }

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: MRPerforationSynth.sampleRate, channels: 2, interleaved: false)!
    private var players: [AVAudioPlayerNode] = []
    private var busyUntil: [Date] = []
    private var started = false
    private var available = true
    private var ticks: [[Float]] = []
    private var separation: [Float] = []
    private var whooshBuffer: [Float] = []
    private var rng = MRRandom(seed: UInt64(truncatingIfNeeded: Date().timeIntervalSince1970.bitPattern))
    private(set) var recent: [String] = []

    private init() {}

    private func prepare() {
        guard ticks.isEmpty else { return }
        ticks = MRPerforationSynth.tickVariants()
        separation = MRPerforationSynth.separation()
        whooshBuffer = MRPerforationSynth.whoosh()
    }

    private func startIfNeeded() -> Bool {
        if started { return available }
        started = true
        prepare()
        for _ in 0..<10 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p); busyUntil.append(.distantPast)
        }
        do { engine.prepare(); try engine.start() } catch { available = false }
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { try? self?.engine.start() }
        }
        return available
    }

    // MARK: API

    /// Pointer down: gets the engine ready so the first bridge is not late. Silent.
    func begin() {
        guard isAllowed() else { return }
        _ = startIfNeeded()
    }

    /// `count` bridges broke since the last call. `speed` 0...1 (the smoothed pull speed): louder, brighter and denser when pulled fast; 0 is silent.
    func bridges(_ count: Int, speed: Double) {
        guard count > 0, speed > 0.001, isAllowed(), startIfNeeded() else { return }
        let n = min(count, 10)
        let v = min(1, max(0, speed))
        let gain = Float(0.16 + 0.58 * pow(v, 0.8))
        let sr = MRPerforationSynth.sampleRate
        // a fast pull packs the clicks closer together (down to 1.6 ms), a slow one lets each ring
        let spacing = Int((0.0055 - 0.0039 * v) * sr)
        let len = (ticks.first?.count ?? 0) + spacing * (n - 1)
        var mono = [Float](repeating: 0, count: len)
        for i in 0..<n {
            let bright = Int(min(5, (v * 3 + rng.next() * 3).rounded(.down)))
            let t = ticks[bright % ticks.count]
            let g = gain * Float(0.7 + 0.3 * rng.next())
            let off = i * spacing + Int(rng.next() * 0.0008 * sr)
            for k in 0..<t.count where off + k < len { mono[off + k] += t[k] * g }
        }
        play(mono, pan: Float(rng.next() - 0.5) * 0.4, tag: "bridges\(n)")
    }

    /// The last bridge gives way: a dry "tak", a short "pat" and a little paper.
    func separate(speed: Double) {
        guard isAllowed(), startIfNeeded() else { return }
        let g = Float(0.55 + 0.35 * min(1, max(0, speed)))
        play(separation.map { $0 * g }, pan: 0.05, tag: "separate")
    }

    /// The freed stub flies to the wallet.
    func whoosh() {
        guard isAllowed(), startIfNeeded() else { return }
        play(whooshBuffer, pan: -0.15, tag: "whoosh")
    }

    // MARK: playback

    private func play(_ mono: [Float], pan: Float, tag: String) {
        let master = Float(min(1, max(0, masterLevel())))
        guard master > 0, !mono.isEmpty,
              let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(mono.count)),
              let ch = buf.floatChannelData else { return }
        buf.frameLength = AVAudioFrameCount(mono.count)
        let l = Float(cos((Double(pan) + 1) * .pi / 4)), r = Float(sin((Double(pan) + 1) * .pi / 4))
        let g = master
        for i in 0..<mono.count { let x = mono[i] * g; ch[0][i] = x * l; ch[1][i] = x * r }
        let now = Date()
        let i = busyUntil.firstIndex { $0 <= now } ?? busyUntil.indices.min { busyUntil[$0] < busyUntil[$1] }!
        let node = players[i]
        if busyUntil[i] > now { node.stop() }
        busyUntil[i] = now.addingTimeInterval(Double(mono.count) / MRPerforationSynth.sampleRate)
        node.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        node.play()
        recent.append(tag); if recent.count > 16 { recent.removeFirst() }
    }
}

// MARK: - Synthesis (pure, deterministic)

nonisolated enum MRPerforationSynth {
    static let sampleRate = 44100.0

    /// RBJ band-pass (constant 0 dB peak gain).
    struct Bandpass {
        var b0 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0
        var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
        init(freq: Double, q: Double) { set(freq: freq, q: q) }
        mutating func set(freq: Double, q: Double) {
            let w = 2 * Double.pi * min(freq, sampleRate * 0.45) / sampleRate
            let alpha = sin(w) / (2 * q)
            let a0 = 1 + alpha
            b0 = alpha / a0; b2 = -alpha / a0
            a1 = -2 * cos(w) / a0; a2 = (1 - alpha) / a0
        }
        mutating func process(_ x: Double) -> Double {
            let y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1; x1 = x; y2 = y1; y1 = y
            return y
        }
    }

    /// One-pole high-pass.
    struct Highpass {
        var a: Double, px = 0.0, py = 0.0
        init(freq: Double) { a = exp(-2 * Double.pi * freq / sampleRate) }
        mutating func process(_ x: Double) -> Double { let y = a * (py + x - px); px = x; py = y; return y }
    }

    static func normalize(_ x: inout [Float], peak: Float) {
        let m = x.reduce(0) { max($0, abs($1)) }
        guard m > 0 else { return }
        let k = peak / m
        for i in x.indices { x[i] *= k }
    }

    /// Six short clicks, dark to bright (centre 2.4 ... 5.8 kHz).
    static func tickVariants() -> [[Float]] {
        (0..<6).map { v in
            var rng = MRRandom(seed: UInt64(1000 + v * 37))
            let fc = 2400 + Double(v) * 680
            let n = Int(0.034 * sampleRate)
            var bp = Bandpass(freq: fc, q: 2.4)
            var out = [Float](repeating: 0, count: n)
            let snapAt = Int((0.0065 + rng.next() * 0.004) * sampleRate)   // the second, smaller fibre snap
            for i in 0..<n {
                let t = Double(i) / sampleRate
                let noise = rng.next() * 2 - 1
                let env = min(1, t / 0.0003) * exp(-t / 0.0021)
                var s = bp.process(noise) * env * 2.2
                s += sin(2 * .pi * fc * 0.92 * t) * exp(-t / 0.0012) * 0.38        // the "tik" body
                if i >= snapAt {
                    let u = Double(i - snapAt) / sampleRate
                    s += bp.process(rng.next() * 2 - 1) * exp(-u / 0.0014) * 0.9 * min(1, u / 0.0002)
                }
                out[i] = Float(s)
            }
            normalize(&out, peak: 0.9)
            return out
        }
    }

    /// The last bridge: dry crack (1 ms attack, 6 ms decay, high-passed), 190 Hz "pat" dropping to 120 Hz, 180 ms of paper rustle.
    static func separation() -> [Float] {
        var rng = MRRandom(seed: 777)
        let n = Int(0.36 * sampleRate)
        var hp = Highpass(freq: 1400)
        var bp = Bandpass(freq: 3200, q: 0.9)
        var out = [Float](repeating: 0, count: n)
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let noise = rng.next() * 2 - 1
            var s = hp.process(noise) * min(1, t / 0.0008) * exp(-t / 0.006) * 0.85
            let f = 120 + 90 * exp(-t / 0.03)
            phase += 2 * .pi * f / sampleRate
            s += sin(phase) * min(1, t / 0.001) * exp(-t / 0.032) * 0.55
            // rustle: band-passed noise, 28 Hz crinkle, rises over 15 ms and dies over ~180 ms
            let crinkle = 0.65 + 0.35 * sin(2 * .pi * 28 * t + 1.3) * sin(2 * .pi * 11 * t)
            let renv = min(1, max(0, (t - 0.012) / 0.015)) * exp(-max(0, t - 0.03) / 0.07)
            s += bp.process(rng.next() * 2 - 1) * renv * crinkle * 0.5
            out[i] = Float(s)
        }
        for i in 0..<Int(0.02 * sampleRate) { out[n - 1 - i] *= Float(i) / Float(0.02 * sampleRate) }
        normalize(&out, peak: 0.8)
        return out
    }

    /// A light whoosh: noise through a band-pass sweeping 500 -> 2300 -> 900 Hz, sin^2 envelope, 0.5 s.
    static func whoosh() -> [Float] {
        var rng = MRRandom(seed: 4242)
        let dur = 0.5, n = Int(dur * sampleRate)
        var bp = Bandpass(freq: 500, q: 1.3)
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let t = Double(i) / sampleRate, u = t / dur
            if i % 16 == 0 { bp.set(freq: 500 + 1800 * sin(.pi * pow(u, 0.8)), q: 1.3) }
            let env = pow(sin(.pi * u), 2)
            out[i] = Float(bp.process(rng.next() * 2 - 1) * env)
        }
        normalize(&out, peak: 0.28)
        return out
    }
}
