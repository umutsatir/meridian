import AppIntents
import MeridianUI
import SwiftUI
import WidgetKit

/// Leaves a "pause" request for the app (read on its next tick, see SystemSurfaces).
struct PauseFlightIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause flight"
    static let isDiscoverable = false

    @MainActor func perform() async throws -> some IntentResult {
        (UserDefaults(suiteName: WidgetSnapshot.groupID) ?? .standard).set(Date(), forKey: WidgetSnapshot.commandKey)
        return .result()
    }
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry { SnapshotEntry(date: .now, snapshot: .preview) }
    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load() ?? .preview))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let snapshot = WidgetSnapshot.load() ?? WidgetSnapshot()
        // Refresh on the hour; the app also reloads after each landing.
        let next = Calendar.current.nextDate(after: .now, matching: DateComponents(minute: 0), matchingPolicy: .nextTime) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [SnapshotEntry(date: .now, snapshot: snapshot)], policy: .after(next)))
    }
}

private struct Themed<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder var content: (WidgetTheme) -> Content
    var body: some View { content(WidgetTheme.resolve(scheme)) }
}

private extension View {
    func widgetBackground(_ builder: @escaping (WidgetTheme) -> LinearGradient) -> some View {
        containerBackground(for: .widget) { Themed { builder($0) } }
    }
}

struct NextCardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextCard", provider: SnapshotProvider()) { entry in
            Themed { WidgetNextCardSmall(snapshot: entry.snapshot, theme: $0, drawsChrome: false) }
                .widgetBackground { $0.background }
        }
        .configurationDisplayName("Next card")
        .description("Progress toward your next membership card.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct LongestRouteWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LongestRoute", provider: SnapshotProvider()) { entry in
            Themed { WidgetLongestMedium(snapshot: entry.snapshot, theme: $0, drawsChrome: false) }
                .widgetBackground { $0.background }
        }
        .configurationDisplayName("Longest route")
        .description("Your longest flight so far.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

struct WeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Week", provider: SnapshotProvider()) { entry in
            Themed { WidgetWeekLarge(snapshot: entry.snapshot, theme: $0, drawsChrome: false) }
                .widgetBackground { $0.background }
        }
        .configurationDisplayName("Week and streak")
        .description("Hours in flight this week and your current streak.")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}

struct LiveFlightWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LiveFlight", provider: SnapshotProvider()) { entry in
            Themed { theme in
                if let live = entry.snapshot.live {
                    LiveBody(live: live, theme: theme)
                } else {
                    WidgetNextCardSmall(snapshot: entry.snapshot, theme: theme, drawsChrome: false)
                }
            }
            .widgetBackground { $0.background }
        }
        .configurationDisplayName("Live flight")
        .description("The countdown of the flight you are on.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

private struct LiveBody: View {
    var live: WidgetSnapshot.Live
    var theme: WidgetTheme
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .systemSmall {
            WidgetLiveSmall(live: live, theme: theme, drawsChrome: false, ticking: true)
        } else {
            WidgetLiveMedium(
                live: live, theme: theme, drawsChrome: false, ticking: true,
                etaText: live.eta.map { "ETA " + $0.formatted(date: .omitted, time: .shortened) } ?? "Paused",
                pauseWrap: { label in AnyView(Button(intent: PauseFlightIntent()) { label }.buttonStyle(.plain)) },
                openWrap: { label in AnyView(Link(destination: URL(string: "meridian://fly")!) { label }) })
        }
    }
}

@main
struct MeridianWidgetBundle: WidgetBundle {
    init() { _ = MRFonts.register() }
    var body: some Widget {
        LiveFlightWidget()
        NextCardWidget()
        LongestRouteWidget()
        WeekWidget()
    }
}
