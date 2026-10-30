import SwiftUI

/// The four map styles of the design (`.map[data-map=...]`).
public enum MapStyle: String, Sendable, CaseIterable, Hashable {
    case terra, mono, standard, satellite
}

/// Dark / light theme of the design (`[data-theme]`).
public enum MapTheme: Sendable, Hashable {
    case dark, light

    init(_ scheme: ColorScheme) { self = scheme == .light ? .light : .dark }
}

/// sRGB colour with alpha, kept as numbers so palettes mirror `meridian.css` one to one.
struct RGBA: Sendable, Hashable {
    var r: Double, g: Double, b: Double, a: Double

    init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) { self.r = r / 255; self.g = g / 255; self.b = b / 255; self.a = a }
    init(hex: UInt32, a: Double = 1) {
        self.init(Double((hex >> 16) & 0xFF), Double((hex >> 8) & 0xFF), Double(hex & 0xFF), a)
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
    func with(alpha: Double) -> RGBA { var c = self; c.a = alpha; return c }
}

/// The map palette: `--m-sea --m-land --m-land-2 --m-line --m-grat --m-label` of `meridian.css`,
/// resolved for a style + theme exactly as the cascade does.
struct MapPalette: Sendable, Hashable {
    var sea: RGBA, land: RGBA, land2: RGBA, line: RGBA, grat: RGBA, label: RGBA

    static func resolve(style: MapStyle, theme: MapTheme) -> MapPalette {
        let white = { (a: Double) in RGBA(255, 255, 255, a) }
        switch (style, theme) {
        // :root / [data-theme="dark"] and [data-theme="light"] values (terra is the cascade default)
        case (.terra, .dark):
            return MapPalette(sea: RGBA(hex: 0x080D1A), land: RGBA(hex: 0x18213B), land2: RGBA(hex: 0x1F2A49),
                              line: white(0.075), grat: white(0.035), label: RGBA(243, 245, 250, 0.62))
        case (.terra, .light):
            return MapPalette(sea: RGBA(hex: 0xE3E1D8), land: RGBA(hex: 0xFBF9F4), land2: RGBA(hex: 0xF3F0E8),
                              line: RGBA(20, 22, 28, 0.12), grat: RGBA(20, 22, 28, 0.05), label: RGBA(20, 22, 28, 0.7))
        // [data-map="mono"]; the light override does not set --m-grat, so it stays white .05
        case (.mono, .dark):
            return MapPalette(sea: RGBA(hex: 0x090C13), land: RGBA(hex: 0xD8D6CE), land2: RGBA(hex: 0xECEAE3),
                              line: RGBA(20, 17, 15, 0.32), grat: white(0.05), label: RGBA(20, 17, 15, 0.76))
        case (.mono, .light):
            return MapPalette(sea: RGBA(hex: 0xEFECE4), land: RGBA(hex: 0xFFFFFF), land2: RGBA(hex: 0xF6F4EE),
                              line: RGBA(20, 22, 28, 0.28), grat: white(0.05), label: RGBA(20, 22, 28, 0.72))
        // [data-map="standard"]; light override leaves --m-grat at white .04
        case (.standard, .dark):
            return MapPalette(sea: RGBA(hex: 0x0E2133), land: RGBA(hex: 0x1D3835), land2: RGBA(hex: 0x2B4C44),
                              line: white(0.12), grat: white(0.04), label: RGBA(243, 245, 250, 0.62))
        case (.standard, .light):
            return MapPalette(sea: RGBA(hex: 0xBCD7EA), land: RGBA(hex: 0xE8EEDC), land2: RGBA(hex: 0xF2F5E8),
                              line: RGBA(20, 22, 28, 0.16), grat: white(0.04), label: RGBA(20, 22, 28, 0.72))
        // [data-map="satellite"] has no light override
        case (.satellite, _):
            return MapPalette(sea: RGBA(hex: 0x0A2536), land: RGBA(hex: 0x26402C), land2: RGBA(hex: 0x31503A),
                              line: white(0.22), grat: white(0.05), label: white(0.78))
        }
    }
}

/// Globe tokens (`--gl-*`) plus the few global tokens the Globe component reads.
struct GlobePalette: Sendable, Hashable {
    var seaA: RGBA, seaB: RGBA, land: RGBA
    var shade: Double, rim: Double
    var edge: RGBA
    var accent: RGBA     // --accent-1, colour of the visited layers
    var bg0: RGBA        // --bg-0, outline of pins and halo of labels
    var text1: RGBA      // --text-1, label colour
    var map: MapPalette  // graticule and border colours come from the (terra) map tokens

    static func resolve(theme: MapTheme) -> GlobePalette {
        switch theme {
        case .dark:
            return GlobePalette(seaA: RGBA(hex: 0x14203F), seaB: RGBA(hex: 0x050816), land: RGBA(hex: 0x1E2A4B),
                                shade: 0.5, rim: 0.5, edge: RGBA(190, 205, 255, 0.28),
                                accent: RGBA(hex: 0x6AB7FF), bg0: RGBA(hex: 0x06080D), text1: RGBA(hex: 0xF3F5FA),
                                map: .resolve(style: .terra, theme: .dark))
        case .light:
            return GlobePalette(seaA: RGBA(hex: 0xDCE8F3), seaB: RGBA(hex: 0xA8C2DB), land: RGBA(hex: 0xFBF9F4),
                                shade: 0.2, rim: 0.25, edge: RGBA(20, 22, 28, 0.22),
                                accent: RGBA(hex: 0x1759E0), bg0: RGBA(hex: 0xEDE9E1), text1: RGBA(hex: 0x14161C),
                                map: .resolve(style: .terra, theme: .light))
        }
    }
}

/// Font names used for map text. The canvas uses Inter (labels) and Barlow Condensed (globe pins);
/// register the files (the app bundles them) and these resolve, otherwise SwiftUI falls back to the system font.
public enum MapFonts {
    nonisolated(unsafe) public static var ui = "Inter"
    nonisolated(unsafe) public static var condensed = "BarlowCondensed-Bold"
}
