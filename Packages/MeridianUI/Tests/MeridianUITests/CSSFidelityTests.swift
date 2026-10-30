import Foundation
import SwiftUI
import Testing
@testable import MeridianUI

/// Verifies tokens against a verbatim copy of the canvas' meridian.css (Fixtures/meridian.css).
/// When the canvas changes, replace the fixture and fix what fails.
struct CSS {
    let text: String

    static let shared: CSS = {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/meridian.css")
        let raw = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        return CSS(text: raw.replacingOccurrences(of: #"/\*.*?\*/"#, with: "", options: .regularExpression))
    }()

    /// Body of the first rule whose selector line starts with `selector`.
    func block(_ selector: String) -> String {
        guard let r = text.range(of: selector + " {") ?? text.range(of: selector + "{") else { return "" }
        guard let end = text[r.upperBound...].firstIndex(of: "}") else { return "" }
        return String(text[r.upperBound..<end])
    }

    /// `--name: value;` pairs of a block (values may contain parentheses and commas).
    func variables(_ selector: String) -> [String: String] {
        var out: [String: String] = [:]
        let body = block(selector)
        var depth = 0, current = "", parts: [String] = []
        for ch in body {
            if ch == "(" { depth += 1 } else if ch == ")" { depth -= 1 }
            if ch == ";" && depth == 0 { parts.append(current); current = "" } else { current.append(ch) }
        }
        parts.append(current)
        for part in parts {
            let t = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard t.hasPrefix("--"), let colon = t.firstIndex(of: ":") else { continue }
            out[String(t[t.index(t.startIndex, offsetBy: 2)..<colon])] = t[t.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        return out
    }

    /// Parses `#RRGGBB` or `rgba(r,g,b,a)` into RGB.
    static func color(_ v: String) -> RGB? {
        if v.hasPrefix("#") { return HexColor.parse(v) }
        guard v.hasPrefix("rgba(") || v.hasPrefix("rgb(") else { return nil }
        let nums = v.drop(while: { $0 != "(" }).dropFirst().dropLast().split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard nums.count >= 3 else { return nil }
        return RGB(r: nums[0] / 255, g: nums[1] / 255, b: nums[2] / 255, a: nums.count > 3 ? nums[3] : 1)
    }
}

private func close(_ a: RGB, _ b: RGB) -> Bool {
    abs(a.r - b.r) < 0.003 && abs(a.g - b.g) < 0.003 && abs(a.b - b.b) < 0.003 && abs(a.a - b.a) < 0.003
}

@Suite struct CSSFidelityTests {
    let css = CSS.shared
    var dark: [String: String] { css.variables(":root, [data-theme=\"dark\"]") }
    var light: [String: String] { css.variables("[data-theme=\"light\"]") }
    var root: [String: String] { css.variables(":root") }

    @Test func fixtureIsPresent() {
        #expect(css.text.count > 30_000)
        #expect(dark["bg-0"] == "#06080D")
        #expect(light["bg-0"] == "#EDE9E1")
    }

    @Test(arguments: [true, false])
    func paletteMatchesCSS(isDark: Bool) throws {
        // Light only overrides some variables; the rest inherit from dark.
        let vars = isDark ? dark : dark.merging(light) { $1 }
        let p: MRPalette = isDark ? .dark : .light
        let pairs: [(String, MRColorToken)] = [
            ("bg-0", p.bg0), ("bg-1", p.bg1), ("bg-2", p.bg2), ("text-1", p.text1), ("text-2", p.text2), ("text-3", p.text3),
            ("accent-1", p.accent1), ("accent-2", p.accent2), ("amber", p.amber), ("paper", p.paper), ("ink", p.ink),
            ("ok", p.ok), ("warn", p.warn), ("danger", p.danger),
            ("glass-tint", p.glassTint), ("glass-spec", p.glassSpec), ("stroke-hair", p.strokeHair), ("stroke-glow", p.strokeGlow),
            ("fill-1", p.fill1), ("fill-2", p.fill2), ("fill-3", p.fill3), ("scrim", p.scrim), ("rim", p.rim), ("seg-on", p.segOn),
            ("cta-fg", p.ctaFg),
        ]
        for (name, token) in pairs {
            let raw = try #require(vars[name], "missing --\(name)")
            let expected = try #require(CSS.color(raw), "unparsable --\(name): \(raw)")
            #expect(close(expected, token.rgb), "--\(name) \(isDark ? "dark" : "light"): css \(raw) vs token \(token.hex)")
        }
    }

    @Test(arguments: [true, false])
    func gradientsMatchCSS(isDark: Bool) throws {
        let vars = isDark ? dark : dark.merging(light) { $1 }
        let p: MRPalette = isDark ? .dark : .light
        let hex = try NSRegularExpression(pattern: "#[0-9A-Fa-f]{6}")
        func hexes(_ s: String) -> [String] { hex.matches(in: s, range: NSRange(s.startIndex..., in: s)).map { String(s[Range($0.range, in: s)!]).uppercased() } }
        #expect(hexes(try #require(vars["accent-grad"])) == [p.accentGradFrom.hex, p.accentGradTo.hex])
        let cta = hexes(try #require(vars["cta-bg"]))
        #expect(cta.first == p.ctaFrom.hex && cta.last == p.ctaTo.hex)
        #expect(try #require(vars["accent-grad"]).contains("135deg"))
    }

    @Test(arguments: [true, false])
    func elevationMatchesCSS(isDark: Bool) throws {
        let vars = isDark ? dark : dark.merging(light) { $1 }
        let p: MRPalette = isDark ? .dark : .light
        for (name, s) in [("e1", p.e1), ("e2", p.e2), ("e3", p.e3)] {
            let raw = try #require(vars[name])
            let parts = raw.split(separator: " ", maxSplits: 3).map(String.init)   // 0 2px 8px rgba(...)
            #expect(parts.count == 4)
            #expect(CGFloat(Double(parts[1].dropLast(2))!) == s.y, "\(name) y")
            #expect(CGFloat(Double(parts[2].dropLast(2))!) == s.blur, "\(name) blur")
            #expect(close(try #require(CSS.color(parts[3])), s.color.rgb), "\(name) color")
        }
    }

    @Test func radiiSpacingMotionMatchCSS() throws {
        let v = root
        func px(_ k: String) -> CGFloat { CGFloat(Double(v[k]!.dropLast(2))!) }
        func ms(_ k: String) -> Double { Double(v[k]!.dropLast(2))! / 1000 }
        #expect([px("r-window"), px("r-sidebar"), px("r-panel"), px("r-card"), px("r-ctl"), px("r-ticket"), px("r-notch")]
            == [MRRadius.window, MRRadius.sidebar, MRRadius.panel, MRRadius.card, MRRadius.control, MRRadius.ticket, MRRadius.ticketNotch])
        #expect(["s-1", "s-2", "s-3", "s-4", "s-6", "s-8", "s-12", "s-16"].map(px) == MRSpacing.all)
        #expect(["d1", "d2", "d3", "d4", "d5", "d6"].map(ms) == MRMotion.durations)
        #expect(v["ease"] == "cubic-bezier(.2,0,0,1)")
        #expect(v["ease-accel"] == "cubic-bezier(.3,0,.8,.15)")
    }

    @Test func scenarioFoilSkyStampColorsMatchCSS() throws {
        let v = root
        let sc: [(String, MRColorToken)] = [("study", MRScenarioColor.study), ("work", MRScenarioColor.work), ("read", MRScenarioColor.read), ("create", MRScenarioColor.create),
                                            ("code", MRScenarioColor.code), ("meditate", MRScenarioColor.meditate), ("fitness", MRScenarioColor.fitness), ("other", MRScenarioColor.other)]
        for (n, t) in sc { #expect(v["sc-\(n)"] == t.hex, "sc-\(n)") }
        for (n, t) in [("ok", MRStamp.ok), ("warn", MRStamp.warn), ("blue", MRStamp.blue), ("red", MRStamp.red)] { #expect(v["stamp-\(n)"] == t.hex, "stamp-\(n)") }

        let re = try NSRegularExpression(pattern: "(#[0-9A-Fa-f]{6})(?: ([0-9.]+)%)?")
        func stops(_ s: String) -> [(String, Double?)] {
            re.matches(in: s, range: NSRange(s.startIndex..., in: s)).map { m in
                (String(s[Range(m.range(at: 1), in: s)!]).uppercased(), Range(m.range(at: 2), in: s).flatMap { Double(s[$0]) })
            }
        }
        for (name, foil) in [("economy", MRFoil.economy), ("premium", .premium), ("business", .business), ("first", .first), ("long", .long)] {
            let css = stops(try #require(v["foil-\(name)"]))
            #expect(css.map(\.0) == foil.stopList.map(\.hex), "foil-\(name) colors")
            for (c, t) in zip(css, foil.stopList) where c.1 != nil { #expect(abs(c.1! / 100 - t.at) < 1e-9, "foil-\(name) stop") }
        }
        for (name, sky) in [("night", MRSky.night), ("blue", .blue), ("sunset", .sunset), ("day", .day), ("overcast", .overcast)] {
            let css = stops(try #require(v["sky-\(name)"]))
            #expect(css.map(\.0) == sky.stopList.map(\.hex), "sky-\(name)")
        }
    }

    @Test func mapPaletteMatchesCSS() throws {
        let d = dark, l = dark.merging(light) { $1 }
        func check(_ vars: [String: String], _ m: MRMapPalette, _ label: String) throws {
            for (k, t) in [("m-sea", m.sea), ("m-land", m.land), ("m-land-2", m.land2), ("m-line", m.line), ("m-grat", m.grat), ("m-label", m.label)] {
                let raw = try #require(vars[k])
                #expect(close(try #require(CSS.color(raw)), t.rgb), "\(label) \(k): \(raw) vs \(t.hex)")
            }
        }
        try check(d, .resolve(.terra, dark: true), "terra dark")
        try check(l, .resolve(.terra, dark: false), "terra light")
        let mapRules = [("mono", MRMapPalette.Style.mono), ("standard", .standard), ("satellite", .satellite)]
        for (n, style) in mapRules {
            let v = css.variables("[data-map=\"\(n)\"]")
            try check(v, .resolve(style, dark: true), "\(n) dark")
            let lv = css.variables("[data-theme=\"light\"] [data-map=\"\(n)\"]")
            if !lv.isEmpty { try check(v.merging(lv) { $1 }, .resolve(style, dark: false), "\(n) light") }
        }
    }

    /// `.t-display{font:600 56px/60px var(--font-ui);letter-spacing:-.012em}` etc.
    @Test func typeScaleMatchesCSS() throws {
        let classes: [(String, MRTextStyle)] = [("t-display", .display), ("t-title1", .title1), ("t-title2", .title2), ("t-headline", .headline),
                                                ("t-body", .body), ("t-callout", .callout), ("t-caption", .caption), ("eyebrow", .eyebrow)]
        let re = try NSRegularExpression(pattern: #"font:(\d+) (\d+)px/(\d+)px"#)
        for (cls, style) in classes {
            let body = css.block(".\(cls)")
            let m = try #require(re.firstMatch(in: body, range: NSRange(body.startIndex..., in: body)), "no font for .\(cls)")
            func g(_ i: Int) -> Double { Double(body[Range(m.range(at: i), in: body)!])! }
            #expect(Int(g(1)) == style.cssWeight, ".\(cls) weight")
            #expect(CGFloat(g(2)) == style.size, ".\(cls) size")
            #expect(CGFloat(g(3)) == style.lineHeight, ".\(cls) line-height")
            if let ls = body.range(of: #"letter-spacing:(-?[.0-9]+)em"#, options: .regularExpression) {
                let v = Double(body[ls].dropFirst("letter-spacing:".count).dropLast(2))!
                #expect(abs(Double(style.tracking) - v) < 1e-9, ".\(cls) tracking")
            } else {
                #expect(style.tracking == 0, ".\(cls) has no tracking")
            }
            #expect(body.contains("text-transform:uppercase") == style.isUppercase, ".\(cls) case")
        }
    }
}
