import MeridianUI
import SwiftUI

/// C12 "System UI kit" (`C12-UI-Kit.dc.html`): every control with default, hover, pressed, focus and disabled,
/// drawn with the real MeridianUI components. Harness route `ui-kit` (1440 wide); `slice` shows one 1000 pt band
/// of the page for windows shorter than the 4000 pt artboard.
struct UIKitScreen: View {
    var slice: Int?

    var body: some View {
        let sheet = UIKitSheet().fixedSize()
        Color.clear
            .overlay(alignment: .topLeading) { sheet.offset(y: -CGFloat(slice ?? 0) * 1000) }
            .clipped()
        .background(MRPalette.dark.bg0.color)
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Flex-wrap row

/// CSS `display:flex; flex-wrap:wrap; gap: row column; align-items:flex-start`.
private struct WrapRow: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? .infinity
        let lines = arrange(width: w, subviews: subviews)
        return CGSize(width: w.isFinite ? w : (lines.map { $0.width }.max() ?? 0), height: lines.reduce(0) { $0 + $1.height } + CGFloat(max(0, lines.count - 1)) * lineSpacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for line in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for (i, size) in zip(line.indices, line.sizes) {
                subviews[i].place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += line.height + lineSpacing
        }
    }

    private struct Line { var indices: [Int] = []; var sizes: [CGSize] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Line] {
        var lines = [Line()]
        for i in subviews.indices {
            let s = subviews[i].sizeThatFits(.unspecified)
            let add = (lines[lines.count - 1].indices.isEmpty ? 0 : spacing) + s.width
            if !lines[lines.count - 1].indices.isEmpty, lines[lines.count - 1].width + add > width + 0.01 { lines.append(Line()) }
            let add2 = (lines[lines.count - 1].indices.isEmpty ? 0 : spacing) + s.width
            lines[lines.count - 1].indices.append(i); lines[lines.count - 1].sizes.append(s)
            lines[lines.count - 1].width += add2
            lines[lines.count - 1].height = max(lines[lines.count - 1].height, s.height)
        }
        return lines
    }
}

// MARK: - Text helpers (CSS line-heights are exact)

private extension View {
    /// CSS `font` shorthand: exact weight, size, line-height (single line = fixed box; `multi` = line spacing), letter-spacing in em.
    func css(_ size: CGFloat, _ weight: Int, lh: CGFloat, family: MRFonts.Family = .ui, tracking em: CGFloat = 0, multi: Bool = false) -> some View {
        let natural = MRFonts.naturalLineHeight(family, size: size, weight: weight)
        return font(.mr(family, size: size, weight: weight)).tracking(em * size).lineSpacing(multi ? lh - natural : 0)
            .lineLimit(multi ? nil : 1)
            .frame(height: multi ? nil : lh, alignment: .center)
    }
}

private struct Cap: View {
    let text: String
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Text(text).textCase(.uppercase).css(11, 600, lh: 14, tracking: 0.06).foregroundStyle(MRPalette.resolve(scheme).text2.color)
    }
}

private struct Note: View {
    let text: String
    var width: CGFloat = 280
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Text(text).css(12, 400, lh: 17.4, family: .mono, multi: true).foregroundStyle(MRPalette.resolve(scheme).text3.color)
            .frame(width: width, alignment: .leading).fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Sheet

private struct UIKitSheet: View {
    var body: some View {
        let p = MRPalette.dark
        VStack(alignment: .leading, spacing: 40) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    MRIcon(.mark, size: 18).foregroundStyle(p.accent1.color)
                    Text("Component library · C12 · §2.16").textCase(.uppercase).css(12, 600, lh: 12, tracking: 0.08).foregroundStyle(p.text2.color)
                }
                Text("System UI kit").css(56, 600, lh: 60, tracking: -0.012).foregroundStyle(p.text1.color)
                Text("The ordinary parts, each with the five states it needs: default, hover, pressed, focus and disabled. They look like macOS 26 controls, in Meridian’s own glass, so nothing in the app feels borrowed.")
                    .css(15, 400, lh: 22, multi: true).foregroundStyle(p.text2.color).frame(maxWidth: 900, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            }
            UIKitPanel(label: "Dark", full: true).environment(\.colorScheme, .dark)
            UIKitPanel(label: "Light — Daybreak", full: false).environment(\.colorScheme, .light)
        }
        .padding(.top, 56).padding(.horizontal, 64).padding(.bottom, 72)
        .frame(width: 1440, alignment: .topLeading)
        .background(p.bg0.color)
    }
}

private struct SectionTitle: View {
    let title: String
    var theme: String?
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let p = MRPalette.resolve(scheme)
        HStack(alignment: .firstTextBaseline) {
            Text(title).css(22, 600, lh: 28).foregroundStyle(p.text1.color)
            Spacer(minLength: 16)
            if let theme { Text(theme).textCase(.uppercase).css(11, 600, lh: 11, family: .mono, tracking: 0.1).foregroundStyle(p.text3.color) }
        }
    }
}

private struct UIKitPanel: View {
    let label: String
    let full: Bool
    @Environment(\.colorScheme) private var scheme

    private let states: [(String, MRForcedState, Bool)] = [("Default", .none, false), ("Hover", .hover, false), ("Pressed", .pressed, false), ("Focus", .focus, false), ("Disabled", .none, true)]

    var body: some View {
        let p = MRPalette.resolve(scheme)
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        VStack(alignment: .leading, spacing: 34) {
            SectionTitle(title: "Buttons", theme: label)
            buttonGrid
            SectionTitle(title: "Segmented control, toggle, slider, stepper")
            controlGrid
            SectionTitle(title: "Text and search fields")
            fields
            if full {
                SectionTitle(title: "Popover, context menu, sheet, alert")
                overlays
                SectionTitle(title: "Tooltip, toast, badge, progress, skeleton")
                feedback
                SectionTitle(title: "Empty-state illustration style")
                empties
                Note(text: "One line weight (1.5 pt), the accent colour, round caps, a dashed outline for “not yet” and a solid detail for “here is the one thing”. No fills, no people, no clip-art planes. The ghost ticket has the same notches as the real one so the first flight clearly goes there.", width: 900)
                SectionTitle(title: "Focus ring")
                focusRing
                native
            }
        }
        .padding(.top, 34).padding(.horizontal, 40).padding(.bottom, 40)
        .frame(width: 1312, alignment: .topLeading)
        .background(p.bg1.color)
        .clipShape(shape)
        .overlay(shape.strokeBorder(p.strokeHair.color, lineWidth: 1))
    }

    // Grid with a 150 pt label column and five equal columns (gap 18 / 16).
    private func grid(@ViewBuilder _ rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 18) { rows() }
    }

    private func row(_ name: String, _ cell: @escaping (MRForcedState, Bool) -> AnyView) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Text(name).css(13, 500, lh: 15.6).foregroundStyle(MRPalette.resolve(scheme).text2.color).frame(width: 150, alignment: .leading)
            ForEach(Array(states.enumerated()), id: \.offset) { _, s in
                cell(s.1, s.2).fixedSize().frame(width: 200.4, alignment: .leading)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Color.clear.frame(width: 150, height: 1)
            ForEach(states, id: \.0) { s in
                Text(s.0).textCase(.uppercase).css(10, 600, lh: 12, tracking: 0.14).foregroundStyle(MRPalette.resolve(scheme).text3.color).frame(width: 200.4, alignment: .leading)
            }
        }
    }

    private func btn(_ kind: MRButtonStyle.Kind, _ title: String, size: MRButtonStyle.Size = .regular) -> (MRForcedState, Bool) -> AnyView {
        { st, dis in AnyView(Button(title) {}.buttonStyle(MRButtonStyle(kind, size: size)).mrForceState(st).disabled(dis)) }
    }

    private var buttonGrid: some View {
        grid {
            header
            row("Primary", btn(.primary, "Check in"))
            row("Secondary", btn(.secondary, "Cancel"))
            row("Tertiary", btn(.tertiary, "Skip for now"))
            row("Danger", btn(.danger, "End flight"))
            row("Small", { st, dis in AnyView(Button("Export CSV") {}.buttonStyle(MRButtonStyle(.secondary, size: .sm)).mrForceState(st).disabled(dis)) })
            row("Round glass", { st, dis in AnyView(Button { } label: { MRIcon(.sound, size: 18) }.buttonStyle(MRRoundButtonStyle(elevation: .e3)).mrForceState(st).disabled(dis)) })
            row("Large", { st, dis in AnyView(Button("Board") {}.buttonStyle(MRButtonStyle(.primary, size: .lg)).mrForceState(st).disabled(dis)) })
        }
    }

    private var controlGrid: some View {
        grid {
            header
            row("Segmented", { st, _ in AnyView(KitSegmented(hover: st == .hover)) })
            row("Toggle · off", { st, dis in AnyView(KitToggle(on: false).mrForceState(st).disabled(dis)) })
            row("Toggle · on", { st, dis in AnyView(KitToggle(on: true).mrForceState(st).disabled(dis)) })
            row("Slider", { st, dis in AnyView(KitSlider().mrForceState(st).disabled(dis).frame(width: 120)) })
            row("Stepper", { st, dis in AnyView(KitStepper(value: "25", state: st).opacity(dis ? 0.38 : 1)) })
        }
    }

    private var fields: some View {
        let items: [(String, MRForcedState, MRIconName, String, String, String, Bool, Bool)] = [
            ("Default", .none, .search, "", "Search airports", "Placeholder in the third tone.", false, false),
            ("Hover", .hover, .search, "", "Search airports", "Fill steps up one level.", false, false),
            ("Focus", .focus, .search, "Lis", "", "Accent ring; the match is highlighted.", false, false),
            ("Filled", .none, .pencil, "Auth module refactor", "", "Topic field, max 60 characters.", false, false),
            ("Error", .none, .alert, "LHRX", "", "Red border and one line of help.", true, false),
            ("Disabled", .none, .search, "", "Search airports", "38% opacity, not focusable.", false, true),
        ]
        return WrapRow(spacing: 28, lineSpacing: 28) {
            ForEach(items, id: \.0) { it in
                VStack(alignment: .leading, spacing: 10) {
                    KitField(placeholder: it.4, value: it.3, icon: it.2, error: it.6).mrForceState(it.1).disabled(it.7).frame(width: 230)
                    Cap(text: it.0)
                    Note(text: it.5, width: 230)
                }
            }
        }
    }

    private var overlays: some View {
        WrapRow(spacing: 36, lineSpacing: 36) {
            captioned("Popover · glass e3, 20 pt radius, arrow 10 pt") { KitPopover() }
            captioned("Context menu · hover = accent fill") { KitMenu() }
            captioned("Sheet · slides from the title bar") { KitSheet() }
            captioned("Alert · destructive on the right") { KitAlert() }
        }
    }

    private func captioned(_ cap: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) { content(); Cap(text: cap) }
    }

    private var feedback: some View {
        WrapRow(spacing: 40, lineSpacing: 40) {
            captioned("Tooltip · 600 ms delay") { MRTooltip("Follow plane", key: "F") }
            captioned("Toast · 4 s") { MRToast("Added to your wallet", message: "+348 km") }
            captioned("Badge and status pills") {
                HStack(spacing: 10) {
                    MRBadge("3"); MRBadge("12")
                    MRPill("On time", kind: .ok, pulsingDot: false).overlay(alignment: .leading) { EmptyView() }
                    MRPill("Last minute", kind: .warn)
                    MRPill("Offline", kind: .danger)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                MRProgressBar(0.62).frame(width: 240)
                MRProgressBar(0.18).frame(width: 240)
                Cap(text: "Progress · 4 pt, accent gradient")
            }.frame(width: 240, alignment: .leading)
            VStack(alignment: .leading, spacing: 10) {
                KitSkeleton().frame(width: 200, height: 16)
                KitSkeleton().frame(width: 140, height: 16)
                KitSkeleton(radius: 14).frame(width: 240, height: 56)
                Cap(text: "Skeleton · shimmer 1.4 s")
            }.frame(width: 240, alignment: .leading)
        }
    }

    private var empties: some View {
        let e: [(String, String, String, String, String, String)] = [
            ("No tickets yet.", "Your first flight will print here.", "Ghost ticket", "M20 18h110a8 8 0 0 1 8 8v12a6 6 0 0 0 0 12v12a8 8 0 0 1-8 8H20a8 8 0 0 1-8-8V26a8 8 0 0 1 8-8z", "M96 18v52M36 40h40M36 54h28", "4 5"),
            ("No stamps yet.", "Land somewhere new to fill this page.", "Empty passport", "M30 10h90a6 6 0 0 1 6 6v68a6 6 0 0 1-6 6H30a6 6 0 0 1-6-6V16a6 6 0 0 1 6-6z", "M75 36a16 16 0 1 0 .1 0M59 44h32M75 28v32", "4 5"),
            ("No friends aboard.", "Invite someone to share a flight.", "No friends", "M30 70c0-14 10-22 22-22s22 8 22 22", "M52 36a10 10 0 1 0 .1 0M96 64c0-10 8-16 18-16M104 36a8 8 0 1 0 .1 0", "4 5"),
            ("You’re offline.", "Your plane keeps flying. We’ll sync when you’re back.", "Offline", "M20 66c0-14 11-24 25-24 3-12 14-20 28-20 17 0 31 13 31 30 11 0 20 6 20 14", "M48 84l60-62", "4 5"),
        ]
        return WrapRow(spacing: 28, lineSpacing: 28) {
            ForEach(e, id: \.0) { it in
                captioned(it.2) { KitEmpty(title: it.0, note: it.1, d1: it.3, d2: it.4, dash: it.5) }
            }
        }
    }

    private var focusRing: some View {
        let p = MRPalette.resolve(scheme)
        return HStack(spacing: 28) {
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(p.fill2.color).frame(width: 104, height: 56)
                .overlay { Button("Button") {}.buttonStyle(MRButtonStyle(.secondary, size: .sm)) }
                .mrFocusRing(true, cornerRadius: 14, color: p.accent1.color)
            Capsule().fill(p.fill2.color).frame(width: 104, height: 56)
                .overlay { ScenarioChip(name: "Coding", icon: .code, colorHex: "#B49CFF") }
                .mrFocusRing(true, cornerRadius: 28, color: p.accent1.color)
            Note(text: "2 pt accent outline, 2 pt offset, same corner radius as the control plus the offset. Keyboard focus only; clicks never show it. In Increase Contrast the ring becomes 3 pt and white on dark, black on light.", width: 520)
        }
        .padding(.leading, 2)
    }

    private var native: some View {
        let p = MRPalette.resolve(scheme)
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        func code(_ s: String) -> Text { Text(s).foregroundColor(p.text1.color) }
        let body: Text = Text("All of these are ") + code("ButtonStyle") + Text(", ") + code("ToggleStyle") + Text(" and ") + code("LabelStyle") +
            Text(" over system controls, so keyboard navigation, VoiceOver and Dynamic Type come free. Glass is ") + code("glassEffect(_:in:)") +
            Text("; the focus ring is the system ") + code("focusEffect") + Text(" tinted with the accent.")
        return HStack(alignment: .top, spacing: 12) {
            Text("Native").textCase(.uppercase).css(10, 700, lh: 18, tracking: 0.12).foregroundStyle(p.accent1.color)
            body.css(12, 400, lh: 18, family: .mono, multi: true).foregroundStyle(p.text2.color).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: 900, alignment: .leading)
        .background(p.fill1.color, in: shape)
        .overlay(shape.strokeBorder(p.strokeHair.color, lineWidth: 1))
    }
}

// MARK: - Kit-only pieces

private struct KitSegmented: View {
    var hover: Bool
    @State private var sel = "Map"
    var body: some View {
        MRSegmented(selection: $sel, options: ["Map", "Window", "Dash"].map { .init($0, $0) }, pinnedHover: hover ? "Window" : nil)
    }
}

private struct KitToggle: View {
    @State var on: Bool
    var body: some View { Toggle("", isOn: $on).labelsHidden().toggleStyle(MRToggleStyle()) }
}

private struct KitSlider: View {
    @State private var v = 0.58
    var body: some View { MRSlider(value: $v) }
}

private struct KitField: View {
    let placeholder: String
    @State var value: String
    let icon: MRIconName
    var error = false
    init(placeholder: String, value: String, icon: MRIconName, error: Bool) {
        self.placeholder = placeholder; self._value = State(initialValue: value); self.icon = icon; self.error = error
    }
    var body: some View { MRField(placeholder, text: $value, icon: icon, iconSize: 14, isError: error) }
}

/// `.c12-step`: 32 pt stepper, 30 pt buttons around a 46 pt mono value.
private struct KitStepper: View {
    let value: String
    var state: MRForcedState = .none
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let p = MRPalette.resolve(scheme)
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        HStack(spacing: 0) {
            MRIcon(.minus, size: 14).foregroundStyle(state == .hover ? p.text1.color : p.text2.color).frame(width: 30, height: 30)
                .frame(maxHeight: .infinity)
                .background(state == .hover ? p.fill2.color : state == .pressed ? p.fill3.color : .clear)
            p.strokeHair.color.frame(width: 1)
            Text(value).font(.mr(.mono, size: 14, weight: 500)).foregroundStyle(p.text1.color).frame(minWidth: 44)
            p.strokeHair.color.frame(width: 1)
            MRIcon(.plus, size: 14).foregroundStyle(p.text2.color).frame(width: 30, height: 30).frame(maxHeight: .infinity)
        }
        .frame(height: 32)
        .background(p.fill1.color)
        .clipShape(shape)
        .overlay(shape.strokeBorder(p.strokeHair.color, lineWidth: 1))
        .mrFocusRing(state == .focus, cornerRadius: 10, color: p.accent1.color)
        .fixedSize()
    }
}

private struct KitPopover: View {
    @Environment(\.colorScheme) private var scheme
    @State private var sel = "25"
    var body: some View {
        let p = MRPalette.resolve(scheme)
        VStack(alignment: .leading, spacing: 12) {
            Text("Time").mrEyebrow().css(11, 500, lh: 14, tracking: 0.08)
            HStack(spacing: 10) {
                KitStepper(value: "42")
                Text("minutes").css(13, 400, lh: 15.6).foregroundStyle(p.text2.color)
            }
            MRSegmented(selection: $sel, options: ["25", "42", "60", "90"].map { .init($0, $0) }, fill: true)
        }
        .padding(16)
        .frame(width: 260, alignment: .leading)
        .mrGlass(cornerRadius: 20, elevation: .e3)
    }
}

private struct KitMenu: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let p = MRPalette.resolve(scheme)
        VStack(spacing: 0) {
            item(.share, "Share card", "⌘S")
            item(.pencil, "Edit note", "⌘E", hover: true)
            item(.copy, "Copy flight number", nil)
            p.strokeHair.color.frame(height: 1).padding(.horizontal, 4).padding(.vertical, 5)
            item(.trash, "Delete ticket", "⌫", color: p.danger.color)
        }
        .padding(6)
        .frame(minWidth: 200)
        .fixedSize()
        .mrGlass(cornerRadius: 14, elevation: .e3)
    }

    private func item(_ icon: MRIconName, _ title: String, _ key: String?, hover: Bool = false, color: Color? = nil) -> some View {
        let p = MRPalette.resolve(scheme)
        let ink: Color = hover ? (scheme == .dark ? MRColorToken("#04101A").color : .white) : (color ?? p.text1.color)
        return HStack(spacing: 10) {
            MRIcon(icon, size: 14)
            Text(title).font(.mr(.ui, size: 13, weight: 500))
            Spacer(minLength: 0)
            if let key { MRKbd(key).opacity(0.7).environment(\.colorScheme, scheme) }
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 10).frame(height: 30)
        .background(hover ? p.accent1.color : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct KitSheet: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let p = MRPalette.resolve(scheme)
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        VStack(alignment: .leading, spacing: 14) {
            Text("Add a note").css(24, 600, lh: 30, tracking: -0.004).foregroundStyle(p.text1.color)
            Text("What did you get done?").font(.mr(.ui, size: 14, weight: 400)).foregroundStyle(p.text3.color)
                .padding(.top, 12).padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 84, maxHeight: 84, alignment: .topLeading)
                .background(p.fill1.color, in: shape).overlay(shape.strokeBorder(p.strokeHair.color, lineWidth: 1))
            HStack(spacing: 10) {
                Spacer(minLength: 0)
                Button("Cancel") {}.buttonStyle(MRButtonStyle(.secondary, size: .sm))
                Button("Save") {}.buttonStyle(MRButtonStyle(.primary, size: .sm))
            }
        }
        .padding(24)
        .frame(width: 360, alignment: .leading)
        .mrGlass(cornerRadius: 26, elevation: .e3)
    }
}

private struct KitAlert: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let p = MRPalette.resolve(scheme)
        VStack(spacing: 8) {
            MRIcon(.alert, size: 24).foregroundStyle(p.warn.color)
            Text("Land early?").css(15, 600, lh: 20).foregroundStyle(p.text1.color)
            Text("You flew 31 of 42 minutes. 248 km will be counted.").css(13, 400, lh: 18, multi: true).foregroundStyle(p.text2.color).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button("Keep flying") {}.buttonStyle(MRButtonStyle(.secondary, size: .sm))
                Button("Land now") {}.buttonStyle(MRButtonStyle(.danger, size: .sm))
            }.padding(.top, 8)
        }
        .padding(.horizontal, 24).padding(.vertical, 22)
        .frame(width: 300)
        .mrGlass(cornerRadius: 22, elevation: .e3)
    }
}

private struct KitSkeleton: View {
    var radius: CGFloat = 8
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        let p = MRPalette.resolve(scheme)
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { ctx in
            let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.4) / 1.4
            // background-size 200%, position 200% → -200%: the 3-stop gradient slides across twice its width.
            GeometryReader { g in
                LinearGradient(colors: [p.fill1.color, p.fill3.color, p.fill1.color], startPoint: .leading, endPoint: .trailing)
                    .frame(width: g.size.width * 2)
                    .offset(x: -g.size.width * (1 - 2 * (1 - t)) )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

private struct KitEmpty: View {
    let title: String, note: String, d1: String, d2: String, dash: String
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let p = MRPalette.resolve(scheme)
        let style = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
        VStack(spacing: 6) {
            ZStack {
                SVGPath.parse(d1).stroke(p.accent1.color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round, dash: [4, 5]))
                SVGPath.parse(d2).stroke(p.accent1.color.opacity(0.6), style: style)
            }
            .frame(width: 150, height: 100, alignment: .topLeading)
            Text(title).css(15, 600, lh: 20).foregroundStyle(p.text1.color)
            Text(note).css(13, 400, lh: 18, multi: true).foregroundStyle(p.text2.color).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(width: 280, height: 230, alignment: .top)
        .background(p.fill1.color, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
