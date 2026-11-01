import AppKit
import MeridianCore
import MeridianData
import MeridianUI
import SwiftUI

/// S34 / S34B / S34C: the passport (PassportScreen.dc.html). Header counts, year and scenario filters, the
/// two-page spread with its page turning, and the spread navigation.
struct PassportScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.shellSidebarInset) private var inset
    @Environment(\.colorScheme) private var scheme
    @Environment(\.passportFixture) private var fixture
    @Environment(\.passportStart) private var start

    @State private var year = "all"
    @State private var scenario = "all"
    @State private var spread = 0
    @State private var animIndex = -1
    @State private var didStart = false
    @FocusState private var focused: Bool

    private static var lastAnimatedFlight: UUID?

    private var content: PassportContent { fixture ?? PassportContent.live(model) }

    var body: some View {
        let p = MRPalette.resolve(scheme)
        let c = content
        let layout = PassportLayout(content: c, year: year, scenario: scenario)
        let nSp = layout.spreadCount
        let sp = max(0, min(nSp - 1, spread))
        ZStack {
            Color.clear.focusable().focusEffectDisabled().focused($focused)
            GeometryReader { geo in
                let W = geo.size.width
                let L = inset + 28
                ZStack(alignment: .topLeading) {
                    EllipticalGlow(color: mrHex("#6AB7FF").opacity(0.10), rx: 0.6, ry: 0.5, cx: 0.8, cy: 0, stop: 0.7)

                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Wallet").mrEyebrow().frame(height: 14)
                            Text("Passport").font(.mr(.serif, size: 42, weight: 500)).tracking(-0.02 * 42)
                                .foregroundStyle(p.text1.color).frame(height: 46, alignment: .leading).padding(.top, 6)
                        }
                        Spacer(minLength: 0)
                        HStack(alignment: .bottom, spacing: 30) {
                            number(c.countries, "countries", p)
                            number(c.airports, "airports", p)
                            number(c.stamps, "stamps", p)
                        }
                    }
                    .frame(width: W - L - 28)
                    .offset(x: L, y: 46)

                    filters(c, nSp: nSp, sp: sp, p: p)
                        .frame(width: W - L - 28, alignment: .leading)
                        .offset(x: L, y: 116)

                    PassportBook(layout: layout, animIndex: animIndex, spread: $spread)
                        .offset(x: inset + 26, y: 166)
                }
                .frame(width: W, height: geo.size.height, alignment: .topLeading)
            }
        }
        .onKeyPress(.rightArrow) { spread = min(nSp - 1, sp + 1); return .handled }
        .onKeyPress(.leftArrow) { spread = max(0, sp - 1); return .handled }
        .onAppear {
            guard !didStart else { return }
            didStart = true
            if fixture != nil {
                year = start.year; scenario = start.scenario; spread = start.spread; animIndex = start.animIndex
            } else if let landing = model.latestLanding, let cc = landing.newStampCountry, landing.flight.id != Self.lastAnimatedFlight,
                      let e = c.entries.first(where: { $0.cc == cc }) {
                Self.lastAnimatedFlight = landing.flight.id
                animIndex = e.idx
                spread = e.idx / PassportLayout.perSpread
            }
            focused = true
        }
        .onChange(of: year) { _, _ in spread = 0 }
        .onChange(of: scenario) { _, _ in spread = 0 }
    }

    private func number(_ n: Int, _ label: String, _ p: MRPalette) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text("\(n)").font(.mr(.serif, size: 34, weight: 500)).tracking(-0.01 * 34).foregroundStyle(p.text1.color)
            Text(label).font(.mr(.ui, size: 12, weight: 500)).tracking(12 * 0.02).textCase(.uppercase).foregroundStyle(p.text2.color)
        }
        .frame(height: 34, alignment: .bottom)
        .accessibilityElement(children: .combine)
    }

    private func filters(_ c: PassportContent, nSp: Int, sp: Int, p: MRPalette) -> some View {
        let years = [MRSegmented<String>.Option("all", "All years")] + c.years.map { MRSegmented<String>.Option($0, $0) }
        let chips: [(id: String, label: String, hex: String)] = [("all", "All", "#C7CCDA")]
            + PlanKit.scenarioOrder.filter { $0 != "other" }.map { id in let s = PlanKit.scenario(id); return (id, s.label, s.hex) }
        return HStack(spacing: 14) {
            MRSegmented(selection: $year, options: years)
            Rectangle().fill(p.strokeHair.color).frame(width: 1, height: 20)
            HStack(spacing: 6) {
                ForEach(chips, id: \.id) { chip in
                    PassportChip(title: chip.label, hex: chip.hex, selected: scenario == chip.id) { scenario = chip.id }
                }
            }
            Spacer(minLength: 0)
            navButton(.chevL, "Previous spread", enabled: sp > 0) { spread = max(0, sp - 1) }
            Text("Spread \(sp + 1) of \(nSp)").font(.mr(.mono, size: 12, weight: 500)).foregroundStyle(p.text2.color)
            navButton(.chevR, "Next spread", enabled: sp < nSp - 1) { spread = min(nSp - 1, sp + 1) }
        }
    }

    private func navButton(_ icon: MRIconName, _ label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { MRIcon(icon, size: 14) }
            .buttonStyle(PassportNavStyle())
            .disabled(!enabled)
            .accessibilityLabel(label)
    }
}

/// `.ps-nav`: 34 pt glass circle, 38 % when disabled.
private struct PassportNavStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { Label(configuration: configuration) }

    private struct Label: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.isFocused) private var isFocused
        @Environment(\.colorScheme) private var scheme
        @State private var hovered = false

        var body: some View {
            let p = MRPalette.resolve(scheme)
            configuration.label
                .foregroundStyle(p.text1.color)
                .frame(width: 34, height: 34)
                .mrGlass(in: Circle(), shadow: false)
                .mrGlassControlWash(Circle(), hovering: hovered && isEnabled, pressed: configuration.isPressed, dark: scheme == .dark)
                .mrFocusRing(isFocused, cornerRadius: 17, offset: 2, color: p.accent1.color)
                .opacity(isEnabled ? 1 : 0.38)
                .onHover { hovered = $0 }
                .contentShape(Circle())
        }
    }
}

/// `.chip.ps-chip`: 30 pt scenario filter, text only. Selected: tinted fill, 1 pt ring and glow.
private struct PassportChip: View {
    let title: String
    let hex: String
    let selected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var hovered = false
    @FocusState private var focused: Bool

    var body: some View {
        let p = MRPalette.resolve(scheme)
        let sc = mrHex(hex)
        let ink: Color = scheme == .dark ? sc : Self.mix(hex, with: "#14161C", 0.54)
        let shape = Capsule()
        Button(action: action) {
            Text(title).font(.mr(.ui, size: 12, weight: 500)).foregroundStyle(ink)
                .padding(.leading, 10).padding(.trailing, 12)
                .frame(height: 30)
                .background {
                    ZStack {
                        if selected {
                            shape.fill(sc.opacity(0.20))
                            shape.strokeBorder(sc, lineWidth: 1).shadow(color: sc.opacity(0.30), radius: 11)
                        } else {
                            shape.fill(hovered ? Self.over(sc, p.fill1.color) : p.fill1.color)
                            shape.strokeBorder(p.strokeHair.color, lineWidth: 1)
                            MRInsetShadow(shape, color: p.strokeGlow.color, y: 1)
                        }
                    }
                }
                .mrFocusRing(focused, cornerRadius: 15, color: p.accent1.color)
                .offset(y: hovered && !selected ? -1 : 0)
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .focused($focused)
        .onHover { hovered = $0 }
        .animation(MRMotion.ease(MRMotion.d2), value: hovered)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityLabel(title)
    }

    /// `color-mix(in srgb, sc 12%, fill-1)`.
    private static func over(_ sc: Color, _ base: Color) -> Color {
        let b = NSColor(base).usingColorSpace(.sRGB) ?? .clear
        let t = NSColor(sc).usingColorSpace(.sRGB)?.withAlphaComponent(1) ?? .white
        return Color(nsColor: b.blended(withFraction: 0.12, of: t) ?? b)
    }

    /// `color-mix(in srgb, a (1 - w), b w)`.
    static func mix(_ a: String, with b: String, _ w: Double) -> Color {
        let x = NSColor(MRColorToken(a).color).usingColorSpace(.sRGB) ?? .white
        let y = NSColor(MRColorToken(b).color).usingColorSpace(.sRGB) ?? .black
        return Color(nsColor: x.blended(withFraction: w, of: y) ?? x)
    }
}
