import MeridianMaps
import SwiftUI

/// Debug routes of the Explore screens (Map, Stats, Year in flight). They draw the canvas' sample persona
/// (`ExploreData.design`) so the render can be compared with the artboards; the app itself uses real data.
@MainActor
enum ExploreRoutes {
    static func register() {
        let reg = ScreenRegistry.self
        reg.register("world-globe", setup: { $0.section = .map }) {
            frame(rail: true) { WorldMapView(data: .design, live: false) }
        }
        reg.register("world-flat-scenario", setup: { $0.section = .map }) {
            frame(rail: true) { WorldMapView(data: .design, initialMode: .flat, initialBy: .scenario, live: false) }
        }
        reg.register("world-replay", setup: { $0.section = .map }) {
            frame(rail: true) { WorldMapView(data: .design, initialT: 0.46, initialHoverRow: 1, live: false) }
        }
        // zoom states (the canvas has no zoom): globe 2x and 0.5x about the globe centre, flat 3x about the middle of the window
        reg.register("world-globe-zoom2", setup: { $0.section = .map }) {
            frame(rail: true) { WorldMapView(data: .design, live: false, initialZoom: 2) }
        }
        reg.register("world-globe-zoom05", setup: { $0.section = .map }) {
            frame(rail: true) { WorldMapView(data: .design, live: false, initialZoom: 0.5) }
        }
        reg.register("world-globe-zoom6", setup: { $0.section = .map }) {
            frame(rail: true) { WorldMapView(data: .design, live: false, initialZoom: 6) }
        }
        reg.register("world-flat-zoom3", setup: { $0.section = .map }) {
            frame(rail: true) { WorldMapView(data: .design, initialMode: .flat, initialBy: .scenario, live: false, initialZoom: 3) }
        }
        reg.register("world-globe-apple", setup: { $0.section = .map }) {
            frame(rail: true) { WorldMapView(data: .design, live: false, engine: .appleMaps) }
        }
        reg.register("world-globe-apple-zoom3", setup: { $0.section = .map }) {
            frame(rail: true) { WorldMapView(data: .design, live: false, initialZoom: 3, engine: .appleMaps) }
        }
        reg.register("world-flat-apple", setup: { $0.section = .map }) {
            frame(rail: true) { WorldMapView(data: .design, initialMode: .flat, live: false, engine: .appleMaps) }
        }
        reg.register("stats", setup: { $0.section = .stats }) { frame(rail: false) { StatsView(data: .design) } }
        reg.register("stats-hover", setup: { $0.section = .stats }) { frame(rail: false) { StatsView(data: .design, initialHover: 2) } }
        reg.register("stats-light", setup: { $0.section = .stats }) { frame(rail: false) { StatsView(data: .design) } }
        reg.register("year", setup: { $0.section = .stats }) { frame(rail: false) { RecapView(data: .design, onBack: {}, initialFrame: 1) } }
        for i in 0..<8 {
            reg.register("year-frame-\(i)") { RecapFrame(index: i, data: .design).frame(width: 360, height: 640) }
        }
        reg.register("year-frames") { ExFramesSheet() }
        reg.register("stats-empty", setup: { $0.section = .stats }) { frame(rail: false) { StatsView() } }
        reg.register("world-empty", setup: { $0.section = .map }) { frame(rail: true) { WorldMapView(live: false) } }
    }

    private static func frame<C: View>(rail: Bool, @ViewBuilder _ content: () -> C) -> some View {
        ZStack(alignment: .topLeading) {
            content().environment(\.shellSidebarInset, rail ? 72 : 236)
            SidebarView(isRail: rail, profileName: "Elif Kaya", km: 12022).padding(8)
        }.mrWindowChrome()
    }
}
