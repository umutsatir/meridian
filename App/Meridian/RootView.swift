import MeridianCore
import MeridianUI
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        AppShell()
            .background(WindowStyler())
            .ignoresSafeArea()
            .task {
                while !Task.isCancelled {
                    model.tick()
                    try? await Task.sleep(for: .seconds(1))
                }
            }
            .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in
                model.tick()
            }
    }
}

/// Remaining time, visible from every section (PRD §8).
enum Clock {
    static func format(_ seconds: TimeInterval?) -> String? {
        guard let seconds else { return nil }
        let total = Int(seconds.rounded(.up))
        let h = total / 3600, m = total % 3600 / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    static func spoken(_ seconds: TimeInterval?) -> String {
        guard let seconds else { return "no end time" }
        let minutes = Int((seconds / 60).rounded(.up))
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }
}

/// Placeholder for sections whose screens are built by other tasks.
struct ComingSoonView: View {
    let section: AppSection
    @Environment(\.colorScheme) private var scheme
    @Environment(\.shellSidebarInset) private var inset

    var body: some View {
        let palette = MRPalette.resolve(scheme)
        VStack(spacing: MRSpacing.s) {
            Image(systemName: section.symbol).font(.system(size: 40)).foregroundStyle(palette.text3.color)
            Text(section.title).mrText(.title1).foregroundStyle(palette.text1.color)
            Text(section == .together ? "Friends and shared flights arrive in v1.5." : "Your flights will show up here after your first landing.")
                .mrText(.body).foregroundStyle(palette.text2.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.leading, inset)
    }
}
