import MeridianUI
import SwiftUI

enum AppIconVariant: String, CaseIterable { case standard, dark, tinted, clear }

/// `AppIcon.dc.html`, concept B "Stub": a boarding pass with notches, perforation and barcode, drawn in the
/// 1024 canvas and scaled. `rounded` draws the 22.37 % squircle the artboard shows; the asset export draws the
/// macOS grid (824 pt body inside the 1024 canvas) with `inset`.
struct AppIconArt: View {
    var variant: AppIconVariant = .standard
    var size: CGFloat = 256
    /// 1 = the artboard (icon fills the canvas); 824/1024 = the macOS asset grid.
    var inset: CGFloat = 1
    var tint: (r: Double, g: Double, b: Double) = (106, 183, 255)

    private struct Palette {
        var bgA, bgB, glow: Color
        var glowO: Double
        var glx = 0.3, gly = 0.1
        var tr1, tr2, paper1, paper2, paperLine, ink: Color
        var paperLW: Double = 2
        var shO: Double
    }

    private func mix(_ pct: Double) -> Color {
        let k = pct / 100
        return sysRGBA(tint.r * k + 0x11 * (1 - k), tint.g * k + 0x13 * (1 - k), tint.b * k + 0x17 * (1 - k))
    }

    private var palette: Palette {
        let blue = sysRGBA(106, 183, 255), mint = sysRGBA(139, 243, 216), ink = sysRGBA(0x14, 0x11, 0x0F)
        switch variant {
        case .standard:
            return Palette(bgA: blue, bgB: mint, glow: .white, glowO: 0.35, tr1: blue, tr2: mint,
                           paper1: sysRGBA(0xFB, 0xF8, 0xF0), paper2: sysRGBA(0xE9, 0xE2, 0xD2), paperLine: .black.opacity(0.1), ink: ink, shO: 0.42)
        case .dark:
            return Palette(bgA: sysRGBA(0x10, 0x16, 0x2A), bgB: sysRGBA(5, 7, 14), glow: blue, glowO: 0.22, tr1: blue, tr2: mint,
                           paper1: sysRGBA(0xE8, 0xE3, 0xD6), paper2: sysRGBA(0xC9, 0xC2, 0xB1), paperLine: .black.opacity(0.1), ink: ink, shO: 0.6)
        case .tinted:
            let t = sysRGBA(tint.r, tint.g, tint.b)
            return Palette(bgA: mix(26), bgB: mix(10), glow: t, glowO: 0.22, tr1: t, tr2: .white,
                           paper1: mix(88), paper2: mix(70), paperLine: .clear, ink: mix(10), shO: 0.5)
        case .clear:
            return Palette(bgA: .clear, bgB: .clear, glow: .white, glowO: 0.18, tr1: .white, tr2: .white,
                           paper1: .white.opacity(0.34), paper2: .white.opacity(0.14), paperLine: .white.opacity(0.9), ink: .white,
                           paperLW: 5, shO: 0.12)
        }
    }

    var body: some View {
        let s = size / 1024
        let pal = palette
        let radius = 1024 * 0.2237
        ZStack {
            Canvas { ctx, _ in
                ctx.scaleBy(x: s, y: s)
                let full = CGRect(x: 0, y: 0, width: 1024, height: 1024)
                // Body (the whole canvas, or the 824 pt macOS grid body).
                let b = 1024 * inset
                let body = CGRect(x: (1024 - b) / 2, y: (1024 - b) / 2, width: b, height: b)
                let shape = Path(roundedRect: body, cornerRadius: b * 0.2237, style: .continuous)
                ctx.clip(to: shape)
                if variant == .clear { ctx.fill(Path(body), with: .color(sysRGBA(0x8D, 0xA2, 0xCF))) }
                ctx.fill(Path(body), with: .linearGradient(Gradient(colors: [pal.bgA, pal.bgB]), startPoint: body.origin,
                                                           endPoint: CGPoint(x: body.maxX, y: body.maxY)))
                if variant == .clear {
                    var blur = ctx
                    blur.addFilter(.blur(radius: 60))
                    blur.fill(Path(ellipseIn: CGRect(x: -40, y: -20, width: 520, height: 520)), with: .color(sysRGBA(255, 143, 177, 0.7)))
                    blur.fill(Path(ellipseIn: CGRect(x: 540, y: 20, width: 560, height: 560)), with: .color(sysRGBA(106, 183, 255, 0.75)))
                    blur.fill(Path(ellipseIn: CGRect(x: 220, y: 580, width: 600, height: 600)), with: .color(sysRGBA(139, 243, 216, 0.55)))
                    ctx.fill(Path(body), with: .color(.white.opacity(0.10)))
                }
                let glowCenter = CGPoint(x: body.minX + b * pal.glx, y: body.minY + b * pal.gly)
                ctx.fill(Path(body), with: .radialGradient(Gradient(colors: [pal.glow.opacity(pal.glowO), pal.glow.opacity(0)]),
                                                           center: glowCenter, startRadius: 0, endRadius: b * 0.62))

                // Stub, rotated -7 degrees about the canvas centre.
                var g = ctx
                g.translateBy(x: 512, y: 512)
                g.scaleBy(x: inset, y: inset)
                g.rotate(by: .degrees(-7))
                g.translateBy(x: -512, y: -512)
                var sh = g
                sh.addFilter(.blur(radius: 22))
                sh.fill(Path(ellipseIn: CGRect(x: 270, y: 896, width: 500, height: 68)), with: .color(.black.opacity(pal.shO)))

                var paper = Path(roundedRect: CGRect(x: 262, y: 132, width: 500, height: 760), cornerRadius: 60, style: .continuous)
                paper.addEllipse(in: CGRect(x: 262 - 46, y: 650 - 46, width: 92, height: 92))
                paper.addEllipse(in: CGRect(x: 762 - 46, y: 650 - 46, width: 92, height: 92))
                g.fill(paper, with: .linearGradient(Gradient(colors: [pal.paper1, pal.paper2]), startPoint: CGPoint(x: 262, y: 132), endPoint: CGPoint(x: 762, y: 892)),
                       style: FillStyle(eoFill: true))
                g.stroke(paper, with: .color(pal.paperLine), lineWidth: pal.paperLW)

                var bar = g
                bar.clip(to: Path(roundedRect: CGRect(x: 262, y: 132, width: 500, height: 760), cornerRadius: 60, style: .continuous))
                bar.fill(Path(CGRect(x: 262, y: 132, width: 500, height: 34)),
                         with: .linearGradient(Gradient(colors: [pal.tr1, pal.tr2]), startPoint: CGPoint(x: 262, y: 0), endPoint: CGPoint(x: 762, y: 0)))

                var plane = g
                plane.translateBy(x: 512, y: 384)
                plane.rotate(by: .degrees(-45))
                plane.translateBy(x: -512, y: -384)
                plane.fill(MRIconShape(name: .plane, filled: true).path(in: CGRect(x: 342, y: 214, width: 340, height: 340)), with: .color(pal.ink))

                var perf = Path()
                perf.move(to: CGPoint(x: 310, y: 650)); perf.addLine(to: CGPoint(x: 714, y: 650))
                g.stroke(perf, with: .color(pal.ink.opacity(0.5)), style: StrokeStyle(lineWidth: 7, lineCap: .round, dash: [1, 20]))

                var bars = Path()
                var x = 322.0
                let seq: [Double] = [7, 3, 10, 4, 4, 9, 3, 6, 11, 3, 5, 8, 4, 10, 3, 7, 4, 9, 5, 3, 8]
                for (i, v) in seq.enumerated() where x < 700 {
                    let w = v * 1.5
                    if i % 2 == 0 { bars.addRect(CGRect(x: x, y: 696, width: w, height: 150)) }
                    x += w + 5
                }
                g.fill(bars, with: .color(pal.ink.opacity(0.85)))

                // Edge highlight (inset 0 1px 0 + hairline), as the artboard's edge layer.
                ctx.stroke(shape, with: .color(.white.opacity(variant == .clear ? 0.55 : 0.16)), lineWidth: variant == .clear ? 6 : 3)
                _ = full; _ = radius
            }
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("App icon, boarding pass stub, \(variant == .standard ? "default" : variant.rawValue) appearance")
    }
}
