import SwiftUI

@main
struct MeridianApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            if let launch = DebugLaunch.current {
                DebugHost(launch: launch)   // screenshot harness (App/Meridian/Debug)
            } else {
                RootView()
                    .environment(model)
                    .frame(minWidth: 960, minHeight: 640)
            }
        }
        .defaultSize(width: 1280, height: 800)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandMenu("Go") {
                Button("Plan") { model.section = .fly }.keyboardShortcut("1", modifiers: .command)
                Button("Tickets") { model.section = .wallet }.keyboardShortcut("2", modifiers: .command)
                Button("Map") { model.section = .map }.keyboardShortcut("3", modifiers: .command)
                Button("Stats") { model.section = .stats }.keyboardShortcut("4", modifiers: .command)
                Button("Together") { model.section = .together }.keyboardShortcut("5", modifiers: .command)
                Divider()
                Button("Cards") { model.section = .cards }
                Button("Passport") { model.section = .passport }
                Divider()
                Button("Search Airports") { model.section = .fly; if model.activeFlight == nil { model.planStage = .plan }; model.searchOpen = true }
                    .keyboardShortcut("k", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button("Quick Start") { PlanActions.checkIn(model)(true) }
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
    }
}
