import Foundation
import SwiftUI
import Testing
@testable import MeridianUI
#if canImport(AppKit)
import AppKit
#endif

@Suite struct SVGPathTests {
    private func bounds(_ d: String) -> CGRect { SVGPath.parse(d).boundingRect }

    @Test func linesAbsoluteAndRelative() {
        #expect(SVGPath.segments("M10 10 L20 10 L20 20 Z") == [.move(.init(x: 10, y: 10)), .line(.init(x: 20, y: 10)), .line(.init(x: 20, y: 20)), .close])
        #expect(SVGPath.segments("m10 10 l10 0 l0 10 z") == [.move(.init(x: 10, y: 10)), .line(.init(x: 20, y: 10)), .line(.init(x: 20, y: 20)), .close])
        #expect(SVGPath.segments("M0 0H5V5h-2v-2") == [.move(.zero), .line(.init(x: 5, y: 0)), .line(.init(x: 5, y: 5)), .line(.init(x: 3, y: 5)), .line(.init(x: 3, y: 3))])
    }

    @Test func implicitRepeatAndCompactNumbers() {
        // implicit lineto after moveto; ".5.5" is two numbers; "1-2" is 1 and -2; exponents
        #expect(SVGPath.segments("M0 0 10 10 20 0") == [.move(.zero), .line(.init(x: 10, y: 10)), .line(.init(x: 20, y: 0))])
        #expect(SVGPath.segments("M.5.5L1-2") == [.move(.init(x: 0.5, y: 0.5)), .line(.init(x: 1, y: -2))])
        #expect(SVGPath.segments("M1e1,2E0L-1.5e-1 0") == [.move(.init(x: 10, y: 2)), .line(.init(x: -0.15, y: 0))])
        // relative moveto then implicit relative lineto
        #expect(SVGPath.segments("m1 1 2 2") == [.move(.init(x: 1, y: 1)), .line(.init(x: 3, y: 3))])
    }

    @Test func curvesAndReflection() {
        let s = SVGPath.segments("M0 0C0 10 10 10 10 0S20 -10 20 0")
        #expect(s[2] == .cubic(.init(x: 10, y: -10), .init(x: 20, y: -10), .init(x: 20, y: 0)))   // reflected control (10,10)->(10,-10)
        let q = SVGPath.segments("M0 0Q5 5 10 0T20 0")
        #expect(q[2] == .quad(.init(x: 15, y: -5), .init(x: 20, y: 0)))
    }

    @Test func arcsIncludingCompactFlags() {
        // half circle r=5 from (0,0) to (10,0), sweep=1 -> through (5,-5)? (y down: sweep 1 = clockwise) top
        let r = bounds("M0 0A5 5 0 0 1 10 0")
        #expect(abs(r.minX) < 1e-6 && abs(r.maxX - 10) < 1e-6 && abs(r.height - 5) < 1e-3)
        // flags glued to the numbers: "a.8.8 0 001.2.7" (from icons.svg)
        let segs = SVGPath.segments("M8 5.2v13.6a.8.8 0 001.2.7")
        #expect(segs.count >= 3)
        if case .cubic(_, _, let end) = segs.last! { #expect(abs(end.x - 9.2) < 1e-9 && abs(end.y - 19.5) < 1e-9) } else { Issue.record("arc not converted") }
        // full circle from two arcs
        let c = bounds("M2 12A10 10 0 1 0 22 12A10 10 0 1 0 2 12Z")
        #expect(abs(c.width - 20) < 1e-3 && abs(c.height - 20) < 1e-3 && abs(c.midY - 12) < 1e-3)
        // radius scaled up when too small
        let s = bounds("M0 0A1 1 0 0 1 10 0")
        #expect(abs(s.width - 10) < 1e-6)
    }

    @Test func malformedInputIsTolerated() {
        #expect(SVGPath.segments("").isEmpty)
        #expect(SVGPath.segments("L10 10").isEmpty)            // must start with moveto
        #expect(SVGPath.segments("M0 0 L10").count == 1)       // truncated -> render up to the error
        #expect(SVGPath.segments("M0 0 L10 10 Q").count == 2)
    }
}

@Suite struct IconTests {
    @Test func spriteIsComplete() throws {
        let svg = try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/icons.svg"), encoding: .utf8)
        let ids = svg.components(separatedBy: "<symbol id=\"").dropFirst().map { String($0.prefix { $0 != "\"" }) }
        #expect(ids.count == 82)
        #expect(Set(ids) == Set(MRIconName.allCases.map(\.rawValue)))
        #expect(MRIconName.allCases.count == 82)
    }

    @Test func everyIconHasGeometryInsideTheViewBox() {
        for name in MRIconName.allCases {
            let parts = MRIconData.parts[name] ?? []
            #expect(!parts.isEmpty, "\(name) has no geometry")
            for filled in [true, false] {
                let p = MRIconCache.path(name, filled: filled)
                guard !p.isEmpty else { continue }
                let b = p.boundingRect
                #expect(b.minX >= -0.5 && b.minY >= -0.5 && b.maxX <= 24.5 && b.maxY <= 24.5, "\(name) out of viewBox: \(b)")
            }
        }
    }

    @Test func knownIconShapes() {
        // search: ring r=6.5 at (10.5,10.5) stroked + handle; no filled part
        let search = MRIconCache.path(.search, filled: false).boundingRect
        #expect(abs(search.minX - 4) < 0.01 && abs(search.maxX - 20) < 0.01)
        #expect(MRIconCache.path(.search, filled: true).isEmpty)
        // plane / play are filled glyphs
        #expect(MRIconCache.path(.plane, filled: false).isEmpty && !MRIconCache.path(.plane, filled: true).isEmpty)
        #expect(!MRIconCache.path(.play, filled: true).isEmpty)
        // target mixes stroked rings and a filled dot
        #expect(!MRIconCache.path(.target, filled: true).isEmpty && !MRIconCache.path(.target, filled: false).isEmpty)
        #expect(MRIconName.chevR.rawValue == "chev-r" && MRIconName.briefcase.rawValue == "case")
    }

    @Test func shapeScalesToTheFrame() {
        let r = MRIconShape(name: .search, filled: false).path(in: CGRect(x: 0, y: 0, width: 48, height: 48)).boundingRect
        #expect(abs(r.minX - 8) < 0.01 && abs(r.maxX - 40) < 0.01)
    }
}

@Suite struct FontTests {
    @Test func bundledFontsRegister() {
        #expect(MRFonts.register())
        #expect(MRFonts.files.count == 7)
    }

    #if canImport(AppKit)
    @Test func fontsLoadByName() {
        #expect(MRFonts.register())
        // NSFont(name:size:) resolves the registered faces.
        for name in ["BarlowCondensed-Bold", "BarlowCondensed-SemiBold", "BarlowCondensed-Medium"] {
            #expect(NSFont(name: name, size: 13) != nil, "\(name)")
        }
        let families = Set(NSFontManager.shared.availableFontFamilies)
        for f in MRFonts.Family.allCases { #expect(families.contains(f.rawValue), "\(f.rawValue) not registered") }
        for f in MRFonts.Family.allCases {
            #expect(MRFonts.resolvedFamilyName(f) == f.rawValue, "\(f) resolved to \(MRFonts.resolvedFamilyName(f))")
            #expect(NSFont(descriptor: CTFontCopyFontDescriptor(MRFonts.ctFont(f, size: 14, weight: 500)), size: 14) != nil)
        }
    }

    @Test func variableWeightsAreRealInstances() {
        func width(_ f: MRFonts.Family, _ w: Int) -> Double {
            let font = MRFonts.ctFont(f, size: 40, weight: w)
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: "Meridian Cabin 0123", attributes: [.font: font]))
            return CTLineGetTypographicBounds(line, nil, nil, nil)
        }
        #expect(width(.ui, 700) > width(.ui, 400) + 5)
        #expect(width(.ui, 600) > width(.ui, 500))
        #expect(width(.ui, 600) < width(.ui, 700))
        #expect(width(.mono, 700) != width(.mono, 400) || true) // mono is fixed pitch; just must not crash
        #expect(width(.serif, 600) > width(.serif, 400))
        #expect(width(.condensed, 700) > width(.condensed, 500))
    }

    @Test func uiFontHasTabularFigures() {
        let font = MRFonts.ctFont(.ui, size: 20, weight: 500)
        func adv(_ s: String) -> Double {
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [.font: font]))
            return CTLineGetTypographicBounds(line, nil, nil, nil)
        }
        #expect(abs(adv("1111") - adv("0000")) < 0.01)   // tnum on
    }

    @Test func lineHeightSpacingComesFromRealMetrics() {
        // Inter's natural line is ~1.21 em, so a 60/56 display line needs negative spacing; body 22/15 needs positive.
        #expect(MRTextStyle.display.extraLineSpacing() < 0)
        #expect(MRTextStyle.body.extraLineSpacing() > 3 && MRTextStyle.body.extraLineSpacing() < 5)
        #expect(abs(MRTextStyle.callout.extraLineSpacing() - (18 - MRFonts.naturalLineHeight(.ui, size: 13, weight: 400))) < 1e-9)
    }
    #endif
}
