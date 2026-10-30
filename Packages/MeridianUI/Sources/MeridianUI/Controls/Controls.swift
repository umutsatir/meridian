import SwiftUI

// Small CSS components of meridian.css: .kbd .badge .av .eyebrow .pill .dotp .hr .bar .tip .toast

private func rgba(_ r: Int, _ g: Int, _ b: Int, _ a: Double) -> Color { MRColorToken(r, g, b, a).color }

// MARK: - .eyebrow

public extension View {
    /// `.eyebrow`: 11/14 medium, +.08em, uppercase, text-2.
    func mrEyebrow() -> some View { modifier(MREyebrow()) }
}

private struct MREyebrow: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content.mrText(.eyebrow).foregroundStyle(MRPalette.resolve(scheme).text2.color)
    }
}

// MARK: - .kbd

/// `.kbd`: 20 pt keycap, 11 medium, radius 6.
public struct MRKbd: View {
    private let text: String
    @Environment(\.colorScheme) private var scheme
    public init(_ text: String) { self.text = text }

    /// `color-mix(in srgb, var(--text-1) 80%, var(--text-2))`
    static func ink(_ p: MRPalette) -> RGB { p.text1.rgb.mixed(with: p.text2.rgb, amount: 0.2) }

    public var body: some View {
        let p = MRPalette.resolve(scheme)
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        Text(text)
            .font(.mr(.ui, size: 11, weight: 500))
            .tracking(11 * 0.02)
            .foregroundStyle(Color(Self.ink(p)))
            .padding(.horizontal, 5)
            .frame(minWidth: 20, minHeight: 20, maxHeight: 20)
            .background(p.fill1.color, in: shape)
            .overlay(shape.strokeBorder(p.strokeHair.color, lineWidth: 1))
    }
}

// MARK: - .badge

/// `.badge`: 20 pt gradient count.
public struct MRBadge: View {
    private let text: String
    @Environment(\.colorScheme) private var scheme
    public init(_ text: String) { self.text = text }
    public init(_ count: Int) { self.text = String(count) }

    public var body: some View {
        let p = MRPalette.resolve(scheme)
        let dark = scheme == .dark
        Text(text)
            .font(.mr(.ui, size: 11, weight: 600))
            .foregroundStyle(dark ? MRColorToken("#04101A").color : .white)
            .padding(.horizontal, 6)
            .frame(minWidth: 20, minHeight: 20, maxHeight: 20)
            .background {
                if dark { Capsule().fill(p.accentGradient) } else { Capsule().fill(MRColorToken("#1E6BFF").color) }
            }
    }
}

// MARK: - .av

/// `.av`: avatar circle with optional presence dot.
public struct MRAvatar: View {
    public enum Size: Sendable {
        case sm, regular, lg
        public var diameter: CGFloat { switch self { case .sm: 22; case .regular: 32; case .lg: 44 } }
        public var fontSize: CGFloat { switch self { case .sm: 10; case .regular: 13; case .lg: 17 } }
    }
    public enum Presence: Sendable { case none, online, idle, left }

    private let initials: String
    private let tint: Color
    private let size: Size
    private let presence: Presence
    @Environment(\.colorScheme) private var scheme

    public init(_ initials: String, tint: Color = MRScenarioColor.study.color, size: Size = .regular, presence: Presence = .none) {
        self.initials = initials; self.tint = tint; self.size = size; self.presence = presence
    }

    public var body: some View {
        let p = MRPalette.resolve(scheme)
        Text(initials)
            .font(.mr(.ui, size: size.fontSize, weight: 600))
            .foregroundStyle(MRColorToken("#04101A").color)
            .frame(width: size.diameter, height: size.diameter)
            .background(tint, in: Circle())
            .overlay(MRInsetShadow(Circle(), color: .white.opacity(0.45), y: 1))
            .overlay(alignment: .bottomTrailing) {
                if presence != .none {
                    Circle().fill(dotColor(p)).frame(width: 10, height: 10)
                        .overlay(Circle().stroke(p.bg1.color, lineWidth: 2).padding(-2))
                        .offset(x: 1, y: 1)
                }
            }
    }

    private func dotColor(_ p: MRPalette) -> Color {
        switch presence {
        case .online, .none: p.accent1.color
        case .idle: p.text3.color
        case .left: p.amber.color
        }
    }
}

// MARK: - .pill

/// `.pill`: 24 pt status capsule, 11 semibold, +.04em, uppercase.
public struct MRPill: View {
    public enum Kind: Sendable { case neutral, ok, warn, danger, accent }
    private let text: String
    private let kind: Kind
    private let pulsingDot: Bool
    @Environment(\.colorScheme) private var scheme

    public init(_ text: String, kind: Kind = .neutral, pulsingDot: Bool = false) {
        self.text = text; self.kind = kind; self.pulsingDot = pulsingDot
    }

    public var body: some View {
        let p = MRPalette.resolve(scheme)
        let dark = scheme == .dark
        let (bg, fg): (Color, Color) = {
            switch kind {
            case .neutral: return (p.fill2.color, p.text2.color)
            case .ok: return (dark ? rgba(91, 227, 160, 0.16) : rgba(14, 138, 90, 0.12), p.ok.color)
            case .warn: return (dark ? rgba(255, 181, 71, 0.16) : rgba(168, 98, 10, 0.12), p.warn.color)
            case .danger: return (dark ? rgba(255, 107, 107, 0.16) : rgba(209, 59, 59, 0.10), p.danger.color)
            case .accent: return (dark ? rgba(106, 183, 255, 0.16) : rgba(30, 107, 255, 0.10), p.accentPillText.color)
            }
        }()
        HStack(spacing: 6) {
            if pulsingDot { MRDot(pulsing: true) }
            Text(text).font(.mr(.ui, size: 11, weight: 600)).tracking(11 * 0.04).textCase(.uppercase)
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// `.mx-pillamb`: amber boarding pill with the expanding `mx-boarding` ring (1.6 s).
public struct MRBoardingPill: View {
    private let text: String
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var on = false
    public init(_ text: String) { self.text = text }

    public var body: some View {
        let p = MRPalette.resolve(scheme)
        let shape = Capsule()
        Text(text)
            .font(.mr(.ui, size: 11, weight: 700)).tracking(11 * 0.1).textCase(.uppercase)
            .foregroundStyle(MRColorToken("#14110F").color)
            .padding(.horizontal, 10)
            .frame(height: 22)
            .background(shape.fill(p.amber.color))
            .overlay(shape.strokeBorder(.white.opacity(0.45), lineWidth: 1))
            .background {
                shape.fill(p.amber.color.opacity(on ? 0 : 0.55)).padding(on ? -7 : 0)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { on = true }
            }
    }
}

// MARK: - .dotp / .pulse

/// `.dotp`: 8 pt dot in the current foreground color; `pulsing` runs `mx-pulse` (1.6 s, opacity 1→.4, scale 1→.8).
public struct MRDot: View {
    private let pulsing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false
    public init(pulsing: Bool = false) { self.pulsing = pulsing }

    public var body: some View {
        Circle().fill(.foreground).frame(width: 8, height: 8)
            .opacity(pulsing && dim ? 0.4 : 1)
            .scaleEffect(pulsing && dim ? 0.8 : 1)
            .onAppear {
                guard pulsing, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { dim = true }
            }
    }
}

// MARK: - .hr

/// `.hr`: 1 pt hairline.
public struct MRDivider: View {
    @Environment(\.colorScheme) private var scheme
    public init() {}
    public var body: some View {
        MRPalette.resolve(scheme).strokeHair.color.frame(height: 1)
    }
}

// MARK: - .bar

/// `.bar`: 4 pt progress track with gradient fill.
public struct MRProgressBar: View {
    private let value: Double
    @Environment(\.colorScheme) private var scheme
    public init(_ value: Double) { self.value = min(1, max(0, value)) }

    public var body: some View {
        let p = MRPalette.resolve(scheme)
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(p.fill2.color)
                Capsule().fill(p.accentGradient).frame(width: geo.size.width * value)
            }
        }
        .frame(height: 4)
        .accessibilityElement()
        .accessibilityValue("\(Int((value * 100).rounded())) percent")
    }
}

// MARK: - .tip

/// `.tip`: tooltip, 12 medium, radius 10, e2.
public struct MRTooltip: View {
    private let text: String
    private let key: String?
    @Environment(\.colorScheme) private var scheme
    public init(_ text: String, key: String? = nil) { self.text = text; self.key = key }

    public var body: some View {
        let p = MRPalette.resolve(scheme)
        let dark = scheme == .dark
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        HStack(spacing: 8) {
            Text(text).font(.mr(.ui, size: 12, weight: 500))
            if let key { MRKbd(key) }
        }
        .foregroundStyle(dark ? p.text1.color : MRColorToken("#F3F5FA").color)
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(dark ? rgba(18, 26, 46, 0.92) : rgba(20, 22, 28, 0.92), in: shape)
        .overlay(shape.strokeBorder(p.strokeHair.color, lineWidth: 1))
        .shadow(color: p.e2.color.color, radius: p.e2.radius, x: p.e2.x, y: p.e2.y)
    }
}

// MARK: - .toast

/// `.toast` on `.glass.e3`: 34 pt tinted icon disc, 14 semibold title, radius 18.
public struct MRToast: View {
    private let title: String
    private let message: String?
    private let icon: MRIconName
    private let tint: KeyPath<MRPalette, MRColorToken>
    @Environment(\.colorScheme) private var scheme

    public init(_ title: String, message: String? = nil, icon: MRIconName = .check, tint: KeyPath<MRPalette, MRColorToken> = \.ok) {
        self.title = title; self.message = message; self.icon = icon; self.tint = tint
    }

    public var body: some View {
        let p = MRPalette.resolve(scheme)
        let t = p[keyPath: tint]
        HStack(spacing: 12) {
            MRIcon(icon, size: 18)
                .foregroundStyle(t.color)
                .frame(width: 34, height: 34)
                .background(Circle().fill(t.opacity(0.16)))
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.mr(.ui, size: 14, weight: 600)).lineSpacing(0)
                if let message {
                    Text(message).font(.mr(.ui, size: 12, weight: 400)).foregroundStyle(p.text2.color)
                }
            }
            .foregroundStyle(p.text1.color)
        }
        .padding(.leading, 14).padding(.trailing, 16).padding(.vertical, 12)
        .mrGlass(cornerRadius: 18, elevation: .e3)
    }
}
