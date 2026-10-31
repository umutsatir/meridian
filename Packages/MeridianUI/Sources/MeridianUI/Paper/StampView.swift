import SwiftUI

public enum StampShape: String, Sendable, CaseIterable { case round, oval, octagon, rosette }

/// Entrance animation of a stamp (MotionSpec M09 / M12).
public enum StampAnimation: Sendable {
    /// Landing stamp: 160 % faint -> 96 % inked at 60 ms (thump) -> 100 % at 180 ms (bleed).
    case landing
    /// Passport page: 145 % -> 98 % at 55 ms -> 105 % at 156 ms -> 100 % at 460 ms.
    case passport
}

/// Passport / ticket stamp, 160 pt wide design space scaled to `size` (Stamp.dc.html). Seeded wear, ink color from the scenario.
public struct StampView: View {
    let shape: StampShape
    let country: String, code: String, date: String, kind: String, cc: String
    let ink: Color
    let rotation: Double
    let size: CGFloat
    let locked: Bool
    let seed: UInt32
    let animation: StampAnimation?
    let onThump: (@Sendable () -> Void)?
    @State private var played = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(shape: StampShape = .round, country: String = "FRANCE", code: String = "CDG", date: String = "29 OCT 2026",
                kind: String = "ARRIVAL", cc: String = "FR", ink: Color = PaperStampInk.blue, rotation: Double = -6,
                size: CGFloat = 150, locked: Bool = false, seed: UInt32 = 3,
                animation: StampAnimation? = nil, onThump: (@Sendable () -> Void)? = nil) {
        self.shape = shape; self.country = country.uppercased(); self.code = code.uppercased(); self.date = date.uppercased()
        self.kind = kind.uppercased(); self.cc = cc.uppercased(); self.ink = ink; self.rotation = rotation; self.size = size
        self.locked = locked; self.seed = seed; self.animation = animation; self.onThump = onThump
    }

    static func viewHeight(_ s: StampShape) -> CGFloat { s == .oval ? 116 : s == .octagon ? 124 : 160 }

    var height: CGFloat { size * StampView.viewHeight(shape) / 160 }

    public var body: some View {
        let still = StampBody(shape: shape, country: country, code: code, date: date, kind: kind, cc: cc,
                              ink: locked ? PaperInk.ink : ink, size: size, locked: locked, seed: seed)
        Group {
            if let animation, !locked { animated(still, animation) }
            else { still.rotationEffect(.degrees(rotation)).opacity(0.94) }
        }
        .blendMode(.multiply)
        .frame(width: size, height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((locked ? "Not yet visited: " : "Passport stamp: ") + country.capitalized)
    }

    private struct Pose { var scale = 1.0, opacity = 1.0, blur = 0.0, rot = 0.0 }

    private static func recipe(_ a: StampAnimation) -> (Pose, [(Double, Pose)]) {
        switch a {
        case .landing:
            return (Pose(scale: 1.6, opacity: 0.22, blur: 1.6, rot: 0),
                    [(0.060, Pose(scale: 0.96, opacity: 1, blur: 0.2)), (0.120, Pose(scale: 1, opacity: 0.92, blur: 0))])
        case .passport:
            return (Pose(scale: 1.45, opacity: 0.15, blur: 0, rot: -6),
                    [(0.055, Pose(scale: 0.98, opacity: 1)), (0.101, Pose(scale: 1.05, opacity: 0.96, blur: 0.5)), (0.304, Pose(scale: 1, opacity: 0.94))])
        }
    }

    @ViewBuilder private func animated(_ still: StampBody, _ a: StampAnimation) -> some View {
        if reduceMotion {
            still.rotationEffect(.degrees(rotation)).opacity(0.94).transition(.opacity)
        } else {
            let (start, k) = Self.recipe(a)
            KeyframeAnimator(initialValue: start, trigger: played) { p in
                still.scaleEffect(p.scale).blur(radius: p.blur).opacity(p.opacity).rotationEffect(.degrees(rotation + p.rot))
            } keyframes: { _ in
                KeyframeTrack(\.scale) { for (i, e) in k.enumerated() { CubicKeyframe(e.1.scale, duration: e.0 - (i > 0 ? k[i - 1].0 : 0)) } }
                KeyframeTrack(\.opacity) { for (i, e) in k.enumerated() { LinearKeyframe(e.1.opacity, duration: e.0 - (i > 0 ? k[i - 1].0 : 0)) } }
                KeyframeTrack(\.blur) { for (i, e) in k.enumerated() { LinearKeyframe(e.1.blur, duration: e.0 - (i > 0 ? k[i - 1].0 : 0)) } }
                KeyframeTrack(\.rot) { for (i, e) in k.enumerated() { LinearKeyframe(0, duration: e.0 - (i > 0 ? k[i - 1].0 : 0)) } }
            }
            .onAppear {
                played = true
                if let onThump { Task { try? await Task.sleep(for: .milliseconds(60)); onThump() } }
            }
        }
    }
}

/// Ink colors for stamps on paper (`--stamp-*`).
public enum PaperStampInk {
    public static let ok = Color(hex: "#08613F")
    public static let warn = Color(hex: "#8C4B08")
    public static let blue = Color(hex: "#243F8F")
    public static let red = Color(hex: "#A82A24")
}

private struct StampBody: View {
    let shape: StampShape
    let country: String, code: String, date: String, kind: String, cc: String
    let ink: Color
    let size: CGFloat
    let locked: Bool
    let seed: UInt32

    private struct Line { var d: String; var w: CGFloat; var fill = false; var dash: [CGFloat] = [] }
    private struct Label { var t: String; var x: CGFloat; var y: CGFloat; var fs: CGFloat; var ls: CGFloat; var mono: Bool; var rot: Double = 0 }

    private static func f(_ v: CGFloat) -> String { String(format: "%.2f", Double(v)) }
    private static func circ(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> String {
        "M\(f(cx - r)) \(f(cy))a\(f(r)) \(f(r)) 0 1 0 \(f(2 * r)) 0a\(f(r)) \(f(r)) 0 1 0 \(f(-2 * r)) 0Z"
    }
    private static func ell(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> String {
        "M\(f(cx - rx)) \(f(cy))a\(f(rx)) \(f(ry)) 0 1 0 \(f(2 * rx)) 0a\(f(rx)) \(f(ry)) 0 1 0 \(f(-2 * rx)) 0Z"
    }
    private static func oct(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat, _ c: CGFloat) -> String {
        "M\(x0 + c) \(y0)H\(x1 - c)L\(x1) \(y0 + c)V\(y1 - c)L\(x1 - c) \(y1)H\(x0 + c)L\(x0) \(y1 - c)V\(y0 + c)Z"
    }
    private static func ticks(_ cx: CGFloat, _ cy: CGFloat, _ r0: CGFloat, _ r1: CGFloat, _ n: Int) -> String {
        (0..<n).map { i in
            let a = CGFloat(i) / CGFloat(n) * .pi * 2
            return "M\(f(cx + r0 * cos(a))) \(f(cy + r0 * sin(a)))L\(f(cx + r1 * cos(a))) \(f(cy + r1 * sin(a)))"
        }.joined()
    }
    private static func star(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> String {
        var d = ""
        for i in 0..<10 {
            let a = -CGFloat.pi / 2 + CGFloat(i) * .pi / 5, rr = i % 2 == 1 ? r * 0.42 : r
            d += (i == 0 ? "M" : "L") + "\(f(cx + rr * cos(a))) \(f(cy + rr * sin(a)))"
        }
        return d + "Z"
    }
    private static func scallop(_ cx: CGFloat, _ cy: CGFloat, _ R: CGFloat, _ n: Int) -> String {
        let ch = 2 * R * sin(.pi / CGFloat(n)), r = ch * 0.56
        var d = ""
        for i in 0...n {
            let a = CGFloat(i) / CGFloat(n) * .pi * 2 - .pi / 2
            let x = cx + R * cos(a), y = cy + R * sin(a)
            d += (i == 0 ? "M" : "A\(f(r)) \(f(r)) 0 0 1 ") + "\(f(x)) \(f(y))"
        }
        return d + "Z"
    }

    /// Text on an ellipse with equal arc-length spacing (`ARC` in Stamp.dc.html). `deg` = parametric angle, -90 is the top.
    private static func arcLabels(_ str: String, _ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ deg: Double,
                                  _ fs: CGFloat, _ ls: CGFloat, mono: Bool, bottom: Bool) -> [Label] {
        let chars = Array(str)
        let cw = fs * (mono ? 0.6 : 0.5) + ls
        let n = chars.count
        func spd(_ th: Double) -> Double { hypot(Double(rx) * sin(th), Double(ry) * cos(th)) }
        func at(_ s0: Double) -> Double {
            var th = deg * .pi / 180, left = abs(s0)
            let dir: Double = (s0 >= 0 ? 1 : -1) * (bottom ? -1 : 1)
            while left > 1e-6 { let st = min(left, 0.8); th += dir * st / spd(th); left -= st }
            return th
        }
        return chars.enumerated().map { i, ch in
            let th = at((Double(i) - Double(n - 1) / 2) * Double(cw))
            let x = cx + rx * CGFloat(cos(th)), y = cy + ry * CGFloat(sin(th))
            let tg = atan2(Double(ry) * cos(th), -Double(rx) * sin(th)) * 180 / .pi
            return Label(t: String(ch), x: x, y: y, fs: fs, ls: 0, mono: mono, rot: bottom ? tg + 180 : tg)
        }
    }

    private var layout: (lines: [Line], labels: [Label], glyph: (x: CGFloat, y: CGFloat, s: CGFloat)) {
        var lines: [Line] = [], labels: [Label] = []
        var glyph: (CGFloat, CGFloat, CGFloat) = (80, 60, 0.15)
        func L(_ d: String, _ w: CGFloat, fill: Bool = false, dash: [CGFloat] = []) { lines.append(Line(d: d, w: w, fill: fill, dash: dash)) }
        func T(_ t: String, _ x: CGFloat, _ y: CGFloat, _ fs: CGFloat, _ ls: CGFloat, _ mono: Bool) { labels.append(Label(t: t, x: x, y: y, fs: fs, ls: ls, mono: mono)) }
        typealias S = StampBody
        if locked {
            let dash: [CGFloat] = [1.5, 4.5]
            switch shape {
            case .round: L(S.circ(80, 80, 72), 1.6, dash: dash)
            case .oval: L(S.ell(80, 58, 74, 50), 1.6, dash: dash)
            case .octagon: L(S.oct(8, 10, 152, 114, 24), 1.6, dash: dash)
            case .rosette: L(S.scallop(80, 80, 72, 26), 1.6, dash: dash)
            }
            T(country, 80, shape == .oval ? 54 : shape == .octagon ? 56 : 78, 15, 2.4, false)
            T("NOT YET VISITED", 80, shape == .oval ? 70 : shape == .octagon ? 72 : 95, 8, 1.6, true)
            return (lines, labels, (80, 60, 0))
        }
        switch shape {
        case .round:
            L(S.circ(80, 80, 75), 3); L(S.circ(80, 80, 69.5), 1); L(S.ticks(80, 80, 62, 65.5, 72), 0.9); L(S.circ(80, 80, 60.5), 1.1); L(S.circ(80, 80, 40), 1.2)
            L(S.star(25, 80, 3.4), 0, fill: true); L(S.star(135, 80, 3.4), 0, fill: true)
            labels += S.arcLabels(country, 80, 80, 50.5, 50.5, -90, 14.5, 3, mono: false, bottom: false)
            labels += S.arcLabels(kind + " · MERIDIAN", 80, 80, 52, 52, 90, 6.8, 2.4, mono: true, bottom: true)
            T(code, 80, 81, 27, 1.2, false); T(date, 80, 98.5, 6, 0.5, true); glyph = (80, 62, 0.12)
        case .oval:
            L(S.ell(80, 58, 75, 51), 3); L(S.ell(80, 58, 69.5, 45.5), 1); L("M33 71H127", 0.9); L("M33 87H127", 0.9)
            labels += S.arcLabels(country, 80, 58, 59, 36, -90, 12.5, 3.2, mono: false, bottom: false)
            labels += S.arcLabels(kind, 80, 58, 59, 36, 90, 7, 3, mono: true, bottom: true)
            T(code, 80, 52, 31, 1.4, false); T(date, 80, 79, 8, 0.9, true); glyph = (80, 33, 0.1)
            L(S.star(26, 58, 3), 0, fill: true); L(S.star(134, 58, 3), 0, fill: true)
        case .octagon:
            L(S.oct(8, 8, 152, 116, 26), 3); L(S.oct(14, 14, 146, 110, 21), 1); L("M30 38H130", 0.9); L("M30 86H130", 0.9)
            L(S.star(36, 26, 3), 0, fill: true); L(S.star(124, 26, 3), 0, fill: true)
            T(kind, 80, 26, 12, 4, false); T(code, 80, 62, 34, 1.5, false); T(date, 80, 99, 9.2, 1, true); glyph = (80, 106, 0)
        case .rosette:
            L(S.scallop(80, 80, 76, 28), 2.6); L(S.circ(80, 80, 66), 1.1); L(S.circ(80, 80, 61), 1.1, dash: [1.6, 3.4]); L(S.circ(80, 80, 39), 2.2); L(S.circ(80, 80, 35.5), 0.9)
            labels += S.arcLabels(country, 80, 80, 48.5, 48.5, -90, 14, 3, mono: false, bottom: false)
            labels += S.arcLabels(kind + " · " + cc, 80, 80, 50, 50, 90, 7, 2.6, mono: true, bottom: true)
            L(S.star(22, 80, 3), 0, fill: true); L(S.star(138, 80, 3), 0, fill: true)
            T(code, 80, 80, 22, 1, false); T(date.split(separator: " ").prefix(2).joined(separator: " "), 80, 94, 6, 0.4, true); glyph = (80, 63.5, 0.09)
        }
        return (lines, labels, glyph)
    }

    var body: some View {
        let k = size / 160
        let h = StampView.viewHeight(shape)
        let lay = layout
        ZStack(alignment: .topLeading) {
            Canvas { ctx, _ in
                ctx.scaleBy(x: k, y: k)
                for l in lay.lines {
                    let p = SVGPath.parse(l.d)
                    if l.fill { ctx.fill(p, with: .color(ink)) }
                    else {
                        ctx.stroke(p, with: .color(ink.opacity(locked ? 0.75 : 1)),
                                   style: StrokeStyle(lineWidth: l.w, lineCap: .round, lineJoin: .round, dash: l.dash))
                    }
                }
                if lay.glyph.s > 0 {
                    var g = PlaneGlyph.twin
                    g = g.applying(CGAffineTransform(translationX: -50, y: -50)).applying(CGAffineTransform(scaleX: lay.glyph.s, y: lay.glyph.s))
                        .applying(CGAffineTransform(translationX: lay.glyph.x, y: lay.glyph.y))
                    ctx.fill(g, with: .color(ink))
                }
            }
            .frame(width: size, height: size * h / 160)
            ForEach(Array(lay.labels.enumerated()), id: \.offset) { _, t in
                Text(t.t)
                    .font(MRFonts.font(t.mono ? .mono : .condensed, size: t.fs * k, weight: t.mono ? 600 : 700))
                    .tracking(t.ls * k)
                    .foregroundStyle(ink)
                    .fixedSize()
                    .rotationEffect(.degrees(t.rot))
                    .position(x: t.x * k, y: t.y * k)
            }
        }
        .frame(width: size, height: size * h / 160, alignment: .topLeading)
        .modifier(StampWear(seed: seed, active: !locked))
    }
}

private struct StampWear: ViewModifier {
    let seed: UInt32
    let active: Bool
    func body(content: Content) -> some View {
        if active, let cg = PaperTextures.wearMask(seed: seed, keep: 0.8) {
            content.mask { Image(decorative: cg, scale: 2).resizable(resizingMode: .tile) }
        } else { content }
    }
}

/// Top-view twin-jet silhouette (`K.plane('twin')`, 100 x 100 box): fuselage, wings, stabilisers.
enum PlaneGlyph {
    static let twin: Path = {
        func f(_ v: Double) -> String { String(format: "%g", (v * 100).rounded() / 100) }
        let fw = 4.8, n = 3.0, t = 97.6
        let fus = "M50 \(f(n)) C\(f(50 + fw * 0.72)) \(f(n)) \(f(50 + fw)) \(f(n + 5.2)) \(f(50 + fw)) \(f(n + 14.5)) L\(f(50 + fw)) \(f(t - 31)) C\(f(50 + fw)) \(f(t - 19)) \(f(50 + fw * 0.3)) \(f(t - 5)) \(f(50 + fw * 0.2)) \(f(t)) L\(f(50 - fw * 0.2)) \(f(t)) C\(f(50 - fw * 0.3)) \(f(t - 5)) \(f(50 - fw)) \(f(t - 19)) \(f(50 - fw)) \(f(t - 31)) L\(f(50 - fw)) \(f(n + 14.5)) C\(f(50 - fw)) \(f(n + 5.2)) \(f(50 - fw * 0.72)) \(f(n)) 50 \(f(n))Z"
        func X(_ s: Double, _ x: Double) -> Double { 50 + s * (x - 50) }
        let w = (rx: 54.4, rle: 39.5, rte: 57.4, tx: 96.4, tle: 59.6, tte: 64.8, kx: 68.5, kte: 58.9)
        func wing(_ s: Double) -> String {
            let m = (w.tle + w.tte) / 2
            return "M\(f(X(s, w.rx - 0.6))) \(f(w.rle)) L\(f(X(s, w.tx))) \(f(w.tle)) Q\(f(X(s, w.tx + 0.9))) \(f(m)) \(f(X(s, w.tx - 0.1))) \(f(w.tte)) L\(f(X(s, w.kx))) \(f(w.kte)) L\(f(X(s, w.rx - 0.6))) \(f(w.rte))Z"
        }
        let st = (rle: 83.6, rte: 91.8, tx: 68.6, tle: 92.2, tte: 95.4)
        func stab(_ s: Double) -> String {
            let m = (st.tle + st.tte) / 2
            return "M\(f(X(s, 50 + fw - 0.6))) \(f(st.rle)) L\(f(X(s, st.tx))) \(f(st.tle)) Q\(f(X(s, st.tx + 0.6))) \(f(m)) \(f(X(s, st.tx - 0.1))) \(f(st.tte)) L\(f(X(s, 50 + fw - 0.6))) \(f(st.rte))Z"
        }
        return SVGPath.parse([fus, wing(1), wing(-1), stab(1), stab(-1)].joined(separator: " "))
    }()
}

#Preview("StampView") {
    HStack(spacing: 20) {
        ForEach(StampShape.allCases, id: \.self) { s in
            StampView(shape: s, size: 160, seed: 3)
        }
    }
    .padding(30).background(PaperInk.paper)
}
