import MeridianCore
import MeridianMaps
import MeridianUI
import SwiftUI

private let blue = Color(.sRGB, red: 106 / 255, green: 183 / 255, blue: 1)
private let mint = Color(.sRGB, red: 139 / 255, green: 243 / 255, blue: 216 / 255)
private let periwinkle = Color(.sRGB, red: 159 / 255, green: 178 / 255, blue: 1)
private let amberPin = Color(.sRGB, red: 1, green: 181 / 255, blue: 71 / 255)

enum ExMapMode: Hashable { case globe, flat }
enum ExMapBy: Hashable { case frequency, scenario }

/// The World map screen (WorldMap.dc.html): globe or flat map, top airports, scenario legend and the replay scrubber.
struct WorldMapView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.mrPalette) private var p
    @Environment(\.colorScheme) private var scheme
    var data: ExploreData?
    var initialMode: ExMapMode = .globe
    var initialBy: ExMapBy = .frequency
    var initialT: Double = 1
    var initialHoverRow = -1
    var live = true
    /// Debug/screenshot routes: start zoomed (about the middle of the map) so zoom states can be rendered and compared.
    var initialZoom: Double = 1
    /// Map engine of the globe / flat map. `nil`: the Settings choice in the real app, Illustrated in the design-comparison routes.
    var engine: MapEngine?

    @State private var mode: ExMapMode?
    @State private var by: ExMapBy?
    @State private var t: Double?
    @State private var playing = false
    @State private var speed = 1
    @State private var seekDrag = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // zoom
    @State private var zoom = MapZoomModel()
    @State private var pinchStart: MapZoomModel?
    @State private var viewport = CGSize(width: 1280, height: 800)
    @State private var mapHover: CGPoint?
    @State private var rotation: CGSize = .zero
    @State private var seededZoom = false
    @State private var homeNonce = 0
    @AppStorage(MapEngine.defaultsKey) private var engineRaw = 0

    private var usesApple: Bool {
        let _ = engineRaw
        return (engine ?? (live ? MapEngine.current : .illustrated)) == .appleMaps && !MapHealth.shared.failed
    }

    /// Zoom-1 layout of the map in the canvas (`WorldMap.dc.html`): the globe frame and the flat world rectangle.
    private static let globeFrame = CGRect(x: 90, y: -50, width: 900, height: 900)
    private static let flatFrame = CGRect(x: 0, y: 152, width: 1280, height: 484)
    private static let globeRadius = 0.43 * 900.0
    private static let globeCenter = CGPoint(x: globeFrame.midX, y: globeFrame.midY)

    private var d: ExploreData {
        data ?? ExploreData.real(flights: model.walletFlights, totalKm: model.totalKm, streak: model.streak, stamps: model.stamps, index: model.index,
                                 name: NSFullUserName().isEmpty ? "You" : NSFullUserName())
    }

    var body: some View {
        let d = d
        let mode = mode ?? initialMode, by = by ?? initialBy, tt = t ?? initialT
        let map = MRMapPalette.resolve(.terra, dark: scheme == .dark)
        let routes = routes(d, by: by, t: tt)
        let pins = pins(d)
        let showVisited = by == .frequency && d.isFixture
        ZStack(alignment: .topLeading) {
            map.sea.color
            ExGlow(rx: 0.7, ry: 0.7, cx: 0.45, cy: 0.5, color: Color(.sRGB, red: 70 / 255, green: 92 / 255, blue: 190 / 255, opacity: scheme == .dark ? 0.22 : 0.12)).frame(maxWidth: .infinity, maxHeight: .infinity)
            Color.clear.overlay(alignment: .topLeading) {
                if usesApple {
                    ExAppleWorld(mode: mode, scale: zoom.scale, viewportHeight: viewport.height, routes: routes, pins: pins, marks: zoom.markScale,
                                 labelBudget: zoom.labelBudget(total: pins.count), homeNonce: homeNonce)
                        .frame(width: viewport.width, height: viewport.height)
                } else {
                ExZoomLayer(scale: zoom.scale, ox: zoom.offset.x, oy: zoom.offset.y, mode: mode, routes: routes, pins: pins, visited: showVisited,
                            isDraggable: live, rotation: $rotation, globeFrame: Self.globeFrame, flatFrame: Self.flatFrame)
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase { case .active(let p): mapHover = p; case .ended: mapHover = nil }
            }
            .simultaneousGesture(SpatialTapGesture(count: 2).onEnded { v in
                let out = NSEvent.modifierFlags.contains(.option)
                setZoom(out ? zoom.steppedOut(about: v.location) : (zoom.canZoomIn ? zoom.steppedIn(about: v.location) : zoom.reset()), mode: mode, animated: true)
            })
            if d.isEmpty && !d.isFixture {
                ExEmptyState(icon: .globe, title: "Nothing on the map yet", message: "Every landed flight draws its route here.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.leading, 72)
            }
            // title chip
            HStack(spacing: 14) {
                MRIcon(.globe, size: 18).foregroundStyle(p.accent1.color)
                ExT(s: "World", size: 15, weight: 600, lh: 15, color: p.text1.color)
                ExT(s: "\(d.countries) countries · \(d.airports) airports", fam: .mono, size: 12, weight: 500, lh: 12, color: p.text2.color)
            }
            .padding(.horizontal, 18).frame(height: 44)
            .mrGlass(in: Capsule(), elevation: .e2)
            .exAt(96, 36)
            // segmented controls
            HStack(spacing: 12) {
                glassSeg { MRSegmented(selection: Binding(get: { self.mode ?? initialMode }, set: { self.mode = $0 }), options: [.init(.globe, "Globe", icon: .globe, iconSize: 14), .init(.flat, "Flat", icon: .map, iconSize: 14)]) }
                glassSeg { MRSegmented(selection: Binding(get: { self.by ?? initialBy }, set: { self.by = $0 }), options: [.init(.frequency, "Frequency"), .init(.scenario, "Scenario")]) }
            }
            .frame(maxWidth: .infinity).offset(x: 30).padding(.top, 36)
            // top airports
            topAirports(d, by: by).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(.trailing, 24).padding(.top, 36)
            if !(d.isEmpty && !d.isFixture) {
                scrubber(d, t: tt).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading).padding(.leading, 96).padding(.bottom, 28)
            }
            zoomButtons(mode: mode).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(.trailing, 24).padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .background(GeometryReader { g in Color.clear.onAppear { viewportChanged(g.size, mode: mode) }.onChange(of: g.size) { _, n in viewportChanged(n, mode: mode) } })
        .background(MapScrollMonitor { handleScroll($0, mode: mode) })
        .onChange(of: mode) { _, m in modeChanged(m) }
        .gesture(MagnifyGesture()
            .onChanged { v in
                let start = pinchStart ?? zoom
                pinchStart = start
                setZoom(start.pinched(magnification: v.magnification, about: v.startLocation), mode: mode, animated: false)
            }
            .onEnded { _ in pinchStart = nil })
        .onKeyPress(characters: CharacterSet(charactersIn: "+=-_0"), phases: [.down, .repeat]) { press in
            let c = mapCenter(mode)
            switch press.characters {
            case "+", "=": setZoom(zoom.steppedIn(about: c), mode: mode, animated: true)
            case "-", "_": setZoom(zoom.steppedOut(about: c), mode: mode, animated: true)
            case "0": setZoom(zoom.reset(), mode: mode, animated: true)
            default: return .ignored
            }
            return .handled
        }
        .focusable().focusEffectDisabled()
        .onKeyPress(.rightArrow) { t = min(1, (t ?? initialT) + 0.05); playing = false; return .handled }
        .onKeyPress(.leftArrow) { t = max(0, (t ?? initialT) - 0.05); playing = false; return .handled }
        .onKeyPress(.space) { togglePlay(); return .handled }
        .task(id: playing) { await runPlayback() }
    }

    // MARK: zoom

    /// Where "the middle of the map" is on screen: the globe centre, or the viewport centre of the flat map.
    private func mapCenter(_ mode: ExMapMode) -> CGPoint {
        mode == .globe ? zoom.apply(Self.globeCenter) : CGPoint(x: viewport.width / 2, y: viewport.height / 2)
    }

    /// Clamps for the active mode (globe: bounded drift; flat: the world's edges stop at the viewport edges).
    private func limited(_ m: MapZoomModel, mode: ExMapMode, viewport: CGSize? = nil) -> MapZoomModel {
        mode == .globe ? m.clamped(toGlobeCenter: Self.globeCenter, radius: Self.globeRadius) : m.clamped(toRect: Self.flatFrame, viewport: viewport ?? self.viewport)
    }

    private func setZoom(_ m: MapZoomModel, mode: ExMapMode, animated: Bool) {
        let next = limited(m, mode: mode)
        if m.isDefault && !zoom.isDefault { homeNonce += 1 }
        if animated && !reduceMotion { withAnimation(MRMotion.smooth) { zoom = next } } else { zoom = next }
    }

    private func viewportChanged(_ size: CGSize, mode: ExMapMode) {
        guard size.width > 0, size.height > 0 else { return }
        viewport = size
        var m = zoom
        if !seededZoom {
            seededZoom = true
            if initialZoom != 1 {
                let c = mode == .globe ? Self.globeCenter : CGPoint(x: size.width * 0.55, y: 280)   // flat: about Europe
                m = MapZoomModel().zoomed(to: initialZoom, about: c)
            }
        }
        zoom = limited(m, mode: mode, viewport: size)
    }

    /// The zoom level is kept when switching between globe and flat; the offset restarts centred, since each mode limits it differently.
    private func modeChanged(_ m: ExMapMode) {
        let c = m == .globe ? Self.globeCenter : CGPoint(x: viewport.width / 2, y: viewport.height / 2)
        setZoom(MapZoomModel().zoomed(to: zoom.scale, about: c), mode: m, animated: true)
    }

    /// Mouse wheel and Option/Control + scroll zoom about the pointer. Plain two-finger trackpad scroll turns the globe
    /// (flat: pans). Returns whether the event was used.
    private func handleScroll(_ e: MapScrollEvent, mode: ExMapMode) -> Bool {
        guard mapHover != nil else { return false }
        if usesApple && !(e.zoomModifier || !e.precise) { return false }   // Apple Maps pans / turns itself   // pointer over a panel: let it be
        if e.zoomModifier || !e.precise {
            let dy = abs(e.dy) >= abs(e.dx) ? e.dy : e.dx
            guard dy != 0 else { return true }
            setZoom(zoom.zoomed(by: MapZoomModel.wheelFactor(deltaY: dy, precise: e.precise), about: e.location), mode: mode, animated: !e.precise)
            return true
        }
        if mode == .globe {
            guard live else { return false }
            // same mapping as a drag (0.4 deg/pt horizontally, 0.3 vertically), slower when zoomed in; latitude 36 +- 70 limit
            let f = zoom.rotationFactor
            rotation = CGSize(width: rotation.width - e.dx * 0.4 * f, height: max(-70 - 36, min(70 - 36, rotation.height + e.dy * 0.3 * f)))
        } else {
            setZoom(zoom.panned(by: CGSize(width: e.dx, height: e.dy)), mode: mode, animated: false)
        }
        return true
    }

    private func zoomButtons(mode: ExMapMode) -> some View {
        VStack(spacing: 8) {
            Button { setZoom(zoom.steppedIn(about: mapCenter(mode)), mode: mode, animated: true) } label: { MRIcon(.plus, size: 18) }
                .buttonStyle(MRRoundButtonStyle()).disabled(!zoom.canZoomIn)
                .accessibilityLabel("Zoom in")
            Button { setZoom(zoom.steppedOut(about: mapCenter(mode)), mode: mode, animated: true) } label: { MRIcon(.minus, size: 18) }
                .buttonStyle(MRRoundButtonStyle()).disabled(!zoom.canZoomOut)
                .accessibilityLabel("Zoom out")
        }
        .help("Zoom: pinch, scroll wheel, Option + scroll, + / - keys, double-click. 0 resets.")
    }

    // MARK: data -> map layers

    private func routes(_ d: ExploreData, by: ExMapBy, t: Double) -> [GlobeRoute] {
        d.routes.filter { $0.t <= t + 1e-6 }.compactMap { r in
            let fresh = t - r.t < 0.07
            let col: Color = by == .scenario ? ExScn.get(r.scenario).color : (r.count >= 6 ? mint : r.count >= 3 ? blue : periwinkle)
            return GlobeRoute(from: r.a, to: r.b, color: fresh ? .white : col, width: 1 + min(2.4, Double(r.count) * 0.16), opacity: fresh ? 0.95 : 0.78, lift: 0.08)
        }
    }

    private func pins(_ d: ExploreData) -> [GlobePin] {
        let mx = Double(max(1, d.topAirportMax))
        return d.topAirports.compactMap { a in
            GlobePin(code: a.code, showsLabel: true, color: amberPin, radius: 2.6 + Double(a.visits) / mx * 2.4)
        }
    }

    // MARK: panels

    private func glassSeg<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        c().padding(4).mrGlass(cornerRadius: 16, elevation: .e2)
    }

    private func topAirports(_ d: ExploreData, by: ExMapBy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                ExT(s: "Top airports", size: 15, weight: 600, lh: 18, color: p.text1.color)
                Spacer(minLength: 0)
                ExEyebrow(s: "Visits")
            }.padding(.horizontal, 10)
            VStack(spacing: 0) {
                let mx = Double(max(1, d.topAirportMax))
                ForEach(Array(d.topAirports.enumerated()), id: \.offset) { i, a in
                    row(i, a.code, a.visits, mx)
                }
            }.padding(.top, 10)
            Rectangle().fill(p.strokeHair.color).frame(height: 1).padding(.horizontal, 10).padding(.top, 10).padding(.bottom, 12)
            VStack(alignment: .leading, spacing: 0) {
                if by == .frequency {
                    ExEyebrow(s: "Country intensity").padding(.bottom, 8)
                    RoundedRectangle(cornerRadius: 4).fill(LinearGradient(colors: [blue.opacity(0.22), blue.opacity(0.46), blue.opacity(0.78)], startPoint: .leading, endPoint: .trailing)).frame(height: 8)
                    HStack {
                        ExT(s: "1 flight", fam: .mono, size: 10, weight: 500, lh: 10, color: p.text3.color)
                        Spacer(minLength: 0)
                        ExT(s: "10+", fam: .mono, size: 10, weight: 500, lh: 10, color: p.text3.color)
                    }.padding(.top, 6)
                } else {
                    ExEyebrow(s: "Routes by scenario").padding(.bottom, 8)
                    ExFlow(hSpacing: 12, vSpacing: 6) {
                        ForEach(ExScn.legend, id: \.self) { id in
                            HStack(spacing: 6) {
                                Circle().fill(ExScn.get(id).color).frame(width: 8, height: 8)
                                ExT(s: ExScn.get(id).name, size: 11, weight: 500, lh: 11, color: p.text2.color)
                            }
                        }
                    }
                }
            }.padding(.horizontal, 10).padding(.bottom, 4)
        }
        .padding(.top, 18).padding(.horizontal, 12).padding(.bottom, 12)
        .frame(width: 272, alignment: .topLeading)
        .mrGlass(cornerRadius: 26, elevation: .e3)
    }

    @State private var hoverRow: Int?

    private func row(_ i: Int, _ code: String, _ n: Int, _ mx: Double) -> some View {
        let hov = hoverRow == i || (hoverRow == nil && initialHoverRow == i && !hoverSeen)
        let city = MapAirports.bundled.coordinate(code) != nil ? (cityName(code)) : code
        return HStack(spacing: 12) {
            ExT(s: "\(i + 1)", fam: .mono, size: 11, weight: 500, lh: 11, color: p.text3.color).frame(width: 16, alignment: .trailing)
            Text(code).font(MRFonts.font(.condensed, size: 13, weight: 700)).tracking(0.65).foregroundStyle(p.ink.color)
                .frame(minWidth: 40).frame(height: 22).background(p.amber.color, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(city).font(MRFonts.font(.ui, size: 13, weight: 500)).foregroundStyle(p.text1.color).lineLimit(1).truncationMode(.tail).frame(height: 16, alignment: .leading)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(p.fill2.color)
                        RoundedRectangle(cornerRadius: 2).fill(p.accentGradient).frame(width: g.size.width * (Double(n) / mx).rounded(toPlaces: 2))
                    }
                }.frame(height: 3).clipShape(RoundedRectangle(cornerRadius: 2))
            }
            ExT(s: "\(n)", fam: .mono, size: 12, weight: 500, lh: 12, color: p.text1.color)
        }
        .padding(.horizontal, 10).frame(height: 44)
        .background(hov ? p.fill1.color : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onHover { h in hoverSeen = true; hoverRow = h ? i : (hoverRow == i ? nil : hoverRow) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(city), \(n) visits")
        .accessibilityAddTraits(.isButton)
    }
    @State private var hoverSeen = false

    private func cityName(_ code: String) -> String {
        if (data?.isFixture ?? false), let c = ExploreData.designCity[code] { return c }
        return model.index.airport(iata: code)?.city ?? ExploreData.designCity[code] ?? code
    }

    // MARK: scrubber

    private func scrubber(_ d: ExploreData, t: Double) -> some View {
        HStack(spacing: 18) {
            Button { togglePlay() } label: { MRIcon(playing ? .pause : .play, size: 20) }
                .buttonStyle(MRRoundButtonStyle()).frame(width: 44, height: 44)
                .accessibilityLabel(playing ? "Pause replay" : "Play replay")
            VStack(alignment: .leading, spacing: 2) {
                ExEyebrow(s: "Replay")
                ExT(s: d.monthLabel(t), fam: .mono, size: 18, weight: 500, lh: 24, color: p.text1.color)
            }.frame(width: 112, alignment: .leading)
            track(d, t: t)
            VStack(alignment: .trailing, spacing: 0) {
                ExT(s: "\(d.flightsAt(t))", fam: .mono, size: 18, weight: 500, lh: 24, color: p.text1.color)
                ExEyebrow(s: "flights")
            }.frame(width: 84, alignment: .trailing)
            MRSegmented(selection: $speed, options: [1, 2, 4].map { .init($0, "\($0)×") })
        }
        .padding(.horizontal, 22)
        .frame(width: 872, height: 84)
        .mrGlass(cornerRadius: 30, elevation: .e3)
    }

    private func track(_ d: ExploreData, t: Double) -> some View {
        let n = max(2, d.replayMonths)
        return GeometryReader { g in
            let w = g.size.width
            ZStack(alignment: .topLeading) {
                Capsule().fill(p.fill3.color).frame(width: w, height: 4).exAt(0, 20)
                Capsule().fill(p.accentGradient).frame(width: w * t, height: 4).exAt(0, 20)
                ForEach(0..<n, id: \.self) { i in
                    let big = (i + d.replayStart.month) % 12 == 0
                    Rectangle().fill(p.text3.color).opacity(big ? 0.9 : 0.5).frame(width: 1, height: big ? 24 : 16).exAt(w * CGFloat(i) / CGFloat(n - 1), big ? 10 : 14)
                }
                Circle().fill(.white).frame(width: 20, height: 20)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                    .background(Circle().fill(blue.opacity(0.35)).frame(width: 30, height: 30))
                    .exAt(w * t - 10, 12)
                ExT(s: d.replayStartLabel, fam: .mono, size: 10, weight: 500, lh: 10, color: p.text3.color).exAt(0, 34)
                ExT(s: d.replayEndLabel, fam: .mono, size: 10, weight: 500, lh: 10, color: p.text3.color).frame(width: w, alignment: .trailing).exAt(0, 34)
            }
            .frame(width: w, height: 44, alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                playing = false
                self.t = max(0, min(1, v.location.x / w))
            })
        }
        .frame(height: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Replay time")
        .accessibilityValue("\(Int((t * 100).rounded())) percent")
        .accessibilityAdjustableAction { dir in
            switch dir { case .increment: self.t = min(1, t + 0.05); case .decrement: self.t = max(0, t - 0.05); @unknown default: break }
        }
    }

    private func togglePlay() {
        let cur = t ?? initialT
        if !playing && cur >= 1 { t = 0 }
        playing.toggle()
    }

    private func runPlayback() async {
        guard playing else { return }
        var last = ContinuousClock.now
        while playing && !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(16))
            let now = ContinuousClock.now
            let dt = Double((now - last).components.seconds) + Double((now - last).components.attoseconds) / 1e18
            last = now
            let next = (t ?? initialT) + dt * 0.06 * Double(speed)
            if next >= 1 { t = 1; playing = false; return }
            t = next
        }
    }
}

private extension Double {
    func rounded(toPlaces n: Int) -> Double { let m = pow(10, Double(n)); return (self * m).rounded() / m }
}

/// Wrapping row layout (`display:flex; flex-wrap:wrap`).
struct ExFlow: Layout {
    var hSpacing: CGFloat, vSpacing: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal.width ?? .infinity, subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let a = arrange(bounds.width, subviews)
        for (i, f) in a.frames.enumerated() { subviews[i].place(at: CGPoint(x: bounds.minX + f.minX, y: bounds.minY + f.minY), proposal: .unspecified) }
    }
    private func arrange(_ width: CGFloat, _ subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        var frames: [CGRect] = []
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0 && x + sz.width > width { x = 0; y += rowH + vSpacing; rowH = 0 }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: sz))
            x += sz.width + hSpacing; rowH = max(rowH, sz.height); maxX = max(maxX, x - hSpacing)
        }
        return (CGSize(width: maxX, height: y + rowH), frames)
    }
}

extension ExploreData {
    /// City names of the canvas airports used by the fixture when the bundled database lacks them.
    static let designCity: [String: String] = ["LHR": "London", "CDG": "Paris", "AMS": "Amsterdam", "IST": "Istanbul", "JFK": "New York", "FRA": "Frankfurt", "DUB": "Dublin", "MAD": "Madrid"]
}

/// The map layer: redraws the globe / flat map at the zoomed size (vector, never a scaled bitmap). It is `Animatable`, so a
/// `withAnimation` zoom re-evaluates it every frame with the interpolated scale and offset.
private struct ExZoomLayer: View, Animatable {
    var scale: Double, ox: Double, oy: Double
    var mode: ExMapMode
    var routes: [GlobeRoute]
    var pins: [GlobePin]
    var visited: Bool
    var isDraggable: Bool
    var rotation: Binding<CGSize>
    var globeFrame: CGRect
    var flatFrame: CGRect

    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { .init(scale, .init(ox, oy)) }
        set { scale = newValue.first; ox = newValue.second.first; oy = newValue.second.second }
    }

    var body: some View {
        let m = MapZoomModel(scale: scale, offset: CGPoint(x: ox, y: oy))
        // labels: more of them the closer you are, fewer far away; pins and route widths follow gently
        let budget = m.labelBudget(total: pins.count)
        let pins = pins.enumerated().map { i, p -> GlobePin in
            var q = p; if i >= budget { q.label = nil }; q.radius *= m.markScale; return q
        }
        let routes = routes.map { r -> GlobeRoute in var q = r; q.width *= m.markScale; return q }
        if mode == .globe {
            let o = m.apply(globeFrame.origin)
            GlobeView(lon: -8, lat: 36, size: globeFrame.width * m.scale, routes: routes, pins: pins, visited: visited, isDraggable: isDraggable,
                      rotation: rotation, dragSpeed: m.rotationFactor).offset(x: o.x, y: o.y)
        } else {
            let o = m.apply(flatFrame.origin)
            WorldFlatView(w: flatFrame.width * m.scale, latTop: 80, latBot: -56, visited: visited, routes: routes, pins: pins).offset(x: o.x, y: o.y)
        }
    }
}
