import AppKit
import MapKit
import MeridianCore
import SwiftUI

/// Real satellite globe (Apple Maps `.imagery(elevation: .realistic)`), seen from far enough to read as a sphere with
/// atmosphere. Non-interactive; drifts slowly eastward unless Reduce Motion is on or the window is not visible.
public struct SatelliteGlobeView<Marker: View>: View {
    public var home: Coordinate
    /// Latitude the camera looks at (the globe is framed so `home` sits higher up the view, like the illustrated one).
    public var tilt: Double
    public var distance: Double
    public var drifts: Bool
    public var hybrid: Bool
    let marker: () -> Marker

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lonShift = 0.0
    @State private var visible = true
    @State private var position: MapCameraPosition

    public init(home: Coordinate, tilt: Double = 38, distance: Double = 17_000_000, drifts: Bool = true, hybrid: Bool = false,
                @ViewBuilder marker: @escaping () -> Marker) {
        self.home = home; self.tilt = tilt; self.distance = distance; self.drifts = drifts; self.hybrid = hybrid; self.marker = marker
        _position = State(initialValue: .camera(Self.camera(home: home, tilt: tilt, distance: distance, shift: 0)))
    }

    static func camera(home: Coordinate, tilt: Double, distance: Double, shift: Double) -> MapCamera {
        let lat = max(-70, min(70, home.latitude - tilt))
        return MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: lat, longitude: home.longitude + shift),
                         distance: distance, heading: 0, pitch: 0)
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
        .task(id: drifts && !reduceMotion && visible) {
            guard drifts, !reduceMotion, visible else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                if Task.isCancelled { break }
                lonShift += 1; let sway = 9 * sin(lonShift * 0.07)   // slow sway around the home airport
                withAnimation(.linear(duration: 2)) {
                    position = .camera(Self.camera(home: home, tilt: tilt, distance: distance, shift: sway))
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didChangeOcclusionStateNotification)) { n in
            if let w = n.object as? NSWindow { visible = w.occlusionState.contains(.visible) }
        }
    }
}
