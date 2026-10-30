import AVFoundation
import os

// MARK: - Real-time DSP: ambient layers and the paper rip.
// Both are AVAudioSourceNode render blocks fed from lock-protected parameter blocks written by the main thread.
// Recipes: `A.layer` and `A.rip` in docs/design/export/project/meridian-audio.js.

/// Ambient layers of the mixer, in the order of the Mixer artboard.
nonisolated enum MRLayer: String, CaseIterable, Sendable, Hashable, Identifiable {
    case hum, rain, ocean, forest, brown, pink, music
    var id: String { rawValue }
    var title: String {
        switch self {
        case .hum: "Cabin hum"
        case .rain: "Rain"
        case .ocean: "Ocean"
        case .forest: "Forest"
        case .brown: "Brown noise"
        case .pink: "Pink noise"
        case .music: "Soft music"
        }
    }
    /// Per-layer loudness factor `L.k` of the recipes.
    var k: Double {
        switch self {
        case .hum: 1.6
        case .rain: 0.5
        case .ocean: 1.3
        case .forest: 0.3
        case .brown: 1.8
        case .pink: 0.4
        case .music: 1.2
        }
    }
    var index: Int { Self.allCases.firstIndex(of: self)! }
}

nonisolated private let kNoiseSeconds = 2

nonisolated private func makeNoise(seed: UInt64, sampleRate: Double) -> [Float] {
    var r = MRRandom(seed: seed)
    return (0..<Int(sampleRate) * kNoiseSeconds).map { _ in Float(r.signed()) }
}

// MARK: Ambient

nonisolated final class MRAmbientDSP: @unchecked Sendable {
    struct Params: Sendable {
        /// Target gain per layer: level x master x k x 0.22 (0 when muted).
        var gain = [Double](repeating: 0, count: MRLayer.allCases.count)
        /// Raw level x master per layer (drives the forest birds).
        var level = [Double](repeating: 0, count: MRLayer.allCases.count)
        /// Smoothing time constant per layer, seconds (0.08, 0.05 when switching everything off).
        var tc = [Double](repeating: 0.08, count: MRLayer.allCases.count)
        /// Ducking gain target (1 = no ducking, 0.5 = -6 dB).
        var duck = 1.0
    }

    let sampleRate: Double
    private let lock = OSAllocatedUnfairLock(initialState: Params())
    private let noise: [Float]

    // render-thread state
    private var cur = [Double](repeating: 0, count: MRLayer.allCases.count)
    private var pos: [Int]
    private var duckCur = 1.0
    private var cache = Params()
    private var samples = 0
    private var hum1: MRBiquad, hum2: MRBiquad, humSawLP: MRBiquad
    private var rainHP: MRBiquad, rainBP: MRBiquad
    private var oceanLP: MRBiquad
    private var forestBP: MRBiquad
    private var brownLP: MRBiquad, pinkLP: MRBiquad
    private var musicLP: MRBiquad
    private var humPhase = 0.0, oceanPhase = 0.0
    private var musicPhase = [Double](repeating: 0, count: 5), musicLFO = [Double](repeating: 0, count: 5)
    private var birds: [Bird] = []
    private var birdRng = MRRandom(seed: 0xB1D5)
    private var nextBird: Int

    private struct Bird { var start: Int; var f0: Double; var phase = 0.0 }

    private static let musicFreqs: [Double] = [261.63, 329.63, 392, 493.88, 587.33]

    init(sampleRate sr: Double) {
        sampleRate = sr
        noise = makeNoise(seed: 0xA3B1E27, sampleRate: sr)
        pos = (0..<MRLayer.allCases.count).map { $0 * Int(sr * 0.37) }
        hum1 = MRBiquad(.lowpass, frequency: 190, sampleRate: sr)
        hum2 = MRBiquad(.lowpass, frequency: 120, sampleRate: sr)
        humSawLP = MRBiquad(.lowpass, frequency: 160, sampleRate: sr)
        rainHP = MRBiquad(.highpass, frequency: 1200, sampleRate: sr)
        rainBP = MRBiquad(.bandpass, frequency: 5200, q: 0.4, sampleRate: sr)
        oceanLP = MRBiquad(.lowpass, frequency: 520, sampleRate: sr)
        forestBP = MRBiquad(.bandpass, frequency: 2400, q: 0.35, sampleRate: sr)
        brownLP = MRBiquad(.lowpass, frequency: 420, sampleRate: sr)
        pinkLP = MRBiquad(.lowpass, frequency: 2600, sampleRate: sr)
        musicLP = MRBiquad(.lowpass, frequency: 900, sampleRate: sr)
        nextBird = Int(2.6 * sr)
    }

    func update(_ body: (inout Params) -> Void) { lock.withLockUnchecked { body(&$0) } }
    func currentParams() -> Params { lock.withLock { $0 } }

    /// Builds the render node. Created in a nonisolated context on purpose (the block runs on the audio thread).
    func makeNode(format: AVAudioFormat) -> AVAudioSourceNode {
        AVAudioSourceNode(format: format) { [self] _, _, frames, abl -> OSStatus in
            let list = UnsafeMutableAudioBufferListPointer(abl)
            guard let first = list.first, let p0 = first.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            render(frames: Int(frames), into: p0)
            for ch in 1..<max(1, list.count) {
                if let d = list[ch].mData?.assumingMemoryBound(to: Float.self) { d.update(from: p0, count: Int(frames)) }
            }
            return noErr
        }
    }

    /// Renders `frames` mono samples (also used directly by tests).
    func render(frames: Int, into out: UnsafeMutablePointer<Float>) {
        if let fresh = lock.withLockIfAvailable({ $0 }) { cache = fresh }
        let p = cache
        let sr = sampleRate
        let nLayers = MRLayer.allCases.count
        let coef = (0..<nLayers).map { 1 - exp(-1 / (max(p.tc[$0], 1e-4) * sr)) }
        let duckDown = 1 - exp(-1 / (0.12 * sr)), duckUp = 1 - exp(-1 / (0.6 * sr))
        let m = noise.count
        for i in 0..<frames {
            var mix = 0.0
            for L in 0..<nLayers {
                cur[L] += (p.gain[L] - cur[L]) * coef[L]
                if cur[L] < 1e-6 && p.gain[L] < 1e-6 { pos[L] += 1; continue }   // silent, skip work
                let n = Double(noise[pos[L] % m]); pos[L] += 1
                var s = 0.0
                switch L {
                case MRLayer.hum.index:
                    let saw = mrWave(.sawtooth, humPhase); humPhase += 58 / sr; humPhase -= humPhase.rounded(.down)
                    s = hum2.process(hum1.process(n)) + humSawLP.process(saw) * 0.05
                case MRLayer.rain.index:
                    s = rainBP.process(rainHP.process(n))
                case MRLayer.ocean.index:
                    let lfo = sin(2 * .pi * oceanPhase); oceanPhase += 0.11 / sr; oceanPhase -= oceanPhase.rounded(.down)
                    s = oceanLP.process(n) * (0.5 + 0.45 * lfo)
                case MRLayer.forest.index:
                    s = forestBP.process(n) * 0.35
                case MRLayer.brown.index:
                    s = brownLP.process(n)
                case MRLayer.pink.index:
                    s = pinkLP.process(n)
                default:
                    var acc = 0.0
                    for k in 0..<5 {
                        let w: MRWave = k % 2 == 1 ? .triangle : .sine
                        let detune = pow(2.0, Double(k - 2) * 4 / 1200)
                        let o = mrWave(w, musicPhase[k]); musicPhase[k] += Self.musicFreqs[k] * detune / sr; musicPhase[k] -= musicPhase[k].rounded(.down)
                        let lfo = sin(2 * .pi * musicLFO[k]); musicLFO[k] += (0.05 + Double(k) * 0.021) / sr; musicLFO[k] -= musicLFO[k].rounded(.down)
                        acc += o * (0.05 + 0.03 * lfo)
                    }
                    s = musicLP.process(acc)
                }
                mix += s * cur[L]
            }
            // forest birds: a chirp every 2.6 s while the layer is audible; amplitude follows the layer level
            let forestLv = p.level[MRLayer.forest.index]
            if samples + i >= nextBird {
                nextBird += Int(2.6 * sr)
                if forestLv >= 0.02 { birds.append(Bird(start: samples + i, f0: 2600 + birdRng.next() * 1500)) }
            }
            if !birds.isEmpty {
                var j = 0
                while j < birds.count {
                    let age = Double(samples + i - birds[j].start) / sr
                    if age >= 0.3 { birds.remove(at: j); continue }
                    let f0 = birds[j].f0
                    let f = age < 0.08 ? f0 * pow(1.35, age / 0.08) : f0 * 1.35 * pow(0.9 / 1.35, min(1, (age - 0.08) / 0.08))
                    birds[j].phase += f / sr; birds[j].phase -= birds[j].phase.rounded(.down)
                    let peak = 0.05 * forestLv
                    let env = age < 0.01 ? peak * age / 0.01 : peak * pow(1e-4 / max(peak, 1e-4), (age - 0.01) / 0.18)
                    mix += sin(2 * .pi * birds[j].phase) * env
                    j += 1
                }
            }
            duckCur += (p.duck - duckCur) * (p.duck < duckCur ? duckDown : duckUp)
            let x = mix * duckCur * 0.85
            out[i] = Float(abs(x) > 0.7 ? (x > 0 ? 1 : -1) * (0.7 + 0.28 * tanh((abs(x) - 0.7) / 0.28)) : x)
        }
        samples += frames
    }
}

// MARK: Rip

nonisolated final class MRRipDSP: @unchecked Sendable {
    struct Params: Sendable {
        var gain = 0.0          // target
        var gainTc = 0.02
        var bandHz = 1800.0     // target
        var bandTc = 0.03
        var pending: [Crackle] = []
    }
    struct Crackle: Sendable {
        var delay: Int          // frames from the moment it is picked up
        var duration: Double
        var highpass: Double
        var peak: Double
        var noiseOffset: Int
    }
    private struct Active {
        var age: Int; var duration: Double; var peak: Double; var pos: Int
        var hp: MRBiquad
    }

    let sampleRate: Double
    private let lock = OSAllocatedUnfairLock(initialState: Params())
    private let noise: [Float]
    private var cache = Params()
    private var g = 0.0, f = 1800.0
    private var bp: MRBiquad
    private var pos = 0
    private var active: [Active] = []
    private var waiting: [Crackle] = []

    init(sampleRate sr: Double) {
        sampleRate = sr
        noise = makeNoise(seed: 0x71B, sampleRate: sr)
        bp = MRBiquad(.bandpass, frequency: 1800, q: 0.8, sampleRate: sr)
    }

    func update(_ body: (inout Params) -> Void) { lock.withLockUnchecked { body(&$0) } }

    func makeNode(format: AVAudioFormat) -> AVAudioSourceNode {
        AVAudioSourceNode(format: format) { [self] _, _, frames, abl -> OSStatus in
            let list = UnsafeMutableAudioBufferListPointer(abl)
            guard let first = list.first, let p0 = first.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            render(frames: Int(frames), into: p0)
            for ch in 1..<max(1, list.count) {
                if let d = list[ch].mData?.assumingMemoryBound(to: Float.self) { d.update(from: p0, count: Int(frames)) }
            }
            return noErr
        }
    }

    func render(frames: Int, into out: UnsafeMutablePointer<Float>) {
        if let fresh = lock.withLockIfAvailable({ p -> Params in let c = p; p.pending.removeAll(); return c }) {
            cache.gain = fresh.gain; cache.gainTc = fresh.gainTc; cache.bandHz = fresh.bandHz; cache.bandTc = fresh.bandTc
            waiting.append(contentsOf: fresh.pending)
            if waiting.count > 64 { waiting.removeFirst(waiting.count - 64) }
        }
        let sr = sampleRate, m = noise.count
        let gc = 1 - exp(-1 / (max(cache.gainTc, 1e-4) * sr)), fc = 1 - exp(-1 / (max(cache.bandTc, 1e-4) * sr))
        for i in 0..<frames {
            g += (cache.gain - g) * gc
            f += (cache.bandHz - f) * fc
            if i % 32 == 0 { bp.set(.bandpass, frequency: f, q: 0.8, sampleRate: sr) }
            var s = 0.0
            if g > 1e-6 { s = bp.process(Double(noise[pos % m])) * g }
            pos += 1
            // start crackles whose delay elapsed
            if !waiting.isEmpty {
                var k = 0
                while k < waiting.count {
                    waiting[k].delay -= 1
                    if waiting[k].delay <= 0 {
                        let c = waiting.remove(at: k)
                        if active.count < 48 {
                            active.append(Active(age: 0, duration: c.duration, peak: c.peak, pos: c.noiseOffset,
                                                 hp: MRBiquad(.highpass, frequency: c.highpass, sampleRate: sr)))
                        }
                    } else { k += 1 }
                }
            }
            if !active.isEmpty {
                var k = 0
                while k < active.count {
                    let t = Double(active[k].age) / sr
                    let total = active[k].duration + 0.002
                    let a = 0.0005
                    if t > a + total + 0.01 { active.remove(at: k); continue }
                    let env = t < a ? active[k].peak * t / a : active[k].peak * pow(0.0001 / active[k].peak, (t - a) / total)
                    s += active[k].hp.process(Double(noise[active[k].pos % m])) * env
                    active[k].pos += 1; active[k].age += 1
                    k += 1
                }
            }
            out[i] = Float(max(-0.95, min(0.95, s)))
        }
    }
}
