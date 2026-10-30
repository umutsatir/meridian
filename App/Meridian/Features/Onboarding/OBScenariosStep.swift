import MeridianUI
import SwiftUI

/// S03: scenario chip playground (ONB-3). Chips collide and settle (own integrator in `ChipPhysics`);
/// with Reduce Motion they sit in a static grid. At least one scenario must stay selected to continue.
struct OBScenariosStep: View {
    @Bindable var model: OnboardingModel
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var physics = ChipPhysics()
    @State private var adding = false
    @State private var newName = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        let p = MRPalette.resolve(scheme)
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                OT("What do you focus on?").obType(.serif, 48, 500, lh: 52, tracking: -0.02).foregroundStyle(p.text1.color)
                OT("Pick the kinds of work you'll fly. Drag them around. Change this any time.")
                    .obType(.ui, 17, 400, lh: 26).foregroundStyle(p.text2.color).padding(.top, 12)
            }
            .frame(width: 700, alignment: .leading)
            .obAt(96, 96)

            countPill(p).obAt(obCanvasWidth - 96 - countPillWidth, 112)
            tray(p).obAt(96, 236)
            addOwn(p).obAt(96, 674)
        }
        .frame(width: obCanvasWidth, height: obCanvasHeight, alignment: .topLeading)
        .onAppear {
            physics.reset(titles: model.chips.map(\.title), staticGrid: reduceMotion)
            if !reduceMotion { physics.run() }
        }
        .onDisappear { physics.stop() }
    }

    private var countPillWidth: CGFloat { 130 }

    private func countPill(_ p: MRPalette) -> some View {
        HStack(spacing: 6) {
            MRIcon(.check, size: 14)
            OT("\(model.selected.count) selected").obType(.ui, 12, 600, lh: 12, tracking: 0.04).textCase(.uppercase)
        }
        .foregroundStyle(p.accentPillText.color)
        .padding(.horizontal, 14).frame(height: 32)
        .background(p.isDark ? obRGBA(106, 183, 255, 0.16) : obRGBA(30, 107, 255, 0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .fixedSize()
        .frame(width: countPillWidth, alignment: .trailing)
        .accessibilityLabel(Text("\(model.selected.count) selected", tableName: "Onboarding"))
    }

    // MARK: Tray

    private func tray(_ p: MRPalette) -> some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        return ZStack(alignment: .topLeading) {
            ForEach(Array(model.chips.enumerated()), id: \.element.id) { i, chip in
                if physics.bodies.indices.contains(i) {
                    chipView(i, chip)
                }
            }
        }
        .frame(width: ChipPhysics.trayWidth, height: ChipPhysics.trayHeight, alignment: .topLeading)
        .background(p.fill1.color, in: shape)
        .overlay(MRInsetShadow(shape, color: .black.opacity(0.18), y: 18, blur: 40))
        .overlay(shape.strokeBorder(p.strokeHair.color, lineWidth: 1))
        .clipShape(shape)
        .coordinateSpace(name: "tray")
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Scenarios", tableName: "Onboarding"))
    }

    private func chipView(_ i: Int, _ chip: OBChip) -> some View {
        let b = physics.bodies[i]
        let on = model.selected.contains(chip.id)
        let dragging = physics.draggingIndex == i
        return ScenarioChip(name: chip.title, icon: MRIconName(rawValue: chip.icon) ?? .dot, colorHex: chip.hex, isSelected: on, large: true)
            .allowsHitTesting(false)
            .fixedSize()
            .scaleEffect(on ? 1.06 : 1)
            .rotationEffect(.degrees(on ? 0 : b.rot))
            .offset(y: on ? -6 : 0)
            .mrAnimation(MRMotion.bouncy, value: on)
            .offset(x: b.x, y: b.y)
            .zIndex(on || dragging ? 5 : 0)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("tray"))
                    .onChanged { g in
                        guard !reduceMotion else { return }
                        if physics.draggingIndex == nil { physics.beginDrag(i, at: g.startLocation) }
                        physics.drag(to: g.location)
                    }
                    .onEnded { g in
                        if reduceMotion { model.toggle(chip.id); return }
                        if let hit = physics.endDrag(), hit == i { model.toggle(chip.id) }
                    }
            )
            .focusable()
            .onKeyPress(.space) { model.toggle(chip.id); return .handled }
            .accessibilityElement()
            .accessibilityLabel(chip.title)
            .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { model.toggle(chip.id) }
    }

    // MARK: Custom scenario (ONB-3 "custom allowed")

    @ViewBuilder
    private func addOwn(_ p: MRPalette) -> some View {
        if adding {
            HStack(spacing: 8) {
                TextField("", text: $newName, prompt: Text("Name your scenario", tableName: "Onboarding").foregroundStyle(p.text3.color))
                    .textFieldStyle(.plain).font(.mr(.ui, size: 13, weight: 500)).focused($nameFocused)
                    .onSubmit(commitCustom)
                    .frame(width: 180)
                Button(action: commitCustom) { OT("Add") }.buttonStyle(MRButtonStyle(.tertiary, size: .sm))
            }
            .padding(.horizontal, 12).frame(height: 30)
            .background(p.fill1.color, in: Capsule())
            .overlay(Capsule().strokeBorder(p.strokeHair.color, lineWidth: 1))
            .onAppear { nameFocused = true }
            .onExitCommand { adding = false; newName = "" }
        } else {
            OBLink(title: "Add your own", icon: .plus) { adding = true }
        }
    }

    private func commitCustom() {
        let before = model.chips.count
        model.addCustom(newName)
        if model.chips.count > before, let last = model.chips.last { physics.append(title: last.title) }
        newName = ""
        adding = false
    }
}
