import SwiftUI

public struct MRColorToken: Sendable, Hashable {
    /// `#RRGGBB`, or `#RRGGBBAA` for translucent tokens.
    public let hex: String
    public let rgb: RGB
    public var color: Color { Color(rgb) }

    public init(_ hex: String) {
        guard let rgb = HexColor.parse(hex) else { preconditionFailure("Invalid token hex \(hex)") }
        self.hex = hex
        self.rgb = rgb
    }

    /// CSS `rgba(r,g,b,a)` with 0...255 channels and 0...1 alpha, as written in meridian.css.
    public init(_ r: Int, _ g: Int, _ b: Int, _ a: Double) {
        self.rgb = RGB(r: Double(r) / 255, g: Double(g) / 255, b: Double(b) / 255, a: a)
        self.hex = String(format: "#%02X%02X%02X%02X", r, g, b, Int((a * 255).rounded()))
    }

    /// The same color with a different alpha.
    public func opacity(_ a: Double) -> Color { Color(RGB(r: rgb.r, g: rgb.g, b: rgb.b, a: a)) }
}

/// One CSS box-shadow layer (`x y blur spread color`). SwiftUI's radius is half the CSS blur.
public struct MRShadow: Sendable, Hashable {
    public let color: MRColorToken
    public let x: CGFloat, y: CGFloat, blur: CGFloat
    public var radius: CGFloat { blur / 2 }
}

/// Color tokens from meridian.css `:root` (dark, "Night Cabin") and `[data-theme="light"]` ("Daybreak").
/// Paper, ink, amber and the scenario/foil/stamp colors are physical materials and identical in both themes.
public struct MRPalette: Sendable {
    public let isDark: Bool
    public let bg0, bg1, bg2: MRColorToken
    public let text1, text2, text3: MRColorToken
    public let accent1, accent2: MRColorToken
    public let amber, paper, ink: MRColorToken
    public let ok, warn, danger: MRColorToken

    // glass / strokes / fills
    /// `--glass-tint`, `--glass-spec`
    public let glassTint, glassSpec: MRColorToken
    /// `--stroke-hair` (1 px borders), `--stroke-glow` (inner top highlight)
    public let strokeHair, strokeGlow: MRColorToken
    /// `--fill-1/2/3` translucent control fills
    public let fill1, fill2, fill3: MRColorToken
    /// `--scrim`, `--rim`, `--seg-on`
    public let scrim, rim, segOn: MRColorToken
    /// `--accent-grad` end stops (135deg) and `--cta-bg` / `--cta-fg`.
    public let accentGradFrom, accentGradTo: MRColorToken
    public let ctaFrom, ctaTo: MRColorToken
    public let ctaFg: MRColorToken
    /// `--e1`, `--e2`, `--e3`
    public let e1, e2, e3: MRShadow

    /// Label color on a filled accent / CTA surface (`--cta-fg`).
    public var onAccent: MRColorToken { ctaFg }

    /// `--accent-grad`: linear-gradient(135deg, …).
    public var accentGradient: LinearGradient { MRGradient.css135(accentGradFrom.color, accentGradTo.color) }
    /// `--cta-bg`.
    public var ctaGradient: LinearGradient { MRGradient.css135(ctaFrom.color, ctaTo.color) }
    /// Pill text for the accent variant (`.pill.accent`).
    public var accentPillText: MRColorToken { isDark ? MRColorToken("#8CC8FF") : accent1 }
    /// `.btn-danger` label.
    public var dangerLabel: MRColorToken { isDark ? MRColorToken("#FF9A9A") : MRColorToken("#B02A2A") }

    public static let dark = MRPalette(
        isDark: true,
        bg0: .init("#06080D"), bg1: .init("#0B1020"), bg2: .init("#121A2E"),
        text1: .init("#F3F5FA"), text2: .init("#A9B2C7"), text3: .init("#96A0BA"),
        accent1: .init("#6AB7FF"), accent2: .init("#8BF3D8"),
        amber: .init("#FFB547"), paper: .init("#F5F0E6"), ink: .init("#14110F"),
        ok: .init("#5BE3A0"), warn: .init("#FFB547"), danger: .init("#FF6B6B"),
        glassTint: .init(18, 26, 46, 0.55), glassSpec: .init(255, 255, 255, 0.10),
        strokeHair: .init(255, 255, 255, 0.08), strokeGlow: .init(255, 255, 255, 0.22),
        fill1: .init(255, 255, 255, 0.06), fill2: .init(255, 255, 255, 0.10), fill3: .init(255, 255, 255, 0.16),
        scrim: .init(6, 8, 13, 0.62), rim: .init(255, 255, 255, 0.14), segOn: .init(255, 255, 255, 0.14),
        accentGradFrom: .init("#6AB7FF"), accentGradTo: .init("#8BF3D8"),
        ctaFrom: .init("#6AB7FF"), ctaTo: .init("#8BF3D8"), ctaFg: .init("#04101A"),
        e1: .init(color: .init(0, 0, 0, 0.25), x: 0, y: 2, blur: 8),
        e2: .init(color: .init(0, 0, 0, 0.35), x: 0, y: 8, blur: 24),
        e3: .init(color: .init(0, 0, 0, 0.45), x: 0, y: 20, blur: 60)
    )

    public static let light = MRPalette(
        isDark: false,
        bg0: .init("#EDE9E1"), bg1: .init("#F4F1EB"), bg2: .init("#FFFFFF"),
        text1: .init("#14161C"), text2: .init("#424959"), text3: .init("#565E70"),
        accent1: .init("#1759E0"), accent2: .init("#18C7A0"),
        amber: .init("#FFB547"), paper: .init("#F5F0E6"), ink: .init("#14110F"),
        ok: .init("#08613F"), warn: .init("#8A4F05"), danger: .init("#BC2D2D"),
        glassTint: .init(255, 255, 255, 0.62), glassSpec: .init(255, 255, 255, 0.75),
        strokeHair: .init(20, 22, 28, 0.10), strokeGlow: .init(255, 255, 255, 0.95),
        fill1: .init(20, 22, 28, 0.05), fill2: .init(20, 22, 28, 0.08), fill3: .init(20, 22, 28, 0.13),
        scrim: .init(237, 233, 225, 0.66), rim: .init(20, 22, 28, 0.14), segOn: .init("#FFFFFF"),
        accentGradFrom: .init("#1E6BFF"), accentGradTo: .init("#18C7A0"),
        ctaFrom: .init("#1E6BFF"), ctaTo: .init("#1E6BFF"), ctaFg: .init("#FFFFFF"),
        e1: .init(color: .init(40, 34, 20, 0.10), x: 0, y: 2, blur: 8),
        e2: .init(color: .init(40, 34, 20, 0.14), x: 0, y: 8, blur: 24),
        e3: .init(color: .init(40, 34, 20, 0.20), x: 0, y: 20, blur: 60)
    )

    public static func resolve(_ scheme: ColorScheme) -> MRPalette { scheme == .dark ? .dark : .light }

    /// Every opaque token by name, for audits and tests.
    public var allTokens: [(name: String, token: MRColorToken)] {
        [("bg-0", bg0), ("bg-1", bg1), ("bg-2", bg2), ("text-1", text1), ("text-2", text2), ("text-3", text3),
         ("accent-1", accent1), ("accent-2", accent2), ("amber", amber), ("paper", paper), ("ink", ink),
         ("ok", ok), ("warn", warn), ("danger", danger)]
    }

    /// Every translucent / derived token by CSS variable name.
    public var layerTokens: [(name: String, token: MRColorToken)] {
        [("glass-tint", glassTint), ("glass-spec", glassSpec), ("stroke-hair", strokeHair), ("stroke-glow", strokeGlow),
         ("fill-1", fill1), ("fill-2", fill2), ("fill-3", fill3), ("scrim", scrim), ("rim", rim), ("seg-on", segOn), ("cta-fg", ctaFg)]
    }
}

public extension EnvironmentValues {
    /// Palette for the current color scheme.
    var mrPalette: MRPalette { MRPalette.resolve(colorScheme) }
}

public enum MRGradient {
    /// CSS `linear-gradient(135deg, a, b)` on a box: runs corner to corner on a square, and along the 135deg axis on any box.
    /// SwiftUI's unit-point gradients are corner to corner on the box, which is identical for squares and close otherwise;
    /// use `css(angle:)` on a sized shape for the exact CSS gradient line.
    public static func css135(_ a: Color, _ b: Color) -> LinearGradient {
        LinearGradient(colors: [a, b], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Exact CSS gradient-line endpoints for a box of `size` at `degrees` (0 = to top, 90 = to right).
    public static func cssPoints(degrees: Double, size: CGSize) -> (start: CGPoint, end: CGPoint) {
        let a = degrees * .pi / 180
        let dx = sin(a), dy = -cos(a)
        let len = abs(size.width * dx) + abs(size.height * dy)
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        return (CGPoint(x: c.x - dx * len / 2, y: c.y - dy * len / 2), CGPoint(x: c.x + dx * len / 2, y: c.y + dy * len / 2))
    }
}
