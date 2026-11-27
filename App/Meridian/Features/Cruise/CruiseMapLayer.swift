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
    @State private var projector = MapProjector()
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
        // Take-off: it waits for the imagery, but not for long. A slow or missing network must never leave the black title card up.
        .task(id: ui.intro?.created) {
            guard ui.intro != nil else { return }
            try? await Task.sleep(for: .seconds(TakeoffIntro.patience))
            beginTakeoff()
        }
    }

    // MARK: Frame

    @ViewBuilder
    private func content(at now: Date) -> some View {
        let progress = progressAt?(now) ?? frame.progress
        let f = driver.step(now: now, frame: frame, progress: progress, ui: ui, size: size, snapRotation: reduceMotion)
        let cam = f.camera
        let W = size.width, H = size.height
        // A tilted camera is a perspective only the map knows: move the map now and ask it where things are.
        let tilted = cam.pitch > 0.01 && projector.apply(cam)
        let project: (CGPoint) -> CGPoint = { p in
            (tilted ? projector.screen(EuropeProjection.coordinate(p)) : nil) ?? cam.screen(p)
        }
        let ground = tilted ? visibleGround() : nil
        // take-off: the flown trail starts on the runway
        let trailP = [f.trailStartP ?? f.routeP[0]] + [CGPoint](f.routeP[1...])
        let sp = trailP.map(cam.screen)
        let hp = project(f.hereP)
        let pitch = tilted ? projector.pitch : 0
        let dark = scheme == .dark
        let style = MapStyleAccess.resolved(ui.style)
        let intro = ui.intro
        let it = f.takeoffT
        // take-off: satellite imagery over the airport, dissolving into the owner's map style once the camera has settled
        let satellite = intro == nil || style == .satellite ? 0 : 1 - TakeoffIntro.ease((it - TakeoffIntro.duration + 0.5) / 2.2)
        let lift = intro.map { $0.heightM(it) } ?? 0
        ZStack(alignment: .topLeading) {
            MapSurface(style: style, center: cam.viewCenter, zoom: cam.scale, animatesCamera: false, followCamera: cam,
                       projector: projector, onRendered: satellite > 0 ? nil : { beginTakeoff() })
                .frame(width: W, height: H)
            if satellite > 0 {
                MapSurface(style: .satellite, theme: .dark, center: cam.viewCenter, zoom: cam.scale, animatesCamera: false, followCamera: cam,
                           onRendered: { beginTakeoff() })
                    .frame(width: W, height: H)
                    .opacity(satellite)
                    .allowsHitTesting(false)
            }

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
                if let ground {
                    // perspective: the part of the route on the visible ground, placed by the map itself
                    let trail = clippedRuns([CGPoint](trailP[0...f.k0]) + [f.hereP], convex: ground).map { $0.map(project) }
                    let future = clippedRuns([f.hereP] + [CGPoint](f.routeP[min(f.routeP.count - 1, f.k0 + 1)...]), convex: ground).map { $0.map(project) }
                    TiltedRouteLayer(trail: trail, future: future, here: hp, size: size, futureAlpha: f.routeAlpha).allowsHitTesting(false)
                } else {
                    RouteLayer(points: sp, k0: f.k0, here: hp, size: size)
                        .allowsHitTesting(false)
                }
            }
            let a = ground == nil ? cam.screen(f.routeP[0]) : (inside(f.routeP[0], ground!) ? project(f.routeP[0]) : CGPoint(x: -999, y: -999))
            if onScreen(a), f.routeAlpha > 0, hypot(a.x - hp.x, a.y - hp.y) > 54 {      // not on top of the aircraft right after take-off
                Group {
                    dot(a, ring: Color(RGB(hex: "#F3F5FA")))
                    tag(frame.origin.iata, at: a, selected: false)
                }
                .opacity(f.routeAlpha)
            }
            if frame.destination != nil, let last = f.routeP.last, let flat = sp.last {
                let end = ground == nil ? flat : (inside(last, ground!) ? project(last) : CGPoint(x: -999, y: -999))
                if onScreen(end) {
                    dot(end, ring: MRPalette.resolve(scheme).amber.color)
                    tag(frame.destination?.iata ?? "", at: end, selected: true)
                }
            }
            // the marker lies on the tilted ground like a navigation arrow, a little larger the closer the camera leans in
            let tiltU = min(1, pitch / 35)
            let big = intro == nil ? 1 : 1 + 1.5 * (1 - TakeoffIntro.ease((it - TakeoffIntro.rollEnd) / (TakeoffIntro.duration - TakeoffIntro.rollEnd)))
            let ps = (34 + 16 * tiltU) * big
            if intro != nil, lift < 1300 {
                // its shadow stays on the runway and falls behind as the aircraft climbs
                let d = min(160, lift * 0.16) + 3
                PlaneMarker(size: ps, heading: f.markerRotation, lights: false, shadow: false)
                    .colorMultiply(.black)
                    .rotation3DEffect(.degrees(pitch * 0.5), axis: (x: 1, y: 0, z: 0), perspective: 0.3)
                    .blur(radius: 1.5 + d * 0.05)
                    .opacity(0.42 * max(0, 1 - lift / 1300))
                    .position(x: hp.x + d * 0.55, y: hp.y + d)
                    .allowsHitTesting(false)
            }
            PlaneMarker(size: ps, heading: f.markerRotation, shadow: intro == nil)
                .rotation3DEffect(.degrees(pitch * 0.5), axis: (x: 1, y: 0, z: 0), perspective: 0.3)
                .position(hp)
                .allowsHitTesting(false)
            if let intro {
                if it < TakeoffIntro.duration { TakeoffHUD(intro: intro, t: it, frame: frame, size: size) }
                Color.clear.frame(width: 0, height: 0)
                    .onChange(of: intro.isPlaying(now)) { _, playing in if !playing { ui.introPlaying = false } }
                    .onChange(of: intro.isOver(now)) { _, over in if over { ui.intro = nil } }
            }
        }
        .frame(width: W, height: H, alignment: .topLeading)
    }

    /// The imagery is on screen (or took too long): the take-off clock starts, with the boarding chime.
    private func beginTakeoff() {
        guard ui.intro != nil, ui.intro?.start == nil else { return }
        ui.intro?.start = Date()
        MRSound.shared.play(.chime(.board))
    }

    /// The ground the tilted camera sees, as a convex quad in plane coordinates (a little larger than the view).
    private func visibleGround() -> [CGPoint]? {
        let corners = [CGPoint(x: 0, y: 0), CGPoint(x: size.width, y: 0), CGPoint(x: size.width, y: size.height), CGPoint(x: 0, y: size.height)]
        let q = corners.compactMap { projector.coordinate($0).map { EuropeProjection.xy($0) } }
        guard q.count == 4 else { return nil }
        let c = CGPoint(x: q.map(\.x).reduce(0, +) / 4, y: q.map(\.y).reduce(0, +) / 4)
        return q.map { CGPoint(x: c.x + ($0.x - c.x) * 1.06, y: c.y + ($0.y - c.y) * 1.06) }
    }

    private func inside(_ p: CGPoint, _ poly: [CGPoint]) -> Bool { !clippedRuns([p, CGPoint(x: p.x + 1e-9, y: p.y)], convex: poly).isEmpty }

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
        /// Take-off: where the flown trail starts (the runway threshold instead of the airport's reference point).
        var trailStartP: CGPoint?
        /// Take-off: seconds on its clock, and how visible the route ahead and the airport tag are.
        var takeoffT = 0.0
        var routeAlpha = 1.0
    }

    static let samples = 90
    private var state = FollowCameraState()
    private var last: Date?
    private var key = ""
    private var routeP: [CGPoint] = []
    private var origin = Coordinate(latitude: 0, longitude: 0), dest = Coordinate(latitude: 0, longitude: 0)
    /// Take-off: the runway in plane coordinates (start, unit direction, plane units per metre, metres of ground roll).
    private var runway: (start: CGPoint, dir: CGPoint, perMetre: Double, roll: Double, bearing: Double)?

    /// Route fraction per second at the flight's pace.
    private func pace(_ frame: CruiseFrame) -> Double { frame.totalMin > 0 ? 1 / (frame.totalMin * 60) : 0 }

    func step(now: Date, frame: CruiseFrame, progress rawProgress: Double, ui: CruiseUI, size: CGSize, snapRotation: Bool) -> Out {
        let intro = ui.intro
        let progress = rawProgress
        let o = frame.origin.coordinate, d = (frame.destination ?? frame.origin).coordinate
        let k = "\(frame.origin.iata)-\(frame.destination?.iata ?? "")"
        if k != key {
            key = k; origin = o; dest = d
            routeP = (0...Self.samples).map { EuropeProjection.xy(Geo.interpolate(from: o, to: d, fraction: Double($0) / Double(Self.samples))) }
            state = FollowCameraState()
            runway = nil
        }
        func onRoute(_ p: Double) -> (CGPoint, Int) {
            let si = max(0, min(Double(Self.samples), p * Double(Self.samples)))
            let a = Int(si.rounded(.down)), b = min(Self.samples, a + 1), t = si - Double(a)
            return (CGPoint(x: routeP[a].x + (routeP[b].x - routeP[a].x) * t, y: routeP[a].y + (routeP[b].y - routeP[a].y) * t), a)
        }
        var (here, a) = onRoute(progress)
        var heading = FollowCameraModel.planeHeading(from: origin, to: dest, fraction: progress)
        var trailStart: CGPoint?
        var takeoffT = 0.0, routeAlpha = 1.0
        if let intro {
            // Take-off: down the real runway that points closest to the route, then a turn onto the route during the climb.
            if runway == nil {
                let out = frame.destination == nil ? 0 : Geo.bearing(from: o, to: Geo.interpolate(from: o, to: d, fraction: 0.02))
                let r = BundledRunways.departure(from: frame.origin, toward: out)
                let s = EuropeProjection.xy(r.start), e = EuropeProjection.xy(r.end)
                let len = max(1e-9, hypot(e.x - s.x, e.y - s.y))
                let perMetre = 1 / FollowCameraModel.groundMetresPerPoint(scale: 1, latitude: o.latitude)
                // lift off well before the far end; long runways do not make the roll longer than it reads well on screen
                let roll = min(r.lengthM * 0.5, 1100)
                // start a little down the runway (the threshold markings are behind the aircraft)
                let lead = min(140, r.lengthM * 0.06) * perMetre
                runway = (CGPoint(x: s.x + (e.x - s.x) / len * lead, y: s.y + (e.y - s.y) / len * lead),
                          CGPoint(x: (e.x - s.x) / len, y: (e.y - s.y) / len), perMetre, roll, r.bearing)
            }
            if let rw = runway {
                let t = intro.time(now), ta = TakeoffIntro.rollEnd
                if t <= ta {
                    let m = intro.rollMetres(t, roll: rw.roll) * rw.perMetre
                    here = CGPoint(x: rw.start.x + rw.dir.x * m, y: rw.start.y + rw.dir.y * m)
                    heading = rw.bearing
                } else {
                    // Airborne: the route position plus what is left of the gap to the lift-off point, carried a little further
                    // along the runway while the speed settles. The nose turns from the runway heading to the route heading.
                    let tau = t - ta
                    let lift = CGPoint(x: rw.start.x + rw.dir.x * rw.roll * rw.perMetre, y: rw.start.y + rw.dir.y * rw.roll * rw.perMetre)
                    let r0 = onRoute(max(0, progress - tau * pace(frame))).0      // where the route position was at lift-off
                    let carry = intro.carry(tau, from: intro.liftOffSpeed(roll: rw.roll), to: pace(frame) * frame.routeKm * 1000) * rw.perMetre
                    let g = intro.gap(tau)
                    here = CGPoint(x: here.x + g * (lift.x - r0.x + rw.dir.x * carry), y: here.y + g * (lift.y - r0.y + rw.dir.y * carry))
                    heading = FollowCamera.normalize(rw.bearing + FollowCamera.signedDelta(from: rw.bearing, to: heading) * intro.turn(tau))
                }
                a = 0
                let w = t <= ta ? 0 : 1 - intro.gap(t - ta)
                trailStart = CGPoint(x: rw.start.x + (routeP[0].x - rw.start.x) * w, y: rw.start.y + (routeP[0].y - rw.start.y) * w)
                takeoffT = t; routeAlpha = intro.routeAlpha(t)
            }
        }

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
        let scripted = intro.flatMap { i -> (scale: Double, pitch: Double)? in
            guard i.isPlaying(now) else { return nil }
            var m = model; m.applyFollowDefaults(orientation: .headingUp)
            return (i.scale(i.time(now), target: m.effectiveScale(fit: fit, engine)), engine == .appleMaps ? FollowCameraModel.followPitch : 0)
        }
        let cam = state.advance(model: model, planeP: here, heading: heading, fit: fit, engine: engine, size: size, dt: dt,
                                snapRotation: snapRotation, rotationMinScale: rotMin, scripted: scripted)
        ui.lastCamera = cam
        return Out(camera: cam, hereP: here, routeP: routeP, k0: a, markerRotation: state.markerRotation(cam),
                   trailStartP: trailStart, takeoffT: takeoffT, routeAlpha: routeAlpha)
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

/// Parts of a polyline inside a convex polygon (Cyrus-Beck per segment).
private func clippedRuns(_ pts: [CGPoint], convex poly: [CGPoint]) -> [[CGPoint]] {
    guard poly.count >= 3, pts.count >= 2 else { return [] }
    var area = 0.0
    for i in 0..<poly.count { let a = poly[i], b = poly[(i + 1) % poly.count]; area += Double(a.x * b.y - b.x * a.y) }
    let sign = area >= 0 ? 1.0 : -1.0
    var runs: [[CGPoint]] = []
    var cur: [CGPoint]?
    for i in 1..<pts.count {
        let a = pts[i - 1], b = pts[i]
        let dx = Double(b.x - a.x), dy = Double(b.y - a.y)
        var t0 = 0.0, t1 = 1.0, ok = true
        for j in 0..<poly.count {
            let e0 = poly[j], e1 = poly[(j + 1) % poly.count]
            let nx = -Double(e1.y - e0.y) * sign, ny = Double(e1.x - e0.x) * sign      // inward normal
            let num = nx * Double(a.x - e0.x) + ny * Double(a.y - e0.y), den = nx * dx + ny * dy
            if abs(den) < 1e-15 { if num < 0 { ok = false; break } } else {
                let t = -num / den
                if den > 0 { t0 = max(t0, t) } else { t1 = min(t1, t) }
                if t0 > t1 { ok = false; break }
            }
        }
        if ok {
            let s = CGPoint(x: a.x + dx * t0, y: a.y + dy * t0), e = CGPoint(x: a.x + dx * t1, y: a.y + dy * t1)
            if cur == nil || t0 > 0 { if let c = cur { runs.append(c) }; cur = [s] }
            cur?.append(e)
            if t1 < 1, let c = cur { runs.append(c); cur = nil }
        } else if let c = cur { runs.append(c); cur = nil }
    }
    if let c = cur { runs.append(c) }
    return runs
}

/// The route under the tilted follow camera: screen-space polylines the map projected. The way ahead is a soft solid line
/// (dashes would crawl in perspective), the flown part the glowing gradient trail.
private struct TiltedRouteLayer: View {
    let trail: [[CGPoint]]
    let future: [[CGPoint]]
    let here: CGPoint
    let size: CGSize
    var futureAlpha = 1.0

    var body: some View {
        let (trail, future, here, size, fa) = (trail, future, here, size, futureAlpha)
        Canvas { ctx, _ in
            var ahead = Path(); for r in future { ahead.addLines(r) }
            ctx.stroke(ahead, with: .color(.black.opacity(0.22 * fa)), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            ctx.stroke(ahead, with: .linearGradient(Gradient(colors: [Color(RGB(hex: "#F3F5FA")).opacity(0.85 * fa), Color(RGB(hex: "#F3F5FA")).opacity(0.35 * fa)]),
                                                    startPoint: here, endPoint: CGPoint(x: here.x, y: 0)),
                       style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
            var flown = Path(); for r in trail { flown.addLines(r) }
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 5))
                l.stroke(flown, with: .color(Color(RGB(hex: "#6AB7FF")).opacity(0.45)), style: StrokeStyle(lineWidth: 12, lineCap: .round))
            }
            ctx.stroke(flown, with: .linearGradient(Gradient(colors: [Color(RGB(hex: "#6AB7FF")), Color(RGB(hex: "#8BF3D8"))]),
                                                    startPoint: CGPoint(x: here.x, y: size.height), endPoint: here),
                       style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size.width, height: size.height)
    }
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


// MARK: - Take-off read-out

/// What the take-off shows on top of the map: the black opening the picture fades out of, the route title with the phase,
/// speed and height, and Skip. All of it leaves before the cruise controls arrive.
private struct TakeoffHUD: View {
    let intro: TakeoffIntro
    let t: Double
    let frame: CruiseFrame
    let size: CGSize

    var body: some View {
        let cover = intro.start == nil ? 1 : 1 - TakeoffIntro.ease(t / TakeoffIntro.fadeIn)
        let out = 1 - TakeoffIntro.ease((t - TakeoffIntro.duration + 1.5) / 1.1)
        let ink = Color(RGB(hex: "#F3F5FA"))
        ZStack {
            Color(.sRGB, red: 4 / 255, green: 6 / 255, blue: 11 / 255).opacity(cover)
            // a soft letterbox so the title and the read-out stay legible on bright imagery
            LinearGradient(stops: [.init(color: .black.opacity(0.55), location: 0), .init(color: .black.opacity(0), location: 0.3),
                                   .init(color: .black.opacity(0), location: 0.72), .init(color: .black.opacity(0.5), location: 1)],
                           startPoint: .top, endPoint: .bottom).opacity(out)
            VStack(spacing: 10) {
                HStack(spacing: 14) {
                    Text(frame.origin.iata)
                    MRIcon(.plane, size: 20).rotationEffect(.degrees(90)).opacity(0.6)
                    Text(frame.destination?.iata ?? "Free flight")
                }
                .font(.mr(.condensed, size: 40, weight: 600)).tracking(0.6)
                Text(intro.phase(t)).font(.mr(.ui, size: 11, weight: 600)).tracking(2.6).textCase(.uppercase).opacity(0.72)
            }
            .foregroundStyle(ink)
            .shadow(color: .black.opacity(0.6), radius: 10, y: 1)
            .frame(maxHeight: .infinity, alignment: .top).padding(.top, 54)
            .opacity(out)

            HStack(spacing: 22) {
                stat("SPD", "\(intro.speedKt(t))", "kt")
                stat("ALT", "\(Int((intro.heightM(t) * 3.281 / 10).rounded()) * 10)", "ft")
                stat("ETA", "\(Int(frame.totalMin.rounded()))", "min")
            }
            .padding(.horizontal, 22).frame(height: 46)
            .cruiseGlass(23, .e2)
            .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 34)
            .opacity(out * TakeoffIntro.ease((t - 0.3) / 0.8))
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Taking off from \(frame.origin.city)")
    }

    private func stat(_ k: String, _ v: String, _ u: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(k).foregroundStyle(MRPalette.resolve(.dark).text3.color)
            Text(v).fontWeight(.semibold).monospacedDigit().frame(minWidth: 34, alignment: .trailing)
            Text(u).foregroundStyle(MRPalette.resolve(.dark).text2.color)
        }
        .font(.mr(.mono, size: 12, weight: 500)).tracking(0.5).foregroundStyle(MRPalette.resolve(.dark).text1.color)
    }
}
