import SwiftUI
import MeridianCore

/// Equirectangular world map of the design (`WorldFlat.dc.html`): land and border masks from the world geometry,
/// the visited-country layers, a 30 degree graticule, glowing route arcs and airport pins with IATA labels.
///
/// `w` is the width in points; the height is `round((latTop - latBot) * w / 360)`. Routes reuse `GlobeRoute`
/// (`lift` is the design's `h` multiplier of the arc height, default 1).
public struct WorldFlatView: View {
    public var w: CGFloat
    public var latTop: Double
    public var latBot: Double
    public var visited: Bool
    public var showsGraticule: Bool
    public var showsLabels: Bool
    public var routes: [GlobeRoute]
    public var pins: [GlobePin]
    public var theme: MapTheme?
    @Environment(\.colorScheme) private var scheme

    public init(w: CGFloat = 1000, latTop: Double = 80, latBot: Double = -56, visited: Bool = true,
                showsGraticule: Bool = true, showsLabels: Bool = true,
                routes: [GlobeRoute] = [], pins: [GlobePin] = [], theme: MapTheme? = nil) {
        self.w = w; self.latTop = latTop; self.latBot = latBot; self.visited = visited
        self.showsGraticule = showsGraticule; self.showsLabels = showsLabels
        self.routes = routes; self.pins = pins; self.theme = theme
    }

    public var height: CGFloat { ((latTop - latBot) * Double(w) / 360).rounded() }

    public var body: some View {
        let theme = theme ?? MapTheme(scheme)
        let r = FlatRenderer(w: Double(w), h: Double(height), top: latTop, theme: theme, visited: visited,
                             graticule: showsGraticule, labels: showsLabels, routes: routes, pins: pins)
        Canvas { ctx, _ in r.draw(ctx) }
            .frame(width: w, height: height)
            .clipped()
            .accessibilityElement()
            .accessibilityLabel("World map")
    }
}

/// Lon/lat (degrees) paths of the world layers, built once.
private enum FlatGeometry {
    static func build(_ rings: WorldGeometry.Rings) -> Path {
        var path = Path()
        rings.pts.withUnsafeBufferPointer { p in
            for r in rings.ranges where r.count > 0 {
                var first = true
                for k in 0..<r.count {
                    let i = (r.start + k) * 4
                    let lat = atan2(Double(p[i + 1]), Double(p[i])) * 180 / .pi
                    let lon = atan2(Double(p[i + 3]), Double(p[i + 2])) * 180 / .pi
                    let pt = CGPoint(x: lon, y: lat)
                    if first { path.move(to: pt); first = false } else { path.addLine(to: pt) }
                }
                path.closeSubpath()
            }
        }
        return path
    }
    static let land = build(MapResources.world.land)
    static let hi = build(MapResources.world.hi)
    static let mid = build(MapResources.world.mid)
    static let lo = build(MapResources.world.lo)
    /// Borders are open polylines.
    static let borders: Path = {
        var path = Path()
        let rings = MapResources.world.borders
        rings.pts.withUnsafeBufferPointer { p in
            for r in rings.ranges where r.count > 0 {
                for k in 0..<r.count {
                    let i = (r.start + k) * 4
                    let pt = CGPoint(x: atan2(Double(p[i + 3]), Double(p[i + 2])) * 180 / .pi, y: atan2(Double(p[i + 1]), Double(p[i])) * 180 / .pi)
                    if k == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                }
            }
        }
        return path
    }()
}

struct FlatRenderer {
    var w: Double, h: Double, top: Double
    var theme: MapTheme
    var visited: Bool
    var graticule: Bool
    var labels: Bool
    var routes: [GlobeRoute]
    var pins: [GlobePin]

    func draw(_ ctx: GraphicsContext) {
        let pal = GlobePalette.resolve(theme: theme)
        let s = w / 360
        var c = ctx
        c.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)), with: .color(pal.map.sea.color))
        // lon/lat degrees -> points: x = (lon + 180) * s, y = (top - lat) * s
        let t = CGAffineTransform(a: s, b: 0, c: 0, d: -s, tx: 180 * s, ty: top * s)

        c.fill(FlatGeometry.land.applying(t), with: .color(pal.map.land.color))
        c.stroke(FlatGeometry.borders.applying(t), with: .color(pal.map.line.color), lineWidth: 0.6 * w / 1440)
        if visited {
            c.fill(FlatGeometry.lo.applying(t), with: .color(pal.accent.with(alpha: 0.24).color))
            c.fill(FlatGeometry.mid.applying(t), with: .color(pal.accent.with(alpha: 0.46).color))
            c.fill(FlatGeometry.hi.applying(t), with: .color(pal.accent.with(alpha: 0.78).color))
        }
        // The graticule is an SVG overlay above the masks.
        if graticule {
            var g = Path()
            for lon in stride(from: -180.0, through: 180, by: 30) { g.move(to: CGPoint(x: (lon + 180) * s, y: 0)); g.addLine(to: CGPoint(x: (lon + 180) * s, y: h)) }
            let bot = top - h / s
            var lat = (bot / 30).rounded(.up) * 30
            while lat <= top { let y = (top - lat) * s; g.move(to: CGPoint(x: 0, y: y)); g.addLine(to: CGPoint(x: w, y: y)); lat += 30 }
            c.stroke(g, with: .color(pal.map.grat.color), lineWidth: 1)
        }

        for r in routes {
            let km = Self.gcKm(r.from, r.to)
            let lift = min(60, km / 100 * s * 0.6 * r.lift)
            let arc = Self.flatArc(r.from, r.to, w: w, top: top, n: 40, lift: lift)
            if arc.isEmpty { continue }
            c.drawLayer { l in
                l.addFilter(.blur(radius: 3))
                l.opacity = r.opacity * 0.3
                l.stroke(arc, with: .color(r.color), style: StrokeStyle(lineWidth: r.width * 4, lineCap: .round))
            }
            c.drawLayer { l in
                l.opacity = r.opacity
                l.stroke(arc, with: .color(r.color), style: StrokeStyle(lineWidth: r.width, lineCap: .round))
            }
        }
        var lbls: [(String, CGPoint)] = []
        for p in pins {
            let x = (p.coordinate.longitude + 180) * s, y = (top - p.coordinate.latitude) * s
            let dot = Path(ellipseIn: CGRect(x: x - p.radius, y: y - p.radius, width: 2 * p.radius, height: 2 * p.radius))
            c.fill(dot, with: .color(p.color))
            c.stroke(dot, with: .color(pal.bg0.color), lineWidth: 1.5)
            if labels, let code = p.label { lbls.append((code, CGPoint(x: x + 6, y: y - 14 + 5.5))) }
        }
        for (code, pos) in lbls {
            let text = Text(code).font(.custom(MapFonts.condensed, fixedSize: 11)).tracking(0.88).foregroundColor(pal.text1.color)
            let resolved = c.resolve(text)
            c.drawLayer { l in
                for (blur, dy) in [(3.0, 0.0), (3.0, 0.0), (6.0, 1.0)] {
                    l.drawLayer { hh in
                        hh.addFilter(.shadow(color: pal.bg0.color, radius: blur * 0.5, x: 0, y: dy, blendMode: .normal, options: []))
                        hh.draw(resolved, at: pos, anchor: .leading)
                    }
                }
                l.draw(resolved, at: pos, anchor: .leading)
            }
        }
    }

    static func gcKm(_ a: Coordinate, _ b: Coordinate) -> Double {
        let D = Double.pi / 180
        let la1 = a.latitude * D, la2 = b.latitude * D, dlo = (b.longitude - a.longitude) * D
        let h = pow(sin((la2 - la1) / 2), 2) + cos(la1) * cos(la2) * pow(sin(dlo / 2), 2)
        return 6371 * 2 * asin(min(1, h.squareRoot()))
    }

    /// `W.gcPoint`: (lat, lon) at fraction t of the great circle.
    static func gcPoint(_ a: Coordinate, _ b: Coordinate, _ t: Double) -> (lat: Double, lon: Double) {
        let D = Double.pi / 180
        let la1 = a.latitude * D, lo1 = a.longitude * D, la2 = b.latitude * D, lo2 = b.longitude * D
        var dd = 2 * asin(min(1, (pow(sin((la2 - la1) / 2), 2) + cos(la1) * cos(la2) * pow(sin((lo2 - lo1) / 2), 2)).squareRoot()))
        if dd == 0 { dd = 1e-6 }
        let A = sin((1 - t) * dd) / sin(dd), B = sin(t * dd) / sin(dd)
        let x = A * cos(la1) * cos(lo1) + B * cos(la2) * cos(lo2)
        let y = A * cos(la1) * sin(lo1) + B * cos(la2) * sin(lo2)
        let z = A * sin(la1) + B * sin(la2)
        return (atan2(z, (x * x + y * y).squareRoot()) / D, atan2(y, x) / D)
    }

    /// `W.flatArc`: sampled great circle, lifted by `lift * sin(pi t)`, pen up when it wraps the antimeridian.
    static func flatArc(_ a: Coordinate, _ b: Coordinate, w: Double, top: Double, n: Int, lift: Double) -> Path {
        var path = Path()
        var pen = false
        var prevX: Double?
        let s = w / 360
        for i in 0...n {
            let p = gcPoint(a, b, Double(i) / Double(n))
            let x = (p.lon + 180) * s, y = (top - p.lat) * s - lift * sin(Double.pi * Double(i) / Double(n))
            if let px = prevX, abs(x - px) > w / 2 { pen = false }
            if pen { path.addLine(to: CGPoint(x: x, y: y)) } else { path.move(to: CGPoint(x: x, y: y)) }
            pen = true; prevX = x
        }
        return path
    }
}
