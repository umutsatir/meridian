import MeridianCore
import MeridianMaps
import MeridianUI
import SwiftUI

func sysRGBA(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> Color {
    Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: a)
}

/// Callbacks of the mini map controls (M02). All optional: the artboards draw the view without behavior.
struct MiniMapActions {
    var pause: () -> Void = {}
    var sound: () -> Void = {}
    var size: () -> Void = {}
    var close: () -> Void = {}
    var dragChanged: () -> Void = {}
    var dragEnded: () -> Void = {}
    var resizeChanged: () -> Void = {}
    var resizeEnded: () -> Void = {}
}

/// `MiniMap.dc.html`: the Europe map framed on the route, the trail, the plane, the time chip, the hover
/// controls and the resize grip. The same view is used in the floating panel, in the menu bar popover (310 x 140)
/// and in the artboards.
struct MiniMapView: View {
    var info: SystemFlightInfo
    var size: CGSize
    var opacity: Double = 1
    var clickThrough = false
    /// Pins the hover state (artboards) instead of tracking the pointer.
    var pinnedHover: Bool?
    /// Name of the control drawn hovered (`pause`, `sound`, `size`, `close`).
    var pinnedButton: String?
    var chip: String?
    var drawsShadow = true
    var interactive = true
    /// Follow camera: closer, the plane stays in the middle and the map moves under it every frame (live surfaces only;
    /// the artboards keep the whole-route framing of the design).
    var follows = false
    var actions = MiniMapActions()

    @State private var hovering = false
    @State private var stamp: (progress: Double, at: Date) = (0, .now)
    @State private var windowVisible = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var over: Bool { pinnedHover ?? hovering }

    var body: some View {
        if follows {
            // 15 fps is plenty for a 310 x 140 map; the plane is advanced from the flight's own rate between the 1 Hz updates
            TimelineView(.animation(minimumInterval: 1.0 / 15, paused: !windowVisible)) { tl in
                mapBody(progress: liveProgress(at: tl.date))
            }
            .onChange(of: info.progress) { _, p in stamp = (p, .now) }
            .onAppear { stamp = (info.progress, .now) }
            .background(WindowActivity(visible: $windowVisible))
        } else {
            mapBody(progress: info.progress)
        }
    }

    private func liveProgress(at now: Date) -> Double {
        guard info.kind == .flight || info.kind == .last, !info.paused, !info.isFreeFlight, info.timeSec > 0, info.progress < 1 else { return info.progress }
        let rate = (1 - info.progress) / info.timeSec
        return min(1, stamp.progress + rate * max(0, min(2, now.timeIntervalSince(stamp.at))))
    }

    private func mapBody(progress: Double) -> some View {
        let W = size.width, H = size.height
        let geo = Geometry(info: info, width: W, height: H, progress: progress, follows: follows)
        return ZStack(alignment: .topLeading) {
            if let cam = geo.camera {
                MapSurface(style: .terra, theme: .dark, center: geo.mid, zoom: geo.zoom, size: size, showsLabels: W >= 480, animatesCamera: false, followCamera: cam)
            } else {
                MapSurface(style: .terra, theme: .dark, center: geo.mid, zoom: geo.zoom, size: size, showsLabels: W >= 480)
            }
            LinearGradient(stops: [.init(color: sysRGBA(6, 8, 13, 0), location: 0.5),
                                   .init(color: sysRGBA(6, 8, 13, 0.5), location: 1)], startPoint: .top, endPoint: .bottom)
            route(geo)
            chipView
            if clickThrough { clickThroughPill }
            controls
            grip
        }
        .frame(width: W, height: H)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.22), lineWidth: 1))
        .overlay(alignment: .top) {
            // inset 0 1px 0 rgba(255,255,255,.3)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.12)), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: drawsShadow ? .black.opacity(0.55) : .clear, radius: 28, y: 24)
        .opacity(opacity)
        .onHover { hv in withAnimation(MRMotion.hover) { if interactive { hovering = hv } } }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mini map. \(info.route). \(info.paused ? "Paused" : info.timeString + " left")")
    }

    // MARK: Route

    private struct Geometry {
        let points: [CGPoint]
        let mid: Coordinate
        let zoom: Double
        let k0: Int
        let here: CGPoint
        let heading: Double
        let hasRoute: Bool
        var camera: FollowCamera?

        init(info: SystemFlightInfo, width W: Double, height H: Double, progress: Double? = nil, follows: Bool = false) {
            guard let a = info.origin, let b = info.destination else {
                mid = info.origin ?? SystemFlightInfo.lhr
                zoom = 3; points = []; k0 = 0; hasRoute = false; heading = 0; camera = nil
                here = CGPoint(x: W / 2, y: H / 2)
                return
            }
            hasRoute = true
            let pts = systemArc(from: a, to: b, steps: 60)
            let prog = min(1, max(0, progress ?? info.progress))
            let si = prog * Double(pts.count - 1)
            let k0 = Int(si.rounded(.down)), k1 = min(pts.count - 1, k0 + 1), f = si - Double(k0)
            let hereC = Coordinate(latitude: pts[k0].latitude + (pts[k1].latitude - pts[k0].latitude) * f,
                                   longitude: pts[k0].longitude + (pts[k1].longitude - pts[k0].longitude) * f)
            let A = EuropeProjection.xy(pts[0]), B = EuropeProjection.xy(pts[pts.count - 1])
            let fit = min(0.62 * W / max(abs(A.x - B.x), 1), 0.5 * H / max(abs(A.y - B.y), 1), 4)
            // follow: closer than the whole route, centred on the plane (continuous position, not the sampled one)
            let z = follows ? max(fit * 2.4, 2.5) : fit
            let mid = follows ? Geo.interpolate(from: a, to: b, fraction: prog) : pts[pts.count / 2]
            let C = EuropeProjection.xy(mid)
            if follows { camera = FollowCamera(centerP: C, scale: z, bearing: 0, pivot: CGPoint(x: W / 2, y: H / 2), size: CGSize(width: W, height: H)) }
            func scr(_ c: Coordinate) -> CGPoint {
                let q = EuropeProjection.xy(c)
                return CGPoint(x: (q.x - C.x) * z + W / 2, y: (q.y - C.y) * z + H / 2)
            }
            let sp = pts.map(scr)
            let ahead = sp[min(sp.count - 1, k0 + 2)]
            self.points = sp
            self.mid = mid
            self.zoom = z
            self.k0 = k0
            self.here = follows ? CGPoint(x: W / 2, y: H / 2) : scr(hereC)
            self.heading = atan2(ahead.x - sp[k0].x, -(ahead.y - sp[k0].y)) * 180 / .pi
        }
    }

    @ViewBuilder
    private func route(_ g: Geometry) -> some View {
        if g.hasRoute {
            let first = g.points[0], last = g.points[g.points.count - 1]
            let future = polyline(Array(g.points[g.k0...]))
            let trail = polyline(Array(g.points[0...g.k0]) + [g.here])
            let gradient = Gradient(colors: [sysRGBA(106, 183, 255), sysRGBA(139, 243, 216)])
            ZStack(alignment: .topLeading) {
                future.stroke(.white.opacity(0.5), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [2, 5]))
                trail.stroke(sysRGBA(106, 183, 255, 0.3), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                trail.stroke(LinearGradient(gradient: gradient, startPoint: UnitPoint(x: 0, y: 0), endPoint: UnitPoint(x: 1, y: 0)),
                             style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                    .opacity(1)
                Circle().fill(.white).frame(width: 6.4, height: 6.4).position(first)
                Circle().strokeBorder(sysRGBA(255, 181, 71), lineWidth: 1.6).frame(width: 6.4, height: 6.4).position(last)
                MRIcon(.plane, size: 24)
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(g.heading))
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 2)
                    .position(g.here)
            }
            .accessibilityHidden(true)
        }
    }

    private func polyline(_ pts: [CGPoint]) -> Path {
        var p = Path()
        for (i, q) in pts.enumerated() { i == 0 ? p.move(to: q) : p.addLine(to: q) }
        return p
    }

    // MARK: Chip, pill

    private var chipView: some View {
        HStack(spacing: 8) {
            Text(chip ?? info.timeString)
                .font(MRFonts.font(.mono, size: 14, weight: 500)).tracking(-0.28).monospacedDigit()
            if chip == nil {
                Text(info.paused ? "Paused" : "to \(info.destinationCity)")
                    .font(MRFonts.font(.ui, size: 11, weight: 500))
                    .foregroundStyle(sysRGBA(243, 245, 250, 0.82))
            }
        }
        .foregroundStyle(sysRGBA(243, 245, 250))
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(Capsule().fill(sysRGBA(18, 26, 46, 0.66)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1))
        .offset(x: 12, y: size.height - 12 - 30)
    }

    private var clickThroughPill: some View {
        HStack(spacing: 6) {
            MRIcon(.target, size: 12)
            Text("Click-through").font(MRFonts.font(.ui, size: 11, weight: 600)).tracking(11 * 0.04).textCase(.uppercase)
        }
        .foregroundStyle(MRPalette.dark.accentPillText.color)
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(Capsule().fill(sysRGBA(18, 26, 46, 0.7)))
        .overlay(Capsule().fill(sysRGBA(106, 183, 255, 0.16)))
        .offset(x: 12, y: 12)
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 6) {
            control(info.paused ? .play : .pause, label: info.paused ? "Resume" : "Pause", key: "pause", action: actions.pause)
            control(.sound, label: "Sound", key: "sound", action: actions.sound)
            control(.resize, label: "Size", key: "size", action: actions.size)
            control(.x, label: "Close", key: "close", action: actions.close)
        }
        .opacity(over ? 1 : 0)
        .offset(y: over || reduceMotion ? 0 : -4)
        .animation(MRMotion.ease(MRMotion.d2), value: over)
        .allowsHitTesting(over && interactive)
        .frame(width: size.width, alignment: .trailing)
        .padding(.trailing, 10)
        .padding(.top, 10)
        .frame(width: size.width, height: 38, alignment: .topTrailing)
    }

    private func control(_ icon: MRIconName, label: String, key: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { MRIcon(icon, size: 14) }
            .buttonStyle(MiniMapButtonStyle(pinnedHover: pinnedButton == key))
            .accessibilityLabel(label)
    }

    private var grip: some View {
        Canvas { ctx, _ in
            var p = Path()
            p.move(to: CGPoint(x: 9, y: 3)); p.addLine(to: CGPoint(x: 3, y: 9))
            p.move(to: CGPoint(x: 9, y: 6.5)); p.addLine(to: CGPoint(x: 6.5, y: 9))
            ctx.stroke(p, with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
        .frame(width: 10, height: 10)
        .frame(width: 22, height: 22, alignment: .bottomTrailing)
        .padding(5)
        .frame(width: 22, height: 22)
        .contentShape(Rectangle())
        .opacity(over ? 1 : 0)
        .animation(MRMotion.ease(MRMotion.d2), value: over)
        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { _ in actions.resizeChanged() }
            .onEnded { _ in actions.resizeEnded() })
        .allowsHitTesting(over && interactive)
        .accessibilityLabel("Resize")
        .offset(x: size.width - 22 - 4, y: size.height - 22 - 4)
    }
}

/// `.mm-b`: 28 pt glass circle.
struct MiniMapButtonStyle: ButtonStyle {
    var pinnedHover = false
    func makeBody(configuration: Configuration) -> some View {
        Content(configuration: configuration, pinnedHover: pinnedHover)
    }

    private struct Content: View {
        let configuration: Configuration
        let pinnedHover: Bool
        @State private var hovered = false
        @Environment(\.isFocused) private var focused
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        var body: some View {
            configuration.label
                .foregroundStyle(MRPalette.dark.text1.color)
                .frame(width: 28, height: 28)
                .background(Circle().fill(hovered || pinnedHover ? sysRGBA(40, 56, 92, 0.8) : sysRGBA(18, 26, 46, 0.62)))
                .overlay(Circle().strokeBorder(.white.opacity(0.16), lineWidth: 1))
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1)
                .overlay { if focused { Circle().strokeBorder(MRPalette.dark.accent1.color, lineWidth: 2).padding(-4) } }
                .animation(MRMotion.ease(MRMotion.d1), value: hovered)
                .animation(MRMotion.ease(MRMotion.d1), value: configuration.isPressed)
                .onHover { hv in withAnimation(MRMotion.hover) { hovered = hv } }
        }
    }
}
