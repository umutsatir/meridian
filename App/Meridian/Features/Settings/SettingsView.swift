import MeridianCore
import MeridianFocus
import MeridianUI
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case general, flight, focus, sounds, maps, appearance, notifications, shortcuts, account, privacy
    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: L("General")
        case .flight: L("Flight")
        case .focus: L("Focus and blocking")
        case .sounds: L("Sounds and announcements")
        case .maps: L("Maps and labels")
        case .appearance: L("Appearance")
        case .notifications: L("Notifications")
        case .shortcuts: L("Shortcuts")
        case .account: L("Account and Pro")
        case .privacy: L("Data and privacy")
        }
    }

    var summary: String {
        switch self {
        case .general: L("How Meridian lives on your Mac. Everything here is reversible.")
        case .flight: L("Defaults for planning, check-in and the rituals around them.")
        case .focus: L("A soft block: Meridian covers distractions, you decide what to do. It never quits an app.")
        case .sounds: L("Layer the cabin, then choose what the crew says.")
        case .maps: L("What the map shows, and what it calls things.")
        case .appearance: L("Theme, app icon and accent.")
        case .notifications: L("Quiet by default. Meridian only speaks when it is useful.")
        case .shortcuts: L("Every action has a key. Click a shortcut to record a new one.")
        case .account: L("Your profile, iCloud sync and your plan.")
        case .privacy: L("Your flights belong to you. Nothing leaves your devices unless you turn it on.")
        }
    }

    var icon: MRIconName {
        switch self {
        case .general: .settings
        case .flight: .plane
        case .focus: .shield
        case .sounds: .sound
        case .maps: .map
        case .appearance: .sun
        case .notifications: .bell
        case .shortcuts: .target
        case .account: .user
        case .privacy: .lock
        }
    }

    /// `P[pane].col`: width of the scrolling content column.
    var columnWidth: CGFloat { self == .focus || self == .sounds ? 940 : 640 }
}

/// The Settings window (S50 family). Used by the `Settings` scene (⌘,) and by the screenshot routes.
struct SettingsView: View {
    @State var pane: SettingsPane
    /// Draws the canvas traffic lights (only for the screenshot harness; the real window has its own).
    var showsChrome = false
    var focusModeOverride: BlockMode?
    @Environment(\.mrPalette) private var p
    @Environment(\.colorScheme) private var scheme
    @State private var paywallOpen = false

    init(pane: SettingsPane = .general, showsChrome: Bool = false, focusModeOverride: BlockMode? = nil) {
        _pane = State(initialValue: pane)
        self.showsChrome = showsChrome
        self.focusModeOverride = focusModeOverride
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            p.bg1.color
            RadialGradient(colors: [Color(red: 106 / 255, green: 183 / 255, blue: 1).opacity(0.10), .clear],
                           center: UnitPoint(x: 0.8, y: 0), startRadius: 0, endRadius: 520)
                .allowsHitTesting(false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            nav
                .frame(width: 268, height: 776)
                .offset(x: 12, y: 12)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Text(L("Settings")).mrText(.eyebrow).foregroundStyle(p.text2.color)
                    MRKbd("⌘ ,")
                }
                Text(pane.title)
                    .font(.mr(.serif, size: 40, weight: 500))
                    .tracking(-0.02 * 40)
                    .foregroundStyle(p.text1.color)
                    .frame(height: 44, alignment: .leading)
                    .padding(.top, 6)
                Text(pane.summary)
                    .font(.mr(.ui, size: 13, weight: 400))
                    .foregroundStyle(p.text2.color)
                    .frame(maxWidth: 640, alignment: .leading)
                    .padding(.top, 4)
            }
            .offset(x: 304, y: 48)

            ScrollView(.vertical, showsIndicators: false) {
                content
                    .frame(width: pane.columnWidth, alignment: .topLeading)
                    .padding(.bottom, 20)
            }
            .frame(width: pane.columnWidth, alignment: .topLeading)
            .padding(.top, 150)
            .padding(.bottom, 20)
            .padding(.leading, 304)

            if pane == .maps { MapsPreview().offset(x: 984, y: 150) }
            if showsChrome { SettingsTrafficLights().offset(x: 20, y: 18) }
            if paywallOpen {
                Rectangle().fill(p.scrim.color).background(.ultraThinMaterial.opacity(0.7))
                    .onTapGesture { paywallOpen = false }
                PaywallView(onClose: { paywallOpen = false }).offset(x: 120, y: 50)
            }
        }
        .environment(\.showPaywall, { paywallOpen = true })
        .frame(minWidth: 1000, maxWidth: .infinity, minHeight: 640, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(p.text1.color)
    }

    // MARK: Navigation

    private var nav: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(SettingsPane.allCases.enumerated()), id: \.element) { index, item in
                if index == 6 { Color.clear.frame(height: 10) }
                SettingsNavItem(pane: item, isActive: item == pane) { pane = item }
            }
            Spacer(minLength: 0)
            Text("Meridian \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                .font(.mr(.mono, size: 11, weight: 400))
                .foregroundStyle(p.text3.color)
                .padding(.horizontal, 10).padding(.bottom, 6)
        }
        .padding(.top, 56).padding(.horizontal, 10).padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .mrGlass(cornerRadius: MRRadius.sidebar, elevation: .e3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L("Settings sections"))
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        switch pane {
        case .general: GeneralPane()
        case .flight: FlightPane()
        case .focus: FocusPane(modeOverride: focusModeOverride)
        case .sounds: SoundsPane()
        case .maps: MapsPane()
        case .appearance: AppearancePane()
        case .notifications: NotificationsPane()
        case .shortcuts: ShortcutsPane()
        case .account: AccountPane()
        case .privacy: PrivacyPane()
        }
    }
}

private struct SettingsNavItem: View {
    let pane: SettingsPane
    let isActive: Bool
    let action: () -> Void
    @Environment(\.mrPalette) private var p
    @Environment(\.colorScheme) private var scheme
    @State private var hovered = false
    @FocusState private var focused: Bool

    var body: some View {
        let dark = scheme == .dark
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        Button(action: action) {
            HStack(spacing: 10) {
                MRIcon(pane.icon, size: 18)
                Text(pane.title).font(.mr(.ui, size: 14, weight: 500)).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                if pane == .account {
                    Spacer(minLength: 0)
                    Text("Pro").font(.mr(.ui, size: 10, weight: 600)).tracking(10 * 0.04).textCase(.uppercase)
                        .foregroundStyle(p.text2.color)
                        .padding(.horizontal, 7).frame(height: 18)
                        .background(p.fill2.color, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                } else {
                    Spacer(minLength: 0)
                }
            }
            .foregroundStyle(isActive || hovered ? p.text1.color : p.text2.color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background {
                if isActive {
                    shape.fill(LinearGradient(
                        colors: dark
                            ? [Color(red: 106 / 255, green: 183 / 255, blue: 1).opacity(0.24), Color(red: 139 / 255, green: 243 / 255, blue: 216 / 255).opacity(0.10)]
                            : [Color(red: 30 / 255, green: 107 / 255, blue: 1).opacity(0.14), Color(red: 24 / 255, green: 199 / 255, blue: 160 / 255).opacity(0.08)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(shape.strokeBorder((dark ? Color(red: 106 / 255, green: 183 / 255, blue: 1) : Color(red: 30 / 255, green: 107 / 255, blue: 1)).opacity(dark ? 0.34 : 0.3), lineWidth: 1))
                        .shadow(color: (dark ? Color(red: 106 / 255, green: 183 / 255, blue: 1) : Color(red: 30 / 255, green: 107 / 255, blue: 1)).opacity(dark ? 0.20 : 0.12), radius: dark ? 13 : 11)
                } else if hovered {
                    shape.fill(p.fill1.color)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .focused($focused)
        .mrFocusRing(focused, cornerRadius: 12, color: p.accent1.color)
        .onHover { hv in withAnimation(MRMotion.hover) { hovered = hv } }
        .help(pane.title)
        .accessibilityLabel(pane.title)
        .accessibilityAddTraits(isActive ? [.isSelected, .isButton] : .isButton)
    }
}
