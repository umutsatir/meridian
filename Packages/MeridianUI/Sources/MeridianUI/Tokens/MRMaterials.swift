import SwiftUI

private func stops(_ list: [(String, Double)]) -> Gradient {
    Gradient(stops: list.map { .init(color: MRColorToken($0.0).color, location: $0.1) })
}

/// Cabin-class foils (`--foil-*`, 90deg) as hex stops, for audits; `gradient` builds the SwiftUI value.
public enum MRFoil: CaseIterable, Sendable {
    case economy, premium, business, first, long

    public var stopList: [(hex: String, at: Double)] {
        switch self {
        case .economy: [("#868FA0", 0), ("#D6DCE6", 0.28), ("#9AA3B3", 0.52), ("#CBD1DC", 0.78), ("#868FA0", 1)]
        case .premium: [("#79BDFB", 0), ("#DCF0FF", 0.38), ("#6FAEEA", 0.68), ("#BFE2FF", 1)]
        case .business: [("#C29A52", 0), ("#F3DFAA", 0.34), ("#B98E3F", 0.62), ("#ECD59C", 1)]
        case .first: [("#E4D7B8", 0), ("#FFFCF2", 0.38), ("#D5C49A", 0.70), ("#F8F1DE", 1)]
        case .long: [("#8BF3D8", 0), ("#6AB7FF", 0.25), ("#B49CFF", 0.50), ("#FF8FB1", 0.75), ("#FFB86B", 1)]
        }
    }

    public var gradient: LinearGradient {
        LinearGradient(gradient: stops(stopList.map { ($0.hex, $0.at) }), startPoint: .leading, endPoint: .trailing)
    }
}

/// Sky gradients by sun elevation (`--sky-*`, 180deg).
public enum MRSky: CaseIterable, Sendable {
    case night, blue, sunset, day, overcast

    public var stopList: [(hex: String, at: Double)] {
        switch self {
        case .night: [("#04060F", 0), ("#0B1430", 1)]
        case .blue: [("#101B3D", 0), ("#3B4C8F", 1)]
        case .sunset: [("#2B2A5C", 0), ("#FF8A5B", 0.62), ("#FFD9A0", 1)]
        case .day: [("#4C97E8", 0), ("#BFE0FF", 1)]
        case .overcast: [("#7C8798", 0), ("#C9D0DA", 1)]
        }
    }

    public var gradient: LinearGradient {
        LinearGradient(gradient: stops(stopList.map { ($0.hex, $0.at) }), startPoint: .top, endPoint: .bottom)
    }
}

/// Ink-on-paper stamp colors (`--stamp-*`); tickets look identical in both themes.
public enum MRStamp {
    public static let ok = MRColorToken("#08613F")
    public static let warn = MRColorToken("#8C4B08")
    public static let blue = MRColorToken("#243F8F")
    public static let red = MRColorToken("#A82A24")
}

/// Map palette (`--m-*`) for each map style and theme, plus the globe (`--gl-*`).
public struct MRMapPalette: Sendable {
    public let sea, land, land2, line, grat, label: MRColorToken

    public enum Style: String, CaseIterable, Sendable { case terra, mono, standard, satellite }

    public static func resolve(_ style: Style, dark: Bool) -> MRMapPalette {
        switch (style, dark) {
        case (.terra, true): MRMapPalette(sea: .init("#080D1A"), land: .init("#18213B"), land2: .init("#1F2A49"), line: .init(255, 255, 255, 0.075), grat: .init(255, 255, 255, 0.035), label: .init(243, 245, 250, 0.62))
        case (.terra, false): MRMapPalette(sea: .init("#E3E1D8"), land: .init("#FBF9F4"), land2: .init("#F3F0E8"), line: .init(20, 22, 28, 0.12), grat: .init(20, 22, 28, 0.05), label: .init(20, 22, 28, 0.7))
        case (.mono, true): MRMapPalette(sea: .init("#090C13"), land: .init("#D8D6CE"), land2: .init("#ECEAE3"), line: .init(20, 17, 15, 0.32), grat: .init(255, 255, 255, 0.05), label: .init(20, 17, 15, 0.76))
        case (.mono, false): MRMapPalette(sea: .init("#EFECE4"), land: .init("#FFFFFF"), land2: .init("#F6F4EE"), line: .init(20, 22, 28, 0.28), grat: .init(255, 255, 255, 0.05), label: .init(20, 22, 28, 0.72))
        case (.standard, true): MRMapPalette(sea: .init("#0E2133"), land: .init("#1D3835"), land2: .init("#2B4C44"), line: .init(255, 255, 255, 0.12), grat: .init(255, 255, 255, 0.04), label: .init(243, 245, 250, 0.62))
        case (.standard, false): MRMapPalette(sea: .init("#BCD7EA"), land: .init("#E8EEDC"), land2: .init("#F2F5E8"), line: .init(20, 22, 28, 0.16), grat: .init(255, 255, 255, 0.04), label: .init(20, 22, 28, 0.72))
        case (.satellite, _): MRMapPalette(sea: .init("#0A2536"), land: .init("#26402C"), land2: .init("#31503A"), line: .init(255, 255, 255, 0.22), grat: .init(255, 255, 255, 0.05), label: .init(255, 255, 255, 0.78))
        }
    }

    /// Globe (`--gl-*`).
    public struct Globe: Sendable {
        public let seaA, seaB, land, edge: MRColorToken
        public let shade, rim: Double
        public static let dark = Globe(seaA: .init("#14203F"), seaB: .init("#050816"), land: .init("#1E2A4B"), edge: .init(190, 205, 255, 0.28), shade: 0.5, rim: 0.5)
        public static let light = Globe(seaA: .init("#DCE8F3"), seaB: .init("#A8C2DB"), land: .init("#FBF9F4"), edge: .init(20, 22, 28, 0.22), shade: 0.2, rim: 0.25)
    }
}

/// `.glass` material numbers: `blur(40px) saturate(1.6)`, 135deg specular gradient over the tint, 1 px hairline, inner top highlight, elevation shadow.
public enum MRGlass {
    public static let blur: CGFloat = 40
    public static let saturation: Double = 1.6
    /// Specular overlay stops (`linear-gradient(135deg, spec 0%, rgba(255,255,255,.015) 38%, rgba(255,255,255,.05) 100%)`).
    public static let specMid = MRColorToken(255, 255, 255, 0.015)
    public static let specEnd = MRColorToken(255, 255, 255, 0.05)
    public static let specMidAt = 0.38
    /// `.glass-ctl` hover / pressed white wash opacity (dark, light).
    public static func hoverWash(dark: Bool) -> Double { dark ? 0.06 : 0.5 }
    public static let pressedWash: Double = 0.03
    /// `.chip` backdrop blur.
    public static let chipBlur: CGFloat = 20
}

/// Focus ring (`outline:2px solid var(--accent-1); outline-offset:2px`).
public enum MRFocus {
    public static let width: CGFloat = 2
    public static let offset: CGFloat = 2
}
