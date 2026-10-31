import SwiftUI
import MeridianUI

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
        register("paper-pass") { PaperPassSheet(variant: 1) }
        register("paper-pass2") { PaperPassSheet(variant: 2) }
        register("paper-pass3") { PaperPassSheet(variant: 3) }
        register("paper-pass4") { PaperPassSheet(variant: 4) }
        register("paper-card") { PaperCardSheet(variant: 1) }
        register("paper-card2") { PaperCardSheet(variant: 2) }
        register("paper-card3") { PaperCardSheet(variant: 3) }
        register("paper-stamp") { PaperStampSheet() }
        register("paper-flap") { PaperFlapSheet() }
        register("paper-print") { PaperPrintSheet(times: [900, 1700]) }
        register("paper-tear") { PaperTearSheet(poses: [.init(p: 0.3, grab: .right), .init(p: 0.55, grab: .left)]) }
        // register("wallet") { WalletView() }
    }
}
