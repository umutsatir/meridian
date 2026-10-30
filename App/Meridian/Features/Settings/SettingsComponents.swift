import MeridianUI
import SwiftUI

// MARK: - Localization

/// Localized string from the `MRSettings` string catalog (EN + TR). The key is the English text.
/// `Scripts/gen-strings.py` scans the sources for `L("…")` and rebuilds the catalog.
func L(_ key: String) -> String {
    String(localized: String.LocalizationValue(key), table: "MRSettings")
}

func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: L(key), arguments: args)
}

// MARK: - Layout pieces (Settings.dc.html: .st-cap .st-card .st-row .st-lbl .st-sub)

struct SettingsCap: View {
    let text: String
    @Environment(\.mrPalette) private var p
    var body: some View {
        Text(text)
            .mrText(.eyebrow)
            .foregroundStyle(p.text2.color)
            .padding(.horizontal, 6)
            .padding(.bottom, 8)
    }
}

@resultBuilder
enum SettingsRowsBuilder {
    static func buildExpression<V: View>(_ v: V) -> [AnyView] { [AnyView(v)] }
    static func buildBlock(_ parts: [AnyView]...) -> [AnyView] { parts.flatMap { $0 } }
    static func buildOptional(_ part: [AnyView]?) -> [AnyView] { part ?? [] }
    static func buildEither(first: [AnyView]) -> [AnyView] { first }
    static func buildEither(second: [AnyView]) -> [AnyView] { second }
    static func buildArray(_ parts: [[AnyView]]) -> [AnyView] { parts.flatMap { $0 } }
}

/// `.glass.e1.st-card`: rows separated by a hairline.
struct SettingsCard: View {
    let rows: [AnyView]
    @Environment(\.mrPalette) private var p
    init(@SettingsRowsBuilder _ rows: () -> [AnyView]) { self.rows = rows() }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { p.strokeHair.color.frame(height: 1) }
                row
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: MRRadius.card, style: .continuous))
        .mrGlass(cornerRadius: MRRadius.card, elevation: .e1)
    }
}

struct SettingsGroup<Content: View>: View {
    let cap: String
    let content: Content
    init(_ cap: String, @ViewBuilder content: () -> Content) { self.cap = cap; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCap(text: cap)
            content
        }
        .padding(.bottom, 22)
    }
}

/// `.st-row`: label + optional sub on the left, control on the right. min-height 54, padding 9/18, gap 16.
struct SettingsRow<Trailing: View>: View {
    let title: String
    let sub: String
    let trailing: Trailing
    @Environment(\.mrPalette) private var p

    init(_ title: String, sub: String = "", @ViewBuilder trailing: () -> Trailing) {
        self.title = title; self.sub = sub; self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.mr(.ui, size: 14, weight: 500)).foregroundStyle(p.text1.color)
                if !sub.isEmpty {
                    Text(sub).font(.mr(.ui, size: 12, weight: 400)).foregroundStyle(p.text2.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.horizontal, 18).padding(.vertical, 9)
        .frame(minHeight: 54)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Preference-backed controls

struct PrefToggleRow: View {
    let key: SettingKey<Bool>
    let title: String
    let sub: String
    var onChange: ((Bool) -> Void)?
    @AppStorage private var value: Bool

    init(_ key: SettingKey<Bool>, _ title: String, _ sub: String = "", onChange: ((Bool) -> Void)? = nil) {
        self.key = key; self.title = title; self.sub = sub; self.onChange = onChange
        _value = AppStorage(wrappedValue: key.defaultValue, key.name)
    }

    var body: some View {
        SettingsRow(title, sub: sub) {
            MRSwitch(title, isOn: $value)
        }
        .onChange(of: value) { _, new in onChange?(new) }
    }
}

struct PrefSegmentedRow: View {
    let title: String
    let sub: String
    let options: [String]
    @AppStorage private var value: Int

    init(_ key: SettingKey<Int>, _ title: String, _ sub: String = "", options: [String]) {
        self.title = title; self.sub = sub; self.options = options
        _value = AppStorage(wrappedValue: key.defaultValue, key.name)
    }

    var body: some View {
        SettingsRow(title, sub: sub) {
            MRSegmented(selection: $value, options: options.enumerated().map { .init($0.offset, $0.element) })
                .accessibilityLabel(title)
        }
    }
}

/// `.btn-secondary.btn-sm` with a chevron that opens a menu.
struct SelectMenu<Value: Hashable>: View {
    let title: String
    let options: [(value: Value, label: String)]
    @Binding var selection: Value
    @Environment(\.mrPalette) private var p

    var body: some View {
        let current = options.first { $0.value == selection }?.label ?? ""
        Menu {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                Button(option.label) { selection = option.value }
            }
        } label: {
            HStack(spacing: 8) {
                Text(current).font(.mr(.ui, size: 13, weight: 600)).foregroundStyle(p.text1.color)
                MRIcon(.chevD, size: 12).foregroundStyle(p.text2.color)
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(p.fill2.color, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(p.strokeHair.color, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("\(title): \(current)")
    }
}

struct PrefSelectRow: View {
    let title: String
    let sub: String
    let options: [(value: String, label: String)]
    @AppStorage private var value: String

    init(_ key: SettingKey<String>, _ title: String, _ sub: String = "", options: [(value: String, label: String)]) {
        self.title = title; self.sub = sub; self.options = options
        _value = AppStorage(wrappedValue: key.defaultValue, key.name)
    }

    var body: some View {
        SettingsRow(title, sub: sub) {
            SelectMenu(title: title, options: options, selection: $value)
        }
    }
}

struct SettingsButtonRow: View {
    let title: String
    let sub: String
    let button: String
    var kind: MRButtonStyle.Kind = .secondary
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        SettingsRow(title, sub: sub) {
            Button(button, action: action)
                .buttonStyle(MRButtonStyle(kind, size: .sm))
                .disabled(!isEnabled)
        }
    }
}

/// Static value on the right (`.mono.c2` 13).
struct SettingsValueRow: View {
    let title: String
    let sub: String
    let value: String
    @Environment(\.mrPalette) private var p
    var body: some View {
        SettingsRow(title, sub: sub) {
            Text(value).font(.mr(.mono, size: 13, weight: 500)).foregroundStyle(p.text2.color)
        }
    }
}

/// Icon + text chrome used in the nav of the settings window.
struct SettingsTrafficLights: View {
    var body: some View {
        HStack(spacing: 8) {
            ForEach([Color(red: 1, green: 0.373, blue: 0.341), Color(red: 0.996, green: 0.737, blue: 0.18), Color(red: 0.157, green: 0.784, blue: 0.251)], id: \.self) { c in
                Circle().fill(c).frame(width: 12, height: 12)
                    .overlay(Circle().strokeBorder(.black.opacity(0.25), lineWidth: 0.5))
            }
        }
    }
}

/// The canvas `.toggle` (44 x 26) without a visible label.
struct MRSwitch: View {
    let label: String
    @Binding var isOn: Bool
    init(_ label: String, isOn: Binding<Bool>) { self.label = label; _isOn = isOn }
    var body: some View {
        Toggle(isOn: $isOn) { EmptyView() }
            .toggleStyle(MRToggleStyle())
            .fixedSize()
            .accessibilityLabel(label)
    }
}
