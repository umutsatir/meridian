import AppKit
import MeridianCore
import MeridianCruise
import MeridianUI
import SwiftUI

/// Bundled photo of a window scene (`wv-city-*.jpg`).
enum WindowPhoto {
    @MainActor private static var cache: [String: NSImage] = [:]
    @MainActor static func image(_ name: String) -> NSImage? {
        if let c = cache[name] { return c }
        guard let url = Bundle.main.url(forResource: "wv-city-\(name)", withExtension: "jpg"), let img = NSImage(contentsOf: url) else { return nil }
        cache[name] = img
        return img
    }
}

/// One scene of the canvas table (`S` and `SKY` of `WindowView.dc.html`).
struct WindowSceneSpec {
    let key: String
    let image: String
    let brightness: Double, contrast: Double, saturation: Double
    let sun: (Double, Double, [Gradient.Stop])?   // centre x, y (fractions) and stops of the radial glow
    let sky: (Double, Double, Double)
    let rain: Bool, storm: Bool, runway: Bool
    /// `takeoff` (tilt -9, zoom 1.28, no sky) and `landing` (tilt 5, runway lights) of `WindowView.dc.html`.
    var tilt = 0.0, zoom = 1.0, hideSky = false

    /// The scene box in the pane: `left, top, width, height` as fractions (canvas `sceneStyle`).
    var box: (x: Double, y: Double, w: Double, h: Double) {
        tilt != 0 || key == "takeoff" ? (-0.14, -0.14, 1.28, 1.28) : (-0.04, 0, 1.08, 1.04)
    }

    static func spec(_ key: String) -> WindowSceneSpec {
        func c(_ r: Double, _ g: Double, _ b: Double, _ a: Double) -> Color { cruiseRGBA(r, g, b, a) }
        switch key {
        case "blue": return .init(key: key, image: "blue", brightness: 0, contrast: 1, saturation: 1, sun: nil, sky: (212, 226, 240), rain: false, storm: false, runway: false)
        case "sunset":
            return .init(key: key, image: "sunset", brightness: 0, contrast: 1, saturation: 1,
                         sun: (0.18, 0.64, [.init(color: c(255, 240, 200, 0.62), location: 0), .init(color: c(255, 176, 110, 0.30), location: 0.14), .init(color: .clear, location: 0.42)]),
                         sky: (255, 216, 180), rain: false, storm: false, runway: false)
        case "takeoff":
            return .init(key: key, image: "day", brightness: 0, contrast: 1, saturation: 1, sun: nil, sky: (238, 241, 240), rain: false, storm: false, runway: false,
                         tilt: -9, zoom: 1.28, hideSky: true)
        case "landing":
            return .init(key: key, image: "blue", brightness: 0.12, contrast: 1, saturation: 1.1,
                         sun: (0.28, 0.66, [.init(color: c(255, 225, 170, 0.5), location: 0), .init(color: .clear, location: 0.36)]),
                         sky: (212, 226, 240), rain: false, storm: false, runway: true, tilt: 5)
        case "night": return .init(key: key, image: "night", brightness: 0, contrast: 1, saturation: 1, sun: nil, sky: (12, 18, 34), rain: false, storm: false, runway: false)
        case "rain": return .init(key: key, image: "rain", brightness: 0, contrast: 1, saturation: 0.9, sun: nil, sky: (168, 176, 186), rain: true, storm: false, runway: false)
        case "storm": return .init(key: key, image: "rain", brightness: -0.38, contrast: 1.12, saturation: 0.7, sun: nil, sky: (58, 66, 82), rain: true, storm: true, runway: false)
        default: return .init(key: "day", image: "day", brightness: 0, contrast: 1, saturation: 1, sun: nil, sky: (238, 241, 240), rain: false, storm: false, runway: false)
        }
    }

    /// The canvas key of the app's `WindowScene`.
    static func key(_ s: WindowScene) -> String {
        switch s { case .day: "day"; case .sunset: "sunset"; case .blueHour: "blue"; case .night: "night"; case .rain: "rain" }
    }
}

/// The oval cabin window (`WindowView.dc.html`): wall, glow, light reveal frame, glass pane with the photo scene,
/// pull-down shade with housing and handle. `fit` .66 and the host offset as in the cruise screen.
struct CruiseWindowView: View {
    let frame: CruiseFrame
    @Bindable var ui: CruiseUI
    let size: CGSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragStart: Double?

    var body: some View {
        let W = size.width, H = size.height
        let fit = 0.66
        var Rh = H * fit, Rw = Rh * 0.77, Th = Rh * 1.48, Tw = Th * 0.733
        let kk = min(1, (W * 0.985) / Tw, (H * 0.99) / Th)
        Rh *= kk; Rw *= kk; Th *= kk; Tw *= kk
        let m = Rw * 0.1, mt = m * 0.5, Pw = Rw - 2 * m, Ph = Rh - mt - m
        let cx = W / 2, cy = H / 2
        return ZStack(alignment: .topLeading) {
            // Flight.dc.html backdrop, then the sidewall
            Color(.sRGB, red: 6 / 255, green: 6 / 255, blue: 7 / 255)
            CSSEllipse(cx: 0.5, cy: 0.46, rx: 0.64, ry: 0.58, stops: [
                .init(color: cruiseRGBA(0x16, 0x18, 0x1c), location: 0), .init(color: cruiseRGBA(0x0b, 0x0c, 0x0e), location: 0.6), .init(color: cruiseRGBA(4, 4, 5), location: 1)])
            // soft cold glow behind the trim
            Ellipse()
                .fill(RadialGradient(stops: [.init(color: cruiseRGBA(176, 196, 226, 0.34), location: 0), .init(color: cruiseRGBA(176, 196, 226, 0.12), location: 0.55),
                                             .init(color: cruiseRGBA(176, 196, 226, 0), location: 1)], center: .center, startRadius: 0, endRadius: 1))
                .frame(width: Tw * 1.24, height: Th * 1.2)
                .blur(radius: Tw * 0.16)
                .position(x: cx, y: cy).allowsHitTesting(false)
            // ring shadow
            RoundedRectangle(cornerRadius: Rw * 0.416, style: .circular)
                .fill(Color.clear)
                .frame(width: Rw + Rw * 0.032, height: Rh + Rw * 0.032)
                .shadow(color: .black.opacity(0.45), radius: Rw * 0.07 / 2, y: Rw * 0.012)
                .position(x: cx, y: cy)
            reveal(Rw: Rw, Rh: Rh, m: m, mt: mt, Pw: Pw, Ph: Ph)
                .frame(width: Rw, height: Rh)
                .position(x: cx, y: cy)
        }
        .frame(width: W, height: H, alignment: .topLeading)
    }

    // MARK: reveal frame

    private func reveal(Rw: Double, Rh: Double, m: Double, mt: Double, Pw: Double, Ph: Double) -> some View {
        let shape = RoundedRectangle(cornerRadius: Rw * 0.4, style: .circular)
        let hh = Rh * 0.112
        let sh = ui.shade
        let hp = hh - mt + Rh * 0.004
        let panelH = hp + sh * (Ph - hp)
        return ZStack(alignment: .topLeading) {
            shape.fill(LinearGradient(stops: [.init(color: cruiseRGBA(0xef, 0xee, 0xe9), location: 0), .init(color: cruiseRGBA(0xd6, 0xd4, 0xcd), location: 0.48),
                                              .init(color: cruiseRGBA(0xb9, 0xb7, 0xb0), location: 1)],
                                      startPoint: cssPoint(162, Rw, Rh).0, endPoint: cssPoint(162, Rw, Rh).1))
            // bevel
            shape.strokeBorder(.white.opacity(0.55), lineWidth: max(1, Rw * 0.004))
            MRInsetShadow(shape, color: .black.opacity(0.2), y: -Rw * 0.03, blur: Rw * 0.06)
            MRInsetShadow(shape, color: .white.opacity(0.4), y: Rw * 0.02, blur: Rw * 0.04)

            pane(Rw: Rw, Rh: Rh, Pw: Pw, Ph: Ph, panelH: panelH)
                .frame(width: Pw, height: Ph)
                .offset(x: m, y: mt)

            // shade housing
            HousingShape()
                .fill(LinearGradient(stops: [.init(color: cruiseRGBA(0x30, 0x30, 0x34), location: 0), .init(color: cruiseRGBA(0x21, 0x21, 0x24), location: 0.55),
                                             .init(color: cruiseRGBA(0x16, 0x16, 0x18), location: 1)], startPoint: .top, endPoint: .bottom))
                .overlay(HousingShape().stroke(.white.opacity(0.07), lineWidth: Rw * 0.006).mask(alignment: .bottom) { Rectangle().frame(height: Rw * 0.012) })
                .frame(width: Rw * 0.74, height: hh + Rh * 0.01)
                .shadow(color: .black.opacity(0.6), radius: Rw * 0.04 / 2, y: Rw * 0.012)
                .offset(x: Rw * 0.13, y: -Rh * 0.01)
                .allowsHitTesting(false)
            Capsule()
                .fill(LinearGradient(colors: [cruiseRGBA(0xd9, 0xd9, 0xd6), cruiseRGBA(0x8f, 0x8f, 0x8c)], startPoint: .top, endPoint: .bottom))
                .frame(width: Rw * 0.4, height: max(2, Rh * 0.007))
                .shadow(color: .black.opacity(0.5), radius: 0, y: 1)
                .offset(x: Rw * 0.3, y: Rh * 0.018)
                .allowsHitTesting(false)
            handle(Rw: Rw, Rh: Rh, mt: mt, hh: hh, panelH: panelH, Ph: Ph)
        }
        .clipShape(shape)
    }

    private func handle(Rw: Double, Rh: Double, mt: Double, hh: Double, panelH: Double, Ph: Double) -> some View {
        let sh = ui.shade
        let down = sh >= 0.03
        let w = down ? Rw * 0.34 : Rw * 0.5
        let h = down ? max(14, Rh * 0.045) : hh
        let y = down ? mt + panelH - Rh * 0.012 : 0
        return ZStack {
            if down {
                RoundedRectangle(cornerRadius: Rh * 0.03, style: .circular)
                    .fill(LinearGradient(colors: [cruiseRGBA(0xe3, 0xe0, 0xd6), cruiseRGBA(0xbd, 0xb8, 0xa8)], startPoint: .top, endPoint: .bottom))
                    .overlay(alignment: .top) { RoundedRectangle(cornerRadius: Rh * 0.03).strokeBorder(.white.opacity(0.6), lineWidth: 1).mask(alignment: .top) { Rectangle().frame(height: 1.5) } }
                    .shadow(color: .black.opacity(0.45), radius: Rw * 0.03 / 2, y: Rw * 0.01)
                Capsule().fill(cruiseRGBA(20, 17, 15, 0.38)).frame(width: w * 0.46, height: 3)
            } else {
                Color.clear
            }
        }
        .frame(width: w, height: h)
        .contentShape(Rectangle())
        .offset(x: Rw / 2 - w / 2, y: y)
        .animation(dragStart == nil ? (reduceMotion ? nil : MRMotion.smooth) : nil, value: ui.shade)
        .gesture(DragGesture(minimumDistance: 1)
            .onChanged { v in
                if dragStart == nil { dragStart = ui.shade }
                ui.shade = max(0, min(1, (dragStart ?? 0) + v.translation.height / Ph))
            }
            .onEnded { _ in dragStart = nil })
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Window shade")
        .accessibilityValue("\(Int((ui.shade * 100).rounded())) percent")
        .accessibilityAdjustableAction { dir in
            ui.shade = max(0, min(1, ui.shade + (dir == .increment ? 0.1 : -0.1)))
        }
    }

    // MARK: pane

    private func pane(Rw: Double, Rh: Double, Pw: Double, Ph: Double, panelH: Double) -> some View {
        let radius = Pw * 0.31
        let shape = RoundedRectangle(cornerRadius: radius, style: .circular)
        let layers = sceneLayers()
        let primary = layers.max(by: { $0.opacity < $1.opacity })?.spec ?? WindowSceneSpec.spec("day")
        return ZStack(alignment: .topLeading) {
            Color.black
            // scene box: left -4%, width 108%, height 104% (tilted scenes: -14%, 128%)
            ZStack(alignment: .topLeading) {
                ForEach(layers, id: \.spec.key) { l in
                    let b = l.spec.box
                    sceneBox(l.spec, w: Pw * b.w, h: Ph * b.h).opacity(l.opacity).offset(x: Pw * b.x, y: Ph * b.y)
                }
            }
            .frame(width: Pw, height: Ph, alignment: .topLeading)

            // glass: softened edges
            ZStack(alignment: .topLeading) {
                ForEach(layers, id: \.spec.key) { l in
                    let b = l.spec.box
                    sceneBox(l.spec, w: Pw * b.w + 60, h: Ph * b.h + 60).opacity(l.opacity).offset(x: Pw * b.x - 30, y: Ph * b.y - 30)
                }
            }
            .frame(width: Pw, height: Ph, alignment: .topLeading)
            .blur(radius: 2.2)
            .mask { CSSEllipse(rx: 0.62, ry: 0.56, stops: [.init(color: .clear, location: 0.34), .init(color: .black, location: 0.92)]) }
            ZStack(alignment: .topLeading) {
                ForEach(layers, id: \.spec.key) { l in
                    let b = l.spec.box
                    sceneBox(l.spec, w: Pw * b.w + 60, h: Ph * b.h + 60).opacity(l.opacity).offset(x: Pw * b.x - 30, y: Ph * b.y - 30)
                }
            }
            .frame(width: Pw, height: Ph, alignment: .topLeading)
            .blur(radius: 5)
            .mask { CSSEllipse(rx: 0.60, ry: 0.54, stops: [.init(color: .clear, location: 0.58), .init(color: .black, location: 1.08)]) }

            // sky gradient at the top
            let sky = primary.sky
            if !primary.hideSky { LinearGradient(stops: [.init(color: cruiseRGBA(sky.0, sky.1, sky.2, 1), location: 0), .init(color: cruiseRGBA(sky.0, sky.1, sky.2, 1), location: 0.38),
                                   .init(color: cruiseRGBA(sky.0, sky.1, sky.2, 0.4), location: 0.68), .init(color: cruiseRGBA(sky.0, sky.1, sky.2, 0), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: Ph * 0.22).allowsHitTesting(false) }
            // reflection and vignette
            LinearGradient(stops: [.init(color: .white.opacity(0), location: 0.30), .init(color: .white.opacity(0.10), location: 0.38),
                                   .init(color: .white.opacity(0.015), location: 0.46), .init(color: .white.opacity(0), location: 0.60)],
                           startPoint: cssPoint(118, Pw, Ph).0, endPoint: cssPoint(118, Pw, Ph).1)
                .allowsHitTesting(false)
            CSSEllipse(cx: 0.5, cy: 0.45, rx: 1.3, ry: 1.0, stops: [.init(color: .clear, location: 0.62), .init(color: .black.opacity(0.34), location: 1)])
            shape.strokeBorder(.white.opacity(0.12), lineWidth: 1)
            MRInsetShadow(shape, color: .black.opacity(0.45), blur: Rw * 0.05)

            // pull-down shade
            ZStack(alignment: .top) {
                LinearGradient(colors: [cruiseRGBA(0xE9, 0xE5, 0xDA), cruiseRGBA(0xD8, 0xD2, 0xC3)], startPoint: .top, endPoint: .bottom)
                Canvas { ctx, sz in
                    var y = 0.0
                    while y < sz.height { ctx.fill(Path(CGRect(x: 0, y: y, width: sz.width, height: 1)), with: .color(cruiseRGBA(20, 17, 15, 0.07))); y += 7 }
                }
                Capsule().fill(cruiseRGBA(0xFF, 0xF4, 0xD8)).frame(width: Pw * 0.84, height: 3)
                    .shadow(color: cruiseRGBA(255, 236, 190, 0.65), radius: 7)
                    .opacity(ui.shade > 0.8 && ui.shade < 0.995 ? 0.35 + (ui.shade - 0.8) * 3 : 0)
                    .frame(maxHeight: .infinity, alignment: .bottom).offset(y: 3)
            }
            .frame(height: panelH)
            .shadow(color: .black.opacity(0.45), radius: Rw * 0.05 / 2, y: Rw * 0.02)
            .opacity(ui.shade <= 0.001 ? 0 : 1)
            .animation(dragStart == nil ? (reduceMotion ? nil : MRMotion.smooth) : nil, value: ui.shade)
        }
        .frame(width: Pw, height: Ph, alignment: .topLeading)
        .clipShape(shape)
        .overlay(shape.stroke(cruiseRGBA(40, 40, 42, 0.9), lineWidth: max(1, Rw * 0.006)).padding(-max(1, Rw * 0.006) / 2))
        .shadow(color: .black.opacity(0.5), radius: Rw * 0.03 / 2)
    }

    private struct SceneLayer { let spec: WindowSceneSpec; let opacity: Double }

    /// The chosen scene, or the crossfade of the real sun elevation.
    private func sceneLayers() -> [SceneLayer] {
        // automatic scene: the take-off roll and the final approach use the canvas' `takeoff` / `landing` scenes
        if ui.sceneAuto, frame.progress < 0.03 { return [SceneLayer(spec: WindowSceneSpec.spec("takeoff"), opacity: 1)] }
        if ui.sceneAuto, frame.progress > 0.96 { return [SceneLayer(spec: WindowSceneSpec.spec("landing"), opacity: 1)] }
        if ui.sceneAuto, let b = frame.windowBlend {
            let from = WindowSceneSpec.spec(WindowSceneSpec.key(b.from)), to = WindowSceneSpec.spec(WindowSceneSpec.key(b.to))
            if from.key == to.key { return [SceneLayer(spec: from, opacity: 1)] }
            return [SceneLayer(spec: from, opacity: 1), SceneLayer(spec: to, opacity: b.weight)]
        }
        return [SceneLayer(spec: WindowSceneSpec.spec(ui.scene), opacity: 1)]
    }

    private func sceneBox(_ s: WindowSceneSpec, w: Double, h: Double) -> some View {
        ZStack {
            if let img = WindowPhoto.image(s.image) {
                // background: url() 50% 0% / cover
                let scale = max(w / img.size.width, h / img.size.height)
                Image(nsImage: img).resizable().interpolation(.high)
                    .frame(width: img.size.width * scale, height: img.size.height * scale)
                    .frame(width: w, height: h, alignment: .top)
                    .brightness(s.brightness).contrast(s.contrast).saturation(s.saturation)
                    .blur(radius: 0.7)
                    .modifier(DriftModifier(enabled: !reduceMotion && s.zoom == 1))
                    .scaleEffect(s.zoom, anchor: .bottom)
            }
            if let sun = s.sun {
                CSSEllipse(cx: sun.0, cy: sun.1, rx: 0.5, ry: 0.5, stops: sun.2).blendMode(.screen)
            }
            if s.rain { WindowRain(storm: s.storm) }
            if s.runway { RunwayLights().frame(width: w, height: h) }
        }
        .frame(width: w, height: h)
        .clipped()
        .rotationEffect(.degrees(s.tilt), anchor: s.key == "takeoff" ? UnitPoint(x: 0.5, y: 0.6) : .center)
    }
}

/// `wv-drift`: 70 s ease-in-out alternate, scale 1 to 1.06 and a small translate.
private struct DriftModifier: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled {
            TimelineView(.animation(minimumInterval: 1.0 / 20)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 140) / 70
                let u = t <= 1 ? t : 2 - t
                let e = u * u * (3 - 2 * u)
                content.scaleEffect(1 + 0.06 * e, anchor: .top)
            }
        } else {
            content
        }
    }
}

/// Approach lights of the `landing` scene: two converging rows of warm dots and the red / white PAPI (`rwy`, viewBox 200 x 300).
private struct RunwayLights: View {
    var body: some View {
        Canvas { ctx, size in
            let sx = size.width / 200, sy = size.height / 300
            for i in 0..<11 {
                let f = Double(i) / 10, y = 296 - f * 120, spread = 7 + (1 - f) * 70
                let r = 1 + (1 - f) * 2.2, o = 0.5 + (1 - f) * 0.5
                for x in [100 - spread, 100 + spread] {
                    ctx.fill(Path(ellipseIn: CGRect(x: (x - r) * sx, y: (y - r) * sy, width: 2 * r * sx, height: 2 * r * sy)),
                             with: .color(cruiseRGBA(0xFF, 0xE9, 0xB8, o)))
                }
            }
            for (x, red) in [(86.0, true), (96, true), (106, false), (116, false)] {
                ctx.fill(Path(ellipseIn: CGRect(x: (x - 2.6) * sx, y: (262 - 2.6) * sy, width: 5.2 * sx, height: 5.2 * sy)),
                         with: .color(red ? cruiseRGBA(0xFF, 0x5C, 0x5C) : .white))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct WindowRain: View {
    let storm: Bool
    var body: some View {
        ZStack {
            Rectangle().fill(cruiseRGBA(40, 52, 70, 0.2))
            TimelineView(.animation(minimumInterval: 1.0 / 20)) { tl in
                Canvas { ctx, size in
                    var seed: UInt64 = storm ? 977 * 5 + 3 : 977 * 4 + 3
                    func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double((seed >> 33) & 0xFFFFFF) / Double(0x1000000) }
                    let t = tl.date.timeIntervalSinceReferenceDate
                    for _ in 0..<26 {
                        let dl = rnd() * 3.2
                        let x = rnd() * 0.96 * size.width, y0 = rnd() * 0.7 * size.height, sc = 0.6 + rnd() * 1.1
                        let dur = 2.6 + rnd() * 2.4
                        let u = ((t - dl).truncatingRemainder(dividingBy: dur) + dur).truncatingRemainder(dividingBy: dur) / dur
                        let dy = -14 + 134 * u * u
                        let op = u < 0.12 ? u / 0.12 * 0.85 : 0.85 * (1 - (u - 0.12) / 0.88)
                        let r = CGRect(x: x, y: y0 + dy, width: 5 * sc, height: 9 * sc)
                        ctx.fill(Path(ellipseIn: r), with: .radialGradient(Gradient(stops: [.init(color: .white.opacity(0.8 * op), location: 0), .init(color: .white.opacity(0.12 * op), location: 0.55), .init(color: .white.opacity(0.04 * op), location: 1)]), center: CGPoint(x: r.minX + r.width * 0.35, y: r.minY + r.height * 0.3), startRadius: 0, endRadius: r.height * 0.7))
                    }
                }
            }
            if storm { StormFlash() }
        }
    }
}

private struct StormFlash: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { tl in
            let u = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 7) / 7
            let o: Double = u < 0.90 ? 0 : u < 0.92 ? 0 : u < 0.94 ? 0.78 : u < 0.96 ? 0.08 : u < 0.98 ? 0.5 : 0
            CSSEllipse(cx: 0.4, cy: 0.3, rx: 0.6, ry: 0.6, stops: [.init(color: cruiseRGBA(0xE8, 0xEE, 0xFF), location: 0), .init(color: cruiseRGBA(0x9D, 0xB2, 0xFF), location: 0.4), .init(color: .clear, location: 0.8)])
                .blendMode(.screen).opacity(o)
        }
    }
}

/// `border-radius: 0 0 50% 50% / 0 0 100% 100%`: a flat top with an elliptical bottom.
private struct HousingShape: Shape {
    nonisolated func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        let steps = 48
        for i in 0...steps {
            let t = Double.pi * Double(i) / Double(steps)
            p.addLine(to: CGPoint(x: r.midX + cos(t) * r.width / 2, y: r.minY + sin(t) * r.height))
        }
        p.closeSubpath()
        return p
    }
}

private func cssPoint(_ deg: Double, _ w: Double, _ h: Double) -> (UnitPoint, UnitPoint) {
    let a = deg * .pi / 180
    let dx = sin(a), dy = -cos(a)
    let len = abs(w * sin(a)) + abs(h * cos(a))
    let c = CGPoint(x: w / 2, y: h / 2)
    return (UnitPoint(x: (c.x - dx * len / 2) / w, y: (c.y - dy * len / 2) / h), UnitPoint(x: (c.x + dx * len / 2) / w, y: (c.y + dy * len / 2) / h))
}

// MARK: - Controls

struct CruiseWindowControls: View {
    let frame: CruiseFrame
    @Bindable var ui: CruiseUI
    let onMap: () -> Void
    @State private var hover = false

    private static let scenes: [(String, String, [Color])] = [
        ("day", "Day", [cruiseRGBA(0x8E, 0xC3, 0xF2), cruiseRGBA(0xDC, 0xEB, 0xFA)]),
        ("blue", "Blue hour", [cruiseRGBA(0x4B, 0x5F, 0xA8), cruiseRGBA(0xC9, 0x8F, 0xA8)]),
        ("sunset", "Sunset", [cruiseRGBA(0x6B, 0x5B, 0x95), cruiseRGBA(0xF2, 0xA0, 0x60)]),
        ("night", "Night", [cruiseRGBA(0x0B, 0x12, 0x26), cruiseRGBA(0x2A, 0x35, 0x60)]),
        ("rain", "Rain", [cruiseRGBA(0x5E, 0x6B, 0x7A), cruiseRGBA(0x9A, 0xA6, 0xB2)]),
        ("storm", "Storm", [cruiseRGBA(0x2B, 0x33, 0x40), cruiseRGBA(0x6A, 0x75, 0x85)]),
    ]

    private var sceneName: String { Self.scenes.first { $0.0 == ui.currentSceneKey(frame) }?.1 ?? "Day" }

    var body: some View {
        let expanded = (hover || ui.capLabels) && ui.menu == nil
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 2) {
                WindowCapItem(icon: .map, label: "Map view", kbd: "W", on: false, expanded: expanded, a11y: "Map view", action: onMap)
                WindowCapItem(icon: .sun, label: "Scene · \(sceneName)", kbd: nil, on: ui.menu == .scene, expanded: expanded, a11y: "Scene: \(sceneName)") {
                    ui.menu = ui.menu == .scene ? nil : .scene
                }
            }
            .padding(4)
            .fixedSize()
            .cruiseGlass(26, .e2, amber: frame.isAmber)
            .onHover { hv in withAnimation(MRMotion.hover) { hover = hv } }
            .animation(MRMotion.ease(MRMotion.d2), value: expanded)
            .padding(.trailing, 20).padding(.top, 18)
            if ui.menu == .scene {
                CruiseMenu(items: Self.scenes.map { ($0.1, $0.2, $0.0) }, selected: ui.currentSceneKey(frame), diagonal: false, a11y: "Scene") {
                    ui.scene = $0; ui.sceneAuto = false; ui.menu = nil
                }
                .padding(.trailing, ui.capLabels ? 244 : 78).padding(.top, 58)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
}

private struct WindowCapItem: View {
    let icon: MRIconName, label: String
    var kbd: String?
    let on: Bool, expanded: Bool
    let a11y: String
    let action: () -> Void
    @State private var hover = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = MRPalette.resolve(scheme)
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        Button(action: action) {
            HStack(spacing: expanded ? 10 : 0) {
                MRIcon(icon, size: 18)
                if expanded {
                    HStack(spacing: 8) {
                        Text(label).font(.mr(.ui, size: 13, weight: 500)).lineLimit(1).fixedSize()
                        if let kbd { MRKbd(kbd) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .foregroundStyle(on ? p.bg0.color : p.text1.color)
            .padding(.leading, expanded ? 11 : 0).padding(.trailing, expanded ? 14 : 0)
            .frame(width: expanded ? nil : 40, height: 40)
            .frame(maxWidth: expanded ? .infinity : 40, alignment: expanded ? .leading : .center)
            .background(shape.fill(on ? p.text1.color : (hover ? p.fill2.color : .clear)))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hv in withAnimation(MRMotion.hover) { hover = hv } }
        .accessibilityLabel(a11y)
    }
}

extension CruiseUI {
    /// The scene key the window shows: the chosen one, or the one the sun picks.
    func currentSceneKey(_ frame: CruiseFrame) -> String {
        if sceneAuto, let b = frame.windowBlend { return WindowSceneSpec.key(b.dominant) }
        return scene
    }
}
