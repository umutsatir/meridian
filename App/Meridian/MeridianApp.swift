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
                    .task {
                        SettingsEffects.applyAll()
                        FocusCoordinator.shared.run(model: model)
                        await ProModel.shared.start()
                    }
                    .frame(minWidth: 960, minHeight: 640)
            }
        }
        .defaultSize(width: 1280, height: 800)
        .windowStyle(.hiddenTitleBar)
        .commands {
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
