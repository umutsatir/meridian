import AppKit
import MeridianUI
import Observation
import SwiftUI

/// One bindable action (S50F).
struct ShortcutAction: Identifiable, Hashable {
    enum Scope { case global, app }
    let id: String
    let scope: Scope
    let title: String
    let sub: String
    let defaultKeys: [String]
    /// Fixed rows (⌘1–5, ⌘,) are shown but cannot be recorded.
    var isFixed = false

    static let all: [ShortcutAction] = [
        .init(id: "g.quickStart", scope: .global, title: L("Quick start"), sub: L("From any app."), defaultKeys: ["⌃", "⌥", "⏎"]),
        .init(id: "g.miniMap", scope: .global, title: L("Show mini map"), sub: "", defaultKeys: ["⌥", "⌘", "M"]),
        .init(id: "g.pause", scope: .global, title: L("Pause or resume"), sub: "", defaultKeys: ["⌥", "⌘", "P"]),
        .init(id: "a.quickStart", scope: .app, title: L("Quick start"), sub: "", defaultKeys: ["⌘", "⏎"]),
        .init(id: "a.sections", scope: .app, title: L("Plan, Tickets, Map, Stats, Together"), sub: L("⌘1 to ⌘5"), defaultKeys: ["⌘", "1–5"], isFixed: true),
        .init(id: "a.window", scope: .app, title: L("Toggle window view"), sub: "", defaultKeys: ["⌘", "J"]),
        .init(id: "a.landEarly", scope: .app, title: L("Hold to land early"), sub: L("Hold for 1.2 s."), defaultKeys: ["⌥", "⌘", "L"]),
        .init(id: "a.settings", scope: .app, title: L("Settings"), sub: "", defaultKeys: ["⌘", ","], isFixed: true),
    ]
}

/// Persisted, user-assigned shortcuts. Other features ask `ShortcutStore.keys(for:)`.
@MainActor
@Observable
final class ShortcutStore {
    static let shared = ShortcutStore()
    private(set) var overrides: [String: [String]] = [:]

    private init() {
        if let data = SettingsKeys.shortcutsJSON.current.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) { overrides = decoded }
    }

    func keys(for action: ShortcutAction) -> [String] { overrides[action.id] ?? action.defaultKeys }
    func isCustom(_ action: ShortcutAction) -> Bool { overrides[action.id] != nil }

    /// The action that already uses `keys`, if any (so two actions never share a key).
    func conflict(for candidate: [String], excluding id: String) -> ShortcutAction? {
        ShortcutAction.all.first { $0.id != id && self.keys(for: $0) == candidate }
    }

    func set(_ keys: [String], for action: ShortcutAction) {
        overrides[action.id] = keys == action.defaultKeys ? nil : keys
        save()
    }

    func reset(_ action: ShortcutAction) { overrides[action.id] = nil; save() }

    private func save() {
        if let data = try? JSONEncoder().encode(overrides), let text = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(text, forKey: SettingsKeys.shortcutsJSON.name)
        }
    }

    /// Parses `["⌥","⌘","L"]` into a SwiftUI shortcut for in-app commands.
    static func keyboardShortcut(_ keys: [String]) -> KeyboardShortcut? {
        guard let last = keys.last, last.count == 1 || last == "⏎" else { return nil }
        var mods: EventModifiers = []
        for k in keys.dropLast() {
            switch k { case "⌃": mods.insert(.control); case "⌥": mods.insert(.option); case "⇧": mods.insert(.shift); case "⌘": mods.insert(.command); default: break }
        }
        let key: KeyEquivalent = last == "⏎" ? .return : KeyEquivalent(Character(last.lowercased()))
        return KeyboardShortcut(key, modifiers: mods)
    }
}

/// Turns a key-down event into display tokens (`⌃ ⌥ ⇧ ⌘ key`).
enum ShortcutCapture {
    static func tokens(for event: NSEvent) -> [String]? {
        var out: [String] = []
        let f = event.modifierFlags
        if f.contains(.control) { out.append("⌃") }
        if f.contains(.option) { out.append("⌥") }
        if f.contains(.shift) { out.append("⇧") }
        if f.contains(.command) { out.append("⌘") }
        guard f.contains(.control) || f.contains(.option) || f.contains(.command) else { return nil }
        let key: String
        switch event.keyCode {
        case 36, 76: key = "⏎"
        case 48: key = "⇥"
        case 49: key = "Space"
        case 51: key = "⌫"
        default:
            guard let c = event.charactersIgnoringModifiers?.uppercased(), c.count == 1 else { return nil }
            key = c
        }
        return out + [key]
    }
}

struct ShortcutsPane: View {
    @State private var store = ShortcutStore.shared
    @State private var recording: String?
    @State private var message: String?
    @State private var monitor: Any?
    @Environment(\.mrPalette) private var p

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsGroup(L("Global")) {
                SettingsCard { ForEach(ShortcutAction.all.filter { $0.scope == .global }) { row($0) } }
            }
            SettingsGroup(L("In the app")) {
                SettingsCard { ForEach(ShortcutAction.all.filter { $0.scope == .app }) { row($0) } }
            }
            if let message {
                Text(message).font(.mr(.ui, size: 12, weight: 500)).foregroundStyle(p.warn.color).padding(.leading, 6)
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private func row(_ action: ShortcutAction) -> some View {
        let isRecording = recording == action.id
        let keys = store.keys(for: action)
        return SettingsRow(action.title, sub: action.sub) {
            HStack(spacing: 8) {
                if store.isCustom(action) && !isRecording {
                    Button(L("Reset")) { store.reset(action) }.buttonStyle(MRButtonStyle(.tertiary, size: .sm))
                }
                Button { isRecording ? stopRecording() : startRecording(action) } label: {
                    HStack(spacing: 4) {
                        if isRecording {
                            Text(L("Press keys…")).font(.mr(.ui, size: 12, weight: 500)).foregroundStyle(p.accent1.color).padding(.horizontal, 8)
                        } else {
                            ForEach(Array(keys.enumerated()), id: \.offset) { _, k in keycap(k) }
                        }
                    }
                    .padding(.horizontal, isRecording ? 2 : 0)
                    .frame(minHeight: 24)
                    .overlay {
                        if isRecording { RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(p.accent1.color, lineWidth: 1.5).padding(-3) }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(action.isFixed)
                .accessibilityLabel("\(action.title): \(keys.joined(separator: " "))")
                .accessibilityHint(action.isFixed ? "" : L("Click to record a new shortcut"))
            }
        }
    }

    private func keycap(_ k: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        return Text(k)
            .font(.mr(.ui, size: 12, weight: 500))
            .foregroundStyle(p.text1.rgb.mixed(with: p.text2.rgb, amount: 0.2).swiftUIColor)
            .padding(.horizontal, 5)
            .frame(minWidth: 24, minHeight: 24, maxHeight: 24)
            .background(p.fill1.color, in: shape)
            .overlay(shape.strokeBorder(p.strokeHair.color, lineWidth: 1))
    }

    private func startRecording(_ action: ShortcutAction) {
        stopRecording()
        recording = action.id
        message = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { stopRecording(); return nil }                          // Esc cancels
            if event.keyCode == 51 && event.modifierFlags.intersection([.command, .option, .control]).isEmpty {
                store.reset(action); stopRecording(); return nil                            // plain Delete = default
            }
            guard let tokens = ShortcutCapture.tokens(for: event) else {
                message = L("Use at least one of ⌃ ⌥ ⌘ with a key.")
                return nil
            }
            if let other = store.conflict(for: tokens, excluding: action.id) {
                message = L("%@ is already used by “%@”.", tokens.joined(separator: " "), other.title)
                return nil
            }
            store.set(tokens, for: action)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = nil
    }
}

private extension RGB {
    var swiftUIColor: Color { Color(self) }
}
