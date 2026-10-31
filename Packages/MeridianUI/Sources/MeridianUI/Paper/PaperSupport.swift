import SwiftUI
import CoreGraphics

// Shared helpers for the "paper" components (boarding pass, stamps, membership card).
// Everything here is a port of the canvas helpers in `meridian-kit.js` (rng, hash, barcode, worldFit, arc)
// so the same ticket gets the same torn edge, barcode and route watermark as in the design.

/// `rng(seed)` from meridian-kit.js: mulberry32. Same seed, same sequence, in JS and Swift.
public struct PaperRandom: Sendable {
    private var a: UInt32
    public init(seed: UInt32) { a = seed }
    public mutating func next() -> Double {
        a = a &+ 0x6D2B_79F5
        var t = (a ^ (a >> 15)) &* (1 | a)
        t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
        return Double(t ^ (t >> 14)) / 4_294_967_296
    }
}

public enum PaperHash {
    /// `hash(s)` from meridian-kit.js: FNV-1a over UTF-16 code units.
    public static func fnv1a(_ s: String) -> UInt32 {
        var h: UInt32 = 2_166_136_261
        for u in s.utf16 { h ^= UInt32(u); h = h &* 16_777_619 }
        return h
    }
}

// MARK: - Colors

enum PaperInk {
    static let paper = Color(hex: "#F5F0E6")
    static let ink = Color(hex: "#14110F")
    static let ink92 = Color(hex: "#14110F").opacity(0.92)
    static let caption = Color(hex: "#14110F").opacity(0.7)
    static let hair = Color(hex: "#14110F").opacity(0.14)
    static let stampOK = Color(hex: "#08613F")
    static let stampWarn = Color(hex: "#8C4B08")
    static let stampBlue = Color(hex: "#243F8F")
    static let stampRed = Color(hex: "#A82A24")
    static let amber = Color(hex: "#FFB547")

    /// CSS `color-mix(in srgb, a pa%, b pb%)` (percentages summing below 100 reduce alpha, as in CSS).
    static func mix(_ a: RGB, _ pa: Double, _ b: RGB, _ pb: Double) -> Color {
        let sum = pa + pb
        let wa = pa / sum, wb = pb / sum
        return Color(RGB(r: a.r * wa + b.r * wb, g: a.g * wa + b.g * wb, b: a.b * wa + b.b * wb, a: min(1, sum / 100)))
    }
    static func rgb(_ hex: String) -> RGB { HexColor.parse(hex) ?? RGB(r: 0, g: 0, b: 0) }
}

// MARK: - Text and layout helpers

extension View {
    /// Absolute placement inside a top-leading `ZStack` (CSS `position:absolute; left/top`).
    func at(_ x: CGFloat, _ y: CGFloat) -> some View { offset(x: x, y: y) }
}

/// One line of text with CSS metrics: font family/size/weight, letter-spacing in em, line-height box.
struct PaperText: View {
    let text: String
    let family: MRFontVariant
    let size: CGFloat
    let weight: Int
    var lineHeight: CGFloat
    var tracking: CGFloat = 0     // em
    var italic = false
    var color: Color = PaperInk.ink92

    init(_ text: String, _ family: MRFontVariant = .standard, size: CGFloat, weight: Int = 400, lh: CGFloat? = nil,
         tracking: CGFloat = 0, italic: Bool = false, color: Color = PaperInk.ink92) {
        self.text = text; self.family = family; self.size = size; self.weight = weight
        self.lineHeight = lh ?? size; self.tracking = tracking; self.italic = italic; self.color = color
    }

    var body: some View {
        Text(text)
            .font(MRFonts.font(family.family, size: size, weight: weight, italic: italic))
            .tracking(tracking * size)
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize()
            .frame(height: lineHeight)
    }
}

extension MRFontVariant {
    var familyKind: MRFonts.Family { family }
}

// MARK: - Grain and wear tiles

enum PaperTextures {
    /// Pre-rendered paper grain tile standing in for `paper-grain.svg` (feTurbulence, baseFrequency .9, matrix
    /// `0 0 0 .9 -.34` alpha, warm brown). 240 pt square at 2x. Deterministic.
    static let grain: CGImage? = {
        let px = 480
        var rng = PaperRandom(seed: 7)
        var data = [UInt8](repeating: 0, count: px * px * 4)
        // two octaves of lattice noise: base period ~1.1 px (freq .9) at 2x device pixels, plus a half-weight finer octave
        func lattice(_ n: Int, _ seed: UInt32) -> [Double] {
            var r = PaperRandom(seed: seed)
            return (0..<(n * n)).map { _ in r.next() }
        }
        let n1 = lattice(px / 2 + 1, 11), n2 = lattice(px + 1, 29)
        func sample(_ g: [Double], _ n: Int, _ x: Double, _ y: Double) -> Double {
            let xi = Int(x) % (n - 1), yi = Int(y) % (n - 1)
            let fx = x - floor(x), fy = y - floor(y)
            let sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy)
            let a = g[yi * n + xi], b = g[yi * n + xi + 1], c = g[(yi + 1) * n + xi], d = g[(yi + 1) * n + xi + 1]
            return (a + (b - a) * sx) + ((c + (d - c) * sx) - (a + (b - a) * sx)) * sy
        }
        _ = rng.next()
        for y in 0..<px {
            for x in 0..<px {
                let v1 = sample(n1, px / 2 + 1, Double(x) * 0.5 / 1.1 * 2.2 / 2, Double(y) * 0.5 / 1.1 * 2.2 / 2)
                let v2 = sample(n2, px + 1, Double(x), Double(y))
                // fractal sum, centred on .5 with perlin-like spread
                let noise = 0.5 + (v1 - 0.5) * 0.62 + (v2 - 0.5) * 0.31
                let alpha = max(0, min(1, 0.9 * noise - 0.34 + 0.02))
                let i = (y * px + x) * 4
                let a = alpha * 0.32
                data[i] = UInt8(a * 0.28 * 255)       // premultiplied
                data[i + 1] = UInt8(a * 0.20 * 255)
                data[i + 2] = UInt8(a * 0.12 * 255)
                data[i + 3] = UInt8(a * 255)
            }
        }
        return makeImage(data, px, px)
    }()

    static func makeImage(_ data: [UInt8], _ w: Int, _ h: Int) -> CGImage? {
        let cs = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let provider = CGDataProvider(data: Data(data) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: cs,
                       bitmapInfo: CGBitmapInfo(rawValue: info), provider: provider, decode: nil, shouldInterpolate: true,
                       intent: .defaultIntent)
    }

    /// Ink wear mask: opaque where the stamp ink prints, transparent holes elsewhere. Mirrors the `holes` branch of the
    /// stamp filter (fractal noise at a high frequency, thresholded). `keep` is the fraction of area that stays inked.
    static func wearMask(seed: UInt32, size: Int = 256, keep: Double) -> CGImage? {
        var rng = PaperRandom(seed: seed &* 2_654_435_761 &+ 12_345)
        let cell = 3
        let n = size / cell + 2
        let g: [Double] = (0..<(n * n)).map { _ in rng.next() }
        var data = [UInt8](repeating: 0, count: size * size * 4)
        for y in 0..<size {
            for x in 0..<size {
                let fx = Double(x) / Double(cell), fy = Double(y) / Double(cell)
                let xi = Int(fx), yi = Int(fy)
                let tx = fx - Double(xi), ty = fy - Double(yi)
                let sx = tx * tx * (3 - 2 * tx), sy = ty * ty * (3 - 2 * ty)
                let a = g[yi * n + xi], b = g[yi * n + xi + 1], c = g[(yi + 1) * n + xi], d = g[(yi + 1) * n + xi + 1]
                let top = a + (b - a) * sx, bot = c + (d - c) * sx
                let v = top + (bot - top) * sy
                // soft threshold: alpha ramps from 0 to 1 around the (1 - keep) quantile of the noise
                let t = (v - (1 - keep) + 0.08) / 0.16
                let alpha = max(0, min(1, t))
                let i = (y * size + x) * 4
                let a8 = UInt8(alpha * 255)
                data[i] = a8; data[i + 1] = a8; data[i + 2] = a8; data[i + 3] = a8
            }
        }
        return makeImage(data, size, size)
    }
}

/// Tiled grain over a clipped shape: `.paper::before` (240 pt tile, 55 % opacity, multiply).
struct PaperGrain: View {
    var body: some View {
        if let cg = PaperTextures.grain {
            Image(decorative: cg, scale: 2)
                .resizable(resizingMode: .tile)
                .opacity(0.55)
                .blendMode(.multiply)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Geography

public struct PaperCoordinate: Sendable, Hashable {
    public var lat: Double
    public var lon: Double
    public init(lat: Double, lon: Double) { self.lat = lat; self.lon = lon }
}

enum PaperGeo {
    /// Equirectangular 1440 x 720 (`EQ.xy`).
    static func eq(_ c: PaperCoordinate) -> CGPoint {
        CGPoint(x: (c.lon + 180) / 360 * 1440, y: (90 - c.lat) / 180 * 720)
    }

    struct Fit { var s: CGFloat; var ox: CGFloat; var oy: CGFloat; var p: CGPoint; var q: CGPoint }

    /// `worldFit(a, b, bw, bh)`: world-map mask size/offset so both airports sit inside a bw x bh box.
    static func fit(_ a: PaperCoordinate, _ b: PaperCoordinate, _ bw: CGFloat, _ bh: CGFloat) -> Fit {
        let P = eq(a), Q = eq(b)
        let dx = abs(P.x - Q.x) / 1440, dy = abs(P.y - Q.y) / 720
        var s = min(bw * 0.7 / max(dx, 0.002), bh * 1.6 / max(dy, 0.002))
        s = max(bw * 1.1, min(s, 6000))
        let mx = (P.x + Q.x) / 2 / 1440 * s, my = (P.y + Q.y) / 2 / 720 * (s / 2)
        let ox = bw / 2 - mx, oy = bh / 2 - my
        return Fit(s: s, ox: ox, oy: oy,
                   p: CGPoint(x: P.x / 1440 * s + ox, y: P.y / 720 * (s / 2) + oy),
                   q: CGPoint(x: Q.x / 1440 * s + ox, y: Q.y / 720 * (s / 2) + oy))
    }

    /// Great-circle points (lat, lon), `arc(p, q, n)`.
    static func arc(_ p: PaperCoordinate, _ q: PaperCoordinate, n: Int) -> [PaperCoordinate] {
        let r = Double.pi / 180
        let f1 = p.lat * r, l1 = p.lon * r, f2 = q.lat * r, l2 = q.lon * r
        let d = 2 * asin(sqrt(pow(sin((f2 - f1) / 2), 2) + cos(f1) * cos(f2) * pow(sin((l2 - l1) / 2), 2)))
        guard d > 1e-6 else { return [p] }
        return (0...n).map { i in
            let f = Double(i) / Double(n)
            let A = sin((1 - f) * d) / sin(d), B = sin(f * d) / sin(d)
            let x = A * cos(f1) * cos(l1) + B * cos(f2) * cos(l2)
            let y = A * cos(f1) * sin(l1) + B * cos(f2) * sin(l2)
            let z = A * sin(f1) + B * sin(f2)
            return PaperCoordinate(lat: atan2(z, sqrt(x * x + y * y)) / r, lon: atan2(y, x) / r)
        }
    }
}

/// `world-land.svg` (1440 x 720 land polygons), parsed once.
enum PaperWorld {
    static let land: Path = {
        guard let url = Bundle.module.url(forResource: "world-land", withExtension: "svg", subdirectory: "Paper"),
              let text = try? String(contentsOf: url, encoding: .utf8),
              let r = text.range(of: " d=\"")
        else { return Path() }
        let rest = text[r.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return Path() }
        return SVGPath.parse(String(rest[..<end]))
    }()
}

/// `.dotmap`: a 5 px dot grid masked by the land polygons, positioned like the canvas mask (size `s`, offset `ox, oy`).
struct PaperDotMap: View {
    let s: CGFloat, ox: CGFloat, oy: CGFloat
    let size: CGSize
    var color: Color = PaperInk.ink

    var body: some View {
        Canvas { ctx, sz in
            let k = s / 1440
            let land = PaperWorld.land.applying(CGAffineTransform(a: k, b: 0, c: 0, d: k, tx: ox, ty: oy))
            var dots = Path()
            let step: CGFloat = 5, r: CGFloat = 1.45
            var y = step / 2
            while y < sz.height {
                var x = step / 2
                while x < sz.width {
                    dots.addEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
                    x += step
                }
                y += step
            }
            ctx.clip(to: land)
            ctx.fill(dots, with: .color(color))
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
}
