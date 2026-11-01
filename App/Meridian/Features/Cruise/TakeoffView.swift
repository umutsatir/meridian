import AppKit
import ImageIO
import MeridianCore
import MeridianUI
import SwiftUI

/// S15: take-off sequence (`Takeoff.dc.html`). A satellite chase camera follows the plane down runway 27R, rotates and
/// climbs; at 4.2 s the cruise map rises in. `t` is the clock in milliseconds. The live view runs 6 s and calls
/// `onDone`; the artboards freeze `t` (1800 ms roll, 3900 ms rotate) and S15C (Reduce Motion) cross-fades.
struct TakeoffView: View {
    let frame: CruiseFrame
    /// Frozen time in ms (artboards) or nil to run live.
    var frozenT: Double?
    var reduce = false
    /// Dusk / night variant (`tod: "dusk"` of `Takeoff.dc.html`): sepia-dark imagery, warm tint, runway edge lights.
    /// Live take-offs use it between 18:00 and 06:00 local time.
    var dusk: Bool = TakeoffView.isDuskNow()
    var onDone: () -> Void = {}

    @State private var t0 = Date()
    @State private var finished = false
    @State private var ui = CruiseUI()
    @Environment(\.accessibilityReduceMotion) private var systemReduce

    var body: some View {
        let isReduce = reduce || systemReduce
        Group {
            if let frozenT {
                content(t: frozenT, reduce: isReduce)
            } else {
                TimelineView(.animation) { tl in
                    let t = min(isReduce ? 700 : 6000, tl.date.timeIntervalSince(t0) * 1000)
                    content(t: t, reduce: isReduce)
                        .onChange(of: t >= (isReduce ? 700 : 6000)) { _, done in if done { finish() } }
                }
            }
        }
        .onAppear { t0 = Date(); MRSound.shared.play(.chime(.board)) }
        .onKeyPress(.escape) { finish(); return .handled }
        .focusable().focusEffectDisabled()
    }

    static func isDuskNow(_ date: Date = .now) -> Bool {
        let h = Calendar.current.component(.hour, from: date)
        return h >= 18 || h < 6
    }

    private func finish() {
        guard !finished else { return }; finished = true
        onDone()
    }

    // MARK: frame

    private func content(t: Double, reduce: Bool) -> some View {
        let sec = t / 1000
        func ease(_ x: Double) -> Double { x * x * (3 - 2 * x) }
        func cl(_ v: Double, _ a: Double, _ b: Double) -> Double { max(a, min(b, v)) }
        let ru = cl((sec - 1.2) / 2.0, 0, 1)
        let dist = sec < 3.2 ? 700 * ru * ru : 700 + 520 * (sec - 3.2) + 90 * pow(sec - 3.2, 2)
        let lu = cl((sec - 3.2) / 2.4, 0, 1)
        let h = 1300 * pow(ease(lu), 1.35) + (sec > 5.6 ? (sec - 5.6) * 500 : 0)
        let D = 100 + h * 1.25 + 18 * ru
        let s = 300 / D
        let kt = Int((sec < 1.2 ? 0 : sec < 3.2 ? 158 * ru : 158 + 74 * lu).rounded()), ft = Int((h * 3.28).rounded())
        let planeY = -dist - 40, camY = planeY - 140 / s
        let fade = 1 - ease(cl((t - 4300) / 900, 0, 1))
        let shake = sec > 1.2 && sec < 3.4 ? sin(sec * 90) * 0.9 * ru : 0
        let rise = t >= 4200 && !reduce
        let riseU = ease(cl((t - 4200) / 1800, 0, 1))
        let rr = reduce ? ease(cl(t / 700, 0, 1)) : riseU
        let cine = !reduce && t < 5300
        let phase = sec < 1.2 ? "Taxi" : sec < 3.2 ? "Take-off roll" : sec < 4.4 ? "Rotate" : "Climb"
        let showSkip = frozenT == nil && t < 4200
        return GeometryReader { geo in
            let W = geo.size.width, H = geo.size.height
            ZStack(alignment: .topLeading) {
                Color(.sRGB, red: 6 / 255, green: 8 / 255, blue: 13 / 255)
                if cine {
                    TakeoffScene(dusk: dusk, s: s, camY: camY, camX: 0, dist: dist, sec: sec, h: h, ru: ru, lu: lu, shake: shake, fade: fade, size: geo.size)
                    // HUD
                    HStack(spacing: 16) {
                        hud("SPD", "\(kt)", "kt"); hud("ALT", "\(ft)", "ft"); hudRwy
                    }
                    .padding(.horizontal, 18).frame(height: 44)
                    .cruiseGlass(22, .e2)
                    .offset(x: 28, y: H - 28 - 44)
                    .opacity(fade * cl(sec / 0.6, 0, 1))
                    VStack(spacing: 8) {
                        Text("\(frame.origin.iata) \(Text("→").foregroundColor(.white.opacity(0.5))) \(frame.destination?.iata ?? "")")
                            .font(.mr(.condensed, size: 34, weight: 600)).frame(height: 34)
                        Text(phase).font(.mr(.ui, size: 11, weight: 500)).tracking(2.2).textCase(.uppercase)
                    }
                    .foregroundStyle(Color(RGB(hex: "#E9EDF5")))
                    .shadow(color: cruiseRGBA(3, 4, 8, 0.85), radius: 6, y: 1)
                    .frame(maxWidth: .infinity).offset(y: 44)
                    .opacity(fade * cl(sec / 0.6, 0, 1))
                }
                if reduce { Color(.sRGB, red: 6 / 255, green: 8 / 255, blue: 13 / 255) }
                if rise || reduce {
                    CruiseScreen(frame: CruiseFrame(origin: frame.origin, destination: frame.destination, progress: 0.03, totalMin: frame.totalMin, policy: frame.policy), ui: ui)
                        .frame(width: W, height: H)
                        .opacity(reduce ? rr : min(1, riseU * 1.6))
                        .scaleEffect(reduce ? 1 : 1.05 - 0.05 * riseU, anchor: .bottom)
                        .offset(y: reduce ? 0 : (1 - riseU) * 0.62 * H)
                        .blur(radius: (1 - rr) * 14)
                        .allowsHitTesting(false)
                }
                if showSkip {
                    Button { finish() } label: { HStack(spacing: 8) { Text("Skip"); MRKbd("Esc") } }
                        .buttonStyle(MRButtonStyle(.secondary))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(.top, 20).padding(.trailing, 24)
                }
            }
            .frame(width: W, height: H, alignment: .topLeading)
            .clipped()
        }
    }

    private func hud(_ k: String, _ v: String, _ u: String) -> some View {
        HStack(spacing: 0) {
            Text(k).foregroundStyle(MRPalette.resolve(.dark).text3.color).padding(.trailing, 6)
            Text(v).fontWeight(.semibold); Text(" \(u)")
        }
        .font(.mr(.mono, size: 12, weight: 500)).tracking(0.48).foregroundStyle(MRPalette.resolve(.dark).text1.color)
    }

    private var hudRwy: some View {
        HStack(spacing: 0) {
            Text("RWY").foregroundStyle(MRPalette.resolve(.dark).text3.color).padding(.trailing, 6)
            Text("27R").fontWeight(.semibold)
        }
        .font(.mr(.mono, size: 12, weight: 500)).tracking(0.48).foregroundStyle(MRPalette.resolve(.dark).text1.color)
    }
}

// MARK: - Scene

enum TakeoffImages {
    @MainActor static var cache: [String: CGImage] = [:]
    private static let files = [("sat-regional", "jpg"), ("sat-farm", "jpg"), ("sat-grain", "png")]

    @MainActor static func image(_ name: String, _ ext: String) -> CGImage? {
        if let c = cache[name] { return c }
        guard let cg = decode(name, ext) else { return nil }
        cache[name] = cg
        return cg
    }

    /// Decodes the satellite imagery off the main thread (4096 pt JPEGs take seconds in a debug build and would freeze the first
    /// take-off). Called when the ritual starts and at launch of a check-in; harmless to call again.
    @MainActor static func prewarm() {
        let todo = files.filter { cache[$0.0] == nil }
        guard !todo.isEmpty else { return }
        Task.detached(priority: .utility) {
            for (name, ext) in todo {
                guard let cg = decode(name, ext) else { continue }
                await MainActor.run { if cache[name] == nil { cache[name] = cg } }
            }
        }
    }

    nonisolated private static func decode(_ name: String, _ ext: String) -> CGImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
    }
}

/// The chase camera drawing: satellite layers, the airport in metres, shadow and plane. All numbers from `Takeoff.dc.html`.
private struct TakeoffScene: View {
    let dusk: Bool
    let s: Double, camY: Double, camX: Double
    let dist: Double, sec: Double, h: Double, ru: Double, lu: Double, shake: Double, fade: Double
    let size: CGSize

    var body: some View {
        let W = size.width, H = size.height
        func cl(_ v: Double, _ a: Double, _ b: Double) -> Double { max(a, min(b, v)) }
        let speedBlur = cl((dist > 0 ? (sec < 3.2 ? 700 * 2 * ru / 2.0 : 700 + 520) : 0) * s / 2600, 0, 1.6)
        let farmA = cl((s - 0.55) / 0.5, 0, 1)
        let pK = pow(min(1, s / 3), 0.33), pS = 128.0
        let sx = W / 2 + shake, sy = H * 0.7
        let shOff = h * s * 0.55 + 2
        let lift = 1 + 0.04 * (lu * lu * (3 - 2 * lu))
        return ZStack(alignment: .topLeading) {
            satLayer("sat-regional", 4096, opacity: fade, blur: speedBlur, W: W, H: H)
            satLayer("sat-farm", 1536 * 0.7, opacity: farmA * fade, blur: speedBlur, W: W, H: H)
            Canvas { ctx, sz in
                let vx = camX - (W / 2) / s, vy = camY - (H * 0.525) / s
                ctx.translateBy(x: -vx * s, y: -vy * s)
                ctx.scaleBy(x: s, y: s)
                TakeoffAirport.draw(&ctx, scale: s)
                if dusk { TakeoffAirport.drawLights(&ctx) }
            }
            .opacity(1)
            grain(opacity: 0.42 * cl(s / 1.6, 0.25, 1) * fade)
            LinearGradient(colors: dusk ? [cruiseRGBA(255, 130, 70, 0.18), cruiseRGBA(40, 20, 70, 0.32)] : [cruiseRGBA(255, 250, 235, 0.06), cruiseRGBA(10, 20, 40, 0.12)],
                           startPoint: .top, endPoint: .bottom).allowsHitTesting(false)
            // plane shadow, then plane
            PlaneMarker(size: pS, heading: 0, lights: false, shadow: false)
                .colorMultiply(.black)
                .frame(width: pS, height: pS)
                .scaleEffect(pK * 0.96)
                .blur(radius: 0.8 + h * s * 0.02)
                .opacity(0.38 * fade * (1 - 0.5 * lu))
                .position(x: sx + shOff * 0.7, y: sy + shOff)
            PlaneMarker(size: pS, heading: shake * 0.4, shadow: false)
                .scaleEffect(pK * lift)
                .shadow(color: .black.opacity(0.25), radius: (3 + h * s * 0.03) / 2, y: 2 + h * s * 0.02)
                .opacity(fade)
                .position(x: sx, y: sy)
            CSSEllipse(cx: 0.5, cy: 0.54, rx: 0.9, ry: 0.8, stops: [.init(color: .clear, location: 0.52), .init(color: cruiseRGBA(3, 4, 8, 0.62), location: 1)])
        }
        .frame(width: W, height: H, alignment: .topLeading)
        .clipped()
    }

    @ViewBuilder
    private func satLayer(_ name: String, _ meters: Double, opacity: Double, blur: Double, W: Double, H: Double) -> some View {
        if opacity > 0.001, let img = TakeoffImages.image(name, "jpg") {
            Canvas { ctx, sz in
                // background-position: (640 - camX*s, 420 - camY*s), size M*s: tiled
                let tile = meters * s
                let ox = W / 2 - camX * s, oy = H * 0.525 - camY * s
                let resolved = ctx.resolve(Image(decorative: img, scale: 1).interpolation(.high))
                var x0 = ox.truncatingRemainder(dividingBy: tile); if x0 > 0 { x0 -= tile }
                var y0 = oy.truncatingRemainder(dividingBy: tile); if y0 > 0 { y0 -= tile }
                var y = y0
                while y < sz.height { var x = x0; while x < sz.width { ctx.draw(resolved, in: CGRect(x: x, y: y, width: tile + 0.5, height: tile + 0.5)); x += tile }; y += tile }
            }
            .modifier(DuskTone(dusk: dusk))
            .blur(radius: blur).opacity(opacity)
        }
    }

    @ViewBuilder
    private func grain(opacity: Double) -> some View {
        if let img = TakeoffImages.image("sat-grain", "png") {
            Canvas { ctx, sz in
                let r = ctx.resolve(Image(decorative: img, scale: 1))
                var y = 0.0
                while y < sz.height { var x = 0.0; while x < sz.width { ctx.draw(r, in: CGRect(x: x, y: y, width: 256, height: 256)); x += 256 }; y += 256 }
            }
            .blendMode(.overlay).opacity(opacity).allowsHitTesting(false)
        }
    }
}

/// `filter: saturate(1.02)` by day; at dusk `sepia(.45) saturate(1.25) brightness(.72) hue-rotate(-10deg)`.
private struct DuskTone: ViewModifier {
    let dusk: Bool
    func body(content: Content) -> some View {
        if dusk {
            content
                .colorMultiply(Color(.sRGB, red: 1, green: 0.9, blue: 0.76))   // sepia .45
                .saturation(1.25).brightness(-0.2).hueRotation(.degrees(-10))
        } else {
            content.saturation(1.02)
        }
    }
}

/// The vector airport in metres (runway 27R, taxiway, apron, terminal, tower, hangar, parked aircraft).
private enum TakeoffAirport {
    static func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Path { Path(CGRect(x: x, y: y, width: w, height: h)) }

    static let marks: Path = {
        var p = Path()
        for i in 0..<6 { for sg in [-1.0, 1.0] { let x = sg * (3.4 + Double(i) * 3.1); p.addPath(rect(sg < 0 ? x - 1.5 : x, -6, 1.5, 30)) } }
        p.addPath(rect(-21.9, -6, 0.5, 3100)); p.addPath(rect(21.4, -6, 0.5, 3100))
        var y = -110.0
        while y > -3000 { p.addPath(rect(-0.45, y, 0.9, 30)); y -= 50 }
        for (i, y) in [-150.0, -300, -450, -600, -750, -900, -1050].enumerated() {
            let big = i == 1
            for sg in [-1.0, 1.0] {
                let o = big ? 9.0 : (i % 2 == 1 ? 5.5 : 8.0)
                p.addPath(rect(sg < 0 ? -o - (big ? 9 : 2.4) : o, y, big ? 9 : 2.4, big ? 30 : 22))
                if !big { p.addPath(rect(sg < 0 ? -o - 6.4 : o + 4, y, 2.4, 22)) }
            }
        }
        return p
    }()

    static let tire: Path = {
        var a = UInt32(41)
        func rnd() -> Double {
            a = a &+ 0x6D2B79F5
            var t = (a ^ (a >> 15)) &* (1 | a)
            t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
            return Double(t ^ (t >> 14)) / 4294967296
        }
        var p = Path()
        for _ in 0..<26 {
            let x = (rnd() < 0.5 ? -1.0 : 1.0) * (3 + rnd() * 5), y = -250 - rnd() * 300
            p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x + (rnd() - 0.5) * 0.8, y: y + 20 + rnd() * 50))
        }
        return p
    }()

    /// Runway edge lights at dusk: a warm glow every 60 m on both edges (`lights` of `Takeoff.dc.html`).
    static func drawLights(_ ctx: inout GraphicsContext) {
        let glow = Gradient(stops: [.init(color: cruiseRGBA(0xFF, 0xF2, 0xCF), location: 0), .init(color: cruiseRGBA(0xFF, 0xD9, 0x8A, 0.8), location: 0.4),
                                    .init(color: cruiseRGBA(0xFF, 0xB5, 0x47, 0), location: 1)])
        var y = 40.0
        while y > -1700 {
            for x in [-23.4, 23.4] {
                let r = 2.6
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                         with: .radialGradient(glow, center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r))
            }
            y -= 60
        }
    }

    static func draw(_ ctx: inout GraphicsContext, scale s: Double) {
        // grass strips with the horizontal fade, pattern 400 x 40 of two 20 m bars
        let fade = Gradient(stops: [.init(color: .clear, location: 0), .init(color: .white, location: 0.3), .init(color: .white, location: 0.7), .init(color: .clear, location: 1)])
        var g = ctx
        g.opacity = 0.9
        var y = -3200.0
        while y < 400 {
            for k in 0..<2 {
                let r = CGRect(x: -110, y: y + Double(k) * 20, width: 220, height: 20)
                let c = k == 0 ? cruiseRGBA(0x8F, 0xA8, 0x5A) : cruiseRGBA(0x87, 0x9F, 0x54)
                let grad = Gradient(stops: fade.stops.map { .init(color: c.opacity($0.color == .clear ? 0 : 1), location: $0.location) })
                g.fill(Path(r), with: .linearGradient(grad, startPoint: CGPoint(x: -110, y: 0), endPoint: CGPoint(x: 110, y: 0)))
            }
            y += 40
        }
        ctx.fill(rect(-31, -3140, 62, 3320), with: .color(cruiseRGBA(0x5B, 0x5F, 0x67)))
        ctx.fill(rect(-23, -3100, 46, 3300), with: .color(cruiseRGBA(0x44, 0x47, 0x4F)))
        var taxi = Path()
        taxi.addPath(rect(-168, -3000, 36, 3200))
        for pts in [[(-132, 150), (-31, 80), (-31, 108), (-132, 178)], [(-132, -240), (-31, -300), (-31, -276), (-132, -216)]] {
            taxi.move(to: CGPoint(x: pts[0].0, y: pts[0].1)); for q in pts.dropFirst() { taxi.addLine(to: CGPoint(x: q.0, y: q.1)) }; taxi.closeSubpath()
        }
        taxi.addPath(rect(-226, -80, 58, 24)); taxi.addPath(rect(-226, 60, 58, 24))
        ctx.fill(taxi, with: .color(cruiseRGBA(0x50, 0x53, 0x5B)))
        var tl = Path()
        tl.move(to: CGPoint(x: -150, y: 200)); tl.addLine(to: CGPoint(x: -150, y: -3000))
        tl.move(to: CGPoint(x: -132, y: 164)); tl.addLine(to: CGPoint(x: -31, y: 94))
        tl.move(to: CGPoint(x: -132, y: -228)); tl.addLine(to: CGPoint(x: -31, y: -288))
        tl.move(to: CGPoint(x: -168, y: -68)); tl.addLine(to: CGPoint(x: -226, y: -68))
        tl.move(to: CGPoint(x: -168, y: 72)); tl.addLine(to: CGPoint(x: -226, y: 72))
        ctx.stroke(tl, with: .color(cruiseRGBA(0xE2, 0xC2, 0x5A, 0.9)), lineWidth: 0.55)
        ctx.stroke(tire, with: .color(cruiseRGBA(0x15, 0x17, 0x1C, 0.22)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
        ctx.fill(marks, with: .color(cruiseRGBA(0xEC, 0xEF, 0xF5, 0.95)))
        for (x, ch) in [(-9.0, "2"), (9.0, "7")] {
            let t = Text(ch).font(.mr(.condensed, size: 21, weight: 700)).foregroundColor(cruiseRGBA(0xEC, 0xEF, 0xF5, 0.92))
            var c = ctx; c.translateBy(x: x, y: -62 - 7); c.draw(c.resolve(t), at: .zero, anchor: .center)
        }
        // apron, terminal, gates
        ctx.fill(Path(roundedRect: CGRect(x: -452, y: -210, width: 226, height: 470), cornerRadius: 6), with: .color(cruiseRGBA(0x9A, 0x9D, 0xA5)))
        var lines = Path(); for yy in [-210.0, -112, -10, 92, 194] { lines.move(to: CGPoint(x: -452, y: yy)); lines.addLine(to: CGPoint(x: -226, y: yy)) }
        ctx.stroke(lines, with: .color(cruiseRGBA(0x7E, 0x81, 0x89, 0.6)), lineWidth: 1)
        ctx.fill(rect(-424, -170, 48, 418), with: .color(cruiseRGBA(5, 7, 12, 0.4)))
        ctx.fill(Path(roundedRect: CGRect(x: -440, y: -190, width: 46, height: 418), cornerRadius: 3), with: .color(cruiseRGBA(0xD3, 0xD6, 0xDE)))
        var jb = Path(); for yy in stride(from: -180.0, through: 210, by: 30) { jb.move(to: CGPoint(x: -433, y: yy)); jb.addLine(to: CGPoint(x: -401, y: yy)) }
        ctx.stroke(jb, with: .color(cruiseRGBA(0xA9, 0xB2, 0xC4, 0.7)), lineWidth: 9)
        for yy in [-155.0, -95, -35, 25, 85, 145] { ctx.fill(rect(-394, yy, 30, 5), with: .color(cruiseRGBA(0xB4, 0xB8, 0xC3))) }
        // parked aircraft
        let g0 = PlaneGeometry.twin
        for y in [-150.0, -90, -30, 30, 90] {
            var sh = ctx
            sh.opacity = 0.34
            sh.translateBy(x: -336, y: y + 12); sh.rotate(by: .degrees(-90)); sh.scaleBy(x: 0.38, y: 0.38); sh.translateBy(x: -50, y: -50)
            sh.fill(g0.stabs, with: .color(.black)); sh.fill(g0.wings, with: .color(.black)); sh.fill(g0.fus, with: .color(.black))
            var c = ctx
            c.translateBy(x: -350, y: y); c.rotate(by: .degrees(-90)); c.scaleBy(x: 0.38, y: 0.38); c.translateBy(x: -50, y: -50)
            c.fill(g0.stabs, with: .color(cruiseRGBA(0xEC, 0xEF, 0xF4))); c.fill(g0.wings, with: .color(cruiseRGBA(0xF4, 0xF6, 0xFA)))
            c.fill(g0.fus, with: .color(cruiseRGBA(0xFA, 0xFB, 0xFD))); c.fill(g0.fus, with: .color(cruiseRGBA(11, 16, 32, 0.1)))
        }
        // tower, hangar
        ctx.fill(rect(-160, 186, 14, 14), with: .color(cruiseRGBA(5, 7, 12, 0.4)))
        ctx.fill(Path(ellipseIn: CGRect(x: -192, y: 148, width: 18, height: 18)), with: .color(cruiseRGBA(0xC8, 0xCB, 0xD3)))
        ctx.fill(Path(ellipseIn: CGRect(x: -187.6, y: 152.4, width: 9.2, height: 9.2)), with: .color(cruiseRGBA(0x8D, 0x93, 0xA2)))
        ctx.fill(rect(166, 138, 120, 48), with: .color(cruiseRGBA(5, 7, 12, 0.4)))
        ctx.fill(Path(roundedRect: CGRect(x: 150, y: 120, width: 120, height: 48), cornerRadius: 2), with: .color(cruiseRGBA(0xBF, 0xC3, 0xCC)))
        var hl = Path(); hl.move(to: CGPoint(x: 150, y: 144)); hl.addLine(to: CGPoint(x: 270, y: 144))
        ctx.stroke(hl, with: .color(cruiseRGBA(0x9A, 0xA0, 0xAD)), lineWidth: 1.2)
    }
}
