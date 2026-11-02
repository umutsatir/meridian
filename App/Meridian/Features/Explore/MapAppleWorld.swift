import MapKit
import MeridianCore
import MeridianMaps
import MeridianUI
import SwiftUI

/// The World screen drawn by Apple Maps (Settings > Maps > Map engine = Apple Maps): the satellite globe, or a flat world.
/// Zoom is the camera distance (`base / scale`, so 0.6x ... 6x like the illustrated map); the drag pans / turns the globe with
/// MapKit's own gesture, pinch / wheel / buttons / keys come from the screen's `MapZoomModel`. Routes are geodesic polylines and
/// the top airports are annotations with the same label density rule as the illustrated map.
struct ExAppleWorld: View {
    var mode: ExMapMode
    var scale: Double
    var viewportHeight: Double
    var routes: [GlobeRoute]
    var pins: [GlobePin]
    var marks: Double
    var labelBudget: Int
    /// Incremented by the screen when the view is reset (key 0, double-click at max zoom) so the camera returns home.
    var homeNonce: Int

    @State private var position: MapCameraPosition = .automatic
    @State private var center = CLLocationCoordinate2D(latitude: 36, longitude: -8)
    @State private var seeded = false

    private func distance(_ scale: Double) -> Double {
        (mode == .globe ? 2.1e7 : 4.2e7) * (viewportHeight / 800) / scale
    }

    private func camera(_ scale: Double, center: CLLocationCoordinate2D) -> MapCamera {
        MapCamera(centerCoordinate: center, distance: distance(scale), heading: 0, pitch: 0)
    }

    var body: some View {
        Map(position: $position, interactionModes: [.pan]) {
            ForEach(Array(routes.enumerated()), id: \.offset) { _, r in
                MapPolyline(coordinates: [CLLocationCoordinate2D(latitude: r.from.latitude, longitude: r.from.longitude),
                                          CLLocationCoordinate2D(latitude: r.to.latitude, longitude: r.to.longitude)], contourStyle: .geodesic)
                    .stroke(r.color.opacity(r.opacity), style: StrokeStyle(lineWidth: r.width, lineCap: .round))
            }
            ForEach(Array(pins.enumerated()), id: \.offset) { i, p in
                Annotation("", coordinate: CLLocationCoordinate2D(latitude: p.coordinate.latitude, longitude: p.coordinate.longitude), anchor: .center) {
                    VStack(spacing: 2) {
                        Circle().fill(p.color).frame(width: p.radius * 2, height: p.radius * 2)
                            .overlay(Circle().stroke(Color.black.opacity(0.55), lineWidth: 1.5))
                        if i < labelBudget, let code = p.label {
                            Text(code).font(MRFonts.font(.condensed, size: 11, weight: 700)).tracking(0.88).foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.8), radius: 2)
                        }
                    }
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(mode == .globe ? .imagery(elevation: .realistic) : .hybrid(elevation: .flat))
        .mapControlVisibility(.hidden)
        .onMapCameraChange(frequency: .onEnd) { ctx in center = ctx.camera.centerCoordinate }
        .onAppear {
            guard !seeded else { return }
            seeded = true
            // `--pan dx,dy` (screenshots): move the camera the way a two-finger scroll of that many points would
            let a = CommandLine.arguments
            if let i = a.firstIndex(of: "--pan"), i + 1 < a.count {
                let v = a[i + 1].split(separator: ",").compactMap { Double($0) }
                if v.count == 2 {
                    let radius = 6.371e6 / (distance(scale) * 0.536) * viewportHeight
                    let k = GlobeCamera.degreesPerPoint(screenRadius: radius)
                    center = CLLocationCoordinate2D(latitude: GlobeCamera.clampLatitude(center.latitude + v[1] * k),
                                                    longitude: GlobeCamera.wrapLongitude(center.longitude - v[0] * k))
                }
            }
            position = .camera(camera(scale, center: center))
        }
        .onChange(of: scale) { _, s in
            withAnimation(MRMotion.smooth) { position = .camera(camera(s, center: center)) }
        }
        .onChange(of: mode) { _, _ in
            let home = CLLocationCoordinate2D(latitude: 36, longitude: -8)
            center = home
            position = .camera(camera(scale, center: home))
        }
        .onChange(of: homeNonce) { _, _ in
            let home = CLLocationCoordinate2D(latitude: 36, longitude: -8)
            center = home
            withAnimation(MRMotion.smooth) { position = .camera(camera(1, center: home)) }
        }
        .accessibilityLabel(mode == .globe ? "Globe" : "World map")
    }
}
