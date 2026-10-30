import AppKit
import MeridianUI
import SwiftUI

/// Debug routes of the system surfaces (`--screen <route>`), drawn at the artboard size.
@MainActor
enum SystemRoutes {
    static func register() {
        let states: [(String, SystemFlightKind, Double, Bool)] = [
            ("popover-idle", .idle, 0.55, false), ("popover-boarding", .boarding, 0.55, false),
            ("popover-flight", .flight, 0.55, false), ("popover-last", .last, 0.98, false),
            ("popover-landed", .landed, 1, false), ("popover-paused", .flight, 0.5, true),
        ]
        for (name, kind, p, paused) in states {
            ScreenRegistry.register(name) { PopoverRoute(info: .preview(kind, p: p, paused: paused)) }
        }
        ScreenRegistry.register("mini-map") { MiniMapView(info: .preview(.flight), size: MiniMapSize.m.dimensions) }
        ScreenRegistry.register("mini-map-hover") {
            MiniMapView(info: .preview(.flight), size: MiniMapSize.m.dimensions, pinnedHover: true)
        }
        ScreenRegistry.register("mini-map-s") { MiniMapView(info: .preview(.flight), size: MiniMapSize.s.dimensions) }
        ScreenRegistry.register("mini-map-l") { MiniMapView(info: .preview(.flight), size: MiniMapSize.l.dimensions) }
        ScreenRegistry.register("seat-tv") { SeatTVRoute(mode: .map) }
        ScreenRegistry.register("seat-tv-window") { SeatTVRoute(mode: .window) }
        ScreenRegistry.register("widget-live-small") { WidgetRoute(kind: .liveSmall) }
        ScreenRegistry.register("widget-live-medium") { WidgetRoute(kind: .liveMedium) }
        ScreenRegistry.register("widget-next-card") { WidgetRoute(kind: .nextCard) }
        ScreenRegistry.register("widget-longest") { WidgetRoute(kind: .longest) }
        ScreenRegistry.register("widget-week") { WidgetRoute(kind: .week) }
        ScreenRegistry.register("appicon") { AppIconRoute(variant: .standard) }
        ScreenRegistry.register("appicon-dark") { AppIconRoute(variant: .dark) }
        ScreenRegistry.register("appicon-tinted") { AppIconRoute(variant: .tinted) }
        ScreenRegistry.register("appicon-clear") { AppIconRoute(variant: .clear) }
        ScreenRegistry.register("appicon-export") { IconExportRoute() }
        ScreenRegistry.register("dock-tile") {
            DockTileView(progress: 0.55, pill: "18:54").frame(width: 128, height: 128).background(Color.gray.opacity(0.3))
        }
    }
}

private struct PopoverRoute: View {
    var info: SystemFlightInfo
    @State private var options = MenuPopoverOptions()
    var body: some View {
        MenuPopoverView(info: info, options: $options, arrowLeft: 240).frame(width: 340, alignment: .topLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct SeatTVRoute: View {
    @State var mode: SeatTVMode
    var body: some View { SeatTVView(info: .preview(.flight), mode: $mode) }
}

private struct WidgetRoute: View {
    enum Kind { case liveSmall, liveMedium, nextCard, longest, week }
    var kind: Kind
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let theme = WidgetTheme.resolve(scheme)
        let s = WidgetSnapshot.preview
        Group {
            switch kind {
            case .liveSmall: WidgetLiveSmall(live: s.live!, theme: theme)
            case .liveMedium: WidgetLiveMedium(live: s.live!, theme: theme)
            case .nextCard: WidgetNextCardSmall(snapshot: s, theme: theme)
            case .longest: WidgetLongestMedium(snapshot: s, theme: theme)
            case .week: WidgetWeekLarge(snapshot: s, theme: theme)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct AppIconRoute: View {
    var variant: AppIconVariant
    var body: some View { AppIconArt(variant: variant, size: 256) }
}

/// Writes the AppIcon PNGs (macOS grid) into the sandbox tmp directory and quits.
private struct IconExportRoute: View {
    var body: some View {
        AppIconArt(variant: .standard, size: 256)
            .task {
                let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("icons", isDirectory: true)
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                for variant in AppIconVariant.allCases {
                    for px in [16, 32, 64, 128, 256, 512, 1024] {
                        let r = ImageRenderer(content: AppIconArt(variant: variant, size: CGFloat(px), inset: 824.0 / 1024.0))
                        r.scale = 1
                        guard let img = r.cgImage else { continue }
                        let rep = NSBitmapImageRep(cgImage: img)
                        try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("\(variant.rawValue)-\(px).png"))
                    }
                }
                FileHandle.standardError.write(Data("icons: \(dir.path)\n".utf8))
            }
    }
}
