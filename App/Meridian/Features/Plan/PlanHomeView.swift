import MeridianCore
import MeridianMaps
import MeridianPlan
import MeridianUI
import SwiftUI

/// Home stage of `Planner.dc.html`: the globe under a starfield, greeting, "Start flight" and the Wallet / Stats /
/// Together list.
struct PlanHomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Binding var popOpen: Bool
    /// Hour of day for the greeting; `nil` uses the clock.
    var hour: Int?

    var body: some View {
        GeometryReader { geo in
            content(W: geo.size.width, H: geo.size.height)
        }
    }

    private var greeting: String {
        let h = hour ?? Calendar.current.component(.hour, from: .now)
        return (h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening") + "!"
    }

    private func content(W: CGFloat, H: CGFloat) -> some View {
        let p = MRPalette.resolve(scheme)
        let dark = scheme == .dark
        let o = model.plan.origin
        let GS = 2200.0, GR = GS * 0.43, GC = GS / 2
        let gLat = max(-60, min(60, o.coordinate.latitude - 38)), gLon = o.coordinate.longitude
        let gx = W / 2 - GS / 2, gy = 190 - (GC - GR)
        // orthographic point of the origin on the globe (`MeridianWorld.point`)
        let d = Double.pi / 180
        let la = o.coordinate.latitude * d, lo = (o.coordinate.longitude - gLon) * d, ph = gLat * d
        let px = GR * cos(la) * sin(lo)
        let py = GR * (cos(ph) * sin(la) - sin(ph) * cos(la) * cos(lo))
        let pin = CGPoint(x: gx + GC + px, y: gy + GC - py)
        let override = dark ? GlobeColorOverride(seaA: 0x34678F, seaB: 0x12304F, land: 0x6B7A4E, shade: 0.62, rim: 0.5)
                            : GlobeColorOverride(seaA: 0xDCE8F3, seaB: 0xA8C2DB, land: 0xFBF9F4, shade: 0.2, rim: 0.25)

        return ZStack(alignment: .topLeading) {
            p.bg0.color
            if dark { Stars(width: W, height: H) }
            Circle()
                .fill(RadialGradient(stops: [.init(color: MRColorToken(130, 160, 255, 0).color, location: 0.84),
                                             .init(color: MRColorToken(130, 165, 255, 0.32).color, location: 0.90),
                                             .init(color: MRColorToken(130, 165, 255, 0).color, location: 1)],
                                     center: .center, startRadius: 0, endRadius: GR * 1.16))
                .frame(width: GR * 2.32, height: GR * 2.32)
                .offset(x: gx + GC - GR * 1.16, y: gy + GC - GR * 1.16)
                .allowsHitTesting(false)
            GlobeView(lon: gLon, lat: gLat, size: GS, showsGraticule: false, showsAtmosphere: false, showsLabels: false,
                      colorOverride: override)
                .frame(width: GS, height: GS)
                .offset(x: gx, y: gy)
                .allowsHitTesting(false)
            PulsePin().position(pin).allowsHitTesting(false)
            LinearGradient(stops: [.init(color: .clear, location: 0.62),
                                   .init(color: p.bg0.color.opacity(0.55), location: 1)], startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                Text(greeting).font(.mr(.ui, size: 20, weight: 500)).foregroundStyle(p.text2.color).frame(height: 24, alignment: .leading)
                Button { popOpen.toggle() } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(o.city).font(.mr(.ui, size: 34, weight: 700)).tracking(-0.68).foregroundStyle(p.text1.color)
                            .frame(height: 40, alignment: .leading).padding(.top, 2)
                        HStack(spacing: 6) {
                            MRIcon(.plane, size: 12)
                            Text("\(o.name) · \(o.iata)").font(.mr(.ui, size: 13, weight: 500))
                            MRIcon(.chevD, size: 12)
                        }
                        .foregroundStyle(p.text2.color).frame(height: 16).padding(.top, 6)
                    }
                    .padding(.vertical, 6).padding(.trailing, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("You are in \(o.city). Activate to change your departure airport.")
            }
            .offset(x: 28, y: 22)

            VStack(alignment: .leading, spacing: 12) {
                Button { model.planStage = .plan } label: {
                    Text("Start flight").font(.mr(.ui, size: 15, weight: 600)).foregroundStyle(p.bg0.color)
                        .frame(width: 252, height: 46)
                        .background(p.text1.color, in: Capsule())
                        .shadow(color: .black.opacity(0.35), radius: 11, y: 6)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain).accessibilityLabel("Start flight")
                VStack(spacing: 0) {
                    HomeItem(title: "Wallet", icon: .ticket, first: true) { model.section = .wallet }
                    HomeItem(title: "Stats", icon: .chart) { model.section = .stats }
                    HomeItem(title: "Together", icon: .users) { model.section = .together }
                }
                .padding(.vertical, 4).padding(.horizontal, 1).frame(width: 276)
                .mrGlass(cornerRadius: 22, elevation: .e3)
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 28).padding(.leading, 28)
            .frame(width: W, height: H, alignment: .bottomLeading)
        }
        .frame(width: W, height: H, alignment: .topLeading)
        .clipped()
    }
}

private struct HomeItem: View {
    let title: String
    let icon: MRIconName
    var first = false
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var hovered = false

    var body: some View {
        let p = MRPalette.resolve(scheme)
        Button(action: action) {
            HStack(spacing: 12) {
                MRIcon(icon, size: 18).foregroundStyle(p.text2.color)
                Text(title).font(.mr(.ui, size: 16, weight: 600)).foregroundStyle(p.text1.color)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16).frame(height: 42)
            .background(hovered ? p.fill2.color : .clear, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 3)
            .overlay(alignment: .top) { if !first { p.strokeHair.color.frame(height: 1).padding(.horizontal, 19).offset(y: -1) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).onHover { hv in withAnimation(MRMotion.hover) { hovered = hv } }
    }
}

/// `.ph-ring` (96 pt, breathing 1 -> 1.1 over 3.6 s) and `.ph-dot`.
private struct PulsePin: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var big = false

    var body: some View {
        let dark = scheme == .dark
        ZStack {
            Circle().fill(dark ? Color.white.opacity(0.28) : MRColorToken(20, 30, 50, 0.14).color)
                .frame(width: 96, height: 96).scaleEffect(big ? 1.1 : 1)
            Circle().fill(MRColorToken("#0B0F19").color).frame(width: 16, height: 16)
            Circle().strokeBorder(.white, lineWidth: 2.5).frame(width: 21, height: 21)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { big = true }
        }
    }
}

/// `.ph-stars`: 170 dots from `K.rng(11)`, in the top 62 % of the window.
private struct Stars: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Canvas { ctx, _ in
            let r = PlanKit.rng(11)
            for _ in 0..<170 {
                let sx = (r() * width).rounded(), sy = (r() * height * 0.62).rounded(), so = 0.25 + r() * 0.6, big = r() < 0.12
                let rect = big ? CGRect(x: sx - 1, y: sy - 1, width: 3, height: 3) : CGRect(x: sx, y: sy, width: 1, height: 1)
                ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(so)))
            }
        }
        .allowsHitTesting(false)
    }
}
