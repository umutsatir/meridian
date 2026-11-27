import MapKit
import MeridianCore
import Network
import SwiftUI

// MARK: - Engine choice

/// Which engine draws the map surfaces. Apple Maps is the default; Illustrated is the design canvas drawing
/// (`EuropeMapView` / `GlobeView`), kept for the design comparison routes and as the offline fallback.
public enum MapEngine: Int, Sendable {
    case appleMaps = 0, illustrated = 1

    public static let defaultsKey = "settings.maps.engine"
    public static let homeGlobeKey = "settings.maps.homeGlobe"

    /// `--map-engine illustrated|apple` on the command line wins (screenshot harness), then the setting.
    public static var current: MapEngine {
        let a = ProcessInfo.processInfo.arguments
        if let i = a.firstIndex(of: "--map-engine"), i + 1 < a.count { return a[i + 1].hasPrefix("ill") ? .illustrated : .appleMaps }
        return MapEngine(rawValue: UserDefaults.standard.object(forKey: defaultsKey) as? Int ?? 0) ?? .appleMaps
    }

    /// Home globe: realistic (satellite) unless the owner chose Illustrated or the engine is Illustrated.
    public static var homeGlobeIsRealistic: Bool {
        current == .appleMaps && (UserDefaults.standard.object(forKey: homeGlobeKey) as? Int ?? 0) == 0
    }
}

/// Network and tile health of the Apple Maps surfaces. When the map cannot load, surfaces draw the illustrated map
/// instead and say so (S54 "Map failed").
@MainActor @Observable
public final class MapHealth {
    public static let shared = MapHealth()
    public private(set) var offline = false
    public private(set) var tilesFailed = false
    /// `--map-offline` forces the failure state (screenshots).
    public var failed: Bool { offline || tilesFailed || ProcessInfo.processInfo.arguments.contains("--map-offline") }
    @ObservationIgnored private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let off = path.status != .satisfied
            Task { @MainActor in self?.offline = off }
        }
        monitor.start(queue: DispatchQueue(label: "meridian.map.health"))
    }

    func tiles(failed: Bool) { if tilesFailed != failed { tilesFailed = failed } }
}

// MARK: - Drop-in surface

/// The map surface: same camera model as `EuropeMapView` (centre, zoom, offset), drawn by Apple Maps or, when the
/// engine is Illustrated or the map failed to load, by the canvas map. Overlays drawn on top by the screens stay aligned
/// because Apple Maps uses the same Mercator projection (`AppleMapView` fits the identical rectangle).
public struct MapSurface: View {
    public var style: MapStyle
    public var theme: MapTheme?
    public var center: Coordinate
    public var zoom: Double
    public var offset: CGSize
    public var size: CGSize?
    public var showsLabels: Bool
    public var showsGraticule: Bool
    /// `false` for cameras that move every frame (cruise follow camera).
    public var animatesCamera: Bool
    /// Follow camera (rotation, deep zoom). When set, `center` / `zoom` / `offset` are ignored.
    public var followCamera: FollowCamera?
    /// Lets the screen ask the Apple map where a coordinate is drawn (tilted follow camera).
    public var projector: MapProjector?
    /// Called when Apple Maps has drawn everything for the current camera (imagery loaded).
    public var onRendered: (() -> Void)?

    @AppStorage(MapEngine.defaultsKey) private var engineRaw = 0
    @Environment(\.colorScheme) private var scheme

    public init(style: MapStyle = .terra, theme: MapTheme? = nil, center: Coordinate, zoom: Double, offset: CGSize = .zero,
                size: CGSize? = nil, showsLabels: Bool = true, showsGraticule: Bool = true, animatesCamera: Bool = true,
                followCamera: FollowCamera? = nil, projector: MapProjector? = nil, onRendered: (() -> Void)? = nil) {
        self.followCamera = followCamera; self.projector = projector; self.onRendered = onRendered
        self.style = style; self.theme = theme; self.center = center; self.zoom = zoom; self.offset = offset; self.size = size
        self.showsLabels = showsLabels; self.showsGraticule = showsGraticule; self.animatesCamera = animatesCamera
    }

    public var body: some View {
        let _ = engineRaw
        let health = MapHealth.shared
        let wantsApple = MapEngine.current == .appleMaps
        let apple = wantsApple && !health.failed
        let dark = (theme.map { $0 == .dark }) ?? (scheme == .dark)
        let wide = size == nil
        Group {
            if apple {
                AppleMapView(style: style, dark: dark, center: center, zoom: zoom, offset: offset, animates: animatesCamera, follow: followCamera, projector: projector, onRendered: onRendered)
                    .grayscale(style == .mono ? 1 : 0)
            } else if let cam = followCamera {
                // The illustrated map has no rotation: draw it on a square big enough to cover the view at any angle and
                // rotate that, like the map engine rotates its camera.
                // north up needs no cover square (and keeps the rim glow exactly where the design has it)
                let d = abs(cam.bearing) < 0.01 ? 0 : hypot(cam.size.width, cam.size.height).rounded(.up)
                EuropeMapView(style: style, theme: theme, center: cam.viewCenter, zoom: cam.scale, offset: .zero,
                              size: d == 0 ? cam.size : CGSize(width: d, height: d), showsLabels: showsLabels, showsGraticule: showsGraticule)
                    .transaction { $0.animation = nil }
                    .rotationEffect(.degrees(-cam.bearing))
                    .frame(width: cam.size.width, height: cam.size.height)
                    .clipped()
            } else {
                EuropeMapView(style: style, theme: theme, center: center, zoom: zoom, offset: offset, size: nil,
                              showsLabels: showsLabels, showsGraticule: showsGraticule)
            }
        }
        .frame(width: followCamera?.size.width ?? size?.width, height: followCamera?.size.height ?? size?.height)
        .overlay(alignment: .top) {
            if wantsApple && health.failed && wide {
                Text("The map didn’t load. Your plane is still flying. We’re showing the simple route until the map is back.")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(.black.opacity(0.55), in: Capsule())
                    .padding(.top, 76).allowsHitTesting(false)
            }
        }
    }
}

// MARK: - MKMapView host

/// Apple Maps with a flat top-down camera that reproduces the design's Mercator camera exactly: the visible map rect is
/// the rect the Europe plane camera shows (plane scale `zoom`, 1 plane px = 1 pt at zoom 1).
public struct AppleMapView: NSViewRepresentable {
    public var style: MapStyle
    public var dark: Bool
    public var center: Coordinate
    public var zoom: Double
    public var offset: CGSize
    public var animates: Bool
    public var follow: FollowCamera?
    public var projector: MapProjector?
    public var onRendered: (() -> Void)?

    public init(style: MapStyle, dark: Bool, center: Coordinate, zoom: Double, offset: CGSize = .zero, animates: Bool = true,
                follow: FollowCamera? = nil, projector: MapProjector? = nil, onRendered: (() -> Void)? = nil) {
        self.style = style; self.dark = dark; self.center = center; self.zoom = zoom; self.offset = offset; self.animates = animates
        self.follow = follow; self.projector = projector; self.onRendered = onRendered
    }

    public func makeNSView(context: Context) -> Host {
        let h = Host()
        h.delegate = context.coordinator
        h.isZoomEnabled = false; h.isScrollEnabled = false; h.isRotateEnabled = false; h.isPitchEnabled = false
        h.showsZoomControls = false; h.showsCompass = false
        projector?.host = h
        return h
    }

    public func updateNSView(_ v: Host, context: Context) {
        if let projector, projector.host !== v { projector.host = v }
        context.coordinator.onRendered = onRendered
        v.apply(style: style, dark: dark)
        if let follow {
            v.setFollow(follow)
            return
        }
        let animated = animates && context.transaction.animation != nil
        v.setCamera(center: center, zoom: zoom, offset: offset, animated: animated)
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor public final class Coordinator: NSObject, MKMapViewDelegate {
        private var pending: Task<Void, Never>?
        var onRendered: (() -> Void)?
        /// A failure report is often transient (tiles retry), so it only counts when no render completes within 8 s.
        public func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: any Error) {
            pending?.cancel()
            pending = Task { @MainActor in
                try? await Task.sleep(for: .seconds(8))
                if !Task.isCancelled { MapHealth.shared.tiles(failed: true) }
            }
        }
        public func mapViewDidFinishLoadingMap(_ mapView: MKMapView) { (mapView as? Host)?.reassertFollow() }
        public func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) {
            (mapView as? Host)?.reassertFollow()
            guard fullyRendered else { return }
            onRendered?()
            pending?.cancel()
            MapHealth.shared.tiles(failed: false)
        }
    }

    public final class Host: MKMapView {
        private var cam: (Coordinate, Double, CGSize, Bool)?
        private var applied: String?
        private var lastRect: MKMapRect?

        func apply(style: MapStyle, dark: Bool) {
            let key = "\(style)-\(dark)"
            guard key != applied else { return }
            applied = key
            appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            switch style {
            case .satellite:
                preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .realistic)
            case .terra, .mono:
                let c = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
                c.pointOfInterestFilter = .excludingAll
                preferredConfiguration = c
            case .standard:
                let c = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .default)
                c.pointOfInterestFilter = .excludingAll
                preferredConfiguration = c
            }
        }

        /// Camera distance per map-rect height, measured once from MapKit itself (it depends on MapKit's field of view).
        private var distanceRatio: Double?
        private var lastFollowKey: [Double] = []

        /// Rotating, deep-zoom camera: an `MKMapCamera` whose distance is bound to the plane scale (the ratio of distance to
        /// visible rect height is measured once from a visible-rect fit, so overlays stay aligned with the map).
        private var pendingFollow: FollowCamera?
        private var reasserts = 0
        private var requestedKey: [Double] = []

        /// MapKit drops a heading that is set before the map has loaded; set it again once it has (a few tries at most).
        func reassertFollow() {
            guard let c = pendingFollow, reasserts < 6, abs(FollowCamera.signedDelta(from: camera.heading, to: c.bearing)) > 0.5 else { return }
            reasserts += 1
            lastFollowKey = []
            setFollow(c)
        }
        func setFollow(_ c: FollowCamera) {
            pendingFollow = c
            if !isRotateEnabled { isRotateEnabled = true }   // programmatic headings need it; gestures never reach this view (the screen overlays catch them)
            guard bounds.width > 1, bounds.height > 1 else { return }
            cameraZoomRange = CameraZoomRange(minCenterCoordinateDistance: 5, maxCenterCoordinateDistance: 6e7)
            let s = (268_435_456.0 / (2 * .pi)) / (c.scale * EuropeProjection.k)          // map points per screen point
            let cc = c.viewCenter
            let coord = CLLocationCoordinate2D(latitude: cc.latitude, longitude: cc.longitude)
            let mp = MKMapPoint(coord)
            let key = [mp.x, mp.y, s, c.bearing, bounds.width, bounds.height, c.pitch]
            if key == lastFollowKey { return }
            // Every camera change makes MapKit re-request tiles (grey squares while they load, worst at street zoom). Moves under
            // half a point, a 0.2 % zoom or 0.05 degrees of heading are not worth that: keep the last image until something
            // visible changes. The overlays are drawn from the exact camera, so they differ from the map by at most that much.
            if lastFollowKey.count == key.count, key[4] == lastFollowKey[4], key[5] == lastFollowKey[5],
               abs(key[0] - lastFollowKey[0]) < 0.5 * s, abs(key[1] - lastFollowKey[1]) < 0.5 * s,
               abs(key[2] / lastFollowKey[2] - 1) < 0.002, abs(FollowCamera.signedDelta(from: lastFollowKey[3], to: key[3])) < 0.05,
               abs(key[6] - lastFollowKey[6]) < 0.05 { return }
            if key != requestedKey { reasserts = 0; requestedKey = key }
            lastFollowKey = key
            let w = bounds.width * s, h = bounds.height * s
            let m = MKMetersPerMapPointAtLatitude(cc.latitude)
            if distanceRatio == nil {
                setVisibleMapRect(MKMapRect(x: mp.x - w / 2, y: mp.y - h / 2, width: w, height: h), edgePadding: NSEdgeInsetsZero, animated: false)
                if visibleMapRect.height > 0, camera.centerCoordinateDistance > 0 {
                    distanceRatio = camera.centerCoordinateDistance / (visibleMapRect.height * m)
                }
            }
            if let ratio = distanceRatio {
                if c.pitch > 0, !isPitchEnabled { isPitchEnabled = true }   // programmatic only, like the heading
                camera = MKMapCamera(lookingAtCenter: coord, fromDistance: ratio * h * m, pitch: c.pitch, heading: c.bearing)
            }
        }

        func setCamera(center: Coordinate, zoom: Double, offset: CGSize, animated: Bool) {
            cam = (center, zoom, offset, animated)
            refit()
        }

        public override func layout() { super.layout(); if let c = pendingFollow { setFollow(c) } else { refit() } }

        private func refit() {
            guard let (c, z, off, animated) = cam, bounds.width > 1, bounds.height > 1 else { return }
            // map points per screen point at this plane scale (Mercator: 2^28 points span 2 pi radians)
            let s = (268_435_456.0 / (2 * .pi)) / (z * EuropeProjection.k)
            let mp = MKMapPoint(CLLocationCoordinate2D(latitude: c.latitude, longitude: c.longitude))
            let w = bounds.width, h = bounds.height
            let rect = MKMapRect(x: mp.x - (w / 2 + off.width) * s, y: mp.y - (h / 2 + off.height) * s, width: w * s, height: h * s)
            if let l = lastRect, MKMapRectEqualToRect(l, rect) { return }
            lastRect = rect
            setVisibleMapRect(rect, edgePadding: NSEdgeInsetsZero, animated: animated)
        }
    }
}


// MARK: - Projector

/// Asks the Apple map where things are on screen. The flat follow camera is plain arithmetic (`FollowCamera.screen`), a tilted
/// one is a perspective only MapKit knows exactly (it also limits the tilt by altitude), so overlays of a tilted camera are
/// placed with the map's own conversion. `apply` moves the map camera at once, so the answers belong to the frame being built.
@MainActor
public final class MapProjector {
    public weak var host: AppleMapView.Host?
    public init() {}

    /// Moves the map to `camera` now. `false` when there is no Apple map (illustrated engine, map not loaded): use the flat maths.
    @discardableResult
    public func apply(_ camera: FollowCamera) -> Bool {
        guard let host, host.bounds.width > 1 else { return false }
        host.setFollow(camera)
        return true
    }

    /// The tilt the map really has (MapKit lowers it for high cameras).
    public var pitch: Double { host.map { Double($0.camera.pitch) } ?? 0 }

    public func screen(_ c: Coordinate) -> CGPoint? {
        guard let host else { return nil }
        let p = host.convert(CLLocationCoordinate2D(latitude: c.latitude, longitude: c.longitude), toPointTo: host)
        guard p.x.isFinite, p.y.isFinite else { return nil }
        return host.isFlipped ? p : CGPoint(x: p.x, y: host.bounds.height - p.y)
    }

    public func coordinate(_ p: CGPoint) -> Coordinate? {
        guard let host else { return nil }
        let q = host.isFlipped ? p : CGPoint(x: p.x, y: host.bounds.height - p.y)
        let c = host.convert(q, toCoordinateFrom: host)
        guard CLLocationCoordinate2DIsValid(c) else { return nil }
        return Coordinate(latitude: c.latitude, longitude: c.longitude)
    }
}
