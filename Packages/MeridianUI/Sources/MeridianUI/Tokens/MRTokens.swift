import SwiftUI

/// One place for the product name (PRD §10.4); Meridian is a working name (Q1).
public enum MRBrand {
    public static let name = "Meridian"
}

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

public enum MRRadius {
    public static let window: CGFloat = 26
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
    case display, title1, title2, headline, body, callout, caption

    public var size: CGFloat {
        switch self {
        case .display: 56
        case .title1: 34
        case .title2: 24
        case .headline: 17
        case .body: 15
        case .callout: 13
        case .caption: 11
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
        case .caption: 14
        }
    }

    public var weight: Font.Weight {
        switch self {
        case .display: .bold
        case .title1, .title2: .semibold
        case .headline: .semibold
        case .body, .callout, .caption: .regular
        }
    }
}

public enum MRFontVariant: Sendable {
    /// SF Pro.
    case standard
    /// SF Pro Condensed (codes, split-flap).
    case condensed
    /// SF Mono (countdowns, flight numbers).
    case mono
    /// New York (ceremonial moments).
    case serif
}

public extension MRTextStyle {
    func font(_ variant: MRFontVariant = .standard) -> Font {
        switch variant {
        case .standard: .system(size: size, weight: weight, design: .default)
        case .condensed: .system(size: size, weight: weight, design: .default).width(.condensed)
        case .mono: .system(size: size, weight: weight, design: .monospaced)
        case .serif: .system(size: size, weight: weight, design: .serif)
        }
    }

    /// Extra line spacing so a line measures `lineHeight`, assuming the system default of about 1.2 × size.
    var extraLineSpacing: CGFloat { max(0, lineHeight - size * 1.2) }
}

public extension View {
    func mrText(_ style: MRTextStyle, _ variant: MRFontVariant = .standard) -> some View {
        font(style.font(variant)).lineSpacing(style.extraLineSpacing)
    }
}

public enum MRMotion {
    /// Durations in seconds (PRD Appendix B: 120/200/320/520/900–1400 ms).
    public static let instant: TimeInterval = 0.12
    public static let fast: TimeInterval = 0.20
    public static let base: TimeInterval = 0.32
    public static let slow: TimeInterval = 0.52
    public static let cinematicRange: ClosedRange<TimeInterval> = 0.9...1.4
    public static let durations: [TimeInterval] = [instant, fast, base, slow, cinematicRange.lowerBound, cinematicRange.upperBound]

    // Spring parameters are provisional: the canvas' F3 board is not available offline.
    public static var snappy: Animation { .spring(response: 0.28, dampingFraction: 0.86) }
    public static var smooth: Animation { .spring(response: 0.45, dampingFraction: 1.0) }
    public static var bouncy: Animation { .spring(response: 0.50, dampingFraction: 0.62) }
    public static var heavy: Animation { .spring(response: 0.75, dampingFraction: 0.80) }
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
