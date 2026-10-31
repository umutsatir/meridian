import MeridianUI
import SwiftUI

/// Debug routes of the wallet (`--screen <route>`), one per canvas artboard. They use the canvas' sample flights as
/// FIXTURES and show the real shell (sidebar) like the artboards do; the app itself reads `AppModel.walletFlights`.
@MainActor
enum WalletRoutes {
    static func register() {
        func route(_ name: String, _ make: @escaping (inout WalletConfig) -> Void) {
            ScreenRegistry.register(name, setup: { model in
                var c = WalletConfig(); c.fixture = true
                make(&c)
                WalletDebug.current = c
                model.section = .wallet
            }) { AppShell(persona: ("Elif Kaya", 12022)) }
        }
        route("wallet-scenario") { _ in }
        route("wallet-class") { $0.colorBy = .class; $0.sel = 2 }
        route("wallet-continent") { $0.colorBy = .continent; $0.hoverIdx = 6 }
        route("wallet-month") { $0.colorBy = .month; $0.filters.scenario = "Study"; $0.filters.year = "2026" }
        route("wallet-empty") { $0.empty = true }
        route("wallet-light") { _ in }
        route("wallet-stack") { $0.stack = true; $0.fan = 0.12 }
        route("wallet-stack-fanned") { $0.stack = true; $0.fan = 0.85 }
        route("ticket-detail") { $0.detailIndex = 0; $0.detailTilt = true }
        route("ticket-detail-back") { $0.detailIndex = 0; $0.detailBack = true }
    }
}
