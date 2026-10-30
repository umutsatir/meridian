import SwiftUI
import Testing
@testable import MeridianUI

@Suite struct TokenTests {
    @Test func hexParsing() throws {
        let c = try #require(HexColor.parse("#6AB7FF"))
        #expect(abs(c.r - 0x6A / 255.0) < 1e-9 && abs(c.g - 0xB7 / 255.0) < 1e-9 && c.b == 1 && c.a == 1)
        #expect(HexColor.parse("6ab7ff") == c)
        #expect(HexColor.parse(" #6AB7FF ") == c)
        #expect(HexColor.parse("#00000080")?.a ?? 0 > 0.49)
        #expect(HexColor.parse("#FFF") == nil)
        #expect(HexColor.parse("#GGGGGG") == nil)
        #expect(HexColor.parse("") == nil)
        #expect(HexColor.parse("#12345678AB") == nil)
    }

    @Test func tokensMatchPRDAppendixB() {
        let d = MRPalette.dark, l = MRPalette.light
        #expect([d.bg0, d.bg1, d.bg2, d.text1, d.text2, d.text3].map(\.hex) == ["#06080D", "#0B1020", "#121A2E", "#F3F5FA", "#A9B2C7", "#96A0BA"])
        #expect([d.accent1, d.accent2, d.amber, d.paper, d.ink, d.ok, d.warn, d.danger].map(\.hex) == ["#6AB7FF", "#8BF3D8", "#FFB547", "#F5F0E6", "#14110F", "#5BE3A0", "#FFB547", "#FF6B6B"])
        #expect([l.bg0, l.bg1, l.bg2, l.text1, l.text2, l.text3].map(\.hex) == ["#EDE9E1", "#F4F1EB", "#FFFFFF", "#14161C", "#424959", "#565E70"])
        #expect([l.accent1, l.accent2, l.ok, l.warn, l.danger].map(\.hex) == ["#1759E0", "#18C7A0", "#08613F", "#8A4F05", "#BC2D2D"])
    }

    @Test func schemeResolution() {
        #expect(MRPalette.resolve(.dark).isDark)
        #expect(!MRPalette.resolve(.light).isDark)
        #expect(MRPalette.dark.onAccent == MRPalette.dark.bg0)
        #expect(MRPalette.light.onAccent == MRPalette.light.bg2)
    }

    @Test(arguments: [MRPalette.dark, MRPalette.light])
    func textMeetsWCAGAAOnEverySurface(palette: MRPalette) {
        for surface in [palette.bg0, palette.bg1, palette.bg2] {
            for text in [palette.text1, palette.text2, palette.text3] {
                #expect(text.rgb.contrastRatio(with: surface.rgb) >= 4.5, "\(text.hex) on \(surface.hex)")
            }
            for status in [palette.ok, palette.warn, palette.danger] {
                #expect(status.rgb.contrastRatio(with: surface.rgb) >= 4.5, "\(status.hex) on \(surface.hex)")
            }
        }
        #expect(palette.onAccent.rgb.contrastRatio(with: palette.accent1.rgb) >= 4.5)
        #expect(palette.ink.rgb.contrastRatio(with: palette.amber.rgb) >= 4.5)
        #expect(palette.ink.rgb.contrastRatio(with: palette.paper.rgb) >= 4.5)
    }

    @Test func contrastRatioEndpoints() {
        let white = RGB(r: 1, g: 1, b: 1), black = RGB(r: 0, g: 0, b: 0)
        #expect(abs(white.contrastRatio(with: black) - 21) < 1e-9)
        #expect(abs(white.contrastRatio(with: white) - 1) < 1e-9)
    }

    @Test func scenarioColorsMatchPRD() {
        #expect([MRScenarioColor.study, MRScenarioColor.work, MRScenarioColor.read, MRScenarioColor.create, MRScenarioColor.code, MRScenarioColor.meditate, MRScenarioColor.fitness, MRScenarioColor.other].map(\.hex)
            == ["#7AA2FF", "#FFB86B", "#7ADDB2", "#FF8FB1", "#B49CFF", "#8EE3E8", "#FF9B7A", "#C7CCDA"])
    }

    @Test func spacingRadiiAndTypeScale() {
        #expect(MRSpacing.all == [4, 8, 12, 16, 24, 32, 48, 64])
        #expect([MRRadius.window, MRRadius.panel, MRRadius.card, MRRadius.control, MRRadius.ticket, MRRadius.ticketNotch] == [26, 28, 20, 14, 22, 14])
        let scale = MRTextStyle.allCases.map { ($0.size, $0.lineHeight) }
        #expect(scale.map(\.0) == [56, 34, 24, 17, 15, 13, 11])
        #expect(scale.map(\.1) == [60, 40, 30, 22, 22, 18, 14])
        #expect(MRTextStyle.allCases.allSatisfy { $0.lineHeight > $0.size })
    }

    @Test func motionDurationsAreAscending() {
        #expect(MRMotion.durations == MRMotion.durations.sorted())
        #expect(MRMotion.instant == 0.12 && MRMotion.fast == 0.2 && MRMotion.base == 0.32 && MRMotion.slow == 0.52)
        #expect(MRMotion.cinematicRange == 0.9...1.4)
    }
}
