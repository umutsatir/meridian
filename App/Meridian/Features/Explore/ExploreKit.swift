import MeridianUI
import SwiftUI

// Small building blocks shared by the Map, Stats and Year-in-flight screens. The canvas lays these screens out with
// absolutely positioned boxes; `exAt` does the same (offset, no layout effect) inside a top-leading ZStack.

extension View {
    /// `position:absolute; left:x; top:y`.
    func exAt(_ x: CGFloat, _ y: CGFloat) -> some View { offset(x: x, y: y) }
    /// Fixed box, content pinned to the top leading corner (`overflow` is visible).
    func exBox(_ w: CGFloat, _ h: CGFloat) -> some View { frame(width: w, height: h, alignment: .topLeading) }
}

/// A text run with CSS-style fixed line height (the line box is centred on the glyphs, like half-leading).
struct ExT: View {
    let s: String
    var fam: MRFonts.Family = .ui
    var size: CGFloat
    var weight: Int = 500
    var lh: CGFloat
    var color: Color
    var em: CGFloat = 0
    var upper = false
    var italic = false
    var wrap: CGFloat?
    var align: TextAlignment = .leading
    var grad: LinearGradient?

    var body: some View {
        let t = Text(upper ? s.uppercased() : s)
            .font(MRFonts.font(fam, size: size, weight: weight, italic: italic))
            .tracking(em * size)
            .foregroundStyle(grad.map { AnyShapeStyle($0) } ?? AnyShapeStyle(color))
        if let wrap {
            let natural = MRFonts.naturalLineHeight(fam, size: size, weight: weight)
            t.lineSpacing(lh - natural).multilineTextAlignment(align).frame(width: wrap, alignment: align == .center ? .center : .leading).fixedSize(horizontal: false, vertical: true)
        } else {
            t.lineLimit(1).fixedSize().frame(height: lh)
        }
    }
}

/// `.eyebrow` at a custom size (Stats cards use 10/12).
struct ExEyebrow: View {
    let s: String
    var size: CGFloat = 11
    var lh: CGFloat = 14
    @Environment(\.mrPalette) private var p
    var body: some View { ExT(s: s, size: size, weight: 500, lh: lh, color: p.text2.color, em: 0.08, upper: true) }
}

/// `radial-gradient(rx% ry% at cx% cy%, color, transparent stop)` on a box.
struct ExGlow: View {
    var rx: CGFloat, ry: CGFloat, cx: CGFloat, cy: CGFloat
    var color: Color
    var stop: CGFloat = 0.7
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width * cx, y: size.height * cy)
            let rW = size.width * rx, rH = size.height * ry
            var g = ctx
            g.translateBy(x: c.x, y: c.y)
            g.scaleBy(x: rW, y: rH)
            let grad = Gradient(stops: [.init(color: color, location: 0), .init(color: color.opacity(0), location: stop)])
            g.fill(Path(CGRect(x: -3, y: -3, width: 6, height: 6)), with: .radialGradient(grad, center: .zero, startRadius: 0, endRadius: 1))
        }
        .allowsHitTesting(false)
    }
}

/// The `.glass.e2` card of the Stats bento: 24 pt radius, clipped content.
struct ExCard<Content: View>: View {
    let w: CGFloat, h: CGFloat
    var radius: CGFloat = 24
    var elevation: MRElevation = .e2
    @ViewBuilder var content: () -> Content
    var body: some View {
        ZStack(alignment: .topLeading) { content() }
            .frame(width: w, height: h, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .mrGlass(cornerRadius: radius, elevation: elevation)
    }
}

/// `.ss-h`: 42/46 serif page title with an eyebrow above.
struct ExPageHeader: View {
    let eyebrow: String
    let title: String
    var onEyebrow: (() -> Void)?
    @Environment(\.mrPalette) private var p
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let onEyebrow {
                Button(action: onEyebrow) { ExEyebrow(s: eyebrow) }.buttonStyle(.plain).accessibilityLabel("Back to Stats")
            } else {
                ExEyebrow(s: eyebrow)
            }
            ExT(s: title, fam: .serif, size: 42, weight: 500, lh: 46, color: p.text1.color, em: -0.02)
        }
    }
}

/// Mountain mark of the streak badge (`viewBox 0 0 26 22`, drawn 18 x 16, "meet").
nonisolated struct ExPeakShape: Shape {
    func path(in rect: CGRect) -> Path {
        let k = min(rect.width / 26, rect.height / 22)
        let ox = rect.minX + (rect.width - 26 * k) / 2, oy = rect.minY + (rect.height - 22 * k) / 2
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * k, y: oy + y * k) }
        var p = Path()
        p.move(to: pt(3, 18)); p.addLine(to: pt(13, 4)); p.addLine(to: pt(23, 18))
        p.move(to: pt(8, 18)); p.addLine(to: pt(13, 11)); p.addLine(to: pt(18, 18))
        return p
    }
}

/// Empty state shown by the three screens when there are no landed flights yet.
struct ExEmptyState: View {
    let icon: MRIconName
    let title: String
    let message: String
    @Environment(\.mrPalette) private var p
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(p.fill2.color).frame(width: 64, height: 64)
                MRIcon(icon, size: 28).foregroundStyle(p.text2.color)
            }
            ExT(s: title, size: 17, weight: 600, lh: 22, color: p.text1.color)
            ExT(s: message, size: 13, weight: 400, lh: 18, color: p.text2.color, wrap: 320, align: .center)
        }
        .accessibilityElement(children: .combine)
    }
}
