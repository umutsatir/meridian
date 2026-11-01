import SwiftUI
import MeridianCore
import os

// MARK: - Public model

/// A route arc on the globe (`routes` of `Globe.dc.html`).
public struct GlobeRoute: Sendable {
    public var from: Coordinate
    public var to: Coordinate
    public var color: Color
    public var width: Double
    public var opacity: Double
    /// Arc lift as a fraction of the radius at the middle of the route.
    public var lift: Double

    public init(from: Coordinate, to: Coordinate, color: Color = Color(.sRGB, red: 106 / 255, green: 183 / 255, blue: 1), width: Double = 1.5, opacity: Double = 0.7, lift: Double = 0.07) {
        self.from = from; self.to = to; self.color = color; self.width = width; self.opacity = opacity; self.lift = lift
    }

    /// Route between two airports; returns `nil` when a code is unknown.
    public init?(from a: String, to b: String, airports: MapAirports = .bundled, color: Color = Color(.sRGB, red: 106 / 255, green: 183 / 255, blue: 1), width: Double = 1.5, opacity: Double = 0.7, lift: Double = 0.07) {
        guard let p = airports.coordinate(a), let q = airports.coordinate(b) else { return nil }
        self.init(from: p, to: q, color: color, width: width, opacity: opacity, lift: lift)
    }
}

/// An airport pin (`pins`): a dot with an optional IATA label.
public struct GlobePin: Sendable {
    public var coordinate: Coordinate
    public var label: String?
    public var color: Color
    public var radius: Double

    public init(coordinate: Coordinate, label: String? = nil, color: Color = Color(.sRGB, red: 1, green: 181 / 255, blue: 71 / 255), radius: Double = 3.2) {
        self.coordinate = coordinate; self.label = label; self.color = color; self.radius = radius
    }

    public init?(code: String, airports: MapAirports = .bundled, showsLabel: Bool = true, color: Color = Color(.sRGB, red: 1, green: 181 / 255, blue: 71 / 255), radius: Double = 3.2) {
        guard let c = airports.coordinate(code) else { return nil }
        self.init(coordinate: c, label: showsLabel ? code.uppercased() : nil, color: color, radius: radius)
    }
}

/// The plane on its route: a dotted future path, a gradient trail and the plane dot at fraction `t`.
public struct GlobePlane: Sendable {
    public var from: Coordinate
    public var to: Coordinate
    public var t: Double
    public init(from: Coordinate, to: Coordinate, t: Double = 0.5) { self.from = from; self.to = to; self.t = t }
}

/// Per-instance override of the globe tokens (`--gl-sea-a`, `--gl-sea-b`, `--gl-land`, `--gl-shade`, `--gl-rim`),
/// e.g. the Home screen's `.ph-globe` rule. Colours are `0xRRGGBB`.
public struct GlobeColorOverride: Sendable, Hashable {
    public var seaA: UInt32, seaB: UInt32, land: UInt32
    public var shade: Double, rim: Double
    public init(seaA: UInt32, seaB: UInt32, land: UInt32, shade: Double, rim: Double) {
        self.seaA = seaA; self.seaB = seaB; self.land = land; self.shade = shade; self.rim = rim
    }
}

// MARK: - View

/// Orthographic globe of the design (`Globe.dc.html` + `meridian-world.js`), drawn in a SwiftUI `Canvas`.
///
/// `lon`/`lat` is the point facing the viewer. `size` is the square frame; the sphere has radius `0.43 * size` and the
/// atmosphere glow extends beyond the frame (it is not clipped, like the HTML). With `live` the globe rotates at
/// `speed` degrees per second (TimelineView); with `isDraggable` a drag rotates it (0.4 deg/pt horizontally, 0.3 vertically, latitude ±70).
public struct GlobeView: View {
    public var lon: Double
    public var lat: Double
    public var size: CGFloat
    public var theme: MapTheme?
    public var routes: [GlobeRoute]
    public var pins: [GlobePin]
    public var plane: GlobePlane?
    public var visited: Bool
    public var showsGraticule: Bool
    public var showsAtmosphere: Bool
    public var showsLabels: Bool
    public var live: Bool
    public var speed: Double
    public var isDraggable: Bool
    public var colorOverride: GlobeColorOverride?
    /// Optional external rotation offset in degrees (width = longitude, height = latitude), so a parent can also turn the globe
    /// (trackpad scroll) and keep it across redraws. Without it the globe keeps its own drag state.
    public var rotation: Binding<CGSize>?
    /// Multiplies the drag-to-rotate speed (the World map passes `1 / zoom`: the closer, the slower).
    public var dragSpeed: Double

    @Environment(\.colorScheme) private var scheme
    @State private var ownDrag: CGSize = .zero
    private var drag: CGSize {
        get { rotation?.wrappedValue ?? ownDrag }
        nonmutating set { if let rotation { rotation.wrappedValue = newValue } else { ownDrag = newValue } }
    }
    @State private var dragStart: CGSize? = nil
    @State private var epoch = Date()

    public init(lon: Double = 10, lat: Double = 28, size: CGFloat = 560, theme: MapTheme? = nil,
                routes: [GlobeRoute] = [], pins: [GlobePin] = [], plane: GlobePlane? = nil, visited: Bool = false,
                showsGraticule: Bool = true, showsAtmosphere: Bool = true, showsLabels: Bool = true,
                live: Bool = false, speed: Double = 6, isDraggable: Bool = false, colorOverride: GlobeColorOverride? = nil,
                rotation: Binding<CGSize>? = nil, dragSpeed: Double = 1) {
        self.colorOverride = colorOverride
        self.rotation = rotation; self.dragSpeed = dragSpeed
        self.lon = lon; self.lat = lat; self.size = size; self.theme = theme
        self.routes = routes; self.pins = pins; self.plane = plane; self.visited = visited
        self.showsGraticule = showsGraticule; self.showsAtmosphere = showsAtmosphere; self.showsLabels = showsLabels
        self.live = live; self.speed = speed; self.isDraggable = isDraggable
    }

    public var body: some View {
        let theme = theme ?? MapTheme(scheme)
        Group {
            if live {
                TimelineView(.animation) { tl in
                    globe(theme: theme, extraLon: tl.date.timeIntervalSince(epoch) * speed)
                }
            } else {
                globe(theme: theme, extraLon: 0)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .gesture(isDraggable ? DragGesture(minimumDistance: 0)
            .onChanged { g in
                if dragStart == nil { dragStart = drag }
                let s = dragStart ?? .zero
                // JS: lon = start.lon - dx * .4; lat = clamp(start.lat + dy * .3, -70, 70)
                // the latitude offset is limited so that lat + offset stays within +-70 (no dead zone when dragging past the pole)
                let h = s.height + g.translation.height * 0.3 * dragSpeed
                drag = CGSize(width: s.width - g.translation.width * 0.4 * dragSpeed, height: max(-70 - lat, min(70 - lat, h)))
            }
            .onEnded { _ in dragStart = nil } : nil)
        .accessibilityElement()
        .accessibilityLabel("Globe")
    }

    private func globe(theme: MapTheme, extraLon: Double) -> some View {
        let r = GlobeRenderer(size: Double(size), lon: lon + drag.width + extraLon,
                              lat: max(-70, min(70, lat + drag.height)) , theme: theme, routes: routes, pins: pins,
                              plane: plane, visited: visited, graticule: showsGraticule, atmosphere: showsAtmosphere, labels: showsLabels,
                              colorOverride: colorOverride)
        // The glow reaches 0.12 * size beyond the sphere: draw in a larger canvas that overflows the frame.
        let pad = showsAtmosphere ? ceil(size * 0.12 * 1.6) : 0
        return Canvas { ctx, sz in
            var c = ctx
            c.translateBy(x: pad, y: pad)
            r.draw(&c)
        }
        .frame(width: size + 2 * pad, height: size + 2 * pad)
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }
}

// MARK: - Math (port of meridian-world.js)

enum GlobeMath {
    /// Orthographic projection; returns (x, y, cosc) with y pointing down.
    @inline(__always)
    static func proj(lon: Double, lat: Double, l0: Double, p0: Double, R: Double) -> (x: Double, y: Double, c: Double) {
        let D = Double.pi / 180
        let la = lat * D, lo = (lon - l0) * D, p = p0 * D
        let cosc = sin(p) * sin(la) + cos(p) * cos(la) * cos(lo)
        let x = R * cos(la) * sin(lo)
        let y = R * (cos(p) * sin(la) - sin(p) * cos(la) * cos(lo))
        return (x, -y, cosc)
    }

    /// Per-frame constants for projecting pre-trig'd points.
    struct View {
        let sp: Float, cp: Float, sl0: Float, cl0: Float, R: Float
        init(l0: Double, p0: Double, R: Double) {
            let D = Double.pi / 180
            sp = Float(sin(p0 * D)); cp = Float(cos(p0 * D)); sl0 = Float(sin(l0 * D)); cl0 = Float(cos(l0 * D)); self.R = Float(R)
        }
        /// i is the index into a flat (cosφ, sinφ, cosλ, sinλ) array.
        @inline(__always)
        func project(_ pts: UnsafeBufferPointer<Float>, _ i: Int) -> (x: Float, y: Float, c: Float) {
            let cphi = pts[i], sphi = pts[i + 1], cl = pts[i + 2], sl = pts[i + 3]
            let cosd = cl * cl0 + sl * sl0        // cos(λ - l0)
            let sind = sl * cl0 - cl * sl0        // sin(λ - l0)
            let c = sp * sphi + cp * cphi * cosd
            let x = R * cphi * sind
            let y = R * (cp * sphi - sp * cphi * cosd)
            return (x, -y, c)
        }
    }

    /// `W.fillPath`: filled rings, hidden points clamped to the limb; rings with no visible point are dropped.
    static func fillPath(_ rings: WorldGeometry.Rings, l0: Double, p0: Double, R: Double, cx: Double, cy: Double) -> Path {
        var path = Path()
        let v = View(l0: l0, p0: p0, R: R)
        let fR = Float(R)
        rings.pts.withUnsafeBufferPointer { pts in
            var tmp = [CGPoint]()
            for r in rings.ranges {
                tmp.removeAll(keepingCapacity: true)
                var vis = 0
                for k in 0..<r.count {
                    var q = v.project(pts, (r.start + k) * 4)
                    if q.c >= 0 { vis += 1 } else {
                        var L = (q.x * q.x + q.y * q.y).squareRoot()
                        if L == 0 { L = 1 }
                        q.x = q.x / L * fR; q.y = q.y / L * fR
                    }
                    tmp.append(CGPoint(x: Double(q.x) + cx, y: Double(q.y) + cy))
                }
                if vis == 0 || tmp.isEmpty { continue }
                path.addLines(tmp)
                path.closeSubpath()
            }
        }
        return path
    }

    /// `W.linePath`: polylines, hidden segments dropped (`cosc < 0.02`).
    static func linePath(_ rings: WorldGeometry.Rings, l0: Double, p0: Double, R: Double, cx: Double, cy: Double) -> Path {
        var path = Path()
        let v = View(l0: l0, p0: p0, R: R)
        rings.pts.withUnsafeBufferPointer { pts in
            for r in rings.ranges {
                var pen = false
                for k in 0..<r.count {
                    let q = v.project(pts, (r.start + k) * 4)
                    if q.c < 0.02 { pen = false; continue }
                    let pt = CGPoint(x: Double(q.x) + cx, y: Double(q.y) + cy)
                    if pen { path.addLine(to: pt) } else { path.move(to: pt) }
                    pen = true
                }
            }
        }
        return path
    }

    /// `W.grat`: meridians every `step` degrees and parallels between ±60.
    static func graticule(l0: Double, p0: Double, R: Double, cx: Double, cy: Double, step: Double) -> Path {
        var path = Path()
        func line(_ pts: [(Double, Double)]) {
            var pen = false
            for (lon, lat) in pts {
                let q = proj(lon: lon, lat: lat, l0: l0, p0: p0, R: R)
                if q.c < 0.02 { pen = false; continue }
                let pt = CGPoint(x: q.x + cx, y: q.y + cy)
                if pen { path.addLine(to: pt) } else { path.move(to: pt) }
                pen = true
            }
        }
        var lon = -180.0
        while lon < 180 {
            line(stride(from: -90.0, through: 90, by: 3).map { (lon, $0) })
            lon += step
        }
        var lat = -60.0
        while lat <= 60 {
            line(stride(from: -180.0, through: 180, by: 3).map { ($0, lat) })
            lat += step
        }
        return path
    }

    /// `W.arcPath`: great-circle arc a -> b lifted by `h * R` at its middle, between fractions t0 and t1.
    static func arcPath(_ a: Coordinate, _ b: Coordinate, l0: Double, p0: Double, R: Double, cx: Double, cy: Double,
                        h: Double, t0: Double = 0, t1: Double = 1) -> (path: Path, end: CGPoint?) {
        let D = Double.pi / 180
        let la1 = a.latitude * D, lo1 = a.longitude * D, la2 = b.latitude * D, lo2 = b.longitude * D
        var dd = 2 * asin(sqrt(pow(sin((la2 - la1) / 2), 2) + cos(la1) * cos(la2) * pow(sin((lo2 - lo1) / 2), 2)))
        if dd == 0 || dd.isNaN { dd = 1e-6 }
        let n = max(12, min(90, Int((dd / D / 2).rounded())))
        var path = Path(), pen = false
        var last: CGPoint? = nil
        for i in 0...n {
            let t = t0 + (t1 - t0) * Double(i) / Double(n)
            let A = sin((1 - t) * dd) / sin(dd), B = sin(t * dd) / sin(dd)
            let x = A * cos(la1) * cos(lo1) + B * cos(la2) * cos(lo2)
            let y = A * cos(la1) * sin(lo1) + B * cos(la2) * sin(lo2)
            let z = A * sin(la1) + B * sin(la2)
            let lat = atan2(z, (x * x + y * y).squareRoot()) / D, lon = atan2(y, x) / D
            let lift = 1 + h * sin(Double.pi * t)
            let q = proj(lon: lon, lat: lat, l0: l0, p0: p0, R: R * lift)
            if q.c < 0 { pen = false; continue }
            let pt = CGPoint(x: q.x + cx, y: q.y + cy)
            last = pt
            if pen { path.addLine(to: pt) } else { path.move(to: pt) }
            pen = true
        }
        return (path, last)
    }

    /// Radial alpha profile (0...1) of a disk of radius R blurred with a Gaussian of deviation sigma, sampled at `count`
    /// distances from the centre up to `maxD`. This is what a CSS `box-shadow: 0 0 blur` of a circle looks like (sigma = blur / 2).
    static func blurredDiskProfile(R: Double, sigma: Double, maxD: Double, count: Int) -> [Double] {
        let step = sigma / 3
        let reach = 3.2 * sigma
        let n = Int(ceil(reach / step))
        var out = [Double]()
        for i in 0..<count {
            let d = maxD * Double(i) / Double(count - 1)
            var sum = 0.0, norm = 0.0
            for iy in -n...n {
                for ix in -n...n {
                    let dx = Double(ix) * step, dy = Double(iy) * step
                    let w = exp(-(dx * dx + dy * dy) / (2 * sigma * sigma))
                    norm += w
                    let px = d + dx, py = dy
                    if px * px + py * py <= R * R { sum += w }
                }
            }
            out.append(sum / norm)
        }
        return out
    }
}

// MARK: - Renderer

struct GlobeRenderer {
    var size: Double
    var lon: Double
    var lat: Double
    var theme: MapTheme
    var routes: [GlobeRoute]
    var pins: [GlobePin]
    var plane: GlobePlane?
    var visited: Bool
    var graticule: Bool
    var atmosphere: Bool
    var labels: Bool
    var colorOverride: GlobeColorOverride? = nil

    func draw(_ ctx: inout GraphicsContext) {
        var pal = GlobePalette.resolve(theme: theme)
        if let o = colorOverride {
            pal.seaA = RGBA(hex: o.seaA); pal.seaB = RGBA(hex: o.seaB); pal.land = RGBA(hex: o.land)
            pal.shade = o.shade; pal.rim = o.rim
        }
        let S = size, c = S / 2, R = S * 0.43
        let world = MapResources.world
        // JS: l0 = ((lon + 180) % 360 + 360) % 360 - 180
        let l0n = ((lon + 180).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) - 180
        let center = CGPoint(x: c, y: c)
        let disk = Path(ellipseIn: CGRect(x: c - R, y: c - R, width: 2 * R, height: 2 * R))

        // glow div: box-shadow: 0 0 round(S*.12) rgba(120,150,255,.38), 0 0 round(S*.02) rgba(160,190,255,.5) (outside the circle)
        if atmosphere {
            Self.glow(&ctx, center: center, R: R, blur: (S * 0.12).rounded(), color: RGBA(120, 150, 255, 0.38))
            Self.glow(&ctx, center: center, R: R, blur: (S * 0.02).rounded(), color: RGBA(160, 190, 255, 0.5))
        }

        // sphere: radialGradient cx 38% cy 32% r 80% of the bounding box
        let seaG = Gradient(colors: [pal.seaA.color, pal.seaB.color])
        ctx.fill(disk, with: .radialGradient(seaG, center: CGPoint(x: c - R + 0.38 * 2 * R, y: c - R + 0.32 * 2 * R), startRadius: 0, endRadius: 0.8 * 2 * R))

        var g = ctx
        g.clip(to: disk)

        if graticule {
            // stroke-width 1, opacity 1.6 (clamped to 1)
            g.stroke(GlobeMath.graticule(l0: l0n, p0: lat, R: R, cx: c, cy: c, step: 30), with: .color(pal.map.grat.color), lineWidth: 1)
        }
        g.fill(GlobeMath.fillPath(world.land, l0: l0n, p0: lat, R: R, cx: c, cy: c), with: .color(pal.land.color))
        if visited {
            g.fill(GlobeMath.fillPath(world.lo, l0: l0n, p0: lat, R: R, cx: c, cy: c), with: .color(pal.accent.with(alpha: 0.22).color))
            g.fill(GlobeMath.fillPath(world.mid, l0: l0n, p0: lat, R: R, cx: c, cy: c), with: .color(pal.accent.with(alpha: 0.42).color))
            g.fill(GlobeMath.fillPath(world.hi, l0: l0n, p0: lat, R: R, cx: c, cy: c), with: .color(pal.accent.with(alpha: 0.74).color))
        }
        g.stroke(GlobeMath.linePath(world.borders, l0: l0n, p0: lat, R: R, cx: c, cy: c), with: .color(pal.map.line.color), lineWidth: 0.6)

        // routes: blurred halo (width*4, opacity*.35, blur sigma 3) + line
        for r in routes {
            let arc = GlobeMath.arcPath(r.from, r.to, l0: l0n, p0: lat, R: R, cx: c, cy: c, h: r.lift).path
            if arc.isEmpty { continue }
            let style = { (w: Double) in StrokeStyle(lineWidth: w, lineCap: .round) }
            g.drawLayer { l in
                l.addFilter(.blur(radius: 3))
                l.opacity = r.opacity * 0.35
                l.stroke(arc, with: .color(r.color), style: style(r.width * 4))
            }
            g.drawLayer { l in
                l.opacity = r.opacity
                l.stroke(arc, with: .color(r.color), style: style(r.width))
            }
        }

        if let pl = plane {
            let t = pl.t
            let tr = GlobeMath.arcPath(pl.from, pl.to, l0: l0n, p0: lat, R: R, cx: c, cy: c, h: 0.09, t0: 0, t1: t)
            let fu = GlobeMath.arcPath(pl.from, pl.to, l0: l0n, p0: lat, R: R, cx: c, cy: c, h: 0.09, t0: t, t1: 1)
            // stroke-dasharray "1 5" with round caps
            g.stroke(fu.path, with: .color(.white.opacity(0.5)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [1, 5]))
            let bb = tr.path.boundingRect
            // an SVG objectBoundingBox gradient on a zero-width/height box renders nothing
            if let end = tr.end, bb.width > 0, bb.height > 0 {
                let grad = Gradient(colors: [RGBA(hex: 0x6AB7FF).color, RGBA(hex: 0x8BF3D8).color])
                g.stroke(tr.path, with: .linearGradient(grad, startPoint: CGPoint(x: bb.minX, y: bb.minY), endPoint: CGPoint(x: bb.maxX, y: bb.maxY)),
                         style: StrokeStyle(lineWidth: 3, lineCap: .round))
                g.fill(Path(ellipseIn: CGRect(x: end.x - 9, y: end.y - 9, width: 18, height: 18)), with: .color(.white.opacity(0.18)))
                g.fill(Path(ellipseIn: CGRect(x: end.x - 4, y: end.y - 4, width: 8, height: 8)), with: .color(.white))
            } else if let end = tr.end {
                g.fill(Path(ellipseIn: CGRect(x: end.x - 9, y: end.y - 9, width: 18, height: 18)), with: .color(.white.opacity(0.18)))
                g.fill(Path(ellipseIn: CGRect(x: end.x - 4, y: end.y - 4, width: 8, height: 8)), with: .color(.white))
            }
        }

        // pins; remember label positions for the HTML-span labels drawn after the globe
        var labelsToDraw: [(String, CGPoint, Double)] = []
        for pin in pins {
            let q = GlobeMath.proj(lon: pin.coordinate.longitude, lat: pin.coordinate.latitude, l0: l0n, p0: lat, R: R)
            guard q.c > 0.02 else { continue }
            let o = 0.35 + 0.65 * min(1, q.c * 2.4)
            let pt = CGPoint(x: q.x + c, y: q.y + c)
            let r = pin.radius
            let dot = Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: 2 * r, height: 2 * r))
            g.drawLayer { l in
                l.opacity = o
                l.fill(dot, with: .color(pin.color))
                l.stroke(dot, with: .color(pal.bg0.color), lineWidth: 1.5)
            }
            if labels, let code = pin.label { labelsToDraw.append((code, CGPoint(x: pt.x + 7, y: pt.y - 14), o)) }
        }

        // shade: radialGradient cx 34% cy 30% r 86%, stops .55 transparent -> 1 black at --gl-shade
        let shade = Gradient(stops: [.init(color: .black.opacity(0), location: 0.55), .init(color: .black.opacity(pal.shade), location: 1)])
        g.fill(disk, with: .radialGradient(shade, center: CGPoint(x: c - R + 0.34 * 2 * R, y: c - R + 0.30 * 2 * R), startRadius: 0, endRadius: 0.86 * 2 * R))
        // rim: radialGradient 50% 50% r 50%, .86 #9FB6FF 0 -> .985 #9FB6FF rim -> 1 #C9D6FF 0
        let rim = Gradient(stops: [
            .init(color: RGBA(hex: 0x9FB6FF, a: 0).color, location: 0.86),
            .init(color: RGBA(hex: 0x9FB6FF, a: pal.rim).color, location: 0.985),
            .init(color: RGBA(hex: 0xC9D6FF, a: 0).color, location: 1),
        ])
        g.fill(disk, with: .radialGradient(rim, center: center, startRadius: 0, endRadius: R))

        // edge ring (outside the clip)
        ctx.stroke(disk, with: .color(pal.edge.color), lineWidth: 1)

        // .gl-lbl: 700 11px/1 condensed, letter-spacing .08em, text-shadow bg-0 halo
        for (code, tl, o) in labelsToDraw {
            let t = Text(code).font(.custom(MapFonts.condensed, fixedSize: 11)).tracking(0.88).foregroundColor(pal.text1.color)
            let resolved = ctx.resolve(t)
            let pos = CGPoint(x: tl.x, y: tl.y + 5.5)
            ctx.drawLayer { l in
                l.opacity = o
                // text-shadow: 0 0 3px, 0 0 3px, 0 1px 6px of --bg-0, each blurred on its own (filters would compound)
                for (blur, dy) in [(3.0, 0.0), (3.0, 0.0), (6.0, 1.0)] {
                    l.drawLayer { h in
                        h.addFilter(.shadow(color: pal.bg0.color, radius: blur * Self.shadowRadiusPerBlur, x: 0, y: dy, blendMode: .normal, options: []))
                        h.draw(resolved, at: pos, anchor: .leading)
                    }
                }
                l.draw(resolved, at: pos, anchor: .leading)
            }
        }
    }

    /// SwiftUI shadow radius per CSS blur px (CSS blur = 2 sigma).
    static let shadowRadiusPerBlur = 0.5

    private static let glowCache = OSAllocatedUnfairLock<[String: [Double]]>(initialState: [:])

    /// Outer glow of a circle: a CSS box-shadow of `blur` px (Gaussian sigma = blur / 2), drawn outside the circle only.
    static func glow(_ ctx: inout GraphicsContext, center: CGPoint, R: Double, blur: Double, color: RGBA) {
        let sigma = blur / 2
        guard sigma > 0 else { return }
        let outer = R + 3.2 * sigma
        let samples = 48
        let key = "\(R)-\(sigma)"
        let prof: [Double]
        if let hit = glowCache.withLock({ $0[key] }) { prof = hit } else {
            prof = GlobeMath.blurredDiskProfile(R: R, sigma: sigma, maxD: outer, count: samples)
            glowCache.withLock { $0[key] = prof }
        }
        var stops = [Gradient.Stop]()
        for (i, a) in prof.enumerated() {
            stops.append(.init(color: color.with(alpha: color.a * a).color, location: Double(i) / Double(samples - 1)))
        }
        let rect = CGRect(x: center.x - outer, y: center.y - outer, width: 2 * outer, height: 2 * outer)
        ctx.fill(Path(ellipseIn: rect), with: .radialGradient(Gradient(stops: stops), center: center, startRadius: 0, endRadius: outer))
    }
}
