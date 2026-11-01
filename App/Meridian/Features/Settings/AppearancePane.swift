import MeridianUI
import SwiftUI

/// `.st-opt`: selectable tile (theme, app icon, focus mode, plan).
struct SettingsOption<Content: View>: View {
    let isSelected: Bool
    var spacing: CGFloat = 6
    var padding = EdgeInsets(top: 14, leading: 14, bottom: 12, trailing: 14)
    var alignment: HorizontalAlignment = .leading
    let action: () -> Void
    @ViewBuilder let content: Content
    @Environment(\.mrPalette) private var p
    @State private var hovered = false
    @FocusState private var focused: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        Button(action: action) {
            VStack(alignment: alignment, spacing: spacing) { content }
                .padding(padding)
                .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
                .background(isSelected || hovered ? p.fill2.color : p.fill1.color, in: shape)
                .overlay(shape.strokeBorder(isSelected ? p.accent1.color : p.strokeHair.color, lineWidth: isSelected ? 2 : 1))
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .focused($focused)
        .mrFocusRing(focused, cornerRadius: 18, color: p.accent1.color)
        .onHover { hv in withAnimation(MRMotion.hover) { hovered = hv } }
        .animation(MRMotion.ease(MRMotion.d2), value: hovered)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

enum AccentChoice: String, CaseIterable {
    case sky, mint, amber, rose, violet
    var title: String {
        switch self { case .sky: L("Sky"); case .mint: L("Mint"); case .amber: L("Amber"); case .rose: L("Rose"); case .violet: L("Violet") }
    }
    func color(_ p: MRPalette) -> Color {
        switch self {
        case .sky: p.accent1.color
        case .mint: p.accent2.color
        case .amber: p.amber.color
        case .rose: MRScenarioColor.create.color
        case .violet: MRScenarioColor.code.color
        }
    }
}

struct AppearancePane: View {
    @AppStorage(SettingsKeys.theme.name) private var theme = SettingsKeys.theme.defaultValue
    @AppStorage(SettingsKeys.appIcon.name) private var icon = SettingsKeys.appIcon.defaultValue
    @AppStorage(SettingsKeys.accent.name) private var accent = SettingsKeys.accent.defaultValue
    @Environment(\.mrPalette) private var p

    private var themes: [(id: String, title: String, sub: String)] {
        [("system", L("System"), L("Follows macOS, switches at sunset.")),
         ("dark", L("Dark"), L("The default for focused work.")),
         ("light", L("Light — Daybreak"), L("Warm paper, same glass."))]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Theme
            VStack(alignment: .leading, spacing: 0) {
                SettingsCap(text: L("Theme"))
                HStack(spacing: 12) {
                    ForEach(themes, id: \.id) { t in
                        SettingsOption(isSelected: theme == t.id, action: { theme = t.id; SettingsEffects.applyTheme(t.id) }) {
                            ThemeThumb(kind: t.id)
                            HStack(spacing: 6) {
                                Text(t.title).font(.mr(.ui, size: 13, weight: 600))
                                if theme == t.id { MRIcon(.check, size: 12).foregroundStyle(p.accent1.color) }
                            }
                            Text(t.sub).font(.mr(.ui, size: 12, weight: 400)).foregroundStyle(p.text2.color)
                                .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .accessibilityElement(children: .contain).accessibilityLabel(L("Theme"))
            }
            .padding(.bottom, 22)

            // App icon
            VStack(alignment: .leading, spacing: 0) {
                SettingsCap(text: L("App icon"))
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        ForEach([("a", L("Meridian"), L("A globe, a plane trail.")), ("b", L("Stub"), L("A boarding pass with a notch.")), ("c", L("Window"), L("An oval window at dusk."))], id: \.0) { c in
                            SettingsOption(isSelected: icon == c.0, padding: EdgeInsets(top: 14, leading: 8, bottom: 10, trailing: 8), alignment: .center,
                                           action: { icon = c.0; AppIconChoice.apply(c.0) }) {
                                SettingsAppIcon(concept: c.0, size: 84)
                                Text(c.1).font(.mr(.ui, size: 13, weight: 600))
                                Text(c.2).font(.mr(.ui, size: 11, weight: 400)).foregroundStyle(p.text2.color).multilineTextAlignment(.center)
                            }
                        }
                    }
                    HStack(spacing: 10) {
                        MRIcon(.info, size: 14).foregroundStyle(p.text2.color)
                        Text(L("Dark, Tinted and Clear follow the macOS icon style in System Settings. All four are drawn for each concept."))
                            .font(.mr(.ui, size: 13, weight: 400)).foregroundStyle(p.text2.color)
                    }
                }
                .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 14)
                .mrGlass(cornerRadius: MRRadius.card, elevation: .e1)
            }
            .padding(.bottom, 22)

            // Accent
            VStack(alignment: .leading, spacing: 0) {
                SettingsCap(text: L("Accent"))
                HStack(spacing: 16) {
                    HStack(spacing: 16) {
                        ForEach(AccentChoice.allCases, id: \.self) { a in
                            AccentSwatch(choice: a, isSelected: accent == a.rawValue) { accent = a.rawValue }
                        }
                    }
                    Spacer(minLength: 0)
                    Text(L("%@ · used for progress, selection and the plane trail", (AccentChoice(rawValue: accent) ?? .sky).title))
                        .font(.mr(.ui, size: 13, weight: 400)).foregroundStyle(p.text2.color)
                }
                .padding(.horizontal, 18).padding(.vertical, 16)
                .mrGlass(cornerRadius: MRRadius.card, elevation: .e1)
            }
        }
    }
}

private struct ThemeThumb: View {
    let kind: String
    var body: some View {
        let dark = MRPalette.dark.bg1.color, light = MRPalette.light.bg1.color
        let bar: Color = kind == "dark" ? .white.opacity(0.14) : kind == "light" ? Color(red: 20 / 255, green: 22 / 255, blue: 28 / 255).opacity(0.12) : Color(white: 0.5).opacity(0.2)
        ZStack(alignment: .topLeading) {
            if kind == "system" {
                GeometryReader { g in
                    ZStack {
                        LinearGradient(stops: [.init(color: dark, location: 0), .init(color: dark, location: 0.5), .init(color: light, location: 0.5), .init(color: light, location: 1)],
                                       startPoint: UnitPoint(x: 0.13, y: 0.35), endPoint: UnitPoint(x: 0.87, y: 0.65))
                    }.frame(width: g.size.width, height: g.size.height)
                }
            } else {
                (kind == "dark" ? dark : light)
            }
            GeometryReader { g in
                RoundedRectangle(cornerRadius: 7, style: .continuous).fill(bar).frame(width: 34).padding(8)
                RoundedRectangle(cornerRadius: 5, style: .continuous).fill(bar).frame(height: 12).padding(.leading, 52).padding(.trailing, 12).padding(.top, 12)
                RoundedRectangle(cornerRadius: 7, style: .continuous).fill(bar).padding(.leading, 52).padding(.trailing, 12).padding(.top, 32).padding(.bottom, 12)
            }
        }
        .frame(height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color(white: 0.5).opacity(0.3), lineWidth: 1))
    }
}

private struct AccentSwatch: View {
    let choice: AccentChoice
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.mrPalette) private var p
    @State private var hovered = false
    @FocusState private var focused: Bool

    var body: some View {
        Button(action: action) {
            Circle().fill(choice.color(p))
                .overlay(Circle().strokeBorder(.white.opacity(0.28), lineWidth: 1))
                .frame(width: 34, height: 34)
                .overlay { if isSelected { Circle().strokeBorder(p.text1.color, lineWidth: 2).padding(-5) } }
                .scaleEffect(hovered ? 1.08 : 1)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .focused($focused)
        .mrFocusRing(focused, cornerRadius: 17, offset: 3, color: p.accent1.color)
        .onHover { hv in withAnimation(MRMotion.hover) { hovered = hv } }
        .animation(MRMotion.snappy, value: hovered)
        .accessibilityLabel(choice.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Switches the Dock icon to the chosen concept. The concept art lives in the asset catalog
/// when the icon task lands; until then the Dock keeps the default.
enum AppIconChoice {
    @MainActor static func apply(_ concept: String) {
        guard let image = NSImage(named: "AppIcon-\(concept)") else { return }
        NSApp.applicationIconImage = image
    }
}

/// Simplified in-app drawing of the three icon concepts (AppIcon.dc.html is the full art).
struct SettingsAppIcon: View {
    let concept: String
    let size: CGFloat

    var body: some View {
        let s = size
        let shape = RoundedRectangle(cornerRadius: s * 0.2237, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(colors: [Color(red: 0.07, green: 0.11, blue: 0.22), Color(red: 0.02, green: 0.03, blue: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
            switch concept {
            case "a":
                Circle().fill(RadialGradient(colors: [Color(red: 0.12, green: 0.2, blue: 0.4), Color(red: 0.03, green: 0.05, blue: 0.12)], center: .topLeading, startRadius: 0, endRadius: s * 0.5))
                    .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                    .frame(width: s * 0.59, height: s * 0.59).offset(x: -s * 0.05, y: s * 0.06)
                MRIcon(.plane, size: s * 0.28).foregroundStyle(MRPalette.dark.accent2.color).rotationEffect(.degrees(-17)).offset(x: s * 0.2, y: -s * 0.2)
            case "c":
                Capsule().fill(LinearGradient(colors: [Color(red: 0.17, green: 0.16, blue: 0.36), Color(red: 1, green: 0.54, blue: 0.36), Color(red: 1, green: 0.85, blue: 0.63)], startPoint: .top, endPoint: .bottom))
                    .overlay(Capsule().strokeBorder(Color(white: 0.8).opacity(0.7), lineWidth: s * 0.04))
                    .frame(width: s * 0.42, height: s * 0.62)
            default:
                RoundedRectangle(cornerRadius: s * 0.06, style: .continuous).fill(MRPalette.dark.paper.color)
                    .frame(width: s * 0.49, height: s * 0.74)
                    .overlay(alignment: .top) {
                        VStack(spacing: s * 0.04) {
                            Capsule().fill(MRPalette.dark.ink.color).frame(width: s * 0.3, height: s * 0.04)
                            MRIcon(.plane, size: s * 0.2).foregroundStyle(MRPalette.dark.ink.color)
                        }.padding(.top, s * 0.14)
                    }
            }
        }
        .frame(width: s, height: s)
        .clipShape(shape)
        .shadow(color: .black.opacity(0.28), radius: 3, y: 2)
        .accessibilityHidden(true)
    }
}
