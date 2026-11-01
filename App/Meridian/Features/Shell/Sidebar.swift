import MeridianCore
import MeridianData
import MeridianUI
import SwiftUI

/// The floating glass sidebar (`Sidebar.dc.html`): 220 pt wide (64 pt rail), 8 pt from the window edges.
struct SidebarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    var isRail = false
    /// Profile line; the harness passes the canvas persona.
    var profileName: String = NSFullUserName().isEmpty ? "You" : NSFullUserName()
    /// Km shown under the name; `nil` uses the saved total.
    var km: Double?
    /// "+1" on the Tickets row while the ritual's stub lands in the wallet (Features/Ritual).
    var ticketsBadge: String?
    /// Ring pulse (`sb-ring-pulse`); also on while the landing ticket arrives.
    var ringPulse = false
    @State private var pulse = false

    private struct Item: Identifiable {
        let id: AppSection, title: String, icon: MRIconName, shortcut: String?, sub: Bool
    }

    var body: some View {
        let p = MRPalette.resolve(scheme)
        let width: CGFloat = isRail ? 64 : 220
        let shape = RoundedRectangle(cornerRadius: MRRadius.sidebar, style: .continuous)
        VStack(spacing: 2) {
            if let flight = model.activeFlight {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    MRLiveCapsule(time: Clock.format(flight.remainingSec(at: ctx.date)) ?? "∞", isRail: isRail) { model.section = .fly }
                        .padding(.bottom, 8)
                }
            }
            label("Fly")
            row(.fly, "Plan", .plane, "⌘1")
            label("Wallet")
            row(.wallet, "Tickets", .ticket, "⌘2", badge: ticketsBadge ?? (model.landingFly > 0.96 ? "+1" : nil))
                .background(GeometryReader { g in Color.clear.preference(key: SidebarTicketsFrameKey.self, value: g.frame(in: .named("ritual"))) })
            row(.cards, "Cards", .card, nil, sub: true)
            row(.passport, "Passport", .passport, nil, sub: true)
            label("Explore")
            row(.map, "Map", .globe, "⌘3")
            row(.stats, "Stats", .chart, "⌘4")
            row(.together, "Together", .users, "⌘5")
            Spacer(minLength: 0)
            footer(p)
        }
        .padding(.top, 53).padding(.bottom, 10).padding(.horizontal, isRail ? 7 : 10)
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .mrGlass(cornerRadius: MRRadius.sidebar, elevation: .e3)
        .clipShape(shape)
    }

    @ViewBuilder private func label(_ t: String) -> some View {
        if !isRail {
            Text(t).mrEyebrow().padding(.horizontal, 10).padding(.top, 14).padding(.bottom, 6).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func row(_ section: AppSection, _ title: String, _ icon: MRIconName, _ shortcut: String?, sub: Bool = false, badge: String? = nil) -> some View {
        MRNavItem(title, icon: icon, shortcut: isRail ? nil : shortcut, badge: isRail ? nil : badge, isActive: model.section == section,
                  isSub: sub && !isRail, isRail: isRail) { model.section = section }
            .padding(.leading, sub && !isRail ? 12 : 0)
    }

    private func footer(_ p: MRPalette) -> some View {
        let landed = model.landingPresented ? (model.latestLanding?.creditedKm ?? 0) : 0
        // the landing flight's km are counted as the ticket arrives (canvas: 12022 + km * e)
        let e = model.landingFly * model.landingFly * (3 - 2 * model.landingFly)
        let shownKm = km ?? (model.landingPresented ? model.totalKm - landed * (1 - e) : model.totalKm)
        let pulsing = ringPulse || model.landingFly > 0.9
        let frac = min(1, shownKm / 20000)
        return HStack(spacing: 10) {
            ZStack {
                Circle().stroke(p.fill3.color, lineWidth: 2.5).frame(width: 30, height: 30)
                Circle().trim(from: 0, to: frac)
                    .stroke(LinearGradient(colors: [MRColorToken("#6AB7FF").color, MRColorToken("#8BF3D8").color], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 30, height: 30).rotationEffect(.degrees(-90))
                MRAvatar(String(profileName.prefix(1)), tint: MRScenarioColor.create.color, size: .sm)
            }
            .frame(width: 34, height: 34)
            .background(
                Circle().fill(.clear)
                    .shadow(color: MRColorToken("#6AB7FF").color.opacity(pulsing && pulse ? 0.22 : 0), radius: 0, x: 0, y: 0)
                    .overlay(Circle().stroke(MRColorToken("#6AB7FF").color.opacity(pulsing && pulse ? 0.22 : 0), lineWidth: 7).padding(-7 / 2 - 0.0))
                    .shadow(color: MRColorToken("#8BF3D8").color.opacity(pulsing && pulse ? 0.55 : 0), radius: 9)
            )
            .animation(pulsing ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true) : .default, value: pulse)
            .onChange(of: pulsing) { _, on in pulse = on }
            .onAppear { pulse = pulsing }
            .accessibilityLabel("\(Int(shownKm)) kilometres flown")
            if !isRail {
                VStack(alignment: .leading, spacing: 0) {
                    Text(profileName).font(.mr(.ui, size: 13, weight: 600)).frame(height: 16)
                    Text("\(PlanKit.fmtKm(shownKm)) km").font(.mr(.mono, size: 11, weight: 500)).foregroundStyle(p.text2.color).frame(height: 14)
                }
                Spacer(minLength: 0)
                SettingsLink {
                    MRIcon(.settings, size: 18).foregroundStyle(p.text2.color)
                }
                .buttonStyle(MRRoundButtonStyle(small: true, glass: false)).help("Settings ⌘,")
            }
        }
        .padding(.top, 10).padding(.bottom, 2).padding(.horizontal, isRail ? 0 : 6)
        .frame(maxWidth: .infinity, alignment: isRail ? .center : .leading)
        .overlay(alignment: .top) { MRDivider() }
        .padding(.top, 6)
    }
}

/// Frame of the Tickets row in the `ritual` coordinate space (the stub flies to its icon).
struct SidebarTicketsFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { let n = nextValue(); if n != .zero { value = n } }
}
