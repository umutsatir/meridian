import MeridianFocus
import MeridianPro
import SwiftUI

/// Built-in debug routes. Other routes are plain strings registered in `ScreenRegistry.registerAll()`.
enum DebugRoute: String, CaseIterable {
    case plan
    case inflight
}

/// Single registration point for screens that the screenshot harness can draw
/// (`--screen <route>`). The list is explicit on purpose: a task that adds a screen
/// adds ONE line to `registerAll()` below. Nothing is discovered automatically.
@MainActor
enum ScreenRegistry {
    struct Entry {
        let name: String
        /// Runs on the fresh AppModel before the view is shown (e.g. start a flight).
        let setup: (AppModel) -> Void
        let make: () -> AnyView
    }

    private(set) static var entries: [String: Entry] = [:]

    /// Registers a screen. `content` is built inside the harness host, so the view
    /// gets the AppModel from the environment, exactly as in the real app.
    static func register<V: View>(
        _ name: String,
        setup: @escaping (AppModel) -> Void = { _ in },
        @ViewBuilder _ content: @escaping () -> V
    ) {
        entries[name] = Entry(name: name, setup: setup, make: { AnyView(content()) })
    }

    static func entry(for name: String) -> Entry? {
        registerAllOnce()
        return entries[name]
    }

    static var names: [String] {
        registerAllOnce()
        return entries.keys.sorted()
    }

    private static var didRegister = false
    private static func registerAllOnce() {
        guard !didRegister else { return }
        didRegister = true
        registerAll()
    }

    // MARK: Explicit list. Add your screen here.

    private static func registerAll() {
        register(DebugRoute.plan.rawValue) { PlanView() }
        register(DebugRoute.inflight.rawValue, setup: { $0.startFlight() }) { InFlightView() }
        registerOnboarding()
        SystemRoutes.register()
        // register("wallet") { WalletView() }
        registerSettingsRoutes()
    }
}

// MARK: Settings, Focus, Sounds, Pro, States (phase-b/settings)

extension ScreenRegistry {
    static func registerSettingsRoutes() {
        for pane in SettingsPane.allCases where pane != .focus && pane != .sounds {
            register("settings-\(pane.rawValue)") { SettingsView(pane: pane, showsChrome: true) }
        }
        register("focus-strict") { SettingsView(pane: .focus, showsChrome: true, focusModeOverride: .strictOverlay) }
        register("focus-nudge") { SettingsView(pane: .focus, showsChrome: true, focusModeOverride: .nudge) }
        register("focus-off") { SettingsView(pane: .focus, showsChrome: true, focusModeOverride: .off) }
        register("sounds") { SettingsView(pane: .sounds, showsChrome: true) }
        register("paywall-lifetime") { PaywallScreen(plan: .lifetime) }
        register("paywall-annual") { PaywallScreen(plan: .annual) }
        register("paywall-light") { PaywallScreen(plan: .annual) }
        register("states") { StatesSheet() }
    }
}
