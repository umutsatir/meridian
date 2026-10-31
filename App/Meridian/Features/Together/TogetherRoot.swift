import MeridianUI
import SwiftUI

/// The Together section (PRD §9.8, S40...S45). Replaces the `ComingSoonView` placeholder in `AppShell`
/// when `TogetherAvailability.isEnabled`.
struct TogetherRoot: View {
    @Environment(AppModel.self) private var app
    @Environment(\.shellSidebarInset) private var inset
    @State private var model = TogetherModel()

    var body: some View {
        GeometryReader { geo in
            let lay = TGLayout(left: inset + 16, width: geo.size.width)
            ZStack(alignment: .topLeading) {
                switch model.screen {
                case .friends: TGFriendsScreen(model: model, lay: lay)
                case .create: TGCreateScreen(model: model, lay: lay)
                case .lobby: TGLobbyScreen(model: model, lay: lay)
                case .inflight: TGInFlightScreen(model: model)
                case .landing: TGLandingScreen(model: model, lay: lay)
                case .board: TGBoardScreen(model: model, lay: lay)
                }
                TGSafetyOverlay(model: model)
                TGPreviewBadge().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(10)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .onAppear { app.sidebarHidden = model.screen == .inflight }
        .onChange(of: model.screen) { _, s in app.sidebarHidden = s == .inflight }
        .onDisappear { app.sidebarHidden = false }
        .animation(MRMotion.ease(MRMotion.d3), value: model.screen)
    }
}

// MARK: - Block / report / age gate (TOG-8; not in the canvas)

struct TGSafetyOverlay: View {
    @Bindable var model: TogetherModel
    @Environment(\.mrPalette) private var p
    @State private var birthYear = ""
    @State private var reason: TGReportReason = .harassment
    @State private var ageError = false

    var body: some View {
        Group {
            if let f = model.blockTarget {
                dialog(title: "Block \(f.name)?", text: "They will not see your status and you will not see theirs. They are not told you blocked them. You can undo this in Settings.") {
                    HStack(spacing: 12) {
                        Spacer(minLength: 0)
                        Button("Cancel") { model.blockTarget = nil }.buttonStyle(MRButtonStyle(.secondary))
                        Button("Block") { model.block(f) }.buttonStyle(MRButtonStyle(.danger))
                    }
                }
            } else if let f = model.reportTarget {
                dialog(title: "Report \(f.name)", text: "Reports are reviewed by people. Nothing is shared with \(f.name). Chat does not exist in Meridian, so there is nothing to attach.") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(TGReportReason.allCases, id: \.self) { r in
                            HStack { TGOption(text: r.rawValue, on: reason == r) { reason = r }; Spacer(minLength: 0) }
                        }
                    }
                    HStack(spacing: 12) {
                        Spacer(minLength: 0)
                        Button("Cancel") { model.reportTarget = nil }.buttonStyle(MRButtonStyle(.secondary))
                        Button("Send report") { model.report(f, reason) }.buttonStyle(MRButtonStyle(.primary))
                    }
                }
            } else if model.showsAgeGate {
                dialog(title: "Confirm your age", text: "Flying with others is for people \(TGAgeGate.minimumAge) and older. We ask once and do not store your birthday, only that you confirmed.") {
                    MRField("Year of birth", text: $birthYear)
                    if ageError { Text("You need to be \(TGAgeGate.minimumAge) or older to fly with others.").font(.mr(.ui, size: 13)).foregroundStyle(p.dangerLabel.color) }
                    HStack(spacing: 12) {
                        Spacer(minLength: 0)
                        Button("Not now") { model.showsAgeGate = false }.buttonStyle(MRButtonStyle(.secondary))
                        Button("Confirm") {
                            guard let y = Int(birthYear), model.confirmAge(birthYear: y) else { ageError = true; return }
                            model.create()
                        }.buttonStyle(MRButtonStyle(.primary))
                    }
                }
            }
        }
        .animation(MRMotion.ease(MRMotion.d2), value: model.blockTarget?.id)
    }

    private func dialog<C: View>(title: String, text: String, @ViewBuilder content: () -> C) -> some View {
        ZStack {
            p.scrim.color.ignoresSafeArea().onTapGesture { model.blockTarget = nil; model.reportTarget = nil; model.showsAgeGate = false }
            VStack(alignment: .leading, spacing: 16) {
                Text(title).font(.mr(.ui, size: 17, weight: 600)).foregroundStyle(p.text1.color)
                Text(text).font(.mr(.ui, size: 13)).foregroundStyle(p.text2.color).fixedSize(horizontal: false, vertical: true)
                content()
            }
            .padding(24).frame(width: 420).tgCard(radius: 26, .e3)
            .accessibilityAddTraits(.isModal)
        }
    }
}
