import MeridianUI
import SwiftUI

/// Shared helpers for the onboarding canvas (Onboarding.dc.html). Every screen is laid out on the
/// design's 1280x800 canvas with absolute positions, exactly like the HTML.

let obCanvasWidth: CGFloat = 1280
let obCanvasHeight: CGFloat = 800

/// Localized text from the onboarding String Catalog (`Onboarding.xcstrings`). English text is the key.
func OT(_ key: LocalizedStringKey) -> Text { Text(key, tableName: "Onboarding") }

extension View {
    /// `position:absolute; left:x; top:y` inside a top-leading ZStack.
    func obAt(_ x: CGFloat, _ y: CGFloat) -> some View { offset(x: x, y: y) }

    /// CSS `font: weight size/lh family` with letter-spacing in em. The line box is exactly `lh` tall
    /// per line (half-leading above and below, as CSS does).
    func obType(_ family: MRFonts.Family = .ui, _ size: CGFloat, _ weight: Int = 400, lh: CGFloat? = nil,
                tracking em: CGFloat = 0, italic: Bool = false) -> some View {
        modifier(OBTypeModifier(family: family, size: size, weight: weight, lh: lh, em: em, italic: italic))
    }
}

private struct OBTypeModifier: ViewModifier {
    let family: MRFonts.Family
    let size: CGFloat
    let weight: Int
    let lh: CGFloat?
    let em: CGFloat
    let italic: Bool

    func body(content: Content) -> some View {
        let natural = MRFonts.naturalLineHeight(family, size: size, weight: weight)
        let extra = (lh ?? natural) - natural
        content
            .font(.mr(family, size: size, weight: weight, italic: italic))
            .tracking(em * size)
            .lineSpacing(extra)
            .padding(.vertical, extra / 2)
    }
}

/// CSS `radial-gradient(rx ry at cx cy, color, transparent stop)` with percentage radii.
struct OBGlow: View {
    let cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat
    let color: Color
    let stop: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: cx * size.width, y: cy * size.height)
            let t = CGAffineTransform(translationX: c.x, y: c.y).scaledBy(x: max(rx * size.width, 1), y: max(ry * size.height, 1))
            ctx.concatenate(t)
            let rect = CGRect(origin: .zero, size: size).applying(t.inverted())
            let g = Gradient(stops: [.init(color: color, location: 0), .init(color: color.opacity(0), location: stop)])
            ctx.fill(Path(rect), with: .radialGradient(g, center: .zero, startRadius: 0, endRadius: 1))
        }
        .allowsHitTesting(false)
    }
}

func obRGBA(_ r: Double, _ g: Double, _ b: Double, _ a: Double) -> Color {
    Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: a)
}

/// `.ob-link`: quiet 13 medium text link (text-3, text-1 on hover, focus ring).
struct OBLink: View {
    let title: LocalizedStringKey
    var icon: MRIconName? = nil
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isFocused) private var focused
    @State private var hovered = false

    var body: some View {
        let p = MRPalette.resolve(scheme)
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { MRIcon(icon, size: 14) }
                OT(title).obType(.ui, 13, 500, lh: 13)
            }
            .foregroundStyle(hovered ? p.text1.color : p.text3.color)
            .padding(.horizontal, 2).padding(.vertical, 6)
            .contentShape(Rectangle())
            .mrFocusRing(focused, cornerRadius: 6, color: p.accent1.color)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(MRMotion.ease(MRMotion.d2), value: hovered)
    }
}

/// `.iata` badge (amber, condensed 14).
struct OBIata: View {
    let code: String
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let p = MRPalette.resolve(scheme)
        Text(code)
            .font(.mr(.condensed, size: 14, weight: 700)).tracking(14 * 0.05)
            .foregroundStyle(p.ink.color)
            .frame(minWidth: 46).frame(height: 26)
            .padding(.horizontal, 6)
            .background(p.amber.color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// seeded generator of the kit (`MeridianKit.rng`, mulberry32).
struct OBRandom {
    private var a: UInt32
    init(seed: UInt32) { a = seed }
    mutating func next() -> Double {
        a = a &+ 0x6D2B79F5
        var t = (a ^ (a >> 15)) &* (1 | a)
        t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
        return Double(t ^ (t >> 14)) / 4294967296.0
    }
}

/// Namespace shim so call sites read `MRColorToken.hex("#…")` for design-literal colors.
extension MRColorToken {
    static func hex(_ s: String) -> Color { Color(hex: s) }
}
