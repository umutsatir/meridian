import Foundation

// MARK: - DSP primitives shared by the offline cue renderer and the live layers.
// Everything here is plain Swift (no AVFoundation) so it can be unit tested and run off the main actor.
// Ported from docs/design/export/project/meridian-audio.js (Web Audio recipes).

/// Deterministic SplitMix64 generator, so pre-rendered cues are reproducible.
nonisolated struct MRRandom: Sendable {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func nextUInt64() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    /// Uniform in [0, 1).
    mutating func next() -> Double { Double(nextUInt64() >> 11) / Double(1 << 53) }
    /// Uniform in [-1, 1).
    mutating func signed() -> Double { next() * 2 - 1 }
}

nonisolated enum MRWave: Sendable { case sine, square, sawtooth, triangle }

/// Evaluates a waveform at phase in [0, 1) (naive, like a non-band-limited oscillator).
nonisolated func mrWave(_ w: MRWave, _ p: Double) -> Double {
    switch w {
    case .sine: return sin(2 * .pi * p)
    case .square: return p < 0.5 ? 1 : -1
    case .sawtooth: return 2 * p - 1
    case .triangle: return p < 0.5 ? 4 * p - 1 : 3 - 4 * p
    }
}

nonisolated enum MRFilterType: Sendable { case lowpass, highpass, bandpass }

/// RBJ biquad with Web Audio semantics: for low/high-pass `q` is in dB (default 1 dB), for band-pass it is linear.
nonisolated struct MRBiquad: Sendable {
    private var b0 = 1.0, b1 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0
    private var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

    init(_ type: MRFilterType, frequency: Double, q: Double? = nil, sampleRate: Double) {
        set(type, frequency: frequency, q: q, sampleRate: sampleRate)
    }

    mutating func set(_ type: MRFilterType, frequency: Double, q: Double? = nil, sampleRate: Double) {
        let f = min(max(frequency, 1), sampleRate * 0.49)
        let w0 = 2 * Double.pi * f / sampleRate
        let cw = cos(w0), sw = sin(w0)
        var n0 = 1.0, n1 = 0.0, n2 = 0.0
        let alpha: Double
        switch type {
        case .bandpass:
            alpha = sw / (2 * max(q ?? 1, 0.0001))
            n0 = alpha; n1 = 0; n2 = -alpha
        case .lowpass:
            alpha = sw / (2 * pow(10, (q ?? 1) / 20))
            n0 = (1 - cw) / 2; n1 = 1 - cw; n2 = (1 - cw) / 2
        case .highpass:
            alpha = sw / (2 * pow(10, (q ?? 1) / 20))
            n0 = (1 + cw) / 2; n1 = -(1 + cw); n2 = (1 + cw) / 2
        }
        let a0 = 1 + alpha
        b0 = n0 / a0; b1 = n1 / a0; b2 = n2 / a0
        a1 = (-2 * cw) / a0; a2 = (1 - alpha) / a0
    }

    @inline(__always)
    mutating func process(_ x: Double) -> Double {
        let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1; x1 = x; y2 = y1; y1 = y
        return y
    }
}

/// Web Audio AudioParam automation (setValueAtTime, linear / exponential ramps, setTargetAtTime), evaluated offline.
nonisolated struct MRParam: Sendable {
    private enum Kind { case set, linear, exp, target(tc: Double) }
    private struct Event { var kind: Kind; var t: Double; var v: Double }
    private var events: [Event] = []
    var initial: Double

    init(_ initial: Double = 0) { self.initial = initial }

    mutating func set(_ v: Double, at t: Double) { add(.init(kind: .set, t: t, v: v)) }
    mutating func linear(_ v: Double, at t: Double) { add(.init(kind: .linear, t: t, v: v)) }
    mutating func exp(_ v: Double, at t: Double) { add(.init(kind: .exp, t: t, v: v)) }
    mutating func target(_ v: Double, at t: Double, tc: Double) { add(.init(kind: .target(tc: tc), t: t, v: v)) }
    private mutating func add(_ e: Event) {
        var i = events.count
        while i > 0 && events[i - 1].t > e.t { i -= 1 }   // stable: equal times keep insertion order
        events.insert(e, at: i)
    }

    /// The `env(g, t, a, peak, d, rel)` helper of the recipes: 0.0001 at t, linear to peak, exponential back to 0.0001.
    static func envelope(at t: Double, attack a: Double, peak: Double, decay d: Double, release rel: Double) -> MRParam {
        var p = MRParam(1)
        p.set(0.0001, at: t)
        p.linear(peak, at: t + a)
        p.exp(0.0001, at: t + a + d + rel)
        return p
    }

    /// Value at time `t` considering only the first `n` events.
    private func value(at t: Double, upTo n: Int) -> Double {
        var i = -1
        var k = 0
        while k < n, events[k].t <= t { i = k; k += 1 }
        if i < 0 { return initial }
        let e = events[i]
        if i + 1 < n {
            let nx = events[i + 1]
            let isRamp: Bool
            switch nx.kind { case .linear, .exp: isRamp = true; default: isRamp = false }
            if isRamp && nx.t > e.t {
                let v0 = endValue(i), f = (t - e.t) / (nx.t - e.t)
                if case .exp = nx.kind {
                    return (v0 > 0 && nx.v > 0) ? v0 * pow(nx.v / v0, f) : v0
                }
                return v0 + (nx.v - v0) * f
            }
        }
        if case .target(let tc) = e.kind {
            let start = value(at: e.t, upTo: i)
            return e.v + (start - e.v) * Foundation.exp(-(t - e.t) / max(tc, 1e-6))
        }
        return e.v
    }
    private func endValue(_ i: Int) -> Double { events[i].v }

    /// Values for sample indices `first ..< first + count` (time = index / sampleRate).
    func values(first: Int, count: Int, sampleRate sr: Double) -> [Float] {
        let n = events.count
        return (0..<count).map { Float(value(at: Double(first + $0) / sr, upTo: n)) }
    }
}

// MARK: - FFT convolution (used once per cue for the reverb)

nonisolated enum MRFFT {
    static func transform(_ re: inout [Double], _ im: inout [Double], inverse: Bool) {
        let n = re.count
        var j = 0
        for i in 1..<n {
            var bit = n >> 1
            while j & bit != 0 { j ^= bit; bit >>= 1 }
            j ^= bit
            if i < j { re.swapAt(i, j); im.swapAt(i, j) }
        }
        var len = 2
        while len <= n {
            let ang = 2 * Double.pi / Double(len) * (inverse ? 1 : -1)
            let wr = cos(ang), wi = sin(ang)
            var i = 0
            while i < n {
                var cr = 1.0, ci = 0.0
                for k in 0..<(len / 2) {
                    let a = i + k, b = i + k + len / 2
                    let tr = re[b] * cr - im[b] * ci, ti = re[b] * ci + im[b] * cr
                    re[b] = re[a] - tr; im[b] = im[a] - ti
                    re[a] += tr; im[a] += ti
                    let nr = cr * wr - ci * wi
                    ci = cr * wi + ci * wr; cr = nr
                }
                i += len
            }
            len <<= 1
        }
        if inverse { let s = 1.0 / Double(n); for i in 0..<n { re[i] *= s; im[i] *= s } }
    }

    /// Full linear convolution of `x` with `h` (output length x.count + h.count - 1).
    static func convolve(_ x: [Float], _ h: [Float]) -> [Float] {
        guard !x.isEmpty, !h.isEmpty else { return [] }
        let outLen = x.count + h.count - 1
        var n = 1; while n < outLen { n <<= 1 }
        var xr = [Double](repeating: 0, count: n), xi = [Double](repeating: 0, count: n)
        var hr = [Double](repeating: 0, count: n), hi = [Double](repeating: 0, count: n)
        for i in 0..<x.count { xr[i] = Double(x[i]) }
        for i in 0..<h.count { hr[i] = Double(h[i]) }
        transform(&xr, &xi, inverse: false); transform(&hr, &hi, inverse: false)
        for i in 0..<n { let r = xr[i] * hr[i] - xi[i] * hi[i]; xi[i] = xr[i] * hi[i] + xi[i] * hr[i]; xr[i] = r }
        transform(&xr, &xi, inverse: true)
        return (0..<outLen).map { Float(xr[$0]) }
    }
}
