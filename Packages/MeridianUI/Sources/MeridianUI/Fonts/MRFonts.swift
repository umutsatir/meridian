import SwiftUI
import CoreText

/// Bundled canvas fonts (ADR 0008, all OFL): Inter, Barlow Condensed, JetBrains Mono, Newsreader.
/// Registered for the process on first use; call `MRFonts.register()` at launch to be explicit.
public enum MRFonts {
    public enum Family: String, CaseIterable, Sendable {
        case ui = "Inter"
        case condensed = "Barlow Condensed"
        case mono = "JetBrains Mono"
        case serif = "Newsreader"
    }

    /// File names (without extension) in `Resources/Fonts`.
    static let files = [
        "Inter-Variable", "JetBrainsMono-Variable", "Newsreader-Variable", "Newsreader-Italic-Variable",
        "BarlowCondensed-Medium", "BarlowCondensed-SemiBold", "BarlowCondensed-Bold",
    ]

    private static let registered: Bool = {
        var ok = true
        for name in files {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts") else { ok = false; continue }
            var error: Unmanaged<CFError>?
            // Already-registered is not a failure.
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                let code = error.map { CFErrorGetCode($0.takeUnretainedValue()) } ?? 0
                if code != CFIndex(CTFontManagerError.alreadyRegistered.rawValue) { ok = false }
            }
        }
        return ok
    }()

    /// Registers the bundled fonts with CoreText for this process. Idempotent. Returns false if any file failed.
    @discardableResult
    public static func register() -> Bool { registered }

    // MARK: Building fonts

    private static func tag(_ s: String) -> Int { s.utf8.reduce(0) { ($0 << 8) | Int($1) } }
    private static let wght = tag("wght"), opsz = tag("opsz")

    /// A CoreText font for the family at an exact CSS weight (100...900) and size. Variable axes (weight, optical size) are set directly,
    /// so 500 and 600 are real instances, not rounded to a system weight.
    public static func ctFont(_ family: Family, size: CGFloat, weight: Int, italic: Bool = false) -> CTFont {
        _ = registered
        switch family {
        case .ui:
            return variable("Inter", size: size, weight: weight, opsz: min(32, max(14, Double(size))), features: Self.uiFeatures)
        case .mono:
            return variable("JetBrains Mono", size: size, weight: weight, opsz: nil, features: [])
        case .serif:
            let name = italic ? "Newsreader Italic" : "Newsreader"
            return variable(name, size: size, weight: weight, opsz: min(72, max(6, Double(size))), features: [])
        case .condensed:
            let ps = weight >= 650 ? "BarlowCondensed-Bold" : weight >= 550 ? "BarlowCondensed-SemiBold" : "BarlowCondensed-Medium"
            return CTFontCreateWithName(ps as CFString, size, nil)
        }
    }

    /// `.mx{font-feature-settings:"tnum" 1,"cv11" 1}`
    private static let uiFeatures: [(String, Int)] = [("tnum", 1), ("cv11", 1)]

    private static func variable(_ name: String, size: CGFloat, weight: Int, opsz o: Double?, features: [(String, Int)]) -> CTFont {
        var variation: [Int: Double] = [wght: Double(weight)]
        if let o { variation[opsz] = o }
        var attrs: [CFString: Any] = [
            kCTFontFamilyNameAttribute: name,
            kCTFontVariationAttribute: variation,
        ]
        if !features.isEmpty {
            attrs[kCTFontFeatureSettingsAttribute] = features.map { [kCTFontOpenTypeFeatureTag: $0.0, kCTFontOpenTypeFeatureValue: $0.1] as [CFString: Any] }
        }
        let desc = CTFontDescriptorCreateWithAttributes(attrs as CFDictionary)
        return CTFontCreateWithFontDescriptor(desc, size, nil)
    }

    /// SwiftUI font for the family at a CSS weight.
    public static func font(_ family: Family, size: CGFloat, weight: Int, italic: Bool = false) -> Font {
        Font(ctFont(family, size: size, weight: weight, italic: italic))
    }

    /// Natural single-line height of the font (ascent + descent + leading); used to turn a CSS `line-height` into SwiftUI line spacing.
    public static func naturalLineHeight(_ family: Family, size: CGFloat, weight: Int = 400) -> CGFloat {
        let f = ctFont(family, size: size, weight: weight)
        return CTFontGetAscent(f) + CTFontGetDescent(f) + CTFontGetLeading(f)
    }

    /// The PostScript/family names CoreText resolves for a family, for tests.
    public static func resolvedFamilyName(_ family: Family) -> String {
        CTFontCopyFamilyName(ctFont(family, size: 14, weight: 400)) as String
    }
}

public extension Font {
    /// `Font` from a bundled family at an exact CSS weight.
    static func mr(_ family: MRFonts.Family, size: CGFloat, weight: Int = 400, italic: Bool = false) -> Font {
        MRFonts.font(family, size: size, weight: weight, italic: italic)
    }
}
