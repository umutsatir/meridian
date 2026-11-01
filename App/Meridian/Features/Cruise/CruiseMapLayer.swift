import AppKit
import MeridianCore
import MeridianMaps
import MeridianUI
import SwiftUI

/// MAP VIEW of `Flight.dc.html`: Europe map with the follow camera, terminator, vignette, the route (dashed future,
/// glowing gradient trail), both airport tags, the plane, drag to pan and wheel / pinch to zoom.
struct CruiseMapLayer: View {
    let frame: CruiseFrame
    @Bindable var ui: CruiseUI
    let size: CGSize
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var panStart: (center: Coordinate, moved: Bool)?

    var body: some View {
        let cam = CruiseCamera(frame: frame, ui: ui, size: size)
        let W = size.width, H = size.height
        let sp = cam.screenPoints
        let hp = cam.hereScreen
        let trail = [CGPoint](sp[0...cam.k0]) + [hp]
        let future = [hp] + [CGPoint](sp[cam.k1...])
        let dark = scheme == .dark
        let camAnim: Animation? = reduceMotion || panStart != nil ? nil : EuropeMapView.cameraAnimation
        ZStack(alignment: .topLeading) {
            EuropeMapView(style: ui.style, center: cam.center, zoom: cam.zoom, offset: cam.offset)
                .animation(camAnim, value: CamKey(c: cam.center, z: cam.zoom))
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

            Color.clear.contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if panStart == nil { panStart = (cam.center, false) }
                        guard var s = panStart else { return }
                        if !s.moved && hypot(v.translation.width, v.translation.height) < 4 { return }
                        s.moved = true; panStart = s
                        // new centre so that the point under the pointer stays: centre - delta
                        let c = CruiseCamera(frame: frame, ui: ui, size: size)
                        let base = CruiseCameraAt(cam: c, center: s.center)
                        ui.follow = false
                        ui.cam = base.coordinate(shiftedBy: v.translation)
                    }
                    .onEnded { _ in panStart = nil })
                .onScrollWheel { dy in ui.zoom(by: -dy * 0.0016) }
                .allowsHitTesting(true)

            if ui.route {
                RouteLayer(trail: trail, future: future, start: sp[0], end: CGPoint(x: hp.x + 1, y: hp.y), size: size)
                    .allowsHitTesting(false)
            }
            dot(sp[0], ring: Color(RGB(hex: "#F3F5FA")))
            tag(frame.origin.iata, at: sp[0], selected: false)
            if frame.destination != nil {
                dot(sp[sp.count - 1], ring: MRPalette.resolve(scheme).amber.color)
                tag(frame.destination?.iata ?? "", at: sp[sp.count - 1], selected: true)
            }
            PlaneMarker(size: 34, heading: cam.heading)
                .position(hp)
                .animation(camAnim, value: hp)
                .allowsHitTesting(false)
        }
        .frame(width: W, height: H, alignment: .topLeading)
        .clipped()
    }

    private struct CamKey: Equatable { var c: Coordinate; var z: Double }

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

/// The camera as it was when the drag began, so the pan is relative to it.
private struct CruiseCameraAt {
    let cam: CruiseCamera
    let center: Coordinate
    func coordinate(shiftedBy t: CGSize) -> Coordinate {
        let k = EuropeProjection.k
        let c = EuropeProjection.xy(center)
        let X = c.x - t.width / cam.zoom, Y = c.y - t.height / cam.zoom
        let rr = Double.pi / 180
        let myf1 = log(tan(.pi / 4 + EuropeProjection.lat1 * rr / 2))
        return Coordinate(latitude: (2 * atan(exp(myf1 - Y / k)) - .pi / 2) / rr, longitude: X / (k * rr) + EuropeProjection.lon0)
    }
}

private struct RouteLayer: View {
    let trail: [CGPoint]
    let future: [CGPoint]
    let start: CGPoint
    let end: CGPoint
    let size: CGSize

    var body: some View {
        let t = polyline(trail), f = polyline(future)
        // gradientUnits="userSpaceOnUse": the shapes fill the whole map, so unit points are map fractions.
        let grad = LinearGradient(colors: [Color(RGB(hex: "#6AB7FF")), Color(RGB(hex: "#8BF3D8"))],
                                  startPoint: UnitPoint(x: start.x / size.width, y: start.y / size.height),
                                  endPoint: UnitPoint(x: end.x / size.width, y: end.y / size.height))
        ZStack {
            f.stroke(Color(RGB(hex: "#F3F5FA")).opacity(0.46), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [2, 7]))
            t.stroke(Color(RGB(hex: "#6AB7FF")).opacity(0.3), style: StrokeStyle(lineWidth: 8, lineCap: .round)).blur(radius: 4)
            t.stroke(grad, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        .frame(width: size.width, height: size.height)
    }

    private func polyline(_ pts: [CGPoint]) -> Path {
        var p = Path()
        guard let first = pts.first else { return p }
        p.move(to: first)
        for q in pts.dropFirst() { p.addLine(to: q) }
        return p
    }
}

// MARK: scroll wheel

extension View {
    /// Reports vertical scroll deltas (mouse wheel and trackpad) to zoom the map, `onWheel` of the canvas.
    func onScrollWheel(_ handler: @escaping (Double) -> Void) -> some View {
        background(ScrollWheelCatcher(handler: handler))
    }
}

private struct ScrollWheelCatcher: NSViewRepresentable {
    let handler: (Double) -> Void
    func makeNSView(context: Context) -> NSView { let v = WheelView(); v.handler = handler; return v }
    func updateNSView(_ nsView: NSView, context: Context) { (nsView as? WheelView)?.handler = handler }

    final class WheelView: NSView {
        var handler: ((Double) -> Void)?
        private var monitor: Any?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] e in
                guard let self, let w = self.window, e.window === w else { return e }
                let p = self.convert(e.locationInWindow, from: nil)
                if self.bounds.contains(p) { self.handler?(Double(e.scrollingDeltaY) * (e.hasPreciseScrollingDeltas ? 1 : 10)) }
                return e
            }
        }
    }
}
