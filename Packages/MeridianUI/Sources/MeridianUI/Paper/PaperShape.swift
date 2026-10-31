import SwiftUI
import QuartzCore

public extension TornEdge {
    /// The canvas' seeded jagged tear line along y = 450 (Ticket.dc.html): x runs 360 -> 0, amplitude 1.5-2.5 pt.
    /// Same seed, same line, in JS and Swift.
    static func polyline(seed: UInt64, width: CGFloat = 360, y: CGFloat = 450) -> [CGPoint] {
        var r = PaperRandom(seed: UInt32(truncatingIfNeeded: seed))
        let amp = 1.5 + r.next() * 1.0
        var pts: [CGPoint] = []
        var x = width
        while x > -4 {
            pts.append(CGPoint(x: max(0, x), y: y - amp + r.next() * amp * 2))
            x -= 2.2 + r.next() * 3.4
        }
        return pts
    }

    /// `K.barcodePath`: PDF417-like stacked bar rows for a w x h area.
    static func barcode(seed: UInt64, width w: CGFloat, height h: CGFloat, rows: Int = 7) -> Path {
        var r = PaperRandom(seed: UInt32(truncatingIfNeeded: seed))
        let rh = h / CGFloat(rows), unit = w / 150
        var p = Path()
        func bar(_ x: CGFloat, _ y: CGFloat, _ wd: CGFloat) { p.addRect(CGRect(x: x, y: y, width: wd, height: rh - 0.6)) }
        for row in 0..<rows {
            var x: CGFloat = 0
            let y = CGFloat(row) * rh
            var on = true
            let st: [CGFloat] = [3, 1, 1, 1, 1, 1, 1, 3]
            for (i, s) in st.enumerated() { if i % 2 == 0 { bar(x, y, s * unit) }; x += s * unit }
            while x < w - 9 * unit {
                let wd = CGFloat(1 + Int(r.next() * 4)) * unit * CGFloat(0.9 + r.next() * 0.3)
                if on { bar(x, y, wd) }
                x += wd; on.toggle()
            }
            let sp: [CGFloat] = [7, 1, 1, 1, 1, 1, 2, 1]
            x = w - 17 * unit
            for (j, s) in sp.enumerated() { if j % 2 == 0 { bar(x, y, min(s, 3) * unit) }; x += s * unit * 0.7 }
        }
        return p
    }
}

/// The paper outline: radius 22, optional seeded torn bottom (or any clip polygon), 14 pt notches at y = 450 on both sides.
struct PaperShape: Shape {
    var height: CGFloat = 600
    var polygon: [CGPoint]? = nil
    var notches = true
    var notchY: CGFloat = 450

    func path(in rect: CGRect) -> Path {
        var p = Path(roundedRect: CGRect(x: 0, y: 0, width: 360, height: height), cornerRadius: MRRadius.ticket, style: .circular)
        if let polygon {
            var poly = Path()
            poly.addLines(polygon)
            poly.closeSubpath()
            p = p.intersection(poly)
        }
        if notches {
            var n = Path()
            let r: CGFloat = 13.75
            for x: CGFloat in [0, 360] { n.addEllipse(in: CGRect(x: x - r, y: notchY - r, width: 2 * r, height: 2 * r)) }
            p = p.subtracting(n)
        }
        return p
    }

    /// Clip polygon of a torn pass: (0,0) (360,0) tear line ... (0,450).
    static func tornPolygon(seed: UInt64) -> [CGPoint] {
        [CGPoint(x: 0, y: 0), CGPoint(x: 360, y: 0)] + TornEdge.polyline(seed: seed) + [CGPoint(x: 0, y: 450)]
    }
}

/// CSS `perspective(d) rotateX rotateY translateY(-lift)` about the center, as a projection.
struct PaperTilt: ViewModifier {
    var rx: Double, ry: Double, lift: CGFloat = 0
    var size: CGSize
    var perspective: CGFloat = 900
    /// Transform origin (CSS `transform-origin`), default center.
    var origin: CGPoint? = nil

    func body(content: Content) -> some View {
        content.projectionEffect(transform)
    }

    var transform: ProjectionTransform {
        var persp = CATransform3DIdentity
        persp.m34 = -1 / perspective
        var t = CATransform3DMakeTranslation(0, -lift, 0)
        t = CATransform3DConcat(t, CATransform3DMakeRotation(CGFloat(ry * .pi / 180), 0, 1, 0))
        t = CATransform3DConcat(t, CATransform3DMakeRotation(CGFloat(rx * .pi / 180), 1, 0, 0))
        t = CATransform3DConcat(t, persp)
        let o = origin ?? CGPoint(x: size.width / 2, y: size.height / 2)
        let m = CATransform3DConcat(CATransform3DConcat(CATransform3DMakeTranslation(-o.x, -o.y, 0), t),
                                    CATransform3DMakeTranslation(o.x, o.y, 0))
        return ProjectionTransform(m)
    }
}
