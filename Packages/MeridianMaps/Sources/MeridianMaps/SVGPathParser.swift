import SwiftUI

/// Minimal SVG path parser for the map geometry (`M L H V C S Q T Z`, absolute and relative; arcs are not
/// needed by the design files and are skipped). Written for speed: one pass over UTF-8 bytes, no regex,
/// no intermediate token array. The map SVGs are 100+ KB of `M`/`L`/`Z`, so callers parse once and cache the `Path`.
public enum SVGPathParser {
    /// Parses a `d` attribute value.
    public static func path(d: String) -> Path {
        var d = d
        return d.withUTF8 { path(bytes: $0) }
    }

    /// All `<path d="...">` elements of an SVG document merged into one `Path` (sub-paths keep their order).
    public static func path(svg: String) -> Path {
        var result = Path()
        var svg = svg
        svg.withUTF8 { bytes in
            let needle = Array(" d=\"".utf8)
            var i = 0
            let n = bytes.count
            while i + needle.count < n {
                var match = true
                for k in 0..<needle.count where bytes[i + k] != needle[k] { match = false; break }
                if !match { i += 1; continue }
                let start = i + needle.count
                var end = start
                while end < n && bytes[end] != UInt8(ascii: "\"") { end += 1 }
                result.addPath(path(bytes: UnsafeBufferPointer(rebasing: bytes[start..<end])))
                i = end + 1
            }
        }
        return result
    }

    static func path(bytes: UnsafeBufferPointer<UInt8>) -> Path {
        var path = Path()
        var i = 0
        let n = bytes.count
        var cur = CGPoint.zero, start = CGPoint.zero
        var lastCtrl: CGPoint? = nil      // previous cubic/quad control point, for S/T reflection
        var lastCmd: UInt8 = 0
        var cmd: UInt8 = 0

        @inline(__always) func skipSep() {
            while i < n {
                let c = bytes[i]
                if c == 0x20 || c == 0x2C || c == 0x0A || c == 0x0D || c == 0x09 { i += 1 } else { break }
            }
        }
        @inline(__always) func number() -> Double? {
            skipSep()
            guard i < n else { return nil }
            let begin = i
            var neg = false
            if bytes[i] == 0x2D { neg = true; i += 1 } else if bytes[i] == 0x2B { i += 1 }
            var mant: Double = 0
            var digits = 0
            while i < n, bytes[i] >= 0x30, bytes[i] <= 0x39 { mant = mant * 10 + Double(bytes[i] - 0x30); i += 1; digits += 1 }
            if i < n, bytes[i] == 0x2E {
                i += 1
                var scale = 0.1
                while i < n, bytes[i] >= 0x30, bytes[i] <= 0x39 { mant += Double(bytes[i] - 0x30) * scale; scale *= 0.1; i += 1; digits += 1 }
            }
            guard digits > 0 else { i = begin; return nil }
            if i < n, bytes[i] == 0x65 || bytes[i] == 0x45 {
                var j = i + 1
                var eneg = false
                if j < n, bytes[j] == 0x2D { eneg = true; j += 1 } else if j < n, bytes[j] == 0x2B { j += 1 }
                var e = 0, ed = 0
                while j < n, bytes[j] >= 0x30, bytes[j] <= 0x39 { e = e * 10 + Int(bytes[j] - 0x30); j += 1; ed += 1 }
                if ed > 0 { mant *= pow(10, Double(eneg ? -e : e)); i = j }
            }
            return neg ? -mant : mant
        }
        func args(_ count: Int) -> [Double]? {
            var out = [Double](); out.reserveCapacity(count)
            for _ in 0..<count { guard let v = number() else { return nil }; out.append(v) }
            return out
        }

        while true {
            skipSep()
            guard i < n else { break }
            let c = bytes[i]
            if (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) { cmd = c; i += 1 } else if cmd == 0 { break }
            let rel = cmd >= 0x61
            let up = rel ? cmd - 0x20 : cmd
            let ox = rel ? cur.x : 0, oy = rel ? cur.y : 0
            var ctrl: CGPoint? = nil
            switch up {
            case UInt8(ascii: "M"):
                guard let a = args(2) else { return path }
                cur = CGPoint(x: a[0] + ox, y: a[1] + oy); start = cur
                path.move(to: cur)
                cmd = rel ? UInt8(ascii: "l") : UInt8(ascii: "L")   // implicit lineto after moveto
            case UInt8(ascii: "L"):
                guard let a = args(2) else { return path }
                cur = CGPoint(x: a[0] + ox, y: a[1] + oy); path.addLine(to: cur)
            case UInt8(ascii: "H"):
                guard let x = number() else { return path }
                cur.x = x + ox; path.addLine(to: cur)
            case UInt8(ascii: "V"):
                guard let y = number() else { return path }
                cur.y = y + oy; path.addLine(to: cur)
            case UInt8(ascii: "C"):
                guard let a = args(6) else { return path }
                let c1 = CGPoint(x: a[0] + ox, y: a[1] + oy), c2 = CGPoint(x: a[2] + ox, y: a[3] + oy)
                cur = CGPoint(x: a[4] + ox, y: a[5] + oy)
                path.addCurve(to: cur, control1: c1, control2: c2); ctrl = c2
            case UInt8(ascii: "S"):
                guard let a = args(4) else { return path }
                let c1: CGPoint = (lastCmd == UInt8(ascii: "C") || lastCmd == UInt8(ascii: "S")) && lastCtrl != nil
                    ? CGPoint(x: 2 * cur.x - lastCtrl!.x, y: 2 * cur.y - lastCtrl!.y) : cur
                let c2 = CGPoint(x: a[0] + ox, y: a[1] + oy)
                cur = CGPoint(x: a[2] + ox, y: a[3] + oy)
                path.addCurve(to: cur, control1: c1, control2: c2); ctrl = c2
            case UInt8(ascii: "Q"):
                guard let a = args(4) else { return path }
                let c1 = CGPoint(x: a[0] + ox, y: a[1] + oy)
                cur = CGPoint(x: a[2] + ox, y: a[3] + oy)
                path.addQuadCurve(to: cur, control: c1); ctrl = c1
            case UInt8(ascii: "T"):
                guard let a = args(2) else { return path }
                let c1: CGPoint = (lastCmd == UInt8(ascii: "Q") || lastCmd == UInt8(ascii: "T")) && lastCtrl != nil
                    ? CGPoint(x: 2 * cur.x - lastCtrl!.x, y: 2 * cur.y - lastCtrl!.y) : cur
                cur = CGPoint(x: a[0] + ox, y: a[1] + oy)
                path.addQuadCurve(to: cur, control: c1); ctrl = c1
            case UInt8(ascii: "Z"):
                path.closeSubpath(); cur = start; cmd = 0
            case UInt8(ascii: "A"):
                guard args(7) != nil else { return path }   // arcs unsupported: skip the segment
            default:
                return path
            }
            lastCmd = up; lastCtrl = ctrl
        }
        return path
    }
}
