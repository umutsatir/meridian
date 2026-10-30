import MeridianCruise
import MeridianUI
import Observation
import SwiftUI

// MARK: - Localization of ResumeBanner keys (table MRStates)

func LS(_ key: String) -> String { String(localized: String.LocalizationValue(key), table: "MRStates") }

// MARK: - Skeleton (.skel, shimmer 1.4 s, Reduce Motion = static fill)

struct Skeleton: View {
    var radius: CGFloat = 8
    @Environment(\.mrPalette) private var p
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if reduceMotion {
            shape.fill(p.fill2.color)
        } else {
            GeometryReader { g in
                // background-size 200% 100%; position 200% -> -200% over 1.4 s, linear, infinite
                LinearGradient(colors: [p.fill1.color, p.fill3.color, p.fill1.color], startPoint: .leading, endPoint: .trailing)
                    .frame(width: g.size.width * 2)
                    .offset(x: phase ? -g.size.width : 0)
            }
            .clipShape(shape)
            .onAppear { withAnimation(.linear(duration: MRMotion.d6).repeatForever(autoreverses: false)) { phase = true } }
        }
    }
}

// MARK: - Resume banner (S54, bottom section)

/// Renders a `ResumeBanner` from MeridianCruise. Text comes from the `MRStates` string catalog.
struct ResumeBannerView: View {
    let banner: ResumeBanner
    /// Optional mono line, e.g. "Quit 09:14 · back 09:31 · 17 min flown · 25 min left".
    var detail: String?
    var onPrimary: () -> Void = {}
    @Environment(\.mrPalette) private var p

    private var city: String? {
        for a in banner.arguments { if case .text(let t) = a { return t } }
        return nil
    }
    private var minutes: Int? {
        for a in banner.arguments { if case .minutes(let m) = a { return m } }
        return nil
    }

    var title: String {
        if banner.kind == .landedWhileAway {
            if let city { return String(format: LS(banner.titleKey), city) }
            return LS("flight.landedWhileAway.openEnded.title")
        }
        return LS(banner.titleKey)
    }

    var message: String { LS(banner.bodyKey) }

    private var autoDetail: String? {
        if let detail { return detail }
        guard let minutes, banner.kind != .landedWhileAway else { return nil }
        return banner.bodyKey.contains("openEnded") ? String(format: LS("flight.resumed.flown"), minutes) : String(format: LS("flight.resumed.left"), minutes)
    }

    var body: some View {
        HStack(spacing: 16) {
            badge
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.mr(.ui, size: 15, weight: 600)).fixedSize(horizontal: false, vertical: true)
                Text(message).font(.mr(.ui, size: 13, weight: 400)).foregroundStyle(p.text2.color).fixedSize(horizontal: false, vertical: true)
                if let d = autoDetail {
                    Text(d).font(.mr(.mono, size: 11, weight: 500)).foregroundStyle(p.text3.color).padding(.top, 5).fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if banner.kind == .landedWhileAway {
                Button(LS("flight.landedWhileAway.action"), action: onPrimary).buttonStyle(MRButtonStyle(.primary, size: .sm))
            } else {
                Button(LS("flight.resumed.dismiss"), action: onPrimary).buttonStyle(MRButtonStyle(.tertiary, size: .sm))
            }
        }
        .padding(.leading, 18).padding(.trailing, 18).padding(.vertical, 16)
        .mrGlass(cornerRadius: 22, elevation: .e2)
        // Never steals focus; VoiceOver reads it once as a status.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
        .accessibilityAddTraits(.isStaticText)
    }

    @ViewBuilder private var badge: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        switch banner.kind {
        case .afterQuit:
            MRIcon(.plane, size: 20).foregroundStyle(p.accent1.color).frame(width: 44, height: 44)
                .background(shape.fill(LinearGradient(colors: [Color(red: 106 / 255, green: 183 / 255, blue: 1).opacity(0.22), Color(red: 139 / 255, green: 243 / 255, blue: 216 / 255).opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                .overlay(shape.strokeBorder(Color(red: 106 / 255, green: 183 / 255, blue: 1).opacity(0.34), lineWidth: 1))
        case .afterSleep:
            MRIcon(.moon, size: 20).foregroundStyle(p.text2.color).frame(width: 44, height: 44).background(shape.fill(p.fill2.color))
        case .landedWhileAway:
            MRIcon(.check, size: 20).foregroundStyle(p.ok.color).frame(width: 44, height: 44).background(shape.fill(p.fill2.color))
        }
    }
}

/// Floating host that shows `AppModel.resumeBanner` at the top of a screen (auto-dismiss is the model's 8 s timer).
struct ResumeBannerHost: ViewModifier {
    @Environment(AppModel.self) private var model
    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let banner = model.resumeBanner {
                ResumeBannerView(banner: banner, onPrimary: { model.dismissResumeBanner() })
                    .frame(maxWidth: 560).padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .mrAnimation(MRMotion.smooth, value: model.resumeBanner)
    }
}

extension View {
    /// Shows the "Flight resumed" banners over this screen.
    func resumeBanners() -> some View { modifier(ResumeBannerHost()) }
}

// MARK: - Toasts

struct ToastItem: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var message: String?
    var icon: MRIconName = .check
    var kind: Kind = .ok
    enum Kind { case ok, warn, danger }
}

@MainActor
@Observable
final class ToastCenter {
    static let shared = ToastCenter()
    private(set) var items: [ToastItem] = []

    func show(_ item: ToastItem, for seconds: Double = 4) {
        items.append(item)
        let id = item.id
        Task { try? await Task.sleep(for: .seconds(seconds)); items.removeAll { $0.id == id } }
    }
    func dismiss(_ id: UUID) { items.removeAll { $0.id == id } }
}

struct ToastHost: ViewModifier {
    @State private var center = ToastCenter.shared
    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                ForEach(center.items) { item in
                    MRToast(item.title, message: item.message, icon: item.icon, tint: item.kind == .ok ? \.ok : item.kind == .warn ? \.warn : \.danger)
                        .onTapGesture { center.dismiss(item.id) }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .padding(.bottom, 24)
            .mrAnimation(MRMotion.smooth, value: center.items)
        }
    }
}

extension View {
    func toasts() -> some View { modifier(ToastHost()) }
}

// MARK: - State tile (S54: 368 x 292)

struct StateTile<Art: View, Actions: View>: View {
    let id: String
    let title: String
    let message: String
    let label: String
    var role: AccessibilityTraits = []
    @ViewBuilder let art: Art
    @ViewBuilder let actions: Actions
    @Environment(\.mrPalette) private var p

    var body: some View {
        VStack(spacing: 0) {
            art.frame(height: 96).padding(.bottom, 14)
            Text(title).font(.mr(.ui, size: 17, weight: 600)).foregroundStyle(p.text1.color).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Text(message).font(.mr(.ui, size: 13, weight: 400)).foregroundStyle(p.text2.color).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 290).padding(.top, 6)
            Spacer(minLength: 0)
            HStack(spacing: 10) { actions }
        }
        .padding(.horizontal, 28).padding(.top, 26).padding(.bottom, 24)
        .frame(maxWidth: .infinity).frame(height: 292)
        .overlay(alignment: .topLeading) {
            Text(id).font(.mr(.mono, size: 10, weight: 600)).tracking(10 * 0.1).textCase(.uppercase)
                .foregroundStyle(p.text3.color).padding(.leading, 14).padding(.top, 12)
        }
        .mrGlass(cornerRadius: 26, elevation: .e2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(role)
    }
}
