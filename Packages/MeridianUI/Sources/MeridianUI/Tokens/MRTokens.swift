import SwiftUI

/// One place for the product name (PRD §10.4); Meridian is a working name (Q1).
public enum MRBrand {
    public static let name = "Meridian"
}

/// 4pt grid, meridian.css `--s-1 … --s-16`.
public enum MRSpacing {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let s: CGFloat = 12
    public static let m: CGFloat = 16
    public static let l: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48
    public static let xxxl: CGFloat = 64
    public static let all: [CGFloat] = [xxs, xs, s, m, l, xl, xxl, xxxl]
}

/// meridian.css `--r-*`.
public enum MRRadius {
    public static let window: CGFloat = 26
    public static let sidebar: CGFloat = 18
    public static let panel: CGFloat = 28
    public static let card: CGFloat = 20
    public static let control: CGFloat = 14
    public static let ticket: CGFloat = 22
    public static let ticketNotch: CGFloat = 14
}

/// Senaryo (focus type) colors. Always pair with an icon and label (PRD COL-2).
public enum MRScenarioColor {
    public static let study = MRColorToken("#7AA2FF")
    public static let work = MRColorToken("#FFB86B")
    public static let read = MRColorToken("#7ADDB2")
    public static let create = MRColorToken("#FF8FB1")
    public static let code = MRColorToken("#B49CFF")
    public static let meditate = MRColorToken("#8EE3E8")
    public static let fitness = MRColorToken("#FF9B7A")
    public static let other = MRColorToken("#C7CCDA")
}

public enum MRTextStyle: CaseIterable, Sendable {
    case display, title1, title2, headline, body, callout, caption, eyebrow

    /// font-size in points (CSS px).
    public var size: CGFloat {
        switch self {
        case .display: 56
        case .title1: 34
        case .title2: 24
        case .headline: 17
        case .body: 15
        case .callout: 13
        case .caption, .eyebrow: 11
        }
    }

    public var lineHeight: CGFloat {
        switch self {
        case .display: 60
        case .title1: 40
        case .title2: 30
        case .headline: 22
        case .body: 22
        case .callout: 18
        case .caption, .eyebrow: 14
        }
    }

    /// CSS font-weight.
    public var cssWeight: Int {
        switch self {
        case .display, .title1, .title2, .headline: 600
        case .body, .callout: 400
        case .caption, .eyebrow: 500
        }
    }

    public var weight: Font.Weight {
        switch cssWeight {
        case 600: .semibold
        case 500: .medium
        default: .regular
        }
    }

    /// letter-spacing in em (`.t-display{-.012em}` …).
    public var tracking: CGFloat {
        switch self {
        case .display: -0.012
        case .title1: -0.008
        case .title2: -0.004
        case .caption: 0.02
        case .eyebrow: 0.08
        case .headline, .body, .callout: 0
        }
    }

    /// `text-transform: uppercase` (`.t-caption`, `.eyebrow`).
    public var isUppercase: Bool { self == .caption || self == .eyebrow }
}

public enum MRFontVariant: Sendable {
    /// Inter (`--font-ui`).
    case standard
    /// Barlow Condensed (`--font-cond`; codes, tags, split-flap). CSS default: weight 700, +.01em.
    case condensed
    /// JetBrains Mono (`--font-mono`; countdowns, flight numbers). CSS default: weight 500, tabular.
    case mono
    /// Newsreader (`--font-serif`; ceremonial moments). CSS default: weight 500.
    case serif

    var family: MRFonts.Family {
        switch self {
        case .standard: .ui
        case .condensed: .condensed
        case .mono: .mono
        case .serif: .serif
        }
    }

    /// Weight the CSS class (`.cond`, `.mono`, `.serif`) applies when none is given.
    var defaultWeight: Int? {
        switch self {
        case .standard: nil
        case .condensed: 700
        case .mono, .serif: 500
        }
    }

    /// Letter-spacing in em the CSS class adds.
    var tracking: CGFloat? { self == .condensed ? 0.01 : nil }
}

public extension MRTextStyle {
    /// Font for this style in a family. `weight` overrides the CSS weight (e.g. `font:400 12px var(--font-mono)`).
    func font(_ variant: MRFontVariant = .standard, weight override: Int? = nil) -> Font {
        MRFonts.font(variant.family, size: size, weight: override ?? variant.defaultWeight ?? cssWeight)
    }

    /// Extra line spacing so a line measures `lineHeight`, from the real font metrics.
    func extraLineSpacing(_ variant: MRFontVariant = .standard, weight override: Int? = nil) -> CGFloat {
        let natural = MRFonts.naturalLineHeight(variant.family, size: size, weight: override ?? variant.defaultWeight ?? cssWeight)
        return lineHeight - natural
    }

    /// Letter-spacing in points for the style in a variant.
    func trackingPoints(_ variant: MRFontVariant = .standard) -> CGFloat {
        (variant.tracking ?? (variant == .standard ? tracking : 0)) * size
    }
}

public extension View {
    /// Applies a canvas type style: bundled font, exact weight, line-height, letter-spacing and case.
    func mrText(_ style: MRTextStyle, _ variant: MRFontVariant = .standard, weight: Int? = nil) -> some View {
        font(style.font(variant, weight: weight))
            .lineSpacing(style.extraLineSpacing(variant, weight: weight))
            .tracking(style.trackingPoints(variant))
            .textCase(style.isUppercase && variant == .standard ? .uppercase : nil)
    }
}

/// meridian.css motion tokens: `--d1…--d6`, `--ease`, `--ease-accel`, springs (F3 board: response · damping).
public enum MRMotion {
    /// Durations in seconds: 120/200/320/520/900/1400 ms.
    public static let d1: TimeInterval = 0.12
    public static let d2: TimeInterval = 0.20
    public static let d3: TimeInterval = 0.32
    public static let d4: TimeInterval = 0.52
    public static let d5: TimeInterval = 0.90
    public static let d6: TimeInterval = 1.40

    public static let instant = d1
    public static let fast = d2
    public static let base = d3
    public static let slow = d4
    public static let cinematicRange: ClosedRange<TimeInterval> = d5...d6
    public static let durations: [TimeInterval] = [d1, d2, d3, d4, d5, d6]

    /// `--ease: cubic-bezier(.2,0,0,1)`
    public static func ease(_ duration: TimeInterval = d2) -> Animation { .timingCurve(0.2, 0, 0, 1, duration: duration) }
    /// `--ease-accel: cubic-bezier(.3,0,.8,.15)`
    public static func easeAccel(_ duration: TimeInterval = d2) -> Animation { .timingCurve(0.3, 0, 0.8, 0.15, duration: duration) }

    /// Spring parameters (response, damping ratio) from the F3 board.
    public static let snappyParams = (response: 0.32, damping: 0.82)   // toggles, chips, tag select
    public static let smoothParams = (response: 0.50, damping: 0.86)   // sheets, card return, ticket settle
    public static let bouncyParams = (response: 0.55, damping: 0.68)   // card flip, stamps, unlock
    public static let heavyParams = (response: 0.70, damping: 0.90)    // panels, wallet-in, big travel

    public static var snappy: Animation { .spring(response: snappyParams.response, dampingFraction: snappyParams.damping) }
    public static var smooth: Animation { .spring(response: smoothParams.response, dampingFraction: smoothParams.damping) }
    public static var bouncy: Animation { .spring(response: bouncyParams.response, dampingFraction: bouncyParams.damping) }
    public static var heavy: Animation { .spring(response: heavyParams.response, dampingFraction: heavyParams.damping) }
}

private struct MRAnimationModifier<V: Equatable>: ViewModifier {
    let animation: Animation
    let value: V
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

public extension View {
    /// Animates only when Reduce Motion is off.
    func mrAnimation<V: Equatable>(_ animation: Animation = MRMotion.smooth, value: V) -> some View {
        modifier(MRAnimationModifier(animation: animation, value: value))
    }
}
