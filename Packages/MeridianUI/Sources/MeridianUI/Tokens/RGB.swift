import SwiftUI

public struct RGB: Sendable, Hashable {
    public var r: Double
    public var g: Double
    public var b: Double
    public var a: Double

    public init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    /// WCAG relative luminance.
    public var relativeLuminance: Double {
        func lin(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    /// WCAG contrast ratio (1...21), ignoring alpha.
    public func contrastRatio(with other: RGB) -> Double {
        let (a, b) = (relativeLuminance, other.relativeLuminance)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}

public enum HexColor {
    /// Parses `#RRGGBB`, `RRGGBB`, `#RRGGBBAA` (case-insensitive). Returns nil for anything else.
    public static func parse(_ string: String) -> RGB? {
        var s = string.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8, s.allSatisfy(\.isHexDigit), let value = UInt64(s, radix: 16) else { return nil }
        let hasAlpha = s.count == 8
        let shift: (UInt64) -> Double = { Double((value >> $0) & 0xFF) / 255 }
        return hasAlpha
            ? RGB(r: shift(24), g: shift(16), b: shift(8), a: shift(0))
            : RGB(r: shift(16), g: shift(8), b: shift(0))
    }
}

public extension Color {
    init(_ rgb: RGB) {
        self.init(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: rgb.a)
    }

    /// Falls back to clear for an invalid hex string; use `HexColor.parse` to validate first.
    init(hex: String) {
        self.init(HexColor.parse(hex).map(Color.init) ?? .clear)
    }
}
