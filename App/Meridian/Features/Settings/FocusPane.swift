import AppKit
import MeridianFocus
import MeridianUI
import Observation
import UniformTypeIdentifiers
import SwiftUI

/// Everything the Focus pane edits, persisted as JSON under `SettingsKeys.focusSettingsJSON`.
struct FocusPrefs: Codable, Equatable {
    var mode: BlockMode = .strictOverlay
    /// Tile name -> blocked. Unlisted tiles use `FocusTile.defaultOn`.
    var tiles: [String: Bool] = [:]
    var customApps: [String] = []
    var sites: [String] = ["news.example", "video.example"]
}

struct FocusTile: Identifiable {
    let name: String
    let colorHex: String
    let glyph: String        // 52-unit SVG path
    let bundleIDs: Set<String>
    let defaultOn: Bool
    var id: String { name }

    static let all: [FocusTile] = [
        .init(name: "Mail", colorHex: "#7AA2FF", glyph: "M14 18h24v16H14z M14 18l12 10 12-10", bundleIDs: ["com.apple.mail"], defaultOn: false),
        .init(name: "Messages", colorHex: "#7ADDB2", glyph: "M14 18h24v14H26l-8 6v-6h-4z", bundleIDs: ["com.apple.MobileSMS"], defaultOn: false),
        .init(name: "Social", colorHex: "#FF8FB1", glyph: "M26 14a6 6 0 1 1 0 12 6 6 0 0 1 0-12 M14 40c2-8 8-10 12-10s10 2 12 10", bundleIDs: BlockPreset.social.list.apps, defaultOn: true),
        .init(name: "Video", colorHex: "#FF9B7A", glyph: "M20 16l18 10-18 10z", bundleIDs: BlockPreset.video.list.apps, defaultOn: true),
        .init(name: "News", colorHex: "#C7CCDA", glyph: "M14 16h24v22H14z M18 22h16 M18 28h16 M18 33h9", bundleIDs: BlockPreset.news.list.apps, defaultOn: true),
        .init(name: "Games", colorHex: "#B49CFF", glyph: "M14 24h24l2 12H12z M20 28v6 M17 31h6 M32 30h.01 M36 33h.01", bundleIDs: BlockPreset.games.list.apps, defaultOn: true),
        .init(name: "Shopping", colorHex: "#FFB86B", glyph: "M14 20h24l-3 18H17z M20 20c0-8 12-8 12 0", bundleIDs: ["com.amazon.Amazon"], defaultOn: true),
        .init(name: "Chat", colorHex: "#8EE3E8", glyph: "M12 18h28v16H28l-8 6v-6h-8z M19 26h14", bundleIDs: ["com.tinyspeck.slackmacgap", "com.hnc.Discord"], defaultOn: true),
    ]
}

@MainActor
@Observable
final class FocusStore {
    static let shared = FocusStore()
    var prefs: FocusPrefs { didSet { save() } }

    private init() {
        let text = SettingsKeys.focusSettingsJSON.current
        prefs = text.data(using: .utf8).flatMap { try? JSONDecoder().decode(FocusPrefs.self, from: $0) } ?? FocusPrefs()
    }

    func isOn(_ tile: FocusTile) -> Bool { prefs.tiles[tile.name] ?? tile.defaultOn }
    func set(_ tile: FocusTile, _ on: Bool) { prefs.tiles[tile.name] = on }

    /// The list `FocusEnforcer` uses (tiles + added apps + sites).
    var blockList: BlockList {
        var apps = Set(prefs.customApps)
        for t in FocusTile.all where isOn(t) { apps.formUnion(t.bundleIDs) }
        return BlockList(apps: apps, domains: Set(prefs.sites))
    }

    var settings: FocusSettings { FocusSettings(mode: prefs.mode, list: blockList) }
    var blockedCount: Int { FocusTile.all.filter(isOn).count + prefs.customApps.count }

    private func save() {
        if let data = try? JSONEncoder().encode(prefs), let text = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(text, forKey: SettingsKeys.focusSettingsJSON.name)
        }
    }
}

struct FocusPane: View {
    var modeOverride: BlockMode?
    @State private var store = FocusStore.shared
    @State private var mode: BlockMode
    @State private var siteDraft = ""
    @AppStorage(SettingsKeys.focusAllowEditor.name) private var allowEditor = SettingsKeys.focusAllowEditor.defaultValue
    @AppStorage(SettingsKeys.focusLiftOnBreak.name) private var liftOnBreak = SettingsKeys.focusLiftOnBreak.defaultValue
    @Environment(\.mrPalette) private var p

    init(modeOverride: BlockMode? = nil) {
        self.modeOverride = modeOverride
        _mode = State(initialValue: modeOverride ?? FocusStore.shared.prefs.mode)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            VStack(alignment: .leading, spacing: 0) {
                SettingsCap(text: L("When a blocked app comes to the front"))
                HStack(spacing: 10) {
                    modeOption(.off, L("Off"), L("Meridian stays out of the way."), .eye)
                    modeOption(.nudge, L("Nudge"), L("A small banner when a blocked app comes forward."), .bell)
                    modeOption(.strictOverlay, L("Strict overlay"), L("A full overlay until you return, take a break or land early."), .shield)
                }
                .padding(.bottom, 22)
                .accessibilityElement(children: .contain).accessibilityLabel(L("Blocking mode"))

                HStack(alignment: .firstTextBaseline) {
                    SettingsCap(text: L("Apps and sites"))
                    Spacer()
                    Text(L("%lld blocked", store.blockedCount)).font(.mr(.mono, size: 12, weight: 500)).foregroundStyle(p.text2.color).padding(.bottom, 8)
                }
                appsCard.opacity(mode == .off ? 0.5 : 1)

                SettingsCard {
                    SettingsRow(L("Allow your editor and terminal"), sub: L("Three apps are always allowed during a flight.")) {
                        MRSwitch(L("Allow your editor and terminal"), isOn: $allowEditor)
                    }
                    SettingsRow(L("Lift the block during a break"), sub: L("Take a break pauses the flight and the block together.")) {
                        MRSwitch(L("Lift the block during a break"), isOn: $liftOnBreak)
                    }
                }
                .padding(.top, 18)
            }
            .frame(width: 520)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    SettingsCap(text: L("Preview"))
                    Spacer()
                    Text(mode == .off ? L("Off") : mode == .nudge ? L("Nudge") : L("Strict overlay"))
                        .font(.mr(.mono, size: 11, weight: 500)).foregroundStyle(p.text3.color).padding(.bottom, 8)
                }
                FocusPreview(mode: mode)
            }
            .frame(width: 392)
        }
        .frame(width: 940, alignment: .topLeading)
    }

    private func modeOption(_ m: BlockMode, _ title: String, _ sub: String, _ icon: MRIconName) -> some View {
        SettingsOption(isSelected: mode == m, spacing: 6, action: { mode = m; store.prefs.mode = m }) {
            HStack(spacing: 8) {
                MRIcon(icon, size: 16).foregroundStyle(m == .off ? p.text2.color : p.accent1.color)
                Text(title).font(.mr(.ui, size: 14, weight: 600))
            }
            Text(sub).font(.mr(.ui, size: 12, weight: 400)).foregroundStyle(p.text2.color)
                .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var appsCard: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 5), spacing: 2) {
                ForEach(FocusTile.all) { tile in
                    AppTile(name: tile.name, hex: tile.colorHex, glyph: tile.glyph, icon: nil, on: store.isOn(tile) && mode != .off) {
                        store.set(tile, !store.isOn(tile))
                    }
                }
                ForEach(store.prefs.customApps, id: \.self) { id in
                    AppTile(name: Self.appName(id), hex: "#C7CCDA", glyph: "", icon: Self.appIcon(id), on: mode != .off) {
                        store.prefs.customApps.removeAll { $0 == id }
                    }
                }
                AddAppTile(action: addApp)
            }
            p.strokeHair.color.frame(height: 1).padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 10)
            FlowRow(spacing: 8) {
                ForEach(store.prefs.sites, id: \.self) { site in
                    HStack(spacing: 6) {
                        MRIcon(.globe, size: 12)
                        Text(site)
                        Button { store.prefs.sites.removeAll { $0 == site } } label: { MRIcon(.x, size: 12).foregroundStyle(p.text3.color) }
                            .buttonStyle(.plain).accessibilityLabel(L("Remove %@", site))
                    }
                    .font(.mr(.ui, size: 12, weight: 500)).foregroundStyle(MRScenarioColor.other.color)
                    .padding(.leading, 12).padding(.trailing, 12).frame(height: 30)
                    .background(p.fill1.color, in: Capsule()).overlay(Capsule().strokeBorder(p.strokeHair.color, lineWidth: 1))
                }
                HStack(spacing: 8) {
                    MRIcon(.plus, size: 12).foregroundStyle(p.text3.color)
                    TextField(L("Add a site"), text: $siteDraft)
                        .textFieldStyle(.plain).font(.mr(.ui, size: 12, weight: 400))
                        .onSubmit(addSite).accessibilityLabel(L("Add a site to block"))
                }
                .padding(.horizontal, 10).frame(width: 160, height: 30)
                .background(p.fill1.color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(p.strokeHair.color, lineWidth: 1))
            }
            .padding(.horizontal, 8).padding(.bottom, 10)
        }
        .padding(.horizontal, 10).padding(.top, 10).padding(.bottom, 6)
        .mrGlass(cornerRadius: MRRadius.card, elevation: .e1)
    }

    private func addSite() {
        let s = siteDraft.trimmingCharacters(in: .whitespaces).lowercased()
        siteDraft = ""
        guard !s.isEmpty, !store.prefs.sites.contains(s) else { return }
        store.prefs.sites.append(s)
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url, let id = Bundle(url: url)?.bundleIdentifier else { return }
        if !store.prefs.customApps.contains(id) { store.prefs.customApps.append(id) }
    }

    static func appName(_ bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    static func appIcon(_ bundleID: String) -> NSImage? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).map { NSWorkspace.shared.icon(forFile: $0.path) }
    }
}

/// Wraps children onto lines (chips).
private struct FlowRow: Layout {
    var spacing: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal.width ?? 400, subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let r = arrange(bounds.width, subviews)
        for (i, f) in r.frames.enumerated() { subviews[i].place(at: CGPoint(x: bounds.minX + f.minX, y: bounds.minY + f.minY), proposal: .unspecified) }
    }
    private func arrange(_ width: CGFloat, _ subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, frames: [CGRect] = [], maxX: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0, x + sz.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: sz))
            x += sz.width + spacing; rowH = max(rowH, sz.height); maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + rowH), frames)
    }
}

private struct AppTile: View {
    let name: String
    let hex: String
    let glyph: String
    let icon: NSImage?
    let on: Bool
    let action: () -> Void
    @Environment(\.mrPalette) private var p
    @State private var hovered = false
    @FocusState private var focused: Bool

    var body: some View {
        let baseRGB = RGB(hex: hex)
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    if let icon { Image(nsImage: icon).resizable().frame(width: 52, height: 52) }
                    else {
                        LinearGradient(colors: [Color(baseRGB), Color(baseRGB.mixed(with: RGB(r: 16 / 255, g: 22 / 255, b: 43 / 255), amount: 0.45))],
                                       startPoint: UnitPoint(x: 0.3, y: 0), endPoint: UnitPoint(x: 0.7, y: 1))
                        SVGPathShape(d: glyph).stroke(.white.opacity(0.92), style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                    }
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(.white.opacity(0.2), lineWidth: 1))
                .shadow(color: .black.opacity(0.28), radius: 3, y: 2)
                .opacity(on ? 1 : 0.45).saturation(on ? 1 : 0.3)
                Text(name).font(.mr(.ui, size: 12, weight: 500)).foregroundStyle(on ? p.text1.color : p.text3.color).lineLimit(1)
            }
            .padding(.top, 10).padding(.bottom, 8).padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(hovered ? p.fill2.color : .clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if on {
                    MRIcon(.check, size: 12).foregroundStyle(p.ctaFg.color)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(p.accentGradient))
                        .overlay(Circle().strokeBorder(p.bg1.color, lineWidth: 2).padding(-2))
                        .padding(.trailing, 20).padding(.top, 4)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($focused)
        .mrFocusRing(focused, cornerRadius: 16, offset: 1, color: p.accent1.color)
        .onHover { hv in withAnimation(MRMotion.hover) { hovered = hv } }
        .accessibilityLabel("\(name), \(on ? L("blocked") : L("allowed"))")
        .accessibilityAddTraits(.isToggle)
    }
}

private struct AddAppTile: View {
    let action: () -> Void
    @Environment(\.mrPalette) private var p
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                MRIcon(.plus, size: 20).foregroundStyle(p.text2.color)
                    .frame(width: 52, height: 52)
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(p.text3.color, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
                Text(L("Add app…")).font(.mr(.ui, size: 12, weight: 500)).foregroundStyle(p.text2.color)
            }
            .padding(.top, 10).padding(.bottom, 8).padding(.horizontal, 4).frame(maxWidth: .infinity).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityLabel(L("Add an app"))
    }
}

struct SVGPathShape: Shape {
    let d: String
    nonisolated func path(in rect: CGRect) -> Path {
        let k = min(rect.width, rect.height) / 52
        return SVGPath.parse(d).applying(CGAffineTransform(translationX: rect.minX, y: rect.minY).scaledBy(x: k, y: k))
    }
}

// MARK: - Preview of the three modes

struct FocusPreview: View {
    let mode: BlockMode
    @Environment(\.mrPalette) private var p

    var body: some View {
        ZStack(alignment: .top) {
            p.bg2.color
            blockedWindow.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top).padding(.horizontal, 18).padding(.top, 20)
            switch mode {
            case .off:
                VStack { Spacer(); MRPill(L("Nothing appears")).padding(.bottom, 16) }
            case .nudge:
                NudgeCard(title: L("You’re in flight to Paris — 18 min left."), action: L("Return to focus"))
                    .padding(.horizontal, 30).padding(.top, 18)
                VStack { Spacer(); Text(L("Slides in for 6 s, then tucks away. Never steals focus.")).font(.mr(.mono, size: 11, weight: 500)).foregroundStyle(p.text3.color).padding(.bottom, 16) }
            case .strictOverlay:
                Rectangle().fill(p.scrim.color).background(.ultraThinMaterial.opacity(0.8))
                StrictCard(route: "LHR → CDG", title: L("You’re in flight to Paris — 18 min left."), progress: 0.57,
                           left: L("24 of 42 min"), right: L("ETA %@", "10:42"), actions: nil).padding(.horizontal, 40).frame(maxHeight: .infinity)
            }
        }
        .frame(width: 392, height: 372)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(p.strokeHair.color, lineWidth: 1))
        .shadow(color: p.e2.color.color, radius: p.e2.radius, y: p.e2.y)
        .animation(MRMotion.ease(), value: mode)
    }

    private var blockedWindow: some View {
        let top = UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 14, style: .continuous)
        return VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { _ in Circle().fill(p.fill3.color).frame(width: 9, height: 9) }
                Text(L("Social — blocked app")).font(.mr(.ui, size: 11, weight: 500)).foregroundStyle(p.text3.color).padding(.leading, 10)
                Spacer()
            }.padding(.horizontal, 12).frame(height: 34)
            VStack(alignment: .leading, spacing: 12) {
                ghostRow(46, 78)
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(p.fill3.color).opacity(0.7).frame(height: 96)
                ghost(88); ghost(64).opacity(0.6)
                ghostRow(52, 70)
            }.padding(.horizontal, 16).padding(.vertical, 8)
            Spacer(minLength: 0)
        }
        .background(p.fill2.color, in: top)
        .overlay(top.strokeBorder(p.strokeHair.color, lineWidth: 1))
    }

    private func ghost(_ pct: CGFloat) -> some View {
        GeometryReader { g in RoundedRectangle(cornerRadius: 4).fill(p.fill3.color).frame(width: g.size.width * pct / 100, height: 8) }.frame(height: 8)
    }
    private func ghostRow(_ a: CGFloat, _ b: CGFloat) -> some View {
        HStack(spacing: 10) {
            Circle().fill(p.fill3.color).frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 6) { ghost(a); ghost(b).opacity(0.6) }
        }
    }
}

/// Non-activating banner (Nudge).
struct NudgeCard: View {
    let title: String
    let action: String
    @Environment(\.mrPalette) private var p
    var body: some View {
        HStack(spacing: 12) {
            MRIcon(.plane, size: 18).foregroundStyle(p.accent1.color)
                .frame(width: 34, height: 34).background(p.fill2.color, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.mr(.ui, size: 13, weight: 600)).foregroundStyle(p.text1.color)
                Text(action).font(.mr(.ui, size: 12, weight: 600)).foregroundStyle(p.accent1.color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            MRIcon(.x, size: 14).foregroundStyle(p.text3.color)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .mrGlass(cornerRadius: 20, elevation: .e2)
    }
}

/// Strict overlay card. `actions == nil` = static preview.
struct StrictCard: View {
    let route: String
    let title: String
    let progress: Double
    let left: String
    let right: String
    let actions: (returnToFocus: () -> Void, takeBreak: () -> Void, landEarly: (() -> Void)?)?
    @Environment(\.mrPalette) private var p

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                MRDot(pulsing: true).foregroundStyle(p.accent1.color)
                Text(L("In flight · %@", route)).mrText(.eyebrow).foregroundStyle(p.text2.color)
            }
            Text(title).font(.mr(.ui, size: 22, weight: 600)).tracking(-0.004 * 22).foregroundStyle(p.text1.color)
                .fixedSize(horizontal: false, vertical: true)
            ProgressView(value: progress).progressViewStyle(StrictBar())
            HStack {
                Text(left); Spacer(); Text(right)
            }.font(.mr(.mono, size: 11, weight: 500)).foregroundStyle(p.text2.color)
            Button { actions?.returnToFocus() } label: { Text(L("Return to focus")).frame(maxWidth: .infinity) }
                .buttonStyle(MRButtonStyle(.primary)).keyboardShortcut(.defaultAction)
            HStack(spacing: 10) {
                Button { actions?.takeBreak() } label: { Text(L("Take a break")).frame(maxWidth: .infinity) }
                    .buttonStyle(MRButtonStyle(.secondary, size: .sm)).keyboardShortcut(.cancelAction)
                Button { actions?.landEarly?() } label: { Text(L("Land early")).frame(maxWidth: .infinity) }
                    .buttonStyle(MRButtonStyle(.tertiary, size: .sm)).disabled(actions != nil && actions?.landEarly == nil)
            }
        }
        .padding(.horizontal, 22).padding(.top, 22).padding(.bottom, 18)
        .mrGlass(cornerRadius: 28, elevation: .e3)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

private struct StrictBar: ProgressViewStyle {
    @Environment(\.mrPalette) private var p
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(p.fill2.color)
                Capsule().fill(p.accentGradient).frame(width: g.size.width * (configuration.fractionCompleted ?? 0))
            }
        }.frame(height: 6)
    }
}
