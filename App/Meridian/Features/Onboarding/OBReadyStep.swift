import MeridianCore
import MeridianUI
import SwiftUI

/// S07: "Ready for take-off" (ONB-7). The CTA ends onboarding and lands on Plan, where the
/// first-run ruler coach mark is shown (it stays unseen: `hasSeenRulerCoachMark` is not touched).
struct OBReadyStep: View {
    let model: OnboardingModel
    let onDone: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private struct Ray { var x1, y1, x2, y2: Double; var color: Color; var w, o: Double }

    private var rays: [Ray] {
        var r = OBRandom(seed: 5)
        return (0..<36).map { i in
            let a = Double(i) / 36 * .pi * 2 + r.next() * 0.1
            let r0 = 270 + r.next() * 40
            let r1 = r0 + 30 + r.next() * 90
            let w = 1 + r.next() * 1.6
            let o = 0.25 + r.next() * 0.5
            let hex = i % 3 == 0 ? "#FFB547" : (i % 3 == 1 ? "#6AB7FF" : "#8BF3D8")
            return Ray(x1: 640 + cos(a) * r0, y1: 300 + sin(a) * r0, x2: 640 + cos(a) * r1, y2: 300 + sin(a) * r1,
                       color: MRColorToken.hex(hex), w: w, o: o)
        }
    }

    var body: some View {
        let p = MRPalette.resolve(scheme)
        let city = model.homeAirport?.city ?? model.home
        ZStack(alignment: .topLeading) {
            ZStack {
                OBGlow(cx: 0.5, cy: 0.38, rx: 0.5, ry: 0.6, color: obRGBA(106, 183, 255, 0.2), stop: 0.70)
                OBGlow(cx: 0.5, cy: 1, rx: 0.4, ry: 0.4, color: obRGBA(139, 243, 216, 0.1), stop: 0.70)
            }
            .frame(width: obCanvasWidth, height: obCanvasHeight)

            Canvas { ctx, _ in
                for r in rays {
                    var path = Path(); path.move(to: CGPoint(x: r.x1, y: r.y1)); path.addLine(to: CGPoint(x: r.x2, y: r.y2))
                    ctx.stroke(path, with: .color(r.color.opacity(r.o)), style: StrokeStyle(lineWidth: r.w, lineCap: .round))
                }
                let g = GraphicsContext.Shading.linearGradient(Gradient(colors: [MRColorToken.hex("#6AB7FF"), MRColorToken.hex("#8BF3D8")]),
                                                                startPoint: .zero, endPoint: CGPoint(x: obCanvasWidth, y: obCanvasHeight))
                for (rad, op) in [(250.0, 0.35), (330.0, 0.16)] {
                    let rect = CGRect(x: 640 - rad, y: 300 - rad, width: rad * 2, height: rad * 2)
                    ctx.opacity = op
                    ctx.stroke(Path(ellipseIn: rect), with: g, lineWidth: 1)
                }
            }
            .frame(width: obCanvasWidth, height: obCanvasHeight)
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            VStack(spacing: 0) {
                lockedTicket(p)
                OT("Ready for take-off.").obType(.serif, 68, 500, lh: 72, tracking: -0.02)
                    .foregroundStyle(p.text1.color).padding(.top, 34)
                OT("Home airport \(city). Soft blocking is set to Nudge. Your first ticket is one tap away.")
                    .obType(.ui, 17, 400, lh: 26).foregroundStyle(p.text2.color)
                    .multilineTextAlignment(.center).frame(maxWidth: 520).padding(.top, 14)
                Button(action: onDone) {
                    HStack(spacing: 8) { MRIcon(.plane, size: 18); OT("Plan my first flight") }
                }
                .buttonStyle(MRButtonStyle(.primary, size: .lg))
                .padding(.top, 34)
            }
            .frame(width: obCanvasWidth)
            .opacity(appeared || reduceMotion ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 14)
            .obAt(0, 60)
        }
        .frame(width: obCanvasWidth, height: obCanvasHeight, alignment: .topLeading)
        .onAppear { withAnimation(MRMotion.ease(MRMotion.d5)) { appeared = true } }
    }

    /// Ticket `state="locked"` at scale .7: dashed outline with a lock and a label.
    private func lockedTicket(_ p: MRPalette) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return ZStack(alignment: .top) {
            shape.fill(p.fill1.color)
            shape.strokeBorder(p.text3.color, style: StrokeStyle(lineWidth: 1.5, dash: [4.5, 3]))
            VStack(spacing: 14) {
                MRIcon(.lock, size: 24)
                OT("Your first flight prints here").mrText(.callout).multilineTextAlignment(.center).frame(maxWidth: 150)
            }
            .foregroundStyle(p.text3.color)
            .padding(.top, 316 * 0.34)
        }
        .frame(width: 252, height: 316)
        .opacity(0.9)
        .accessibilityElement(children: .combine)
    }
}
