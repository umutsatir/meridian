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
                ForEach(Array(AppSection.allCases.enumerated()), id: \.element) { offset, section in
                    Button(section.title) { model.section = section }
                        .keyboardShortcut(KeyEquivalent(Character("\(offset + 1)")), modifiers: .command)
                }
            }
            CommandGroup(after: .newItem) {
                Button("Quick Start") { model.quickStart() }
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
