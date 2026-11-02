import SwiftUI

@main
struct MeridianApp: App {
    @State private var model: AppModel

    init() {
        let model = AppModel()
        _model = State(initialValue: model)
        if DebugLaunch.current == nil {
            SystemSurfaces.shared.attach(model: model)
            // `--demo-flight`: start the planned flight at launch (manual check of the system surfaces).
            if CommandLine.arguments.contains("--demo-flight") { model.startFlight() }
        }
    }

    var body: some Scene {
        WindowGroup {
            if let launch = DebugLaunch.current {
                DebugHost(launch: launch)   // screenshot harness (App/Meridian/Debug)
            } else {
                LaunchGate()
                    .environment(model)
                    .modifier(ClearWindowBackground())
                    .task {
                        SettingsEffects.applyAll()
                        FocusCoordinator.shared.run(model: model)
                        await ProModel.shared.start()
                    }
                    .frame(minWidth: 960, minHeight: 640)
            }
        }
        MenuBarExtra {
            MenuPopoverHost(surfaces: SystemSurfaces.shared)
        } label: {
            MenuBarItemLabel(surfaces: SystemSurfaces.shared)
        }
        .menuBarExtraStyle(.window)
        .defaultSize(width: 1280, height: 800)
        .windowStyle(.hiddenTitleBar)
        .commands {
            SystemCommands()
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
        Settings {
            SettingsView()
                .environment(model)
                .frame(width: 1280, height: 800)
        }
    }
}


/// The shell draws its own 26 pt rounded window; the scene's default window background (white in a light system
/// appearance) must not show in the corners and along the edges.
private struct ClearWindowBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.containerBackground(.clear, for: .window)
        } else {
            content
        }
    }
}
