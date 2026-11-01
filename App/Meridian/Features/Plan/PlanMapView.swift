import AppKit
import MeridianCore
import MeridianMaps
import MeridianPlan
import MeridianUI
import SwiftUI

/// Plan stage of `Planner.dc.html`: map, range ring, tags, ruler, destination dock and the Check in bar.
struct PlanMapView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Binding var popOpen: Bool
    @Binding var mapStyle: MapStyle
    let onCheckIn: (_ quick: Bool) -> Void

    @State private var scrub: DurationScrub?
    @State private var hover: String?
    @State private var scenarioMenu = false

    var body: some View {
        GeometryReader { geo in
            content(size: geo.size)
        }
    }

    private func content(size: CGSize) -> some View {
        let plan = model.plan
        let p = MRPalette.resolve(scheme)
        let W = size.width, H = size.height
        let free = scrub?.isFree ?? plan.isFreeFlight
        let rawMinutes = scrub?.rawMinutes ?? Double(plan.durationMinutes ?? 372)
        let scene = PlanScene(plan: plan, size: size, minutes: free ? nil : min(360, rawMinutes))
        let dragging = scrub != nil
        let flagText = free ? "∞ Free flight" : PlanKit.fmtDur(dragging ? Double(scrub?.detentMinutes ?? 0) : rawMinutes.rounded())
        let cx = W / 2

        return ZStack(alignment: .topLeading) {
            MapSurface(style: MapStyleAccess.resolved(mapStyle), center: plan.origin.coordinate, zoom: scene.zoom,
                          offset: CGSize(width: 0, height: scene.center.y - H / 2))
                .animation(EuropeMapView.cameraAnimation, value: MapKey(zoom: scene.zoom, origin: plan.origin.iata))
                .frame(width: W, height: H)

            LinearGradient(stops: [.init(color: Color(red: 6 / 255, green: 8 / 255, blue: 13 / 255).opacity(0), location: 0.55),
                                   .init(color: Color(red: 6 / 255, green: 8 / 255, blue: 13 / 255).opacity(0.45), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)

            // range ring, arc, tags, origin
            RangeRingView(radius: scene.ringRadius, animated: !dragging)
                .position(scene.center)
                .allowsHitTesting(false)
            if let arc = scene.arc, let end = scene.selectedPoint {
                ArcLayer(size: size, path: arc, from: scene.center, to: end)
                    .id("\(plan.origin.iata)>\(scene.selected?.iata ?? "")")
                    .allowsHitTesting(false)
            }
            ForEach(scene.tags) { t in
                tagView(t, palette: p)
                    .position(t.point)
                    .animation(MRMotion.ease(MRMotion.d4), value: t.point)
                    .zIndex(t.kind == .selected ? 4 : (hover == t.airport.iata ? 6 : 2))
            }
            OriginDot().position(scene.center).allowsHitTesting(false)
            Text("\(plan.origin.iata) · YOU ARE HERE")
                .font(.mr(.ui, size: 10, weight: 500)).tracking(0.8)
                .foregroundStyle(p.text1.color).shadow(color: .black.opacity(0.4), radius: 4, y: 1)
                .fixedSize().position(x: scene.center.x, y: scene.center.y + 24 + 7)
                .allowsHitTesting(false)

            // top bar
            Button { model.planStage = .home } label: { MRIcon(.chevL, size: 18) }
                .buttonStyle(MRRoundButtonStyle()).accessibilityLabel("Back")
                .offset(x: 20, y: 18)
            originChip(p).offset(x: 74, y: 14)
            HStack(spacing: 10) {
                Button { _ = model.plan.surpriseMe() } label: { MRIcon(.shuffle, size: 18) }
                    .buttonStyle(MRRoundButtonStyle()).accessibilityLabel("Random destination")
                Button { model.searchOpen = true } label: { MRIcon(.search, size: 18) }
                    .buttonStyle(MRRoundButtonStyle()).accessibilityLabel("Search airports ⌘K")
                Button { cycleStyle() } label: { MRIcon(.layers, size: 18) }
                    .buttonStyle(MRRoundButtonStyle()).accessibilityLabel("Map style: \(mapStyle.rawValue)")
            }
            .offset(x: W - 20 - 140, y: 18)

            // scenario row
            HStack(spacing: 10) {
                ScenarioMenuChip(open: $scenarioMenu)
                MRSegmented(selection: Binding(get: { model.plan.mode }, set: { model.plan.setMode($0) }),
                            options: [.init(.solo, "Solo"), .init(.together, "Together", icon: .users, iconSize: 12)])
                    .background(MRGlassBackdrop(cornerRadius: 12))
            }
            .frame(height: 40)
            .offset(x: 28, y: H - 332)
            .zIndex(20)

            // ruler
            DurationRuler(minutes: rawMinutes, flagText: flagText, isDragging: dragging,
                          onBegin: { x in beginScrub(x) }, onDrag: { x in dragScrub(x) },
                          onScroll: { d, ended in scrollScrub(d, ended: ended) }, onEnd: { endScrub() },
                          onKey: { dir, shift in keyScrub(dir, shift: shift) })
                .offset(x: cx - 380 - 12, y: H - 282)
                .zIndex(20)

            // dock
            DestinationDock(scene: scene, width: W - 56)
                .frame(width: W - 56, height: 108, alignment: .topLeading)
                .clipped()
                .offset(x: 28, y: H - 200)
                .zIndex(20)

            // check in
            HStack(spacing: 12) {
                Button { onCheckIn(false) } label: { Text("Check in") }
                    .buttonStyle(MRButtonStyle(.primary, size: .lg))
                    .keyboardShortcut(.return, modifiers: [])
                Button { onCheckIn(true) } label: {
                    HStack(spacing: 8) { Text("Quick start"); MRKbd("⌘⏎") }.padding(.horizontal, -6)
                }
                .buttonStyle(MRButtonStyle(.secondary, size: .lg))
                .keyboardShortcut(.return, modifiers: .command)
            }
            .disabled(!free && scene.selected == nil)
            .frame(width: 480, height: 64)
            .mrGlass(cornerRadius: 34, elevation: .e3)
            .offset(x: cx - 240, y: H - 82)
            .zIndex(25)

            if plan.showsRulerCoachMark { CoachMark(width: W, height: H) { model.plan.dismissRulerCoachMark() } }
        }
        .frame(width: W, height: H, alignment: .topLeading)
        .overlay(alignment: .topLeading) {
            if scenarioMenu {
                ScenarioMenu(close: { scenarioMenu = false }).offset(x: 28, y: H - 332 - 6 - 8 * 28 - 12).zIndex(50)
            }
        }
        .onKeyPress(.leftArrow) { model.plan.selectPreviousDestination(); return .handled }
        .onKeyPress(.rightArrow) { model.plan.selectNextDestination(); return .handled }
    }

    private struct MapKey: Equatable { var zoom: Double; var origin: String }

    // MARK: pieces

    private func tagView(_ t: PlanScene.Tag, palette p: MRPalette) -> some View {
        let visited = PlanKit.visited[t.airport.iata].map { Color(RGB(hex: PlanKit.scenario($0).hex)) }
        return AirportTag(code: t.airport.iata, isSelected: t.kind == .selected, isDisabled: t.kind == .out, showsIcon: true, visitedColor: visited)
            .overlay(alignment: .top) {
                if hover == t.airport.iata {
                    HStack(spacing: 8) {
                        Text(t.airport.name).font(.mr(.ui, size: 12, weight: 600))
                        Text("\(PlanKit.fmtKm(t.km)) km · \(PlanKit.fmtShort(t.minutes))").font(.mr(.mono, size: 11, weight: 500)).foregroundStyle(p.text2.color)
                    }
                    .foregroundStyle(scheme == .dark ? p.text1.color : Color(RGB(hex: "#F3F5FA")))
                    .padding(.horizontal, 10).padding(.vertical, 7).fixedSize()
                    .background(scheme == .dark ? MRColorToken(18, 26, 46, 0.92).color : MRColorToken(20, 22, 28, 0.92).color, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(p.strokeHair.color))
                    .fixedSize().offset(y: -42)
                }
            }
            .onHover { hv in withAnimation(MRMotion.hover) { hover = hv ? t.airport.iata : (hover == t.airport.iata ? nil : hover) } }
            .onTapGesture { if t.kind != .out { model.plan.select(iata: t.airport.iata) } }
    }

    private func originChip(_ p: MRPalette) -> some View {
        Button { popOpen.toggle() } label: {
            HStack(spacing: 8) {
                Text("From").font(.mr(.ui, size: 13)).foregroundStyle(p.text2.color).padding(.leading, 4)
                Text(model.plan.origin.iata).font(.mr(.condensed, size: 24, weight: 700)).tracking(24 * 0.02).foregroundStyle(p.text1.color)
                Text("· \(model.plan.origin.city)").font(.mr(.ui, size: 13)).foregroundStyle(p.text2.color)
                MRIcon(.chevD, size: 14).foregroundStyle(p.text2.color).padding(.leading, 4)
            }
            .padding(.leading, 12).padding(.trailing, 16).frame(height: 48)
            .mrGlass(cornerRadius: 24, elevation: .e2)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Departure airport \(model.plan.origin.iata) \(model.plan.origin.city). Activate to change.")
        .zIndex(30)
    }

    private func cycleStyle() {
        let all = MapStyle.allCases
        let open = all.filter { MapStyleAccess.isUnlocked($0) }
        mapStyle = open[((open.firstIndex(of: mapStyle) ?? -1) + 1) % open.count]
    }

    // MARK: scrubbing (DurationScrub owns the numbers)

    private func haptic() { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now) }

    private func beginScrub(_ x: Double) {
        var s = model.plan.makeScrub()
        s.beginDrag(atX: x)
        scrub = s
        model.plan.dismissRulerCoachMark()
    }

    private func dragScrub(_ x: Double) {
        guard var s = scrub else { return }
        let step = s.drag(toX: x)
        scrub = s
        if step.crossedDetent { haptic(); model.plan.apply(s) }
    }

    private func scrollScrub(_ delta: Double, ended: Bool) {
        var s = scrub ?? model.plan.makeScrub()
        if delta != 0 {
            model.plan.dismissRulerCoachMark()
            let step = s.scroll(deltaPx: delta)
            if step.crossedDetent { haptic(); model.plan.apply(s) }
            scrub = s
        }
        if ended { endScrub() }
    }

    private func keyScrub(_ dir: Int, shift: Bool) {
        var s = model.plan.makeScrub()
        let step = s.step(dir, shift: shift)
        model.plan.dismissRulerCoachMark()
        if step.crossedDetent { haptic() }
        model.plan.apply(s)
    }

    private func endScrub() {
        guard var s = scrub else { return }
        s.endGesture()
        model.plan.apply(s)
        withAnimation(MRMotion.snappy) { scrub = nil }
    }
}

// MARK: - Layers

private struct RangeRingView: View {
    let radius: Double
    let animated: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let dark = scheme == .dark
        let d = radius * 2
        let fill = dark ? [MRColorToken(160, 170, 255, 0.16), MRColorToken(160, 170, 255, 0.08), MRColorToken(160, 170, 255, 0.04)]
                        : [MRColorToken(30, 107, 255, 0.10), MRColorToken(30, 107, 255, 0.06), MRColorToken(30, 107, 255, 0.03)]
        let line = dark ? MRColorToken(190, 200, 255, 0.34) : MRColorToken(30, 107, 255, 0.4)
        let glow = dark ? (MRColorToken(140, 150, 255, 0.18), 80.0) : (MRColorToken(30, 107, 255, 0.12), 60.0)
        ZStack {
            Circle().fill(glow.0.color).blur(radius: glow.1 / 2)
                .mask {
                    Rectangle().padding(-200).overlay(Circle().blendMode(.destinationOut)).compositingGroup()
                }
            Circle().fill(RadialGradient(stops: [.init(color: fill[0].color, location: 0), .init(color: fill[1].color, location: 0.7),
                                                 .init(color: fill[2].color, location: 1)],
                                         center: .center, startRadius: 0, endRadius: radius * 2.0.squareRoot()))
            Circle().stroke(line.color, lineWidth: 1.5).padding(-0.75)
        }
        .frame(width: d, height: d)
        .animation(animated ? MRMotion.snappy : nil, value: radius)
    }
}

private struct OriginDot: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let dark = scheme == .dark
        ZStack {
            Circle().fill(dark ? MRColorToken(255, 255, 255, 0.14).color : MRColorToken(20, 22, 28, 0.12).color).frame(width: 34, height: 34)
                .shadow(color: dark ? .black.opacity(0.5) : MRColorToken(40, 34, 20, 0.3).color, radius: 6, y: 4)
            Circle().fill(dark ? MRColorToken("#06080D").color : MRColorToken("#14161C").color).frame(width: 16, height: 16)
            Circle().strokeBorder(.white, lineWidth: 3).frame(width: 22, height: 22)
        }
    }
}

private struct ArcLayer: View {
    let size: CGSize
    let path: Path
    let from: CGPoint
    let to: CGPoint
    @State private var shown = false

    var body: some View {
        ZStack {
            ArcShape(path: path, progress: shown ? 1 : 0)
                .stroke(Color(red: 106 / 255, green: 183 / 255, blue: 1).opacity(0.3), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .blur(radius: 4)
            ArcShape(path: path, progress: shown ? 1 : 0)
                .stroke(LinearGradient(colors: [MRColorToken("#6AB7FF").color, MRColorToken("#8BF3D8").color],
                                       startPoint: UnitPoint(x: from.x / size.width, y: from.y / size.height),
                                       endPoint: UnitPoint(x: to.x / size.width, y: to.y / size.height)),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        .onAppear { withAnimation(MRMotion.ease(MRMotion.d3 + 0.1)) { shown = true } }
    }
}

private struct ArcShape: Shape {
    var path: Path
    var progress: Double
    nonisolated var animatableData: Double { get { progress } set { progress = newValue } }
    nonisolated func path(in rect: CGRect) -> Path { path.trimmedPath(from: 0, to: progress) }
}

/// `.glass` backdrop behind a control that has its own fill (the `.seg.glass` combination of the canvas).
private struct MRGlassBackdrop: View {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let p = MRPalette.resolve(scheme)
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape.fill(.ultraThinMaterial.opacity(0.0)).mrOuterShadow(shape, [p.e3])
    }
}
