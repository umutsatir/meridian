import AppKit
import MeridianCore
import MeridianMaps
import MeridianUI
import SwiftUI

/// MAP VIEW of `Flight.dc.html`: the map with the follow camera, terminator, vignette, the route (dashed future,
/// glowing gradient trail), both airport tags and the plane.
///
/// The camera is not an animation chain: every rendered frame (30 fps) the plane position is recomputed from the clock
/// (`progressAt(now)`), `FollowCameraState` turns it into a camera that sits exactly on the plane, and the map, the route,
/// the tags and the plane marker are all drawn from that one camera. Dragging / scrolling leaves follow mode (free camera,
/// the plane keeps flying); Recenter glides back.
struct CruiseMapLayer: View {
    let frame: CruiseFrame
    var progressAt: ((Date) -> Double)?
    @Bindable var ui: CruiseUI
    let size: CGSize
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var driver = CruiseFollowDriver()
    @State private var windowVisible = true
    @State private var dragLast: CGSize?
    @State private var pinchLast = 1.0

    /// 30 fps cap (PRD §10.1 energy budget); nothing is drawn while the window is hidden or occluded.
    static let frameInterval = 1.0 / 30

    var body: some View {
        ZStack(alignment: .topLeading) {
            TimelineView(.animation(minimumInterval: Self.frameInterval, paused: !windowVisible)) { tl in
                content(at: tl.date)
            }
            Color.clear.contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 3)
                    .onChanged { v in
                        guard let cam = ui.lastCamera else { return }
                        if dragLast == nil { ui.camera.userMoved(camera: cam); dragLast = .zero }
                        let last = dragLast ?? .zero
                        ui.camera.pan(by: CGSize(width: v.translation.width - last.width, height: v.translation.height - last.height), camera: cam)
                        dragLast = v.translation
                    }
                    .onEnded { _ in dragLast = nil })
                .simultaneousGesture(MagnifyGesture()
                    .onChanged { v in
                        let f = v.magnification / pinchLast
                        pinchLast = v.magnification
                        ui.zoom(factor: f, about: v.startLocation)
                    }
                    .onEnded { _ in pinchLast = 1 })
                .onScroll { e in handleScroll(e) }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipped()
        .background(WindowActivity(visible: $windowVisible))
    }

    // MARK: Frame

    @ViewBuilder
    private func content(at now: Date) -> some View {
        let progress = progressAt?(now) ?? frame.progress
        let f = driver.step(now: now, frame: frame, progress: progress, ui: ui, size: size, snapRotation: reduceMotion)
        let cam = f.camera
        let W = size.width, H = size.height
        let sp = f.routeP.map(cam.screen)
        let hp = cam.screen(f.hereP)
        let dark = scheme == .dark
        ZStack(alignment: .topLeading) {
            MapSurface(style: MapStyleAccess.resolved(ui.style), center: cam.viewCenter, zoom: cam.scale, animatesCamera: false, followCamera: cam)
                .frame(width: W, height: H)

            if ui.style == .terra {
                // linear-gradient(104deg, transparent 56%, .16 70%, .3 100%) multiplied over the map
                LinearGradient(stops: [.init(color: cruiseRGBA(2, 4, 16, 0), location: 0.56), .init(color: cruiseRGBA(2, 4, 16, 0.16), location: 0.70),
                                       .init(color: cruiseRGBA(2, 4, 16, 0.3), location: 1)],
                               startPoint: cssStart(104, W, H).0, endPoint: cssStart(104, W, H).1)
                    .blendMode(.multiply).allowsHitTesting(false)
            }
            // .vig::after
            CSSEllipse(rx: 1.2, ry: 0.9, stops: dark
                ? [.init(color: cruiseRGBA(6, 8, 13, 0), location: 0.55), .init(color: cruiseRGBA(6, 8, 13, 0.55), location: 1)]
                : [.init(color: cruiseRGBA(120, 110, 90, 0), location: 0.6), .init(color: cruiseRGBA(120, 110, 90, 0.22), location: 1)])

            if ui.route {
                RouteLayer(points: sp, k0: f.k0, here: hp, size: size)
                    .allowsHitTesting(false)
            }
            if onScreen(sp[0]) {
                dot(sp[0], ring: Color(RGB(hex: "#F3F5FA")))
                tag(frame.origin.iata, at: sp[0], selected: false)
            }
            if frame.destination != nil, let end = sp.last, onScreen(end) {
                dot(end, ring: MRPalette.resolve(scheme).amber.color)
                tag(frame.destination?.iata ?? "", at: end, selected: true)
            }
            PlaneMarker(size: 34, heading: f.markerRotation)
                .position(hp)
                .allowsHitTesting(false)
        }
        .frame(width: W, height: H, alignment: .topLeading)
    }

    private func onScreen(_ p: CGPoint) -> Bool {
        p.x > -60 && p.x < size.width + 60 && p.y > -80 && p.y < size.height + 60
    }

    // MARK: Scroll

    /// Mouse wheel and ⌥ / ⌃ + two-finger scroll zoom (about the plane while following, about the pointer while free);
    /// a plain two-finger scroll pans like in Maps and leaves follow mode.
    private func handleScroll(_ e: ScrollInfo) {
        guard let cam = ui.lastCamera else { return }
        if !e.precise || e.zoomModifier {
            let dy = e.dy * (e.precise ? 1 : 4)
            ui.zoom(factor: FollowCameraModel.wheelFactor(delta: -dy * 0.6), about: e.location)
        } else if abs(e.dx) + abs(e.dy) > 0 {
            ui.camera.userMoved(camera: cam)
            ui.camera.pan(by: CGSize(width: e.dx, height: e.dy), camera: cam)
        }
    }

    private func dot(_ p: CGPoint, ring: Color) -> some View {
        Circle().fill(MRPalette.resolve(scheme).bg1.color).frame(width: 10, height: 10)
            .overlay(Circle().strokeBorder(ring, lineWidth: 2).padding(-1))
            .position(p).allowsHitTesting(false)
    }

    private func tag(_ code: String, at p: CGPoint, selected: Bool) -> some View {
        // transform: translate(-50%, -190%) of the 24 pt tag
        AirportTag(code: code, isSelected: selected, showsIcon: true)
            .scaleEffect(selected ? 1 / 1.15 : 1)
            .fixedSize()
            .position(x: p.x, y: p.y - 24 * 1.9 + 12)
            .allowsHitTesting(false)
    }

    private func cssStart(_ deg: Double, _ w: Double, _ h: Double) -> (UnitPoint, UnitPoint) {
        let a = deg * .pi / 180
        let dx = sin(a), dy = -cos(a)
        let len = abs(w * sin(a)) + abs(h * cos(a))
        let c = CGPoint(x: w / 2, y: h / 2)
        let s = CGPoint(x: c.x - dx * len / 2, y: c.y - dy * len / 2), e = CGPoint(x: c.x + dx * len / 2, y: c.y + dy * len / 2)
        return (UnitPoint(x: s.x / w, y: s.y / h), UnitPoint(x: e.x / w, y: e.y / h))
    }
}

// MARK: - Driver

/// Per-frame state of the cruise camera: the route in plane coordinates, the smoothed camera and the clock of the last frame.
/// A reference type on purpose: it is advanced while the frame is built, which must not invalidate the view.
@MainActor
final class CruiseFollowDriver {
    struct Out {
        var camera: FollowCamera
        var hereP: CGPoint
        var routeP: [CGPoint]
        var k0: Int
        var markerRotation: Double
    }

    static let samples = 90
    private var state = FollowCameraState()
    private var last: Date?
    private var key = ""
    private var routeP: [CGPoint] = []
    private var origin = Coordinate(latitude: 0, longitude: 0), dest = Coordinate(latitude: 0, longitude: 0)

    func step(now: Date, frame: CruiseFrame, progress: Double, ui: CruiseUI, size: CGSize, snapRotation: Bool) -> Out {
        let o = frame.origin.coordinate, d = (frame.destination ?? frame.origin).coordinate
        let k = "\(frame.origin.iata)-\(frame.destination?.iata ?? "")"
        if k != key {
            key = k; origin = o; dest = d
            routeP = (0...Self.samples).map { EuropeProjection.xy(Geo.interpolate(from: o, to: d, fraction: Double($0) / Double(Self.samples))) }
            state = FollowCameraState()
        }
        let si = max(0, min(Double(Self.samples), progress * Double(Self.samples)))
        let a = Int(si.rounded(.down)), b = min(Self.samples, a + 1), t = si - Double(a)
        let here = CGPoint(x: routeP[a].x + (routeP[b].x - routeP[a].x) * t, y: routeP[a].y + (routeP[b].y - routeP[a].y) * t)
        let heading = FollowCameraModel.planeHeading(from: origin, to: dest, fraction: progress)

        // route fit (the old default view): the whole leg at a comfortable size
        let W = size.width, H = size.height
        let A = routeP[0], B = routeP[Self.samples]
        let zFit = min(0.62 * (W - 220) / max(abs(A.x - B.x), 1), 0.5 * (H - 240) / max(abs(A.y - B.y), 1), 5)
        let fit = max(0.5, min(zFit, 3.2))
        let engine: FollowCameraModel.Engine = MapEngine.current == .appleMaps && !MapHealth.shared.failed ? .appleMaps : .illustrated
        ui.fitScale = fit
        ui.engine = engine

        var model = ui.camera
        if !model.following && model.freeCenterP == nil { model.freeCenterP = routeP[Self.samples / 2] }   // S16G: the route's middle
        let dt = last.map { min(0.2, max(0, now.timeIntervalSince($0))) } ?? 1.0 / 30
        last = now
        let lat = EuropeProjection.coordinate(here).latitude
        let rotMin = engine == .appleMaps ? FollowCameraModel.minRotationScale(viewHeight: size.height, latitude: lat) : 0
        let cam = state.advance(model: model, planeP: here, heading: heading, fit: fit, engine: engine, size: size, dt: dt,
                                snapRotation: snapRotation, rotationMinScale: rotMin)
        ui.lastCamera = cam
        return Out(camera: cam, hereP: here, routeP: routeP, k0: a, markerRotation: state.markerRotation(cam))
    }
}

// MARK: - Route

private struct RouteRun { var pts: [CGPoint]; var startDist: Double }

/// Parts of a polyline inside `rect` (Liang-Barsky per segment), each with the distance along the full polyline where it
/// starts, so dashes keep their phase while the camera moves. At street zoom the route is millions of points long; drawing
/// only what is near the screen keeps strokes fast and precise.
private func clippedRuns(_ pts: [CGPoint], in rect: CGRect, startDist: Double = 0) -> [RouteRun] {
    var runs: [RouteRun] = []
    var cur: RouteRun?
    var dist = startDist
    for i in 1..<max(1, pts.count) {
        let a = pts[i - 1], b = pts[i]
        let dx = b.x - a.x, dy = b.y - a.y
        let len = hypot(dx, dy)
        var t0 = 0.0, t1 = 1.0
        var inside = true
        for (p, q) in [(-dx, a.x - rect.minX), (dx, rect.maxX - a.x), (-dy, a.y - rect.minY), (dy, rect.maxY - a.y)] {
            if p == 0 { if q < 0 { inside = false; break } } else {
                let r = q / p
                if p < 0 { if r > t1 { inside = false; break }; t0 = max(t0, r) } else { if r < t0 { inside = false; break }; t1 = min(t1, r) }
            }
        }
        if inside {
            let s = CGPoint(x: a.x + dx * t0, y: a.y + dy * t0), e = CGPoint(x: a.x + dx * t1, y: a.y + dy * t1)
            if cur == nil || t0 > 0 {
                if let c = cur { runs.append(c) }
                cur = RouteRun(pts: [s], startDist: dist + len * t0)
            }
            cur?.pts.append(e)
            if t1 < 1, let c = cur { runs.append(c); cur = nil }
        } else if let c = cur {
            runs.append(c); cur = nil
        }
        dist += len
    }
    if let c = cur { runs.append(c) }
    return runs
}

private func length(_ pts: [CGPoint]) -> Double {
    var d = 0.0
    for i in 1..<max(1, pts.count) { d += hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y) }
    return d
}

private struct RouteLayer: View {
    let points: [CGPoint]
    let k0: Int
    let here: CGPoint
    let size: CGSize

    var body: some View {
        // one Canvas instead of a view per stroke: the route is redrawn every frame
        let (points, k0, here, size) = (points, k0, here, size)
        Canvas { ctx, _ in
            let view = CGRect(origin: .zero, size: size).insetBy(dx: -120, dy: -120)
            let trailPts = [CGPoint](points[0...k0]) + [here]
            let futurePts = [here] + [CGPoint](points[min(points.count - 1, k0 + 1)...])
            let trailLen = length(trailPts)
            // gradientUnits="userSpaceOnUse": from the origin to the plane. At street zoom the origin is far off screen, so the
            // gradient is clamped to a span the visible part of the trail still spans.
            let g0 = clamped(points[0], size), g1 = clamped(CGPoint(x: here.x + 1, y: here.y), size)
            let grad = GraphicsContext.Shading.linearGradient(Gradient(colors: [Color(RGB(hex: "#6AB7FF")), Color(RGB(hex: "#8BF3D8"))]),
                                                              startPoint: g0, endPoint: g1)
            var trail = Path()
            for r in clippedRuns(trailPts, in: view) { trail.addLines(r.pts) }
            for r in clippedRuns(futurePts, in: view, startDist: trailLen) {
                var p = Path(); p.addLines(r.pts)
                ctx.stroke(p, with: .color(Color(RGB(hex: "#F3F5FA")).opacity(0.46)),
                           style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [2, 7], dashPhase: CGFloat(r.startDist.truncatingRemainder(dividingBy: 9))))
            }
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 4))
                l.stroke(trail, with: .color(Color(RGB(hex: "#6AB7FF")).opacity(0.3)), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            }
            ctx.stroke(trail, with: grad, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        .frame(width: size.width, height: size.height)
    }

    private func clamped(_ p: CGPoint, _ size: CGSize) -> CGPoint {
        CGPoint(x: max(-4 * size.width, min(5 * size.width, p.x)), y: max(-4 * size.height, min(5 * size.height, p.y)))
    }
}

// MARK: - Window visibility

/// Reports whether the window can be seen (on screen, not minimised, not fully covered) so the map stops redrawing when it cannot.
struct WindowActivity: NSViewRepresentable {
    @Binding var visible: Bool
    func makeNSView(context: Context) -> NSView { Probe(update: { v in DispatchQueue.main.async { if visible != v { visible = v } } }) }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class Probe: NSView {
        let update: (Bool) -> Void
        nonisolated(unsafe) private var tokens: [NSObjectProtocol] = []
        init(update: @escaping (Bool) -> Void) { self.update = update; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError() }
        deinit { tokens.forEach(NotificationCenter.default.removeObserver) }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            tokens.forEach(NotificationCenter.default.removeObserver); tokens = []
            guard let w = window else { return }
            let nc = NotificationCenter.default
            for n in [NSWindow.didChangeOcclusionStateNotification, NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification] {
                tokens.append(nc.addObserver(forName: n, object: w, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.report() } })
            }
            report()
        }
        @MainActor private func report() {
            guard let w = window else { return }
            update(w.occlusionState.contains(.visible) && !w.isMiniaturized)
        }
    }
}

// MARK: - Scroll

struct ScrollInfo {
    var dx: Double, dy: Double
    var precise: Bool
    var zoomModifier: Bool
    var location: CGPoint
}

extension View {
    /// Reports scroll events over this view (mouse wheel and trackpad).
    func onScroll(_ handler: @escaping (ScrollInfo) -> Void) -> some View {
        background(ScrollCatcher(handler: handler))
    }
}

private struct ScrollCatcher: NSViewRepresentable {
    let handler: (ScrollInfo) -> Void
    func makeNSView(context: Context) -> NSView { let v = WheelView(); v.handler = handler; return v }
    func updateNSView(_ nsView: NSView, context: Context) { (nsView as? WheelView)?.handler = handler }

    final class WheelView: NSView {
        var handler: ((ScrollInfo) -> Void)?
        nonisolated(unsafe) private var monitor: Any?
        override var isFlipped: Bool { true }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] e in
                guard let self, let w = self.window, e.window === w else { return e }
                let p = self.convert(e.locationInWindow, from: nil)
                guard self.bounds.contains(p) else { return e }
                let mods = e.modifierFlags
                self.handler?(ScrollInfo(dx: Double(e.scrollingDeltaX), dy: Double(e.scrollingDeltaY), precise: e.hasPreciseScrollingDeltas,
                                         zoomModifier: mods.contains(.option) || mods.contains(.control), location: p))
                return e
            }
        }
        deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
    }
}
