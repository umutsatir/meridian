import SwiftUI

/// How the stub strip bends while it is pulled off. Everything is computed in "u-space": the tear runs from u = 360 towards 0
/// (a right-hand tear is x = u, a left-hand tear is mirrored, x = 360 - u). Angles are degrees, clockwise (the free end drops) positive.
///
/// The stub is one strip of paper over the whole width. It is hinged where the separation ends (`front`): left of the hinge it is still attached
/// and flat; over `bendLength` it curves smoothly into the hinge angle; right of the hinge it is free and keeps that angle plus a gentle curl.
struct StubBend {
    static let step: CGFloat = 3
    var front: CGFloat            // u-space hinge position (separation ends here), 360 = nothing torn yet, 0 = fully torn
    var hinge: Double
    var curl: Double              // extra angle gained over the free length
    var bendLength: CGFloat = 30

    var bendStart: CGFloat { max(0, front - bendLength) }

    func angle(at s: CGFloat) -> Double {
        if s <= bendStart { return 0 }
        if s < front {
            let t = Double((s - bendStart) / max(1, front - bendStart))
            return hinge * (t * t * (3 - 2 * t))
        }
        return hinge + curl * pow(Double((s - front) / 360), 1.25)
    }

    /// Positions of the stub's top-edge line at every `step` along u (index i = s = i * step) and the angle of each cell.
    func frames() -> (pos: [CGPoint], phi: [Double]) {
        let n = Int((360 / Self.step).rounded())
        var pos = [CGPoint(x: 0, y: 450)], phi: [Double] = []
        for i in 0..<n {
            let a = angle(at: (CGFloat(i) + 0.5) * Self.step)
            phi.append(a)
            let r = a * .pi / 180
            pos.append(CGPoint(x: pos[i].x + Self.step * CGFloat(cos(r)), y: pos[i].y + Self.step * CGFloat(sin(r))))
        }
        return (pos, phi)
    }
}

/// One slice of the stub: a clip polygon in pass space and the transform that puts it where the bent paper is.
struct StubStrip {
    var transform: CGAffineTransform
    var poly: [CGPoint]
    var top: [CGPoint]
    var free: Bool
    var shade: Double
    var merged = false
}

struct StubPoseInfo {
    var strips: [StubStrip]
    /// Centre of the stub (pass space, mirrored for a left-hand tear), used as anchor of the flight.
    var center: CGPoint
}

enum TearRender {
    static let mirror = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 360, ty: 0)

    static func pose(edges: PerforationEdge, front f: CGFloat, grab: TearGrabSide, hinge: Double, curl: Double, bendLength: CGFloat = 30) -> StubPoseInfo {
        let left = grab == .left
        let uFront = left ? 360 - f : f
        let bend = StubBend(front: uFront, hinge: hinge, curl: curl, bendLength: bendLength)
        let fr = bend.frames()
        let st = StubBend.step
        let n = fr.phi.count
        let m = left ? mirror : .identity
        var strips: [StubStrip] = []
        let sa = bend.bendStart
        let first = Int((sa / st).rounded(.down))
        func topPoly(_ x0: CGFloat, _ x1: CGFloat) -> [CGPoint] {
            var pts = [CGPoint(x: x0, y: edges.stubTopY(at: x0, front: f, grab: grab))]
            for q in edges.stub where q.x > x0 && q.x < x1 {
                if (grab == .right ? q.x >= f - 1e-6 : q.x <= f + 1e-6) { pts.append(q) }
            }
            pts.append(CGPoint(x: x1, y: edges.stubTopY(at: x1, front: f, grab: grab)))
            return pts
        }
        func make(_ x0: CGFloat, _ x1: CGFloat, _ t: CGAffineTransform, free: Bool, shade: Double, merged: Bool = false) -> StubStrip {
            let top = topPoly(x0, x1)
            return StubStrip(transform: t, poly: top + [CGPoint(x: x1, y: 601), CGPoint(x: x0, y: 601)], top: top, free: free, shade: shade, merged: merged)
        }
        // attached, flat part (one slice, identity transform)
        if first > 0 {
            let ua = CGFloat(first) * st
            let (x0, x1) = left ? (360 - ua, CGFloat(360)) : (0, ua + 0.4)
            strips.append(make(x0, x1, .identity, free: false, shade: 0, merged: true))
        }
        for i in first..<n {
            let u0 = CGFloat(i) * st, u1 = u0 + st
            let mid = (u0 + u1) / 2
            let phi = fr.phi[i]
            // position/angle at the strip centre: midpoint of the two frame points
            let p = CGPoint(x: (fr.pos[i].x + fr.pos[i + 1].x) / 2, y: (fr.pos[i].y + fr.pos[i + 1].y) / 2)
            let home = CGAffineTransform(translationX: -mid, y: -450)
                .concatenating(CGAffineTransform(rotationAngle: CGFloat(phi * .pi / 180)))
                .concatenating(CGAffineTransform(translationX: p.x, y: p.y))
            let t = m.concatenating(home).concatenating(m)
            let (ua, ub) = (u0 - 0.45, u1 + 0.45)
            let (x0, x1) = left ? (360 - ub, 360 - ua) : (ua, ub)
            // darker where the paper bends, a little where it is tilted
            let curvature = abs(angle(bend, (CGFloat(i) + 1) * st) - angle(bend, CGFloat(i) * st)) / Double(st)
            let shade = min(0.38, 0.5 * curvature + 0.004 * abs(phi))
            strips.append(make(max(0, x0), min(360, x1), t, free: mid >= uFront, shade: shade))
        }
        // centre of the stub
        let ci = min(n - 1, 60)
        let cp = CGPoint(x: (fr.pos[ci].x + fr.pos[ci + 1].x) / 2, y: (fr.pos[ci].y + fr.pos[ci + 1].y) / 2)
        let ph = fr.phi[ci] * .pi / 180
        var c = CGPoint(x: cp.x - 75 * CGFloat(sin(ph)), y: cp.y + 75 * CGFloat(cos(ph)))
        if left { c.x = 360 - c.x }
        return StubPoseInfo(strips: strips, center: c)
    }

    private static func angle(_ b: StubBend, _ s: CGFloat) -> Double { b.angle(at: s) }

    // MARK: drawing

    static func polygon(_ pts: [CGPoint]) -> Path {
        var p = Path(); p.addLines(pts); p.closeSubpath(); return p
    }

    /// The silhouette of the bent stub (for its shadow).
    static func silhouette(_ strips: [StubStrip], free: Bool?) -> Path {
        var path = Path()
        for s in strips where free == nil || s.free == free {
            path.addPath(polygon(s.poly).applying(s.transform))
        }
        return path
    }

    static func drawStub(_ ctx: GraphicsContext, image: Image, strips: [StubStrip], opacity: Double = 1, shadowOnAttached: Bool = false) {
        let img = ctx.resolve(image)
        func draw(_ s: StubStrip) {
            if s.shade > 0.012 {
                ctx.drawLayer { l in
                    l.opacity = opacity
                    l.concatenate(s.transform)
                    l.clip(to: polygon(s.poly))
                    l.draw(img, in: CGRect(x: 0, y: 0, width: 360, height: 600))
                    var o = l
                    o.blendMode = .sourceAtop
                    o.fill(Path(CGRect(x: -10, y: 440, width: 380, height: 180)), with: .color(Color(red: 0.24, green: 0.19, blue: 0.12).opacity(s.shade)))
                }
            } else {
                var l = ctx
                l.opacity = opacity
                l.concatenate(s.transform)
                l.clip(to: polygon(s.poly))
                l.draw(img, in: CGRect(x: 0, y: 0, width: 360, height: 600))
            }
        }
        if shadowOnAttached {
            // the lifted part shades the paper it came off
            strips.filter { !$0.free }.forEach(draw)
            ctx.drawLayer { l in
                l.addFilter(.shadow(color: .black.opacity(0.28), radius: 5, x: 0, y: 3, options: .shadowOnly))
                l.fill(silhouette(strips, free: true), with: .color(.black))
            }
            strips.filter { $0.free }.forEach(draw)
        } else {
            strips.forEach(draw)
        }
        // white paper edge along the torn top edge
        for s in strips where s.top.count > 2 && s.top[0].x > 14 && s.top[s.top.count - 1].x < 346 {
            var l = ctx
            l.opacity = 0.9 * opacity
            l.concatenate(s.transform)
            var top = Path(); top.addLines(s.top)
            l.stroke(top, with: .color(.white), style: StrokeStyle(lineWidth: 1.0, lineJoin: .round))
        }
    }

    /// Hairs of paper fibre at the broken bridges.
    static func fibres(edges: PerforationEdge, front f: CGFloat, grab: TearGrabSide, seed: UInt64) -> Path {
        var path = Path()
        for (k, xb) in PerforationEdge.bridgeCenters.enumerated() where (grab == .right ? xb >= f - 1e-6 : xb <= f + 1e-6) {
            var rng = PaperRandom(seed: UInt32(truncatingIfNeeded: seed &+ UInt64(k) &* 7919))
            guard let q = edges.body.first(where: { abs($0.x - xb) < 1e-6 }) else { continue }
            let n = 1 + Int(rng.next() * 2.2)
            for _ in 0..<n {
                let a = (rng.next() - 0.5) * 1.4 + .pi / 2          // mostly down, slightly sideways
                let len = CGFloat(1.0 + rng.next() * 2.0)
                path.move(to: q)
                path.addLine(to: CGPoint(x: q.x + len * CGFloat(cos(a)), y: q.y + len * CGFloat(sin(a))))
            }
        }
        return path
    }
}
