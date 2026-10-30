import MeridianCore
import MeridianMaps
import MeridianUI
import SwiftUI

/// S01 / S01T: welcome with the slowly turning globe (ONB-1).
struct OBWelcomeStep: View {
    let live: Bool
    let onNext: () -> Void
    let onSkip: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private static let amber = MRColorToken.hex("#FFB547")

    var body: some View {
        let p = MRPalette.resolve(scheme)
        ZStack(alignment: .topLeading) {
            ZStack {
                OBGlow(cx: 0.78, cy: 0.46, rx: 0.60, ry: 0.90, color: obRGBA(70, 92, 190, 0.34), stop: 0.72)
                OBGlow(cx: 0.12, cy: 1.0, rx: 0.40, ry: 0.50, color: obRGBA(106, 183, 255, 0.10), stop: 0.70)
            }
            .frame(width: obCanvasWidth, height: obCanvasHeight)

            globe.frame(width: 1000, height: 1000).obAt(470, -100)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    MRIcon(.mark, size: 24).foregroundStyle(p.accent1.color)
                    Text(MRBrand.name).mrText(.eyebrow).tracking(11 * 0.2).foregroundStyle(p.text1.color)
                }
                .padding(.bottom, 34)

                VStack(alignment: .leading, spacing: 0) {
                    OT("Fly into").obType(.serif, 104, 500, lh: 100, tracking: -0.03)
                        .foregroundStyle(p.text1.color)
                    OT("focus.").obType(.serif, 104, 500, lh: 100, tracking: -0.03, italic: true)
                        .foregroundStyle(p.accentGradient)
                        .padding(.trailing, 6)
                }

                OT("Pick a destination. Land your work.")
                    .obType(.ui, 21, 400, lh: 30)
                    .foregroundStyle(p.text2.color)
                    .frame(maxWidth: 420, alignment: .leading)
                    .padding(.top, 28)

                HStack(spacing: 26) {
                    Button(action: onNext) {
                        HStack(spacing: 8) { OT("Let’s get started"); MRIcon(.chevR, size: 18) }
                    }
                    .buttonStyle(MRButtonStyle(.primary, size: .lg))
                    OBLink(title: "Skip setup", action: onSkip)
                }
                .padding(.top, 44)
            }
            .frame(width: 640, alignment: .leading)
            .opacity(appeared || reduceMotion ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 14)
            .obAt(96, 150)

            OT("Free to start · No account needed")
                .obType(.mono, 12, 500, lh: 12)
                .foregroundStyle(p.text3.color)
                .obAt(96, 800 - 44 - 12)
        }
        .frame(width: obCanvasWidth, height: obCanvasHeight, alignment: .topLeading)
        .onAppear { withAnimation(MRMotion.ease(MRMotion.d5)) { appeared = true } }
    }

    private var globe: some View {
        let a = MapAirports.bundled
        func route(_ x: String, _ y: String, _ hex: String, _ w: Double, _ o: Double, _ lift: Double) -> GlobeRoute? {
            GlobeRoute(from: x, to: y, airports: a, color: MRColorToken.hex(hex), width: w, opacity: o, lift: lift)
        }
        func pin(_ code: String, _ r: Double, _ label: Bool) -> GlobePin? {
            GlobePin(code: code, airports: a, showsLabel: label, color: Self.amber, radius: r)
        }
        let plane: GlobePlane? = {
            guard let l = a.coordinate("LHR"), let j = a.coordinate("JFK") else { return nil }
            return GlobePlane(from: l, to: j, t: 0.46)
        }()
        return GlobeView(
            lon: -36, lat: 34, size: 1000,
            routes: [route("LHR", "JFK", "#6AB7FF", 1.8, 0.85, 0.09), route("LHR", "DXB", "#8BF3D8", 1.2, 0.45, 0.08),
                     route("JFK", "LAX", "#B49CFF", 1.2, 0.4, 0.08)].compactMap { $0 },
            pins: [pin("LHR", 4.2, true), pin("JFK", 4.2, true), pin("DXB", 3, false), pin("LAX", 3, false)].compactMap { $0 },
            plane: plane, showsGraticule: true,
            live: live && !reduceMotion, speed: 2.6)
    }
}
