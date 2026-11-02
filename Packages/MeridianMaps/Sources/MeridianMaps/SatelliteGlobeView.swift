import MapKit
import MeridianCore
import SwiftUI

/// Real satellite globe (Apple Maps `.imagery(elevation: .realistic)`), seen from far enough to read as a sphere with
/// atmosphere.
///
/// The view is fully static: it never moves by itself (no drift, sway or timer). The camera is whatever `camera` says; the
/// owner of the view changes it from trackpad scrolling, pinch, buttons and keys (`GlobeCamera`). MapKit's own gestures are off
/// so they cannot fight with those.
public struct SatelliteGlobeView<Marker: View>: View {
    public var home: Coordinate
    public var camera: GlobeCamera
    /// Camera distance at zoom 1; the real distance is `distance / camera.zoom`.
    public var distance: Double
    public var hybrid: Bool
    let marker: () -> Marker

    @State private var position: MapCameraPosition

    public init(home: Coordinate, camera: GlobeCamera, distance: Double = 17_000_000, hybrid: Bool = false,
                @ViewBuilder marker: @escaping () -> Marker) {
        self.home = home; self.camera = camera; self.distance = distance; self.hybrid = hybrid; self.marker = marker
        _position = State(initialValue: .camera(Self.mapCamera(camera, distance: distance)))
    }

    /// The camera that frames `home` the way the canvas does: the globe is looked at from `tilt` degrees south of home, so the
    /// home airport sits higher up the view.
    public static func homeCamera(home: Coordinate, tilt: Double) -> GlobeCamera {
        GlobeCamera(lon: home.longitude, lat: home.latitude - tilt)
    }

    static func mapCamera(_ c: GlobeCamera, distance: Double) -> MapCamera {
        MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: c.lat, longitude: c.lon),
                  distance: distance / c.zoom, heading: 0, pitch: 0)
    }

    public var body: some View {
        Map(position: $position, interactionModes: []) {
            Annotation("", coordinate: CLLocationCoordinate2D(latitude: home.latitude, longitude: home.longitude), anchor: .center) {
                marker()
            }
            .annotationTitles(.hidden)
        }
        .mapStyle(hybrid ? .hybrid(elevation: .realistic) : .imagery(elevation: .realistic))
        .mapControlVisibility(.hidden)
        .allowsHitTesting(false)
        .onChange(of: camera) { _, c in
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { position = .camera(Self.mapCamera(c, distance: distance)) }
        }
        .onChange(of: distance) { _, d in position = .camera(Self.mapCamera(camera, distance: d)) }
    }
}
