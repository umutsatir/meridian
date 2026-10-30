import SwiftUI

/// SVG path-data parser (SVG 1.1 §8): M L H V C S Q T A Z, absolute and relative, implicit command repeats,
/// compact numbers (`.5.5`, `1-2`, `1e-3`) and compact arc flags (`a1 1 0 001 2`).
/// Public so the map renderer can reuse it. Coordinates stay in the path's own space (y down, like SwiftUI).
public enum SVGPath {
    public enum Segment: Equatable, Sendable {
        case move(CGPoint)
        case line(CGPoint)
        case cubic(CGPoint, CGPoint, CGPoint)
        case quad(CGPoint, CGPoint)
        case close
    }

    /// Parses path data into a SwiftUI `Path`. Malformed trailing data is ignored (SVG error handling: render up to the error).
    public static func parse(_ d: String) -> Path {
        var path = Path()
        for s in segments(d) {
            switch s {
            case .move(let p): path.move(to: p)
            case .line(let p): path.addLine(to: p)
            case .cubic(let c1, let c2, let p): path.addCurve(to: p, control1: c1, control2: c2)
            case .quad(let c, let p): path.addQuadCurve(to: p, control: c)
            case .close: path.closeSubpath()
            }
        }
        return path
    }

    /// Parses path data into absolute move/line/cubic/quad/close segments (arcs become cubics).
    public static func segments(_ d: String) -> [Segment] {
        var scanner = Scanner(Array(d.utf8))
        var out: [Segment] = []
        var cur = CGPoint.zero, start = CGPoint.zero
        var lastCubicCtl: CGPoint?, lastQuadCtl: CGPoint?
        var cmd: UInt8 = 0
        var first = true

        while true {
            scanner.skipSeparators()
            if scanner.atEnd { break }
            let c = scanner.peek
            if c.isCommandLetter {
                cmd = c
                scanner.advance()
                if (cmd == UInt8(ascii: "Z") || cmd == UInt8(ascii: "z")) {
                    out.append(.close)
                    cur = start
                    lastCubicCtl = nil; lastQuadCtl = nil
                    first = false
                    continue
                }
            } else if cmd == 0 || cmd == UInt8(ascii: "Z") || cmd == UInt8(ascii: "z") {
                break // number without a command
            }
            // The first command must be a moveto.
            if first && cmd != UInt8(ascii: "M") && cmd != UInt8(ascii: "m") { break }
            first = false

            let rel = cmd >= UInt8(ascii: "a")
            let upper = rel ? cmd - 32 : cmd
            func abs(_ p: CGPoint) -> CGPoint { rel ? CGPoint(x: cur.x + p.x, y: cur.y + p.y) : p }

            switch upper {
            case UInt8(ascii: "M"):
                guard let x = scanner.number(), let y = scanner.number() else { return out }
                cur = abs(CGPoint(x: x, y: y)); start = cur
                out.append(.move(cur))
                cmd = rel ? UInt8(ascii: "l") : UInt8(ascii: "L") // implicit lineto
                lastCubicCtl = nil; lastQuadCtl = nil
            case UInt8(ascii: "L"):
                guard let x = scanner.number(), let y = scanner.number() else { return out }
                cur = abs(CGPoint(x: x, y: y))
                out.append(.line(cur))
                lastCubicCtl = nil; lastQuadCtl = nil
            case UInt8(ascii: "H"):
                guard let x = scanner.number() else { return out }
                cur = CGPoint(x: rel ? cur.x + x : x, y: cur.y)
                out.append(.line(cur))
                lastCubicCtl = nil; lastQuadCtl = nil
            case UInt8(ascii: "V"):
                guard let y = scanner.number() else { return out }
                cur = CGPoint(x: cur.x, y: rel ? cur.y + y : y)
                out.append(.line(cur))
                lastCubicCtl = nil; lastQuadCtl = nil
            case UInt8(ascii: "C"):
                guard let a = scanner.number(), let b = scanner.number(), let c = scanner.number(),
                      let d = scanner.number(), let e = scanner.number(), let f = scanner.number() else { return out }
                let c1 = abs(CGPoint(x: a, y: b)), c2 = abs(CGPoint(x: c, y: d)), p = abs(CGPoint(x: e, y: f))
                out.append(.cubic(c1, c2, p))
                cur = p; lastCubicCtl = c2; lastQuadCtl = nil
            case UInt8(ascii: "S"):
                guard let c = scanner.number(), let d = scanner.number(), let e = scanner.number(), let f = scanner.number() else { return out }
                let c1 = lastCubicCtl.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let c2 = abs(CGPoint(x: c, y: d)), p = abs(CGPoint(x: e, y: f))
                out.append(.cubic(c1, c2, p))
                cur = p; lastCubicCtl = c2; lastQuadCtl = nil
            case UInt8(ascii: "Q"):
                guard let a = scanner.number(), let b = scanner.number(), let c = scanner.number(), let d = scanner.number() else { return out }
                let q = abs(CGPoint(x: a, y: b)), p = abs(CGPoint(x: c, y: d))
                out.append(.quad(q, p))
                cur = p; lastQuadCtl = q; lastCubicCtl = nil
            case UInt8(ascii: "T"):
                guard let c = scanner.number(), let d = scanner.number() else { return out }
                let q = lastQuadCtl.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let p = abs(CGPoint(x: c, y: d))
                out.append(.quad(q, p))
                cur = p; lastQuadCtl = q; lastCubicCtl = nil
            case UInt8(ascii: "A"):
                guard let rx = scanner.number(), let ry = scanner.number(), let rot = scanner.number(),
                      let large = scanner.flag(), let sweep = scanner.flag(),
                      let x = scanner.number(), let y = scanner.number() else { return out }
                let p = abs(CGPoint(x: x, y: y))
                out.append(contentsOf: arc(from: cur, to: p, rx: rx, ry: ry, rotation: rot, large: large, sweep: sweep))
                cur = p; lastCubicCtl = nil; lastQuadCtl = nil
            default:
                return out
            }
        }
        return out
    }

    // MARK: Arcs (SVG 1.1 implementation notes F.6)

    static func arc(from p0: CGPoint, to p1: CGPoint, rx rxIn: Double, ry ryIn: Double, rotation: Double, large: Bool, sweep: Bool) -> [Segment] {
        if p0 == p1 { return [] }
        var rx = Swift.abs(rxIn), ry = Swift.abs(ryIn)
        if rx == 0 || ry == 0 { return [.line(p1)] }
        let phi = rotation * .pi / 180
        let cosP = cos(phi), sinP = sin(phi)
        let dx2 = (p0.x - p1.x) / 2, dy2 = (p0.y - p1.y) / 2
        let x1p = cosP * dx2 + sinP * dy2
        let y1p = -sinP * dx2 + cosP * dy2
        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 { let s = lambda.squareRoot(); rx *= s; ry *= s }
        let num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
        let den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
        var coef = den == 0 ? 0 : (max(0, num / den)).squareRoot()
        if large == sweep { coef = -coef }
        let cxp = coef * rx * y1p / ry
        let cyp = -coef * ry * x1p / rx
        let cx = cosP * cxp - sinP * cyp + (p0.x + p1.x) / 2
        let cy = sinP * cxp + cosP * cyp + (p0.y + p1.y) / 2

        func angle(_ ux: Double, _ uy: Double, _ vx: Double, _ vy: Double) -> Double {
            let dot = ux * vx + uy * vy
            let len = (ux * ux + uy * uy).squareRoot() * (vx * vx + vy * vy).squareRoot()
            var a = acos(max(-1, min(1, dot / len)))
            if ux * vy - uy * vx < 0 { a = -a }
            return a
        }
        let theta1 = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
        var dTheta = angle((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
        if !sweep && dTheta > 0 { dTheta -= 2 * .pi }
        if sweep && dTheta < 0 { dTheta += 2 * .pi }

        let n = max(1, Int((Swift.abs(dTheta) / (.pi / 2) - 1e-9).rounded(.up)))
        let delta = dTheta / Double(n)
        let t = 4.0 / 3.0 * tan(delta / 4)
        var segs: [Segment] = []
        var th = theta1
        func pt(_ a: Double) -> (Double, Double, Double, Double) { // point and derivative direction on the unit ellipse
            (cos(a), sin(a), -sin(a), cos(a))
        }
        func map(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: cosP * rx * x - sinP * ry * y + cx, y: sinP * rx * x + cosP * ry * y + cy)
        }
        for i in 0..<n {
            let (c1x, s1y, _, _) = pt(th)
            let (c2x, s2y, _, _) = pt(th + delta)
            let a = map(c1x - t * s1y, s1y + t * c1x)
            let b = map(c2x + t * s2y, s2y - t * c2x)
            let end = i == n - 1 ? p1 : map(c2x, s2y)
            segs.append(.cubic(a, b, end))
            th += delta
        }
        return segs
    }

    // MARK: Scanner

    private struct Scanner {
        let b: [UInt8]
        var i = 0
        init(_ bytes: [UInt8]) { b = bytes }
        var atEnd: Bool { i >= b.count }
        var peek: UInt8 { b[i] }
        mutating func advance() { i += 1 }

        mutating func skipSeparators() {
            while i < b.count, b[i] == 32 || b[i] == 9 || b[i] == 10 || b[i] == 13 || b[i] == 44 { i += 1 }
        }

        /// A single `0` or `1` arc flag (may be glued to the next token).
        mutating func flag() -> Bool? {
            skipSeparators()
            guard i < b.count, b[i] == 48 || b[i] == 49 else { return nil }
            defer { i += 1 }
            return b[i] == 49
        }

        mutating func number() -> Double? {
            skipSeparators()
            let s = i
            var j = i
            if j < b.count, b[j] == 43 || b[j] == 45 { j += 1 }
            var digits = 0
            while j < b.count, b[j].isDigit { j += 1; digits += 1 }
            if j < b.count, b[j] == 46 {
                j += 1
                while j < b.count, b[j].isDigit { j += 1; digits += 1 }
            }
            guard digits > 0 else { return nil }
            if j < b.count, b[j] == 101 || b[j] == 69 {
                var k = j + 1
                if k < b.count, b[k] == 43 || b[k] == 45 { k += 1 }
                if k < b.count, b[k].isDigit {
                    while k < b.count, b[k].isDigit { k += 1 }
                    j = k
                }
            }
            i = j
            return Double(String(decoding: b[s..<j], as: UTF8.self))
        }
    }
}

private extension UInt8 {
    var isDigit: Bool { self >= 48 && self <= 57 }
    var isCommandLetter: Bool {
        switch self {
        case UInt8(ascii: "M"), UInt8(ascii: "m"), UInt8(ascii: "L"), UInt8(ascii: "l"), UInt8(ascii: "H"), UInt8(ascii: "h"),
             UInt8(ascii: "V"), UInt8(ascii: "v"), UInt8(ascii: "C"), UInt8(ascii: "c"), UInt8(ascii: "S"), UInt8(ascii: "s"),
             UInt8(ascii: "Q"), UInt8(ascii: "q"), UInt8(ascii: "T"), UInt8(ascii: "t"), UInt8(ascii: "A"), UInt8(ascii: "a"),
             UInt8(ascii: "Z"), UInt8(ascii: "z"): true
        default: false
        }
    }
}
