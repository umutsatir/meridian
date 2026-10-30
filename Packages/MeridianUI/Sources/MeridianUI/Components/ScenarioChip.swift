import SwiftUI

/// `.chip`: focus-type chip. Color is never the only signal: icon and label always show (PRD COL-2).
public struct ScenarioChip: View {
    public enum Glyph: Sendable { case sf(String), icon(MRIconName) }

    private let name: String
    private let glyph: Glyph
    private let colorHex: String
    private let isSelected: Bool
    private let isLarge: Bool
    private let action: () -> Void
    private let forcedHover: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    @State private var hovered = false

    public init(name: String, symbol: String, colorHex: String, isSelected: Bool = false, action: @escaping () -> Void = {}) {
        self.init(name: name, glyph: .sf(symbol), colorHex: colorHex, isSelected: isSelected, large: false, action: action)
    }

    public init(name: String, icon: MRIconName, colorHex: String, isSelected: Bool = false, large: Bool = false, action: @escaping () -> Void = {}) {
        self.init(name: name, glyph: .icon(icon), colorHex: colorHex, isSelected: isSelected, large: large, action: action)
    }

    private init(name: String, glyph: Glyph, colorHex: String, isSelected: Bool, large: Bool, action: @escaping () -> Void, forcedHover: Bool = false) {
        self.name = name; self.glyph = glyph; self.colorHex = colorHex; self.isSelected = isSelected
        self.isLarge = large; self.action = action; self.forcedHover = forcedHover
    }

    /// Pins the hover state for galleries (`.is-hover`).
    public func hoverPinned() -> ScenarioChip {
        ScenarioChip(name: name, glyph: glyph, colorHex: colorHex, isSelected: isSelected, large: isLarge, action: action, forcedHover: true)
    }

    /// Light theme text: `color-mix(in srgb, var(--sc) 46%, #14161C)`.
    static func ink(sc: RGB, dark: Bool) -> RGB {
        dark ? sc : sc.mixed(with: RGB(hex: "#14161C"), amount: 0.54)
    }

    public var body: some View {
        let p = MRPalette.resolve(scheme)
        let sc = RGB(hex: colorHex)
        let ink = Color(Self.ink(sc: sc, dark: scheme == .dark))
        let shape = Capsule()
        let hover = (hovered || forcedHover) && isEnabled
        Button(action: action) {
            HStack(spacing: isLarge ? 10 : 8) {
                switch glyph {
                case .sf(let s): Image(systemName: s).font(.system(size: 13))
                case .icon(let i): MRIcon(i, size: 16)
                }
                Text(name).font(.mr(.ui, size: isLarge ? 15 : 13, weight: 500))
            }
            .foregroundStyle(ink)
            .padding(.leading, isLarge ? 16 : 12).padding(.trailing, isLarge ? 20 : 14)
            .frame(height: isLarge ? 44 : 34)
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial).opacity(0.5) // backdrop-filter: blur(20px)
                    shape.fill(chipFill(p, sc: sc, hover: hover))
                }
            }
            .overlay {
                ZStack {
                    MRInsetShadow(shape, color: p.strokeGlow.color, y: 1)
                    shape.strokeBorder(p.strokeHair.color, lineWidth: 1)
                    if isSelected { shape.stroke(Color(sc), lineWidth: 1).padding(-1) } // 0 0 0 1px var(--sc)
                }
            }
            .background {
                if isSelected { shape.fill(Color(sc).opacity(0.3)).blur(radius: 11).padding(-4) } // 0 0 22px sc 30%
            }
            .mrFocusRing(isFocused, cornerRadius: 22, color: p.accent1.color)
            .offset(y: hover && !isSelected ? -1 : 0)
        }
        .buttonStyle(ChipPressStyle())
        .onHover { hovered = $0 }
        .opacity(isEnabled ? 1 : 0.38)
        .animation(MRMotion.snappy, value: isSelected)
        .animation(MRMotion.ease(MRMotion.d2), value: hover)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func chipFill(_ p: MRPalette, sc: RGB, hover: Bool) -> Color {
        if isSelected { return Color(sc).opacity(0.20) } // color-mix(sc 20%, transparent)
        if hover { return Color(RGB(r: sc.r, g: sc.g, b: sc.b).mixedPremultiplied(with: p.fill1.rgb, share: 0.12)) } // color-mix(sc 12%, fill-1)
        return p.fill1.color
    }

    private struct ChipPressStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.scaleEffect(configuration.isPressed ? 0.97 : 1).animation(MRMotion.snappy, value: configuration.isPressed)
        }
    }
}

public extension RGB {
    init(hex: String) { self = HexColor.parse(hex) ?? RGB(r: 0, g: 0, b: 0) }

    /// `color-mix(in srgb, self, other X%)` without alpha handling: `amount` is the share of `other`.
    func mixed(with other: RGB, amount: Double) -> RGB {
        RGB(r: r + (other.r - r) * amount, g: g + (other.g - g) * amount, b: b + (other.b - b) * amount, a: a + (other.a - a) * amount)
    }

    /// `color-mix(in srgb, self share%, other)` with premultiplied alpha, as CSS does for translucent colors.
    func mixedPremultiplied(with other: RGB, share: Double) -> RGB {
        let wa = a * share, wb = other.a * (1 - share)
        let outA = wa + wb
        guard outA > 0 else { return RGB(r: 0, g: 0, b: 0, a: 0) }
        return RGB(r: (r * wa + other.r * wb) / outA, g: (g * wa + other.g * wb) / outA, b: (b * wa + other.b * wb) / outA, a: outA)
    }
}

#Preview("ScenarioChip") {
    HStack {
        ScenarioChip(name: "Study", icon: .book, colorHex: MRScenarioColor.study.hex, isSelected: true)
        ScenarioChip(name: "Code", icon: .code, colorHex: MRScenarioColor.code.hex)
        ScenarioChip(name: "Meditate", icon: .lotus, colorHex: MRScenarioColor.meditate.hex, large: true)
    }
    .padding(24)
    .background(MRPalette.dark.bg0.color)
    .preferredColorScheme(.dark)
}
