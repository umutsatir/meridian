import SwiftUI

/// `.btn` family from meridian.css. Default 44 pt tall; `.lg` 52, `.sm` 32. States: default, hover, pressed, focus, disabled.
public struct MRButtonStyle: ButtonStyle {
    public enum Kind: Sendable { case primary, secondary, tertiary, danger, ghost }
    public enum Size: Sendable {
        case regular, lg, sm

        public var height: CGFloat { switch self { case .regular: 44; case .lg: 52; case .sm: 32 } }
        public var horizontalPadding: CGFloat { switch self { case .regular: 20; case .lg: 28; case .sm: 12 } }
        public var fontSize: CGFloat { switch self { case .regular: 15; case .lg: 16; case .sm: 13 } }
        public var cornerRadius: CGFloat { switch self { case .regular: MRRadius.control; case .lg: 26; case .sm: 10 } }
    }

    private let kind: Kind
    private let size: Size
    private let pill: Bool
    private let forcedHover: Bool

    public init(_ kind: Kind = .primary, size: Size = .regular, pill: Bool = false) {
        self.kind = kind; self.size = size; self.pill = pill; self.forcedHover = false
    }

    /// Previews / galleries: pins the hover state (`.is-hover`).
    func hovering() -> MRButtonStyle { MRButtonStyle(kind, size: size, pill: pill, forcedHover: true) }
    private init(_ kind: Kind, size: Size, pill: Bool, forcedHover: Bool) {
        self.kind = kind; self.size = size; self.pill = pill; self.forcedHover = forcedHover
    }

    public func makeBody(configuration: Configuration) -> some View {
        StyledLabel(kind: kind, size: size, pill: pill, forcedHover: forcedHover, configuration: configuration)
    }

    private struct StyledLabel: View {
        let kind: Kind
        let size: Size
        let pill: Bool
        let forcedHover: Bool
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.isFocused) private var isFocusedEnv
        @Environment(\.mrForcedState) private var forced
        @Environment(\.colorScheme) private var scheme
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var hovered = false

        var body: some View {
            let p = MRPalette.resolve(scheme)
            let radius = pill ? 999 : size.cornerRadius
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            let pressed = configuration.isPressed || forced == .pressed
            let isFocused = isFocusedEnv || forced == .focus
            let hover = (hovered || forcedHover || forced == .hover) && isEnabled
            configuration.label
                .font(.mr(.ui, size: size.fontSize, weight: 600))
                .foregroundStyle(foreground(p))
                .padding(.horizontal, kind == .tertiary ? 10 : size.horizontalPadding)
                .frame(height: size.height)
                .background { background(p, hover: hover, pressed: pressed, shape: shape) }
                .overlay { decoration(p, shape: shape) }
                .modifier(PrimaryFilter(active: kind == .primary && scheme == .dark, hover: hover, pressed: pressed))
                .mrFocusRing(isFocused, cornerRadius: radius, color: p.accent1.color)
                .scaleEffect(pressed && !reduceMotion ? 0.97 : 1)
                .opacity(isEnabled ? 1 : 0.38)
                .animation(reduceMotion ? nil : MRMotion.ease(MRMotion.d2), value: pressed)
                .animation(reduceMotion ? nil : MRMotion.ease(MRMotion.d2), value: hover)
                .onHover { hv in withAnimation(MRMotion.hover) { hovered = hv } }
                .contentShape(shape)
                .allowsHitTesting(isEnabled)
        }

        private func foreground(_ p: MRPalette) -> Color {
            switch kind {
            case .primary: p.ctaFg.color
            case .secondary, .ghost: p.text1.color
            case .tertiary: p.accent1.color
            case .danger: p.dangerLabel.color
            }
        }

        @ViewBuilder
        private func background(_ p: MRPalette, hover: Bool, pressed: Bool, shape: RoundedRectangle) -> some View {
            let dark = scheme == .dark
            switch kind {
            case .primary:
                // light hover swaps the flat #1E6BFF for #1759E0
                let sh = primaryShadow(dark: dark, hover: hover)
                if !dark && hover { shape.fill(p.accent1.color).shadow(color: sh.0, radius: sh.1 / 2, y: sh.2) }
                else { shape.fill(p.ctaGradient).shadow(color: sh.0, radius: sh.1 / 2, y: sh.2) }
            case .secondary:
                shape.fill(hover ? p.fill3.color : p.fill2.color)
            case .tertiary, .ghost:
                shape.fill(hover ? p.fill1.color : .clear)
            case .danger:
                shape.fill(dangerFill(dark: dark, hover: hover))
            }
        }

        private func dangerFill(dark: Bool, hover: Bool) -> Color {
            if hover { return Color(red: 1, green: 107 / 255, blue: 107 / 255, opacity: 0.24) }
            return dark ? Color(red: 1, green: 107 / 255, blue: 107 / 255, opacity: 0.14) : Color(red: 209 / 255, green: 59 / 255, blue: 59 / 255, opacity: 0.10)
        }

        @ViewBuilder
        private func decoration(_ p: MRPalette, shape: RoundedRectangle) -> some View {
            let dark = scheme == .dark
            let hover = (hovered || forcedHover || forced == .hover) && isEnabled
            switch kind {
            case .primary:
                let glow: Double = dark ? (hover ? 0.55 : 0.45) : 0.35
                MRInsetShadow(shape, color: .white.opacity(glow), y: 1)
            case .secondary:
                ZStack {
                    MRInsetShadow(shape, color: p.strokeGlow.color, y: 1)
                    shape.strokeBorder(p.strokeHair.color, lineWidth: 1)
                }
            case .danger:
                shape.strokeBorder(dark ? Color(red: 1, green: 107 / 255, blue: 107 / 255, opacity: 0.38) : Color(red: 209 / 255, green: 59 / 255, blue: 59 / 255, opacity: 0.4), lineWidth: 1)
            case .tertiary, .ghost:
                EmptyView()
            }
        }

        /// color, css blur, y
        private func primaryShadow(dark: Bool, hover: Bool) -> (Color, CGFloat, CGFloat) {
            if dark { return (Color(red: 106 / 255, green: 183 / 255, blue: 1, opacity: hover ? 0.38 : 0.22), hover ? 32 : 24, hover ? 10 : 8) }
            return (Color(red: 30 / 255, green: 107 / 255, blue: 1, opacity: 0.28), 18, 6)
        }
    }

    /// Dark primary: hover `brightness(1.07) saturate(1.06)`, pressed `brightness(.93)`.
    private struct PrimaryFilter: ViewModifier {
        let active: Bool
        let hover: Bool
        let pressed: Bool
        func body(content: Content) -> some View {
            if active && pressed { content.brightness(-0.07) }
            else if active && hover { content.brightness(0.05).saturation(1.06) }
            else { content }
        }
    }
}

/// `.btn-round`: 40 pt (32 `.sm`) circle for glass controls. `on` tints the glyph accent. Includes the `.glass-ctl` hover wash.
public struct MRRoundButtonStyle: ButtonStyle {
    private let isOn: Bool
    private let small: Bool
    private let glass: Bool
    private let elevation: MRElevation

    public init(on: Bool = false, small: Bool = false, glass: Bool = true, elevation: MRElevation = .e1) {
        self.isOn = on; self.small = small; self.glass = glass; self.elevation = elevation
    }

    public func makeBody(configuration: Configuration) -> some View {
        Label(isOn: isOn, small: small, glass: glass, elevation: elevation, configuration: configuration)
    }

    private struct Label: View {
        let isOn: Bool
        let small: Bool
        let glass: Bool
        let elevation: MRElevation
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.isFocused) private var isFocusedEnv
        @Environment(\.mrForcedState) private var forced
        @Environment(\.colorScheme) private var scheme
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var hovered = false

        var body: some View {
            let p = MRPalette.resolve(scheme)
            let d: CGFloat = small ? 32 : 40
            let pressed = configuration.isPressed || forced == .pressed
            let isFocused = isFocusedEnv || forced == .focus
            configuration.label
                .foregroundStyle(isOn ? p.accent1.color : p.text1.color)
                .frame(width: d, height: d)
                .modifier(OptionalGlass(glass: glass, elevation: elevation))
                .mrGlassControlWash(Circle(), hovering: (hovered || forced == .hover) && isEnabled, pressed: pressed, dark: scheme == .dark)
                .mrFocusRing(isFocused, cornerRadius: d / 2, color: p.accent1.color)
                .scaleEffect(pressed && !reduceMotion ? 0.94 : 1)
                .opacity(isEnabled ? 1 : 0.38)
                .animation(reduceMotion ? nil : MRMotion.ease(MRMotion.d2), value: pressed)
                .onHover { hv in withAnimation(MRMotion.hover) { hovered = hv } }
                .contentShape(Circle())
                .allowsHitTesting(isEnabled)
        }
    }

    private struct OptionalGlass: ViewModifier {
        let glass: Bool
        let elevation: MRElevation
        func body(content: Content) -> some View {
            if glass { content.mrGlass(in: Circle(), elevation: elevation) } else { content }
        }
    }
}
