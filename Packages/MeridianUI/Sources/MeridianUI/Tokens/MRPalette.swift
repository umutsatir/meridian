import SwiftUI

public struct MRColorToken: Sendable, Hashable {
    public let hex: String
    public let rgb: RGB
    public var color: Color { Color(rgb) }

    init(_ hex: String) {
        guard let rgb = HexColor.parse(hex) else { preconditionFailure("Invalid token hex \(hex)") }
        self.hex = hex
        self.rgb = rgb
    }
}

/// Color tokens from PRD Appendix B. Dark is "Night Cabin", light is "Daybreak".
/// Paper, ink and amber are physical materials and stay the same in both themes.
public struct MRPalette: Sendable {
    public let isDark: Bool
    public let bg0, bg1, bg2: MRColorToken
    public let text1, text2, text3: MRColorToken
    public let accent1, accent2: MRColorToken
    public let amber, paper, ink: MRColorToken
    public let ok, warn, danger: MRColorToken

    /// Label color on a filled accent-1 surface.
    public var onAccent: MRColorToken { isDark ? bg0 : bg2 }

    public static let dark = MRPalette(
        isDark: true,
        bg0: .init("#06080D"), bg1: .init("#0B1020"), bg2: .init("#121A2E"),
        text1: .init("#F3F5FA"), text2: .init("#A9B2C7"), text3: .init("#96A0BA"),
        accent1: .init("#6AB7FF"), accent2: .init("#8BF3D8"),
        amber: .init("#FFB547"), paper: .init("#F5F0E6"), ink: .init("#14110F"),
        ok: .init("#5BE3A0"), warn: .init("#FFB547"), danger: .init("#FF6B6B")
    )

    public static let light = MRPalette(
        isDark: false,
        bg0: .init("#EDE9E1"), bg1: .init("#F4F1EB"), bg2: .init("#FFFFFF"),
        text1: .init("#14161C"), text2: .init("#424959"), text3: .init("#565E70"),
        accent1: .init("#1759E0"), accent2: .init("#18C7A0"),
        amber: .init("#FFB547"), paper: .init("#F5F0E6"), ink: .init("#14110F"),
        ok: .init("#08613F"), warn: .init("#8A4F05"), danger: .init("#BC2D2D")
    )

    public static func resolve(_ scheme: ColorScheme) -> MRPalette { scheme == .dark ? .dark : .light }

    /// Every token by name, for audits and tests.
    public var allTokens: [(name: String, token: MRColorToken)] {
        [("bg-0", bg0), ("bg-1", bg1), ("bg-2", bg2), ("text-1", text1), ("text-2", text2), ("text-3", text3),
         ("accent-1", accent1), ("accent-2", accent2), ("amber", amber), ("paper", paper), ("ink", ink),
         ("ok", ok), ("warn", warn), ("danger", danger)]
    }
}

public extension EnvironmentValues {
    /// Palette for the current color scheme.
    var mrPalette: MRPalette { MRPalette.resolve(colorScheme) }
}
