import SwiftUI

/// CSS coverflow slot: `translateZ` / `rotateY` / `scale` about the card center inside a `perspective: 1100px`
/// container (origin at its center). Driven by the continuous offset from the selected card so the spring
/// animates positions smoothly (the canvas animates the transform only; left/top jump).
struct CoverflowEffect: GeometryEffect {
    var off: Double
    var reduceMotion = false

    var animatableData: Double {
        get { off }
        set { off = newValue }
    }

    private nonisolated struct Knot { var cx, cy, w, z, ry, s: Double }

    private nonisolated static func knot(_ k: Int) -> Knot {
        let a = abs(k)
        if k == 0 { return Knot(cx: 530, cy: 171, w: 480, z: 40, ry: 0, s: 1) }
        let mult = a == 1 ? 300.0 : 300.0 + Double(a - 1) * 120
        return Knot(cx: 530 + Double(k) * mult, cy: 161, w: 340, z: -60 * Double(a), ry: k > 0 ? -28 : 28,
                    s: a == 1 ? 0.84 : 0.7)
    }

    private nonisolated static func lerp(_ off: Double) -> Knot {
        let o = max(-5, min(5, off)), lo = Int(floor(o)), t = o - Double(lo)
        let x = knot(lo), y = knot(min(5, lo + 1))
        func m(_ a: Double, _ b: Double) -> Double { a + (b - a) * t }
        return Knot(cx: m(x.cx, y.cx), cy: m(x.cy, y.cy), w: m(x.w, y.w), z: m(x.z, y.z), ry: m(x.ry, y.ry), s: m(x.s, y.s))
    }

    /// Full CSS matrix of the slot for a (possibly fractional) offset; `size` is the card's layout size.
    nonisolated static func matrix(off: Double, size sz: CGSize) -> CSSMat4 {
        let k = lerp(off)
        let vs = (k.w / Double(sz.width)) * k.s
        let transform = CSSMat4.translate(0, 0, k.z) * CSSMat4.rotateY(k.ry) * CSSMat4.scale(vs)
        return CSSMat4.translate(530, 170, 0) * CSSMat4.perspective(1100) * CSSMat4.translate(-530, -170, 0)
            * CSSMat4.translate(k.cx, k.cy, 0) * transform * CSSMat4.translate(-Double(sz.width) / 2, -Double(sz.height) / 2, 0)
    }

    nonisolated func effectValue(size s: CGSize) -> ProjectionTransform {
        Self.matrix(off: reduceMotion ? off.rounded() : off, size: s).projection()
    }
}

/// Which coverflow slot a point in the 1060 x 340 coverflow area belongs to. SwiftUI hit-tests a card by its layout
/// frame (every card is laid out at the container origin and only moved by the `GeometryEffect`), and the card's own
/// tap handler swallowed taps anyway, so tapping a side card where it is drawn never selected it. The tap is therefore
/// resolved here against the projected card quads, front-most first (hero, then +-1, then +-2: the z-index order).
nonisolated enum CoverflowHitTest {
    static let layoutHero = CGSize(width: 480, height: 302), layoutSide = CGSize(width: 340, height: 214)

    /// Corners of the card at `offset` from the selection in coverflow coordinates (clockwise from top-left).
    static func quad(offset: Int) -> [CGPoint] {
        let sz = offset == 0 ? layoutHero : layoutSide
        let m = CoverflowEffect.matrix(off: Double(offset), size: sz).a
        return [CGPoint(x: 0, y: 0), CGPoint(x: sz.width, y: 0), CGPoint(x: sz.width, y: sz.height), CGPoint(x: 0, y: sz.height)].map { c in
            let x = Double(c.x), y = Double(c.y)
            let w = m[12] * x + m[13] * y + m[15]
            return CGPoint(x: (m[0] * x + m[1] * y + m[3]) / w, y: (m[4] * x + m[5] * y + m[7]) / w)
        }
    }

    static func contains(_ q: [CGPoint], _ p: CGPoint) -> Bool {
        var sign = 0.0
        for i in 0..<q.count {
            let a = q[i], b = q[(i + 1) % q.count]
            let c = Double((b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x))
            if c == 0 { continue }
            if sign == 0 { sign = c } else if sign * c < 0 { return false }
        }
        return true
    }

    /// Offset (-2...2) of the front-most card under `point`, or nil when none.
    static func offset(at point: CGPoint, selected: Int, count: Int) -> Int? {
        for off in [0, -1, 1, -2, 2] {
            let i = selected + off
            guard i >= 0, i < count else { continue }
            if contains(quad(offset: off), point) { return off }
        }
        return nil
    }

    /// Pointer position over the hero card in -0.5...0.5 (card-local, y down), or nil when `point` is not on the hero. At rest the
    /// hero quad is an axis-aligned rectangle (no rotation), so the unit position is a plain division; it deliberately ignores the
    /// card's own tilt so the hit area never moves under the pointer.
    static func heroPointer(at point: CGPoint) -> CGPoint? {
        let q = quad(offset: 0)
        let w = q[2].x - q[0].x, h = q[2].y - q[0].y
        guard w > 0, h > 0, point.x >= q[0].x, point.x <= q[2].x, point.y >= q[0].y, point.y <= q[2].y else { return nil }
        return CGPoint(x: (point.x - q[0].x) / w - 0.5, y: (point.y - q[0].y) / h - 0.5)
    }

    /// Index to select for a tap at (`x`, `y`); nil for the hero (it flips) or empty space.
    static func index(forX x: CGFloat, y: CGFloat, selected: Int, count: Int) -> Int? {
        guard let off = offset(at: CGPoint(x: x, y: y), selected: selected, count: count), off != 0 else { return nil }
        return selected + off
    }
}
