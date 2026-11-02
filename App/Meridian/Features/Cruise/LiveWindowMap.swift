import AppKit
import MapKit
import MeridianCore
import MeridianCruise
import SwiftUI

// MARK: - Overlays (draped on the terrain by MapKit)

/// NASA GIBS true-colour tiles turned into a cloud layer: bright, colourless pixels keep their colour and get an alpha,
/// everything else becomes transparent (`CloudMask`). Real satellite imagery of the UTC day `day`.
nonisolated final class GIBSCloudOverlay: MKTileOverlay, @unchecked Sendable {
    let day: Date

    init(day: Date) {
        self.day = day
        super.init(urlTemplate: nil)
        canReplaceMapContent = false
        tileSize = CGSize(width: 256, height: 256)
        minimumZ = 0
        maximumZ = 9
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping @Sendable (Data?, (any Error)?) -> Void) {
        let url = CloudMask.gibsURL(day: day, z: path.z, x: path.x, y: path.y)
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.cachePolicy = .returnCacheDataElseLoad
        URLSession.shared.dataTask(with: req) { data, resp, error in
            guard let data, (resp as? HTTPURLResponse)?.statusCode == 200, let png = Self.cloudPNG(from: data) else {
                result(nil, error ?? URLError(.badServerResponse)); return
            }
            result(png, nil)
        }.resume()
    }

    static func cloudPNG(from jpeg: Data) -> Data? {
        guard let src = CGImageSourceCreateWithData(jpeg as CFData, nil), let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        let w = img.width, h = img.height
        var px = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        for i in stride(from: 0, to: px.count, by: 4) {
            let r = Double(px[i]) / 255, g = Double(px[i + 1]) / 255, b = Double(px[i + 2]) / 255
            let a = CloudMask.alpha(r: r, g: g, b: b)
            px[i] = UInt8(r * a * 255); px[i + 1] = UInt8(g * a * 255); px[i + 2] = UInt8(b * a * 255); px[i + 3] = UInt8(a * 255)
        }
        guard let out = ctx.makeImage() else { return nil }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, out, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }
}

/// A flat colour over the whole map (day / golden / blue / night grade), below the city lights.
nonisolated final class WorldOverlay: NSObject, MKOverlay {
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: 0, longitude: 0) }
    var boundingMapRect: MKMapRect { .world }
}

nonisolated final class TintRenderer: MKOverlayRenderer, @unchecked Sendable {
    nonisolated(unsafe) private(set) var color = CGColor(gray: 0, alpha: 0)

    func update(_ c: DayNightGrade.RGBA) {
        // quantised: every change redraws the tiles
        let q = { (v: Double, s: Double) in (v / s).rounded() * s }
        let a = q(c.a, 0.02)
        let next = CGColor(red: q(c.r, 16) / 255, green: q(c.g, 16) / 255, blue: q(c.b, 16) / 255, alpha: a)
        if next != color { color = next; setNeedsDisplay() }
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in ctx: CGContext) {
        guard color.alpha > 0 else { return }
        ctx.setFillColor(color)
        ctx.fill(rect(for: mapRect))
    }
}

/// Warm light clusters around the airports of the bundled data (a stand-in for city density, which MapKit does not give):
/// a soft halo and a scatter of dots per airport, additive. Fake but plausible.
nonisolated final class LightsRenderer: MKOverlayRenderer, @unchecked Sendable {
    struct Site { let point: MKMapPoint; let ppm: Double; let seed: UInt64; let radiusM: Double }
    let sites: [Site]

    init(overlay: MKOverlay, sites: [Site]) {
        self.sites = sites
        super.init(overlay: overlay)
    }

    static func sites(_ coords: [Coordinate]) -> [Site] {
        coords.enumerated().map { i, c in
            let loc = CLLocationCoordinate2D(latitude: c.latitude, longitude: c.longitude)
            let seed = UInt64(i &* 2_654_435_761 &+ 12_345)
            let size = Double(seed % 1000) / 1000
            return Site(point: MKMapPoint(loc), ppm: MKMapPointsPerMeterAtLatitude(c.latitude), seed: seed, radiusM: 3_000 + size * size * 9_000)
        }
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in ctx: CGContext) {
        let space = CGColorSpaceCreateDeviceRGB()
        ctx.setBlendMode(.normal)
        for s in sites {
            let r = s.radiusM * s.ppm
            let m = r * 1.1
            guard s.point.x > mapRect.minX - m, s.point.x < mapRect.maxX + m, s.point.y > mapRect.minY - m, s.point.y < mapRect.maxY + m else { continue }
            let px = r * zoomScale   // cluster radius in screen points of this tile level
            if px < 1.5 { continue }
            let c = CGPoint(x: s.point.x, y: s.point.y)
            ctx.setBlendMode(.normal)
            // halo
            if let g = CGGradient(colorsSpace: space, colors: [CGColor(red: 1, green: 0.62, blue: 0.28, alpha: 0.62), CGColor(red: 1, green: 0.5, blue: 0.2, alpha: 0.2),
                                                            CGColor(red: 1, green: 0.45, blue: 0.15, alpha: 0)] as CFArray, locations: [0, 0.45, 1]) {
                ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: r * 0.55, options: [])
            }
            guard px > 7 else { continue }
            ctx.setBlendMode(.plusLighter)
            var seed = s.seed
            func rnd() -> Double { seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407; return Double((seed >> 33) & 0xFFFFFF) / Double(0x1000000) }
            let n = Int(min(420, 70 + px / 1.6))
            let dot = max(2.0, min(3.6, px / 30)) / zoomScale
            for _ in 0..<n {
                let a = rnd() * 2 * .pi, d = r * 0.9 * pow(rnd(), 2.0)
                let warm = rnd()
                ctx.setFillColor(CGColor(red: 1, green: 0.72 + 0.2 * warm, blue: 0.38 + 0.4 * warm * warm, alpha: 0.55 + 0.4 * rnd()))
                let x = c.x + cos(a) * d, y = c.y + sin(a) * d * 0.9
                ctx.fillEllipse(in: CGRect(x: x - dot, y: y - dot, width: dot * 2, height: dot * 2))
            }
        }
    }
}

// MARK: - Map host

/// The window's ground: Apple Maps realistic satellite imagery with a perspective camera at the aircraft, plus the cloud
/// tiles, the day / night grade and the city lights as overlays. Non-interactive.
struct LiveWindowMap: NSViewRepresentable {
    var camera: WindowCameraSpec
    var tint: DayNightGrade.RGBA
    var lights: Double
    var cloudAlpha: Double
    var cloudDay: Date
    var animated: Bool
    var onHealth: (Bool) -> Void = { _ in }

    func makeNSView(context: Context) -> Host {
        let h = Host(cloudDay: cloudDay)
        h.delegate = context.coordinator
        context.coordinator.host = h
        context.coordinator.onHealth = onHealth
        return h
    }

    func updateNSView(_ v: Host, context: Context) {
        context.coordinator.onHealth = onHealth
        // energy: nothing to draw while the window is hidden or occluded
        if let w = v.window, !w.occlusionState.contains(.visible) { return }
        v.apply(camera: camera, animated: animated)
        context.coordinator.wantTint = tint; context.coordinator.wantLights = lights; context.coordinator.wantCloud = cloudAlpha
        context.coordinator.tint?.update(tint)
        context.coordinator.setLights(lights)
        context.coordinator.setCloud(cloudAlpha)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor final class Coordinator: NSObject, MKMapViewDelegate {
        weak var host: Host?
        var tint: TintRenderer?
        var lightsRenderer: LightsRenderer?
        var cloudRenderer: MKTileOverlayRenderer?
        var onHealth: (Bool) -> Void = { _ in }
        /// Latest requested values, applied when MapKit creates the renderers (after the first update).
        var wantTint = DayNightGrade.RGBA(r: 255, g: 255, b: 255, a: 0)
        var wantLights = 0.0, wantCloud = 0.0
        private var pending: Task<Void, Never>?
        private var lastLights = -1.0, lastCloud = -1.0

        func setLights(_ v: Double) {
            let q = (v * 25).rounded() / 25
            guard let r = lightsRenderer, q != lastLights else { return }
            lastLights = q; r.alpha = q; r.setNeedsDisplay()
        }

        func setCloud(_ v: Double) {
            let q = (v * 25).rounded() / 25
            guard let r = cloudRenderer, q != lastCloud else { return }
            lastCloud = q; r.alpha = q; r.setNeedsDisplay()
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            if let t = overlay as? MKTileOverlay {
                let r = MKTileOverlayRenderer(tileOverlay: t)
                cloudRenderer = r
                r.alpha = wantCloud
                return r
            }
            if overlay is WorldOverlay, host?.lightsOverlay === overlay {
                let r = LightsRenderer(overlay: overlay, sites: LiveWindowMap.lightSites)
                lightsRenderer = r
                r.alpha = wantLights
                return r
            }
            let r = TintRenderer(overlay: overlay)
            tint = r
            r.update(wantTint)
            return r
        }

        func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: any Error) {
            pending?.cancel()
            pending = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(8))
                if !Task.isCancelled { self?.onHealth(true) }
            }
        }

        func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) {
            guard fullyRendered else { return }
            pending?.cancel()
            onHealth(false)
        }
    }

    @MainActor static let lightSites: [LightsRenderer.Site] = LightsRenderer.sites(PlanKit.index.airports.map(\.coordinate))

    final class Host: MKMapView {
        let tintOverlay = WorldOverlay()
        let lightsOverlay = WorldOverlay()
        private var last: WindowCameraSpec?

        init(cloudDay: Date) {
            super.init(frame: .zero)
            preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .realistic)
            isZoomEnabled = false; isScrollEnabled = false; isRotateEnabled = false; isPitchEnabled = true
            showsZoomControls = false; showsCompass = false; showsScale = false
            addOverlay(GIBSCloudOverlay(day: cloudDay), level: .aboveLabels)
            addOverlay(tintOverlay, level: .aboveLabels)
            addOverlay(lightsOverlay, level: .aboveLabels)
        }

        @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func layout() {
            super.layout()
            // MapKit clamps the pitch while the view has no size: apply again once it has one
            if bounds.width > 1, !sized, let c = last {
                sized = true
                setCamera(Self.camera(c), animated: false)
            }
        }
        private var sized = false

        static func camera(_ c: WindowCameraSpec) -> MKMapCamera {
            MKMapCamera(lookingAtCenter: CLLocationCoordinate2D(latitude: c.center.latitude, longitude: c.center.longitude),
                        fromEyeCoordinate: CLLocationCoordinate2D(latitude: c.eye.latitude, longitude: c.eye.longitude), eyeAltitude: c.eyeAltitudeM)
        }

        func apply(camera c: WindowCameraSpec, animated: Bool) {
            if let l = last, l == c { return }
            let first = last == nil
            last = c
            let cam = Self.camera(c)
            setCamera(cam, animated: animated && !first && bounds.width > 1)
        }
    }
}
