import SwiftUI

/// Top view aircraft geometry of the canvas (`K.plane('twin')`, 100 x 100 box, nose up, centre line x = 50).
/// Ported number for number from `meridian-kit.js`; `PlaneMarker` draws it like `Plane.dc.html`.
struct PlaneGeometry {
    let fus, win, wings, stabs, fair, lines, winglet, nacR, nacL, intakes, exhaust: Path
    let fin: CGRect
    let tipLx: Double, tipRx: Double, tipY: Double, tailY: Double

    // twin
    private static let fw = 4.8, n = 3.0, t = 97.6
    private static let w = (rx: 54.4, rle: 39.5, rte: 57.4, tx: 96.4, tle: 59.6, tte: 64.8, kx: 68.5, kte: 58.9)
    private static let e = (x: 67.4, w: 5.8, y0: 37.2, y1: 54.6)
    private static let s = (rle: 83.6, rte: 91.8, tx: 68.6, tle: 92.2, tte: 95.4)
    private static let f = (y0: 78.0, y1: 96.8, w: 1.8)

    static let twin = PlaneGeometry()

    private init() {
        let fw = Self.fw, n = Self.n, t = Self.t, w = Self.w, e = Self.e, st = Self.s
        func X(_ s: Double, _ x: Double) -> Double { 50 + s * (x - 50) }
        func P(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }

        var fus = Path()
        fus.move(to: P(50, n))
        fus.addCurve(to: P(50 + fw, n + 14.5), control1: P(50 + fw * 0.72, n), control2: P(50 + fw, n + 5.2))
        fus.addLine(to: P(50 + fw, t - 31))
        fus.addCurve(to: P(50 + fw * 0.2, t), control1: P(50 + fw, t - 19), control2: P(50 + fw * 0.3, t - 5))
        fus.addLine(to: P(50 - fw * 0.2, t))
        fus.addCurve(to: P(50 - fw, t - 31), control1: P(50 - fw * 0.3, t - 5), control2: P(50 - fw, t - 19))
        fus.addLine(to: P(50 - fw, n + 14.5))
        fus.addCurve(to: P(50, n), control1: P(50 - fw, n + 5.2), control2: P(50 - fw * 0.72, n))
        fus.closeSubpath()
        self.fus = fus

        func wingPath(_ s: Double) -> Path {
            let m = (w.tle + w.tte) / 2
            var p = Path()
            p.move(to: P(X(s, w.rx - 0.6), w.rle))
            p.addLine(to: P(X(s, w.tx), w.tle))
            p.addQuadCurve(to: P(X(s, w.tx - 0.1), w.tte), control: P(X(s, w.tx + 0.9), m))
            p.addLine(to: P(X(s, w.kx), w.kte))
            p.addLine(to: P(X(s, w.rx - 0.6), w.rte))
            p.closeSubpath()
            return p
        }
        var wings = wingPath(1); wings.addPath(wingPath(-1)); self.wings = wings

        func stabPath(_ s: Double) -> Path {
            let m = (st.tle + st.tte) / 2
            var p = Path()
            p.move(to: P(X(s, 50 + fw - 0.6), st.rle))
            p.addLine(to: P(X(s, st.tx), st.tle))
            p.addQuadCurve(to: P(X(s, st.tx - 0.1), st.tte), control: P(X(s, st.tx + 0.6), m))
            p.addLine(to: P(X(s, 50 + fw - 0.6), st.rte))
            p.closeSubpath()
            return p
        }
        var stabs = stabPath(1); stabs.addPath(stabPath(-1)); self.stabs = stabs

        func nac(_ s: Double) -> Path {
            let cx = X(s, e.x), hw = e.w / 2
            var p = Path()
            p.move(to: P(cx - hw, e.y0 + 2))
            p.addQuadCurve(to: P(cx, e.y0), control: P(cx - hw, e.y0))
            p.addQuadCurve(to: P(cx + hw, e.y0 + 2), control: P(cx + hw, e.y0))
            p.addLine(to: P(cx + hw, e.y1 - 2.4))
            p.addQuadCurve(to: P(cx + hw * 0.5, e.y1 + 0.5), control: P(cx + hw, e.y1))
            p.addLine(to: P(cx - hw * 0.5, e.y1 + 0.5))
            p.addQuadCurve(to: P(cx - hw, e.y1 - 2.4), control: P(cx - hw, e.y1))
            p.closeSubpath()
            return p
        }
        nacR = nac(1); nacL = nac(-1)

        func ell(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double) -> Path { Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)) }
        var intakes = ell(X(1, e.x), e.y0 + 0.7, e.w * 0.38, 0.95); intakes.addPath(ell(X(-1, e.x), e.y0 + 0.7, e.w * 0.38, 0.95)); self.intakes = intakes
        var exhaust = ell(X(1, e.x), e.y1 + 0.4, e.w * 0.2, 0.6); exhaust.addPath(ell(X(-1, e.x), e.y1 + 0.4, e.w * 0.2, 0.6)); self.exhaust = exhaust

        func leAt(_ x: Double) -> Double { w.rle + (x - w.rx) / (w.tx - w.rx) * (w.tle - w.rle) }
        func teAt(_ x: Double) -> Double {
            x <= w.kx ? w.rte + (x - w.rx) / (w.kx - w.rx) * (w.kte - w.rte) : w.kte + (x - w.kx) / (w.tx - w.kx) * (w.tte - w.kte)
        }
        func at(_ x: Double, _ fr: Double) -> Double { let a = leAt(x), b = teAt(x); return a + (b - a) * fr }
        func seg(_ x1: Double, _ f1: Double, _ x2: Double, _ f2: Double) -> [Double] { [x1, at(x1, f1), x2, at(x2, f2)] }
        let xr = w.rx + 1.2, xk = w.kx, xt = w.tx - 1.4
        let L: [[Double]] = [
            seg(xr, 0.74, xk - 1, 0.76), seg(xk + 2, 0.8, xt - 2.6, 0.82), seg(xk + 2, 0.66, xt - 2.6, 0.68),
            seg(xr, 0.14, xk, 0.13), seg(xk, 0.12, xt, 0.1),
            seg(xk - 6, 0.3, xk - 6, 0.76), seg(xk + 7, 0.66, xk + 7, 0.8), seg(xk + 15, 0.64, xk + 15, 0.82),
        ]
        var lines = Path()
        for s in [1.0, -1.0] {
            for q in L {
                lines.move(to: P(X(s, q[0]), q[1]))
                lines.addLine(to: P(X(s, q[2]), q[3]))
            }
        }
        self.lines = lines

        var fair = Path()
        fair.move(to: P(50 + fw - 0.2, w.rle + 1.2))
        fair.addQuadCurve(to: P(50 + fw - 0.2, w.rte + 5.5), control: P(50 + fw + 3.1, (w.rle + w.rte) / 2 + 2))
        fair.addLine(to: P(50 - fw + 0.2, w.rte + 5.5))
        fair.addQuadCurve(to: P(50 - fw + 0.2, w.rle + 1.2), control: P(50 - fw - 3.1, (w.rle + w.rte) / 2 + 2))
        fair.closeSubpath()
        self.fair = fair

        var winglet = Path()
        for s2 in [1.0, -1.0] {
            winglet.move(to: P(X(s2, w.tx - 0.5), w.tle + 1.2))
            winglet.addLine(to: P(X(s2, w.tx + 1.1), w.tle - 3.2))
            winglet.addLine(to: P(X(s2, w.tx + 1.5), w.tle - 2.8))
            winglet.addLine(to: P(X(s2, w.tx + 0.9), w.tle + 3.8))
            winglet.closeSubpath()
        }
        self.winglet = winglet

        var win = Path()
        win.move(to: P(50 - fw * 0.6, n + 6.9))
        win.addLine(to: P(50 - fw * 0.4, n + 4.7))
        win.addQuadCurve(to: P(50 + fw * 0.4, n + 4.7), control: P(50, n + 4.1))
        win.addLine(to: P(50 + fw * 0.6, n + 6.9))
        win.addQuadCurve(to: P(50 - fw * 0.6, n + 6.9), control: P(50, n + 6.1))
        win.closeSubpath()
        self.win = win

        fin = CGRect(x: 50 - Self.f.w / 2, y: Self.f.y0, width: Self.f.w, height: Self.f.y1 - Self.f.y0)
        tipLx = 100 - w.tx; tipRx = w.tx; tipY = (w.tle + w.tte) / 2; tailY = t - 0.2
    }

    /// Seam lines across the fuselage.
    var seams: Path {
        var p = Path()
        var y = Self.n + 22
        while y < Self.t - 30 {
            p.move(to: CGPoint(x: 50 - Self.fw, y: y)); p.addLine(to: CGPoint(x: 50 + Self.fw, y: y))
            y += 11.5
        }
        return p
    }
}

/// `Plane.dc.html`: the aircraft icon on the map. `heading` in degrees clockwise from up. The wing tips carry the
/// red / green navigation lights and the tail a white strobe (`.nl`, blinking `mx-blink`).
struct PlaneMarker: View {
    var size: CGFloat = 34
    var heading: Double = 0
    var color: Color = .white
    var lights = true
    var shadow = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let g = PlaneGeometry.twin
        let ink = Color(.sRGB, red: 11 / 255, green: 16 / 255, blue: 32 / 255)
        let k = size / 100
        Canvas { ctx, _ in
            ctx.scaleBy(x: k, y: k)
            let full = Path(CGRect(x: 0, y: 0, width: 100, height: 100))
            // tailplane
            ctx.fill(g.stabs, with: .color(color)); ctx.fill(g.stabs, with: .color(ink.opacity(0.1)))
            vgrad(&ctx, g.stabs, wingStops(ink))
            // wings
            ctx.fill(g.wings, with: .color(color)); ctx.stroke(g.wings, with: .color(color), style: StrokeStyle(lineWidth: 0.5, lineJoin: .round))
            ctx.fill(g.wings, with: .color(ink.opacity(0.08)))
            vgrad(&ctx, g.wings, wingStops(ink))
            ctx.fill(g.winglet, with: .color(color)); ctx.stroke(g.winglet, with: .color(color), lineWidth: 0.3)
            ctx.fill(g.winglet, with: .color(ink.opacity(0.22)))
            ctx.stroke(g.lines, with: .color(ink.opacity(0.3)), style: StrokeStyle(lineWidth: 0.32, lineCap: .round))
            // engines
            for nac in [g.nacR, g.nacL] {
                ctx.fill(nac, with: .color(color)); ctx.fill(nac, with: .color(ink.opacity(0.12)))
                hgrad(&ctx, nac, nacStops(ink))
            }
            ctx.fill(g.intakes, with: .color(ink.opacity(0.78))); ctx.fill(g.exhaust, with: .color(ink.opacity(0.7)))
            // fuselage
            ctx.fill(g.fair, with: .color(color)); ctx.fill(g.fair, with: .color(ink.opacity(0.05)))
            ctx.fill(g.fus, with: .color(color))
            var c = ctx
            c.clip(to: g.fus)
            c.fill(full, with: .linearGradient(Gradient(stops: fusStops(ink)), startPoint: .zero, endPoint: CGPoint(x: 100, y: 0)))
            c.stroke(g.seams, with: .color(ink.opacity(0.13)), lineWidth: 0.26)
            let fin = Path(roundedRect: g.fin, cornerRadius: g.fin.width / 2)
            c.fill(fin, with: .color(.white.opacity(0.5)))
            c.stroke(fin, with: .color(ink.opacity(0.22)), lineWidth: 0.25)
            ctx.fill(g.win, with: .color(Color(.sRGB, red: 0x12 / 255, green: 0x19 / 255, blue: 0x2A / 255, opacity: 0.88)))
        }
        .frame(width: size, height: size)
        .overlay {
            if lights { NavLights(size: size, reduceMotion: reduceMotion) }
        }
        .rotationEffect(.degrees(heading))
        .shadow(color: shadow ? .black.opacity(0.45) : .clear, radius: 2.5, y: 6)
        .accessibilityHidden(true)
    }

    private func fusStops(_ ink: Color) -> [Gradient.Stop] {
        [.init(color: ink.opacity(0.34), location: 0), .init(color: ink.opacity(0.06), location: 0.2),
         .init(color: .white.opacity(0.34), location: 0.42), .init(color: .white.opacity(0.14), location: 0.6),
         .init(color: ink.opacity(0.1), location: 0.85), .init(color: ink.opacity(0.38), location: 1)]
    }
    private func wingStops(_ ink: Color) -> [Gradient.Stop] {
        [.init(color: .white.opacity(0.36), location: 0), .init(color: .white.opacity(0.02), location: 0.42), .init(color: ink.opacity(0.26), location: 1)]
    }
    private func nacStops(_ ink: Color) -> [Gradient.Stop] {
        [.init(color: ink.opacity(0.42), location: 0), .init(color: .white.opacity(0.3), location: 0.34),
         .init(color: .white.opacity(0.02), location: 0.62), .init(color: ink.opacity(0.5), location: 1)]
    }
    /// Gradient in the object's own bounding box (SVG objectBoundingBox default), top to bottom.
    private func vgrad(_ ctx: inout GraphicsContext, _ path: Path, _ stops: [Gradient.Stop]) {
        let b = path.boundingRect
        ctx.fill(path, with: .linearGradient(Gradient(stops: stops), startPoint: CGPoint(x: b.midX, y: b.minY), endPoint: CGPoint(x: b.midX, y: b.maxY)))
    }
    private func hgrad(_ ctx: inout GraphicsContext, _ path: Path, _ stops: [Gradient.Stop]) {
        let b = path.boundingRect
        ctx.fill(path, with: .linearGradient(Gradient(stops: stops), startPoint: CGPoint(x: b.minX, y: b.midY), endPoint: CGPoint(x: b.maxX, y: b.midY)))
    }
}

/// `.nl` navigation lights: red left tip, green right tip, white tail strobe (`mx-blink` steps).
private struct NavLights: View {
    let size: CGFloat
    let reduceMotion: Bool

    static func on(_ t: Double, _ period: Double, _ delay: Double, _ reduce: Bool) -> Double {
        reduce || ((t - delay).truncatingRemainder(dividingBy: period) + period).truncatingRemainder(dividingBy: period) < period / 2 ? 1 : 0.15
    }

    var body: some View {
        let g = PlaneGeometry.twin
        let k = size / 100
        TimelineView(.animation(minimumInterval: 0.2, paused: reduceMotion)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            ZStack(alignment: .topLeading) {
                Circle().fill(Color(.sRGB, red: 1, green: 0x5C / 255, blue: 0x5C / 255)).frame(width: 3.6 * k, height: 3.6 * k)
                    .position(x: g.tipLx * k, y: g.tipY * k).opacity(Self.on(t, 1.8, 0, reduceMotion))
                Circle().fill(Color(.sRGB, red: 0x4D / 255, green: 0xF0 / 255, blue: 0x8C / 255)).frame(width: 3.6 * k, height: 3.6 * k)
                    .position(x: g.tipRx * k, y: g.tipY * k).opacity(Self.on(t, 1.8, 0.9, reduceMotion))
                Circle().fill(.white).frame(width: 2.8 * k, height: 2.8 * k)
                    .position(x: 50 * k, y: g.tailY * k).opacity(Self.on(t, 2.4, 0, reduceMotion))
            }
        }
        .frame(width: size, height: size)
    }
}
