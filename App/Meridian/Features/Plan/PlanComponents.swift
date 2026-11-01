import MeridianCore
import MeridianPlan
import MeridianUI
import SwiftUI

// MARK: - Destination dock

/// `.dest` cards: 176 x 96, glass with the selected one on paper, lifted 6 pt. The track scrolls so the selection
/// sits at the 1.6th card (520 ms smooth spring).
struct DestinationDock: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    let scene: PlanScene
    let width: CGFloat

    var body: some View {
        let plan = model.plan
        let p = MRPalette.resolve(scheme)
        if plan.destinations.isEmpty && !plan.isFreeFlight {
            HStack(spacing: 16) {
                MRIcon(.map, size: 24).foregroundStyle(p.text2.color)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Nothing this close").font(.mr(.ui, size: 17, weight: 600)).frame(height: 22)
                    Text("No airports fit inside \(PlanKit.fmtDur(Double(plan.durationMinutes ?? 0))) from \(plan.origin.iata). Try 20 min or more.")
                        .font(.mr(.ui, size: 13)).foregroundStyle(p.text2.color).frame(height: 18)
                }
            }
            .padding(.horizontal, 24).frame(height: 96).frame(maxWidth: 640)
            .mrGlass(cornerRadius: 20, elevation: .e3)
            .frame(width: width, alignment: .center)
        } else {
            let dests = plan.destinations
            let selIdx = max(0, dests.firstIndex { $0.iata == plan.selectedDestinationIata } ?? 0)
            let maxOff = max(0, CGFloat(dests.count) * 188 - width)
            let off = max(0, min(maxOff, CGFloat(selIdx) * 188 - 188 * 1.6))
            HStack(spacing: 0) {
                ForEach(dests) { d in
                    DestCard(airport: d, origin: plan.origin, selected: d.iata == plan.selectedDestinationIata) { model.plan.select(iata: d.iata) }
                        .padding(.trailing, 12)
                }
            }
            .padding(.top, 8)
            .offset(x: -off)
            .animation(MRMotion.smooth, value: off)
            .frame(width: width, alignment: .leading)
            .accessibilityElement(children: .contain)
        }
    }
}

private struct DestCard: View {
    let airport: Airport
    let origin: Airport
    let selected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var hovered = false

    var body: some View {
        let p = MRPalette.resolve(scheme)
        let km = PlanKit.km(origin, airport)
        let minutes = PlanState.canvasMinutes(forKm: km)
        let ink = MRColorToken(20, 17, 15, 0.8).color
        let sub = MRColorToken(20, 17, 15, 0.66).color
        let arcColor = selected ? MRColorToken("#14110F").color : p.accent1.color
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    HStack(spacing: 5) {
                        MRIcon(.plane, size: 12)
                        Text(airport.iata).font(.mr(.condensed, size: 13, weight: 700)).tracking(13 * 0.05)
                    }
                    .foregroundStyle(p.ink.color)
                    .padding(.leading, 6).padding(.trailing, 8).frame(height: 24)
                    .background(p.amber.color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Spacer()
                    Text("\(minutes) min").font(.mr(.mono, size: 12, weight: 600)).foregroundStyle(selected ? ink : p.text2.color)
                }
                Spacer(minLength: 0)
                Text(airport.city).font(.mr(.ui, size: 17, weight: 600)).tracking(-0.085).lineLimit(1)
                    .frame(height: 20, alignment: .leading).padding(.top, 2)
                Spacer(minLength: 0)
                HStack(spacing: 7) {
                    FlagDot(cc: airport.countryCode)
                    Text(PlanKit.countryName(airport.countryCode)).font(.mr(.ui, size: 12, weight: 500)).lineLimit(1).fixedSize()
                        .foregroundStyle(selected ? sub : p.text2.color)
                    Spacer(minLength: 0)
                    MiniArc(color: arcColor).frame(width: 50, height: 18)
                }
                .frame(height: 18)
            }
            .foregroundStyle(selected ? p.ink.color : p.text1.color)
            .frame(width: 148, height: 68, alignment: .topLeading)
            .padding(14)
            .frame(width: 176, height: 96)
            .background {
                if selected {
                    shape.fill(p.paper.color)
                        .overlay(shape.strokeBorder(.white.opacity(0.8), lineWidth: 1))
                        .shadow(color: .black.opacity(0.45), radius: 18, y: 18)
                } else {
                    Color.clear.mrGlass(cornerRadius: 20, elevation: .e2)
                }
            }
            .clipShape(shape)
            .contentShape(shape)
            .offset(y: selected ? -6 : (hovered ? -3 : 0))
            .animation(MRMotion.snappy, value: selected)
            .animation(MRMotion.snappy, value: hovered)
        }
        .buttonStyle(.plain)
        .onHover { hv in withAnimation(MRMotion.hover) { hovered = hv } }
        .accessibilityLabel("\(airport.city), \(airport.iata), \(minutes) minutes\(selected ? ", selected" : "")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct FlagDot: View {
    let cc: String
    var body: some View {
        let f = PlanKit.flagStripes(cc)
        Group {
            if f.colors.count == 1 { f.colors[0] } else {
                let stops: [Gradient.Stop] = [
                    .init(color: f.colors[0], location: 0), .init(color: f.colors[0], location: 0.334),
                    .init(color: f.colors[1], location: 0.334), .init(color: f.colors[1], location: 0.666),
                    .init(color: f.colors[2], location: 0.666), .init(color: f.colors[2], location: 1)]
                LinearGradient(stops: stops, startPoint: f.vertical ? .leading : .top, endPoint: f.vertical ? .trailing : .bottom)
            }
        }
        .frame(width: 14, height: 14).clipShape(Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.28), lineWidth: 1))
    }
}

private struct MiniArc: View {
    let color: Color
    var body: some View {
        Canvas { ctx, _ in
            var path = Path()
            path.move(to: CGPoint(x: 2, y: 15))
            path.addQuadCurve(to: CGPoint(x: 48, y: 15), control: CGPoint(x: 25, y: -4))
            ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [1, 3.2]))
            ctx.fill(Path(ellipseIn: CGRect(x: 0, y: 13, width: 4, height: 4)), with: .color(color))
            ctx.fill(Path(ellipseIn: CGRect(x: 45.6, y: 12.6, width: 4.8, height: 4.8)), with: .color(color))
        }
    }
}

// MARK: - Scenario chip and menu

/// The selected `.chip` of the canvas with its trailing chevron; opens the scenario menu.
struct ScenarioMenuChip: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Binding var open: Bool

    var body: some View {
        let p = MRPalette.resolve(scheme)
        let sc = PlanKit.scenario(model.plan.scenarioID)
        let rgb = RGB(hex: sc.hex)
        let ink = scheme == .dark ? Color(rgb) : Color(rgb.mixed(with: RGB(hex: "#14161C"), amount: 0.54))
        let shape = Capsule()
        Button { open.toggle() } label: {
            HStack(spacing: 8) {
                MRIcon(MRIconName(rawValue: sc.icon) ?? .dot, size: 14)
                Text(sc.label).font(.mr(.ui, size: 13, weight: 500))
                MRIcon(.chevD, size: 12).foregroundStyle(p.text2.color)
            }
            .foregroundStyle(ink)
            .padding(.leading, 12).padding(.trailing, 14).frame(height: 34)
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial).opacity(0.5)
                    shape.fill(Color(rgb).opacity(0.20))
                }
            }
            .overlay {
                ZStack {
                    MRInsetShadow(shape, color: p.strokeGlow.color, y: 1)
                    shape.strokeBorder(p.strokeHair.color, lineWidth: 1)
                    shape.stroke(Color(rgb), lineWidth: 1).padding(-1)
                }
            }
            .background(shape.fill(Color(rgb).opacity(0.3)).blur(radius: 11).padding(-4))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Scenario \(sc.label)")
    }
}

/// `.menu` of scenarios (accent highlight on hover).
struct ScenarioMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    let close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(PlanKit.scenarioOrder, id: \.self) { id in
                let sc = PlanKit.scenario(id)
                MenuRow(title: sc.label, icon: MRIconName(rawValue: sc.icon) ?? .dot, tint: Color(RGB(hex: sc.hex)),
                        selected: model.plan.scenarioID == id) {
                    model.plan.setScenario(id: id); close()
                }
            }
        }
        .padding(6).frame(minWidth: 200)
        .mrGlass(cornerRadius: 14, elevation: .e2)
    }

    private struct MenuRow: View {
        let title: String, icon: MRIconName, tint: Color, selected: Bool, action: () -> Void
        @Environment(\.colorScheme) private var scheme
        @State private var hovered = false
        var body: some View {
            let p = MRPalette.resolve(scheme)
            Button(action: action) {
                HStack(spacing: 10) {
                    MRIcon(icon, size: 16).foregroundStyle(hovered ? p.ctaFg.color : tint)
                    Text(title).font(.mr(.ui, size: 13, weight: 500))
                    Spacer()
                    if selected { MRIcon(.check, size: 14) }
                }
                .foregroundStyle(hovered ? (scheme == .dark ? MRColorToken("#04101A").color : .white) : p.text1.color)
                .padding(.horizontal, 10).frame(height: 30)
                .background(hovered ? p.accent1.color : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).onHover { hv in withAnimation(MRMotion.hover) { hovered = hv } }
        }
    }
}

// MARK: - Coach mark

struct CoachMark: View {
    let width: CGFloat
    let height: CGFloat
    let dismiss: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = MRPalette.resolve(scheme)
        ZStack(alignment: .topLeading) {
            p.scrim.color.frame(width: width, height: height - 292).allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 0) {
                Text("Drag the ruler to set your focus time").font(.mr(.ui, size: 15, weight: 600)).frame(height: 20, alignment: .leading)
                Text("The ring shows how far you can fly. Airports inside it match your time.")
                    .font(.mr(.ui, size: 13)).lineSpacing(0).foregroundStyle(p.text2.color)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 4)
                HStack(spacing: 10) {
                    Button("Got it", action: dismiss).buttonStyle(MRButtonStyle(.primary, size: .sm))
                    Text("Arrow keys also work").font(.mr(.ui, size: 13)).foregroundStyle(p.text3.color)
                }
                .padding(.top, 12)
            }
            .foregroundStyle(p.text1.color)
            .padding(.horizontal, 18).padding(.vertical, 16)
            .frame(width: 340, alignment: .leading)
            .mrGlass(cornerRadius: 22, elevation: .e3)
            .overlay(alignment: .bottomLeading) {
                Rectangle().fill(p.bg2.color).frame(width: 14, height: 14)
                    .overlay(alignment: .trailing) { Rectangle().fill(p.strokeHair.color).frame(width: 1) }
                    .overlay(alignment: .bottom) { Rectangle().fill(p.strokeHair.color).frame(height: 1) }
                    .rotationEffect(.degrees(45)).offset(x: 63, y: 7)
            }
            .alignmentGuide(.top) { _ in 0 }
            .offset(x: width / 2 - 70, y: height - 282 - 172)
            .fixedSize(horizontal: false, vertical: true)
        }
        .zIndex(70)
    }
}
