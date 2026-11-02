import SwiftUI

/// The torn perforation, as on a real ticket (S14A owner feedback: the stub comes off along the row of holes, it is not ripped like a sheet).
///
/// 40 holes (radius 2.1 pt, pitch 8 pt, x = 24 ... 336) leave 41 bridges (x = 12, 28 ... 332, 348). Tearing breaks the bridges one by one.
/// Along a torn stretch both edges are scalloped: the body edge bites up into the ticket at every hole, the stub edge bites down, and each broken bridge
/// leaves a tiny seeded nub on one side (0.3 - 0.8 pt) with a matching notch on the other. All coordinates are in the 360 x 600 pass space,
/// ascending in x.
public struct PerforationEdge: Sendable {
    public static let pitch: CGFloat = 8
    public static let holeRadius: CGFloat = 2.1
    public static let lineY: CGFloat = 450
    public static let holeCenters: [CGFloat] = Array(stride(from: CGFloat(24), through: 336, by: 8))
    public static let bridgeCenters: [CGFloat] = [12] + Array(stride(from: CGFloat(28), through: 332, by: 8)) + [348]
    /// Where the flat (not yet torn) body edge ends and the stub edge starts: they overlap by 1.8 pt so no hairline shows between them.
    static let bodyFlatY: CGFloat = 450.8
    static let stubFlatY: CGFloat = 449.0

    /// Lower edge of the ticket body (ascending x, x = 0 ... 360).
    public let body: [CGPoint]
    /// Upper edge of the stub.
    public let stub: [CGPoint]

    public init(seed: UInt64) {
        var rng = PaperRandom(seed: UInt32(truncatingIfNeeded: seed &* 0x9E37_79B1 &+ 0x7EA2))
        let r = Self.holeRadius, y0 = Self.lineY
        var b: [CGPoint] = [CGPoint(x: 0, y: y0)]
        var s: [CGPoint] = [CGPoint(x: 0, y: y0 + 0.15)]
        func bridge(at xb: CGFloat) {
            let mag = CGFloat(0.3 + rng.next() * 0.5)
            let stubKeeps = rng.next() < 0.5   // the nub stays on the stub (points up) or on the body (points down)
            b.append(CGPoint(x: xb, y: stubKeeps ? y0 - mag - 0.25 : y0 + mag))
            s.append(CGPoint(x: xb, y: stubKeeps ? y0 - mag : y0 + mag + 0.25))
        }
        bridge(at: 12)
        for (i, c) in Self.holeCenters.enumerated() {
            for k in 0...8 {
                let th = Double(k) / 8 * .pi
                let x = c - r * CGFloat(cos(th)), h = r * CGFloat(sin(th))
                b.append(CGPoint(x: x, y: y0 - h))
                s.append(CGPoint(x: x, y: y0 + 0.15 + h))
            }
            bridge(at: i == Self.holeCenters.count - 1 ? 348 : c + Self.pitch / 2)
        }
        b.append(CGPoint(x: 360, y: y0)); s.append(CGPoint(x: 360, y: y0 + 0.15))
        body = b; stub = s
    }

    /// Number of bridges the front has broken: those at or beyond `frontX` on the torn side.
    public static func brokenCount(frontX: CGFloat, grab: TearGrabSide) -> Int {
        bridgeCenters.filter { grab == .right ? $0 >= frontX - 1e-6 : $0 <= frontX + 1e-6 }.count
    }

    /// Where the separation ends: the last broken bridge (360 or 0 while none is broken). The front moves in 8 pt steps, one "tak" per bridge.
    public static func quantizedFront(frontX: CGFloat, grab: TearGrabSide) -> CGFloat {
        let broken = bridgeCenters.filter { grab == .right ? $0 >= frontX - 1e-6 : $0 <= frontX + 1e-6 }
        return grab == .right ? (broken.min() ?? 360) : (broken.max() ?? 0)
    }

    /// Torn stretch of the body edge, ascending x, from the front to the end of the pass.
    func tornBody(front f: CGFloat, grab: TearGrabSide) -> [CGPoint] { body.filter { grab == .right ? $0.x >= f - 1e-6 : $0.x <= f + 1e-6 } }
    func tornStub(front f: CGFloat, grab: TearGrabSide) -> [CGPoint] { stub.filter { grab == .right ? $0.x >= f - 1e-6 : $0.x <= f + 1e-6 } }

    /// Height of the stub's upper edge at `x` once the stretch beyond `front` is torn (flat, hidden under the body elsewhere).
    func stubTopY(at x: CGFloat, front f: CGFloat, grab: TearGrabSide) -> CGFloat {
        let torn = grab == .right ? x >= f - 1e-6 : x <= f + 1e-6
        guard torn else { return Self.stubFlatY }
        var lo = 0, hi = stub.count - 1
        while hi - lo > 1 { let m = (lo + hi) / 2; if stub[m].x <= x { lo = m } else { hi = m } }
        let a = stub[lo], b = stub[hi]
        return b.x == a.x ? a.y : a.y + (b.y - a.y) * (x - a.x) / (b.x - a.x)
    }
}

/// Geometry of a partial tear. All coordinates are in the 360 x 600 pass space.
public enum TicketTearGeometry {
    public struct Cut: Sendable {
        public var front: CGPoint          // where the separation ends (the last broken bridge)
        public var body: [CGPoint]         // polygon that stays on the pass (everything above the perforation)
        public var piece: [CGPoint]        // polygon of the stub strip (one strip over the whole width, hinged at the front)
        public var rim: [CGPoint]          // the torn edge of the body (white paper edge)
        public var stubRim: [CGPoint]      // the torn edge of the stub
        public var brokenBridges: Int
    }

    /// Front position of the raw front: `x_f = 360 (1 - p)` pulling from the right, `360 p` from the left.
    public static func frontX(progress p: Double, grab: TearGrabSide) -> CGFloat { grab == .right ? 360 * (1 - p) : 360 * p }

    public static func cut(seed: UInt64, progress p: Double, grab: TearGrabSide) -> Cut {
        cut(edges: PerforationEdge(seed: seed), progress: p, grab: grab)
    }

    public static func cut(edges: PerforationEdge, progress p: Double, grab: TearGrabSide) -> Cut {
        let torn = p >= 1
        let raw = frontX(progress: p, grab: grab)
        let f: CGFloat = torn ? (grab == .right ? 0 : 360) : PerforationEdge.quantizedFront(frontX: raw, grab: grab)
        let n = torn ? PerforationEdge.bridgeCenters.count : PerforationEdge.brokenCount(frontX: raw, grab: grab)
        let tb = edges.tornBody(front: f, grab: grab), ts = edges.tornStub(front: f, grab: grab)
        let bf = PerforationEdge.bodyFlatY, sf = PerforationEdge.stubFlatY
        let body: [CGPoint], piece: [CGPoint]
        var front = CGPoint(x: f, y: PerforationEdge.lineY)
        if n == 0 {
            body = [CGPoint(x: 0, y: 0), CGPoint(x: 360, y: 0), CGPoint(x: 360, y: bf), CGPoint(x: 0, y: bf)]
            piece = [CGPoint(x: 0, y: sf), CGPoint(x: 360, y: sf), CGPoint(x: 360, y: 600), CGPoint(x: 0, y: 600)]
        } else if grab == .right {
            front = tb.first ?? front
            body = [CGPoint(x: 0, y: 0), CGPoint(x: 360, y: 0)] + tb.reversed() + (f > 0 ? [CGPoint(x: f, y: bf), CGPoint(x: 0, y: bf)] : [])
            piece = [CGPoint(x: 0, y: sf)] + (f > 0 ? [CGPoint(x: f, y: sf)] : []) + ts + [CGPoint(x: 360, y: 600), CGPoint(x: 0, y: 600)]
        } else {
            front = tb.last ?? front
            body = [CGPoint(x: 0, y: 0), CGPoint(x: 360, y: 0)] + (f < 360 ? [CGPoint(x: 360, y: bf), CGPoint(x: f, y: bf)] : []) + tb.reversed()
            piece = ts + (f < 360 ? [CGPoint(x: f, y: sf), CGPoint(x: 360, y: sf)] : []) + [CGPoint(x: 360, y: 600), CGPoint(x: 0, y: 600)]
        }
        return Cut(front: front, body: body, piece: piece, rim: n == 0 ? [] : tb, stubRim: n == 0 ? [] : ts, brokenBridges: n)
    }

    /// Hinge angle of the stub in degrees (right-hand tear, clockwise positive) and the extra drift/drop of the whole stub while it is dragged.
    /// `pull` is the extra swing (degrees, positive = pulled down) from where the pointer is relative to where it grabbed.
    public static func piecePose(progress p: Double, grab: TearGrabSide, dy: CGFloat, pull: Double = 0) -> (degrees: Double, dx: CGFloat, dy: CGFloat) {
        let s: Double = grab == .right ? 1 : -1
        return (s * (TearState.stubAngle(atProgress: p) + pull), CGFloat(s) * CGFloat(p) * 14, 4 + CGFloat(p) * 22 + dy * 0.5)
    }

    /// Area of a polygon (shoelace).
    public static func area(_ pts: [CGPoint]) -> CGFloat {
        guard pts.count > 2 else { return 0 }
        var a: CGFloat = 0
        for i in pts.indices { let p = pts[i], q = pts[(i + 1) % pts.count]; a += p.x * q.y - q.x * p.y }
        return abs(a) / 2
    }
}
