import SwiftUI
import MeridianCore

/// Projection of the design's Europe plane (`K.eu`): Mercator, lon -35...60, lat 22...70 onto 3200 x 2589 px.
public enum EuropeProjection {
    public static let lon0 = -35.0, lat1 = 70.0
    public static let k = 1929.963099388036
    public static let plane = MapResources.europePlane

    private static func mercatorY(_ lat: Double) -> Double { log(tan(.pi / 4 + lat * .pi / 180 / 2)) }

    /// Plane coordinates of a coordinate (`EU.xy(lat, lon)`).
    public static func xy(latitude: Double, longitude: Double) -> CGPoint {
        CGPoint(x: k * (longitude - lon0) * .pi / 180, y: k * (mercatorY(lat1) - mercatorY(latitude)))
    }
    public static func xy(_ c: Coordinate) -> CGPoint { xy(latitude: c.latitude, longitude: c.longitude) }

    /// Screen position of a coordinate for a camera.
    public static func screenPoint(_ c: Coordinate, center: Coordinate, zoom: Double, size: CGSize, offset: CGSize = .zero) -> CGPoint {
        let p = xy(c), o = xy(center)
        return CGPoint(x: size.width / 2 + offset.width - o.x * zoom + p.x * zoom,
                       y: size.height / 2 + offset.height - o.y * zoom + p.y * zoom)
    }
}

/// The design's flat Europe map (`MapLayer.dc.html` + `.map[data-map]` CSS): sea, land with its diagonal sheen,
/// borders, graticule, sea and city labels, the rim glow, and for Satellite the terrain texture.
///
/// The camera is `center` (shown at the middle of the view, shifted by `offset`) and `zoom` (plane scale, 1.9 = the
/// Plan default). Zoom and centre animate together like the CSS `transform` transition: wrap a change in
/// `withAnimation(EuropeMapView.cameraAnimation)` (560 ms, `cubic-bezier(.2,0,0,1)`).
public struct EuropeMapView: View, Animatable {
    public var style: MapStyle
    public var theme: MapTheme?
    public var showsLabels: Bool
    public var showsGraticule: Bool
    public var size: CGSize?

    /// The CSS `--ease` curve with the 560 ms the design uses for `smooth` camera moves.
    public static let cameraAnimation: Animation = .timingCurve(0.2, 0, 0, 1, duration: 0.56)

    // Camera in the form CSS interpolates: translate (minus the half-size, which is view-size dependent) and scale.
    private var camX: Double
    private var camY: Double
    private var zoom: Double

    @Environment(\.colorScheme) private var scheme

    /// - Parameters:
    ///   - style: terra / mono / standard / satellite.
    ///   - theme: `nil` follows the colour scheme.
    ///   - center: coordinate shown at the centre of the view (plus `offset`).
    ///   - zoom: plane scale; labels keep their screen size.
    ///   - offset: `dx`/`dy` of the design, shifts the centre point (e.g. under a sidebar).
    ///   - size: fixed size of the map; `nil` fills the proposed size.
    public init(style: MapStyle = .terra, theme: MapTheme? = nil, center: Coordinate, zoom: Double,
                offset: CGSize = .zero, size: CGSize? = nil, showsLabels: Bool = true, showsGraticule: Bool = true) {
        self.style = style
        self.theme = theme
        self.showsLabels = showsLabels
        self.showsGraticule = showsGraticule
        self.size = size
        let p = EuropeProjection.xy(center)
        self.zoom = zoom
        self.camX = offset.width - p.x * zoom
        self.camY = offset.height - p.y * zoom
    }

    nonisolated public var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(zoom, AnimatablePair(camX, camY)) }
        set { zoom = newValue.first; camX = newValue.second.first; camY = newValue.second.second }
    }

    public var body: some View {
        let renderer = EuropeRenderer(style: style, theme: theme ?? MapTheme(scheme), zoom: zoom, camX: camX, camY: camY,
                                      labels: showsLabels, graticule: showsGraticule)
        let canvas = Canvas { ctx, size in renderer.draw(&ctx, size: size) }
        if let size {
            canvas.frame(width: size.width, height: size.height)
        } else {
            canvas
        }
    }
}

// MARK: - Renderer

struct EuropeRenderer {
    var style: MapStyle
    var theme: MapTheme
    var zoom: Double
    var camX: Double
    var camY: Double
    var labels: Bool
    var graticule: Bool

    func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        let pal = MapPalette.resolve(style: style, theme: theme)
        let z = zoom
        let tx = size.width / 2 + camX, ty = size.height / 2 + camY
        let full = CGRect(origin: .zero, size: size)

        // .map { background: var(--m-sea) }
        ctx.fill(Path(full), with: .color(pal.sea.color))

        // .eu { transform: translate(tx,ty) scale(z) } and its children, in plane coordinates
        var p = ctx
        p.translateBy(x: tx, y: ty)
        p.scaleBy(x: z, y: z)
        let plane = MapResources.europePlane
        let land = MapResources.europeLand

        if style == .satellite {
            drawTerrain(&p, land: land, tx: tx, ty: ty, size: size)
        } else {
            // .eu-land / .eu-land2 (mask = land svg, fill-rule evenodd)
            p.fill(land, with: .color(pal.land.color), style: FillStyle(eoFill: true))
            // linear-gradient(160deg, land-2, transparent 60%) over the 3200 x 2589 box
            let (a, b) = Self.cssGradientLine(angleDegrees: 160, width: plane.width, height: plane.height)
            let g = Gradient(stops: [.init(color: pal.land2.color, location: 0), .init(color: pal.land2.with(alpha: 0).color, location: 0.6)])
            p.fill(land, with: .linearGradient(g, startPoint: a, endPoint: b), style: FillStyle(eoFill: true))
        }

        // .eu-border: mask of the borders svg, stroke 1.2 round joins
        p.stroke(MapResources.europeBorders, with: .color(pal.line.color),
                 style: StrokeStyle(lineWidth: 1.2, lineCap: .butt, lineJoin: .round))

        if graticule && style != .satellite {
            let w = 1 / z
            var lines = Path()
            var lon = -30.0
            while lon <= 60 {
                let x = EuropeProjection.xy(latitude: 40, longitude: lon).x
                lines.addRect(CGRect(x: x, y: 0, width: w, height: plane.height))
                lon += 10
            }
            var lat = 30.0
            while lat <= 70 {
                let y = EuropeProjection.xy(latitude: lat, longitude: 0).y
                lines.addRect(CGRect(x: 0, y: y, width: plane.width, height: w))
                lat += 10
            }
            p.fill(lines, with: .color(pal.grat.color))
        }

        if labels { drawLabels(&ctx, pal: pal, tx: tx, ty: ty, size: size) }

        // rim glow overlay
        switch style {
        case .terra:
            // radial-gradient(70% 55% at 28% -10%, rgba(150,140,255,.20), transparent 70%)
            let c = RGBA(150, 140, 255, 0.20)
            Self.ellipticalGlow(&ctx, size: size, cx: 0.28, cy: -0.10, rx: 0.70, ry: 0.55,
                                stops: [.init(color: c.color, location: 0), .init(color: c.with(alpha: 0).color, location: 0.7)])
        case .satellite:
            // radial-gradient(120% 100% at 50% 50%, transparent 55%, rgba(4,10,20,.55))
            let c = RGBA(4, 10, 20, 0.55)
            Self.ellipticalGlow(&ctx, size: size, cx: 0.5, cy: 0.5, rx: 1.2, ry: 1.0,
                                stops: [.init(color: c.with(alpha: 0).color, location: 0.55), .init(color: c.color, location: 1)])
        default:
            break
        }
    }

    // MARK: pieces

    /// CSS `linear-gradient(<angle>, ...)` gradient line for a w x h box (start and end points).
    static func cssGradientLine(angleDegrees: Double, width w: Double, height h: Double) -> (CGPoint, CGPoint) {
        let a = angleDegrees * .pi / 180
        let dx = sin(a), dy = -cos(a)
        let len = abs(w * sin(a)) + abs(h * cos(a))
        let c = CGPoint(x: w / 2, y: h / 2)
        return (CGPoint(x: c.x - dx * len / 2, y: c.y - dy * len / 2), CGPoint(x: c.x + dx * len / 2, y: c.y + dy * len / 2))
    }

    /// CSS `radial-gradient(rx ry at cx cy, stops)` filling the whole canvas; radii and centre as fractions of the size.
    static func ellipticalGlow(_ ctx: inout GraphicsContext, size: CGSize, cx: Double, cy: Double, rx: Double, ry: Double, stops: [Gradient.Stop]) {
        var g = ctx
        let pcx = cx * size.width, pcy = cy * size.height, prx = rx * size.width, pry = ry * size.height
        g.translateBy(x: pcx, y: pcy)
        g.scaleBy(x: prx, y: pry)
        let rect = CGRect(x: -pcx / prx, y: -pcy / pry, width: size.width / prx, height: size.height / pry)
        g.fill(Path(rect), with: .radialGradient(Gradient(stops: stops), center: .zero, startRadius: 0, endRadius: 1))
    }

    private func drawTerrain(_ p: inout GraphicsContext, land: Path, tx: Double, ty: Double, size: CGSize) {
        guard let tex = MapResources.terrain else { return }
        var c = p
        c.clip(to: land, style: FillStyle(eoFill: true))
        let resolved = c.resolve(Image(decorative: tex.image, scale: 1).interpolation(.high))
        // .eu-sat { background: url(terrain-fields.svg) 0 0 / 1100px 1100px } (MapLayer overrides 1400px with 1100px)
        let tile = 1100.0
        let z = zoom
        let vis = CGRect(x: -tx / z, y: -ty / z, width: size.width / z, height: size.height / z)
        let plane = MapResources.europePlane
        let x0 = max(0, Int(floor(vis.minX / tile))), x1 = min(Int(ceil(plane.width / tile)) - 1, Int(floor(vis.maxX / tile)))
        let y0 = max(0, Int(floor(vis.minY / tile))), y1 = min(Int(ceil(plane.height / tile)) - 1, Int(floor(vis.maxY / tile)))
        guard x0 <= x1, y0 <= y1 else { return }
        for j in y0...y1 {
            for i in x0...x1 {
                // 0.5 px overlap hides antialiasing seams between tiles
                c.draw(resolved, in: CGRect(x: Double(i) * tile, y: Double(j) * tile, width: tile + 0.5, height: tile + 0.5))
            }
        }
    }

    private func drawLabels(_ ctx: inout GraphicsContext, pal: MapPalette, tx: Double, ty: Double, size: CGSize) {
        let z = zoom
        func visible(_ s: CGPoint) -> Bool { s.x > -60 && s.x < size.width + 60 && s.y > -30 && s.y < size.height + 30 }
        let color = pal.label.color
        // .eu-lbl: 500 11.5px (screen) italic uppercase, letter-spacing (.14/z)em of a (11.5/z)px font = 1.61/z screen px
        for (name, lat, lon) in MapLabels.seas {
            let q = EuropeProjection.xy(latitude: lat, longitude: lon)
            let s = CGPoint(x: q.x * z + tx, y: q.y * z + ty)
            guard visible(s) else { continue }
            let track = 0.14 * 11.5 / z
            let t = Text(name.uppercased()).font(.custom(MapFonts.ui, fixedSize: 11.5).weight(.medium)).tracking(track).foregroundColor(color)
            // Inter ships no italic: browsers synthesize an oblique with a 0.25 skew about the baseline, and so do we.
            // Baseline sits (ascent - descent) / 2 = 0.3638 em below the centre of the line box.
            let drop = 0.3638 * 11.5
            var l = ctx
            l.translateBy(x: s.x, y: s.y + drop)
            l.concatenate(CGAffineTransform(a: 1, b: 0, c: -0.25, d: 1, tx: 0, ty: 0))
            l.draw(l.resolve(t), at: CGPoint(x: 0, y: -drop), anchor: .center)
        }
        // .eu-city: 500 11px
        for (name, lat, lon) in MapLabels.cities {
            let q = EuropeProjection.xy(latitude: lat, longitude: lon)
            let s = CGPoint(x: q.x * z + tx, y: q.y * z + ty)
            guard visible(s) else { continue }
            let t = Text(name).font(.custom(MapFonts.ui, fixedSize: 11).weight(.medium)).foregroundColor(color)
            ctx.draw(ctx.resolve(t), at: s, anchor: .center)
        }
    }
}

/// Label tables copied from `MapLayer.dc.html` (name, latitude, longitude).
enum MapLabels {
    static let seas: [(String, Double, Double)] = [
        ("North Sea", 56.3, 2.6), ("Atlantic Ocean", 47.5, -16), ("Mediterranean Sea", 36.4, 16), ("Baltic Sea", 58.4, 19.6),
        ("Bay of Biscay", 45.2, -5.2), ("Norwegian Sea", 66.2, 1.5), ("Black Sea", 43.3, 34.2), ("Irish Sea", 53.8, -4.9),
        ("English Channel", 50.15, -2.2),
    ]
    static let cities: [(String, Double, Double)] = [
        ("London", 51.51, -0.13), ("Paris", 48.86, 2.35), ("Amsterdam", 52.37, 4.9), ("Brussels", 50.85, 4.35), ("Berlin", 52.52, 13.4),
        ("Madrid", 40.42, -3.7), ("Rome", 41.9, 12.5), ("Dublin", 53.35, -6.26), ("Edinburgh", 55.95, -3.19), ("Manchester", 53.48, -2.24),
        ("Copenhagen", 55.68, 12.57), ("Oslo", 59.91, 10.75), ("Stockholm", 59.33, 18.07), ("Vienna", 48.21, 16.37), ("Zurich", 47.37, 8.54),
        ("Lisbon", 38.72, -9.14), ("Rennes", 48.11, -1.68), ("Lille", 50.63, 3.06), ("Cologne", 50.94, 6.96), ("Bristol", 51.45, -2.59),
        ("Newcastle", 54.98, -1.62), ("Birmingham", 52.48, -1.9), ("Istanbul", 41.01, 28.98), ("Athens", 37.98, 23.73), ("Warsaw", 52.23, 21.01),
        ("Reykjavik", 64.15, -21.94), ("Helsinki", 60.17, 24.94), ("Munich", 48.14, 11.58), ("Barcelona", 41.39, 2.17), ("Milan", 45.46, 9.19),
    ]
}
