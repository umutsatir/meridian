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
    @AppStorage(MapEngine.homeGlobeKey) private var homeGlobeRaw = 0
    @AppStorage(MapEngine.defaultsKey) private var engineRaw = 0
    /// Hour of day for the greeting; `nil` uses the clock.
    var hour: Int?
    /// Trackpad / pinch / keys move the globe. `false`: a fixed picture.
    var interactive = true
    /// The user's camera; `nil` = the home framing. The globe never moves on its own.
    @State private var userCamera: GlobeCamera?
    @State private var pinchStart: GlobeCamera?
    @State private var seededDebug = false
    @State private var viewSize = CGSize(width: 1280, height: 800)

    var body: some View {
        GeometryReader { geo in
            content(W: geo.size.width, H: geo.size.height)
        }
    }

    private var greeting: String {
        let h = hour ?? Calendar.current.component(.hour, from: .now)
        return (h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening") + "!"
    }

    // MARK: globe camera

    private static let satelliteTilt = 32.0
    private static let illustratedTilt = 38.0
    private static let globeSize = 2200.0
    private var realisticGlobe: Bool { let _ = (homeGlobeRaw, engineRaw); return MapEngine.homeGlobeIsRealistic && !MapHealth.shared.failed }

    /// The canvas framing (Home S10): the origin above the middle of the globe.
    private func homeCamera() -> GlobeCamera {
        let c = model.plan.origin.coordinate
        if realisticGlobe { return SatelliteGlobeView<EmptyView>.homeCamera(home: c, tilt: Self.satelliteTilt) }
        return GlobeCamera(lon: c.longitude, lat: max(-60, min(60, c.latitude - Self.illustratedTilt)))
    }
    private var camera: GlobeCamera { userCamera ?? homeCamera() }

    /// Screen radius of the sphere in points (for finger-following pan speed).
    private func screenRadius(_ cam: GlobeCamera, height H: Double) -> Double {
        if realisticGlobe { return 6.371e6 / (2.2e7 * (H / 800) / cam.zoom * 0.536) * H }   // MapKit: visible height ~ 0.536 x distance
        return 0.43 * Self.globeSize * cam.zoom
    }

    private func setCamera(_ c: GlobeCamera) {
        userCamera = c.isDisplaced(from: homeCamera(), epsilon: 0.01) ? c : nil
    }
    private func pan(dx: Double, dy: Double) {
        let c = camera
        setCamera(c.panned(dx: dx, dy: dy, degreesPerPoint: GlobeCamera.degreesPerPoint(screenRadius: screenRadius(c, height: viewSize.height))))
    }
    private func recenter(animated: Bool) {
        if animated { withAnimation(MRMotion.smooth) { userCamera = nil } } else { userCamera = nil }
    }
    private func handleScroll(_ e: MapScrollEvent) -> Bool {
        guard interactive, !model.searchOpen, !popOpen else { return false }
        // the Start flight / list panel keeps its own scrolling
        if e.location.x < 330 && e.location.y > viewSize.height - 240 { return false }
        if e.modifiers.contains(.command) {
            let dy = abs(e.dy) >= abs(e.dx) ? e.dy : e.dx
            if dy != 0 { setCamera(camera.zoomed(by: MapZoomModel.wheelFactor(deltaY: dy, precise: e.precise))) }
            return true
        }
        let f = e.precise ? 1.0 : 8.0   // a notched wheel reports lines
        pan(dx: e.dx * f, dy: e.dy * f)
        return true
    }
    /// `--pan dx,dy` / `--pinch f` launch arguments apply one gesture at start (screenshots).
    private func seedDebugGesture() {
        guard !seededDebug else { return }
        seededDebug = true
        let a = CommandLine.arguments
        if let i = a.firstIndex(of: "--pan"), i + 1 < a.count {
            let v = a[i + 1].split(separator: ",").compactMap { Double($0) }
            if v.count == 2 { pan(dx: v[0], dy: v[1]) }
        }
        if let i = a.firstIndex(of: "--pinch"), i + 1 < a.count, let f = Double(a[i + 1]) { setCamera(camera.zoomed(by: f)) }
    }

    private func content(W: CGFloat, H: CGFloat) -> some View {
        let p = MRPalette.resolve(scheme)
        let dark = scheme == .dark
        let _ = (homeGlobeRaw, engineRaw)
        let realistic = realisticGlobe
        let o = model.plan.origin
        let cam = camera
        let GS = Self.globeSize * cam.zoom, GR = GS * 0.43, GC = GS / 2
        let gLat = cam.lat, gLon = cam.lon
        // the sphere turns and grows about its canvas centre: the sphere top sits at y = 190 at zoom 1
        let centerY = 190 + 0.43 * Self.globeSize
        let gx = W / 2 - GS / 2, gy = centerY - GC
        // orthographic point of the origin on the globe (`MeridianWorld.point`); hidden on the far side
        let d = Double.pi / 180
        let la = o.coordinate.latitude * d, lo = (o.coordinate.longitude - gLon) * d, ph = gLat * d
        let px = GR * cos(la) * sin(lo)
        let py = GR * (cos(ph) * sin(la) - sin(ph) * cos(la) * cos(lo))
        let facing = sin(ph) * sin(la) + cos(ph) * cos(la) * cos(lo) > 0.02
        let pin = CGPoint(x: gx + GC + px, y: gy + GC - py)
        let override = dark ? GlobeColorOverride(seaA: 0x34678F, seaB: 0x12304F, land: 0x6B7A4E, shade: 0.62, rim: 0.5)
                            : GlobeColorOverride(seaA: 0xDCE8F3, seaB: 0xA8C2DB, land: 0xFBF9F4, shade: 0.2, rim: 0.25)

        return ZStack(alignment: .topLeading) {
            p.bg0.color
            if dark && !realistic { Stars(width: W, height: H) }
            if realistic {
                SatelliteGlobeView(home: o.coordinate, camera: cam, distance: 2.2e7 * (H / 800)) {
                    PulsePin()
                }
                .frame(width: W, height: H)
                // top scrim so the greeting reads over bright imagery
                LinearGradient(stops: [.init(color: p.bg0.color.opacity(dark ? 0.78 : 0.6), location: 0),
                                       .init(color: p.bg0.color.opacity(0), location: 0.34)], startPoint: .top, endPoint: .bottom)
                    .allowsHitTesting(false)
                // bottom scrim under "Start flight" and the list
                LinearGradient(stops: [.init(color: p.bg0.color.opacity(0), location: 0.62),
                                       .init(color: p.bg0.color.opacity(dark ? 0.7 : 0.5), location: 1)], startPoint: .top, endPoint: .bottom)
                    .allowsHitTesting(false)
            } else {
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
                if facing { PulsePin().position(pin).allowsHitTesting(false) }
            }
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
        .background(MapScrollMonitor { handleScroll($0) })
        .gesture(MagnifyGesture()
            .onChanged { v in
                let start = pinchStart ?? camera
                pinchStart = start
                setCamera(start.pinched(magnification: v.magnification))
            }
            .onEnded { _ in pinchStart = nil }, isEnabled: interactive)
        .simultaneousGesture(SpatialTapGesture(count: 2).onEnded { _ in recenter(animated: true) }, isEnabled: interactive)
        .focusable(interactive).focusEffectDisabled()
        .onKeyPress(characters: CharacterSet(charactersIn: "+=-_0"), phases: [.down, .repeat]) { press in
            guard interactive else { return .ignored }
            switch press.characters {
            case "+", "=": setCamera(camera.steppedIn())
            case "-", "_": setCamera(camera.steppedOut())
            case "0": recenter(animated: true)
            default: return .ignored
            }
            return .handled
        }
        .onChange(of: model.plan.origin.iata) { _, _ in userCamera = nil }
        .onAppear { viewSize = CGSize(width: W, height: H); seedDebugGesture() }
        .onChange(of: H) { _, _ in viewSize = CGSize(width: W, height: H) }
        .overlay(alignment: .bottomTrailing) {
            if interactive && userCamera != nil {
                Button { recenter(animated: true) } label: { MRIcon(.target, size: 18) }
                    .buttonStyle(MRRoundButtonStyle())
                    .accessibilityLabel("Recenter home")
                    .help("Recenter on home (double-click, 0)")
                    .padding(.trailing, 24).padding(.bottom, 28)
            }
        }
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
