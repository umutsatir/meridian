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

    @AppStorage(MapEngine.defaultsKey) private var engineRaw = 0
    @Environment(\.colorScheme) private var scheme

    public init(style: MapStyle = .terra, theme: MapTheme? = nil, center: Coordinate, zoom: Double, offset: CGSize = .zero,
                size: CGSize? = nil, showsLabels: Bool = true, showsGraticule: Bool = true, animatesCamera: Bool = true) {
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
                AppleMapView(style: style, dark: dark, center: center, zoom: zoom, offset: offset, animates: animatesCamera)
                    .grayscale(style == .mono ? 1 : 0)
            } else {
                EuropeMapView(style: style, theme: theme, center: center, zoom: zoom, offset: offset, size: nil,
                              showsLabels: showsLabels, showsGraticule: showsGraticule)
            }
        }
        .frame(width: size?.width, height: size?.height)
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

    public init(style: MapStyle, dark: Bool, center: Coordinate, zoom: Double, offset: CGSize = .zero, animates: Bool = true) {
        self.style = style; self.dark = dark; self.center = center; self.zoom = zoom; self.offset = offset; self.animates = animates
    }

    public func makeNSView(context: Context) -> Host {
        let h = Host()
        h.delegate = context.coordinator
        h.isZoomEnabled = false; h.isScrollEnabled = false; h.isRotateEnabled = false; h.isPitchEnabled = false
        h.showsZoomControls = false; h.showsCompass = false
        return h
    }

    public func updateNSView(_ v: Host, context: Context) {
        v.apply(style: style, dark: dark)
        let animated = animates && context.transaction.animation != nil
        v.setCamera(center: center, zoom: zoom, offset: offset, animated: animated)
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor public final class Coordinator: NSObject, MKMapViewDelegate {
        private var pending: Task<Void, Never>?
        /// A failure report is often transient (tiles retry), so it only counts when no render completes within 8 s.
        public func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: any Error) {
            pending?.cancel()
            pending = Task { @MainActor in
                try? await Task.sleep(for: .seconds(8))
                if !Task.isCancelled { MapHealth.shared.tiles(failed: true) }
            }
        }
        public func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) {
            guard fullyRendered else { return }
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

        func setCamera(center: Coordinate, zoom: Double, offset: CGSize, animated: Bool) {
            cam = (center, zoom, offset, animated)
            refit()
        }

        public override func layout() { super.layout(); refit() }

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
