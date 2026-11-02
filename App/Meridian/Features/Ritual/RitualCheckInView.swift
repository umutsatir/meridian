import MeridianUI
import SwiftUI

/// S12 / S12B: "Check in · Step 2 of 2 · Choose your seat." (`CheckIn.dc.html`). Laid out on the canvas' 1280 x 800 grid
/// (the sidebar is drawn by the host) and fitted into the space right of the sidebar.
struct RitualCheckInView: View {
    var info: RitualFlightInfo
    @Binding var seat: String
    @Binding var topic: String
    @Binding var together: Bool
    /// Scenario chip next to the topic (follows the zone the user picks).
    var scenario: PaperScenario
    var zone: RitualZone
    var friends: [RitualFriend] = []
    var sidebarInset: CGFloat = 236
    var live = true
    /// Design reference states: "topic" focus ring, "cta" hover, a hovered seat code.
    var pinnedHover = ""
    var onSeat: (String, RitualZone) -> Void = { _, _ in }
    var onZone: (RitualZone) -> Void = { _ in }
    var onCheckIn: () -> Void = {}
    var onQuickStart: () -> Void = {}
    var onCancel: () -> Void = {}

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var topicFocused: Bool
    @State private var flyCode: String?
    @State private var flyProgress: Double = 0

    private let seatMapScale: CGFloat = 0.92
    private let ticketScale: CGFloat = 0.628

    var body: some View {
        GeometryReader { geo in
            let free = geo.size.width - sidebarInset - 20
            let s = min(1, free / 1024, geo.size.height / 800)
            let dx = sidebarInset + (free - 1024 * s) / 2 - 236 * s
            let dy = max(0, (geo.size.height - 800 * s) / 2)
            design.frame(width: 1280, height: 800, alignment: .topLeading)
                .scaleEffect(s, anchor: .topLeading)
                .offset(x: dx, y: dy)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
    }

    private var design: some View {
        let p = MRPalette.resolve(scheme)
        let type = RitualSeatMap.type(of: String(seat.suffix(1)))
        let pass = info.passModel(seat: seat, topic: topic, scenario: scenario)
        return ZStack(alignment: .topLeading) {
            // title row
            VStack(alignment: .leading, spacing: 6) {
                Text("Check in · Step 2 of 2").mrText(.eyebrow).foregroundStyle(p.text2.color)
                Text("Choose your seat.").font(.mr(.serif, size: 42, weight: 500)).tracking(-0.84)
                    .foregroundStyle(p.text1.color).frame(height: 46, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
            }
            .offset(x: 264, y: 52)
            HStack(spacing: 12) {
                Text(info.originCode).font(.mr(.condensed, size: 22, weight: 700)).tracking(0.22)
                MRIcon(.plane, size: 14).rotationEffect(.degrees(90)).foregroundStyle(p.text3.color)
                Text(info.destinationCode).font(.mr(.condensed, size: 22, weight: 700)).tracking(0.22)
                Text("\(info.durationText) · \(info.km) km · \(info.flightNumber)").font(.mr(.mono, size: 12, weight: 500)).foregroundStyle(p.text2.color)
            }
            .foregroundStyle(p.text1.color)
            .padding(.horizontal, 18).frame(height: 44)
            .mrGlass(cornerRadius: 22, elevation: .e2)
            .frame(width: 1280 - 24, alignment: .trailing)
            .offset(x: 0, y: 74)

            RitualSeatMap(seat: seat, zone: zone, live: live, scale: seatMapScale, friends: friends, pinnedHover: pinnedHover == "topic" || pinnedHover == "cta" ? "" : pinnedHover,
                          onSeat: { code, z in if code != seat { startFly(code) }; onSeat(code, z) }, onZone: onZone)
                .offset(x: 264, y: 136)

            legend(p).offset(x: 272, y: 516)

            topicField(p).offset(x: 264, y: 574)
            if TogetherAvailability.isVisible { togetherCard(p).offset(x: 264, y: 646) }

            BoardingPassView(pass, scale: ticketScale)
                .offset(x: 1030, y: 142)
                .accessibilityLabel(pass.accessibilityDescription(canTear: false))
            VStack(spacing: 0) {
                summary("Seat", "\(seat) · \(type)", p, last: false)
                summary("Zone", "\(zone.label) zone", p, last: false)
                summary("Gate", "\(info.gate) · \(info.boardingTime)", p, last: true)
            }
            .frame(width: 226)
            .offset(x: 1030, y: 530)
            VStack(spacing: 8) {
                Button(action: onCheckIn) { Text("Check in").frame(maxWidth: .infinity) }
                    .buttonStyle(MRButtonStyle(.primary, size: .lg))
                    .frame(width: 226)
                    .keyboardShortcut(.return, modifiers: [])
                    .modifier(PinnedHover(on: pinnedHover == "cta"))
                HStack(spacing: 4) {
                    MRKbd("⌘"); MRKbd("⏎")
                    Text("to quick start").font(.mr(.ui, size: 13)).padding(.leading, 2)
                }
                .foregroundStyle(p.text3.color)
                .frame(maxWidth: .infinity)
            }
            .frame(width: 226)
            .offset(x: 1030, y: 668)


            if let code = flyCode { SeatFlyer(code: code, progress: flyProgress, palette: p).allowsHitTesting(false) }

            // hidden actions: Quick start (⌘⏎) and Escape
            Button("Quick start", action: onQuickStart).keyboardShortcut(.return, modifiers: .command).opacity(0).frame(width: 0, height: 0).accessibilityHidden(true)
            Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction).opacity(0).frame(width: 0, height: 0).accessibilityHidden(true)
        }
        .frame(width: 1280, height: 800, alignment: .topLeading)
    }

    /// The window scene for the departure clock ("HH:mm"): day, sunset, blue hour or night.
    static func scene(forBoarding time: String) -> String {
        let h = Int(time.prefix(2)) ?? 12
        switch h {
        case 6..<17: return "day"
        case 17..<19: return "sunset"
        case 19..<21: return "blue"
        default: return "night"
        }
    }

    // MARK: pieces

    private func summary(_ label: String, _ value: String, _ p: MRPalette, last: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).mrText(.callout).foregroundStyle(p.text2.color)
            Spacer(minLength: 0)
            Text(value).font(.mr(.mono, size: 13, weight: 500)).foregroundStyle(p.text1.color)
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) { if !last { Rectangle().fill(p.strokeHair.color).frame(height: 1) } }
        .accessibilityElement(children: .combine)
    }

    private func legend(_ p: MRPalette) -> some View {
        HStack(spacing: 20) {
            legendItem("Free", p) { RoundedRectangle(cornerRadius: 5, style: .continuous).fill(p.fill2.color).overlay(MRInsetShadow(RoundedRectangle(cornerRadius: 5, style: .continuous), color: p.strokeGlow.color, y: 1)).overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(p.strokeHair.color, lineWidth: 1)) }
            legendItem("Your seat", p) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 106 / 255, green: 183 / 255, blue: 1).opacity(0.55), Color(red: 139 / 255, green: 243 / 255, blue: 216 / 255).opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).inset(by: -1.5).strokeBorder(p.accent1.color, lineWidth: 1.5))
            }
            legendItem("Taken", p) {
                RoundedRectangle(cornerRadius: 5, style: .continuous).fill(p.fill2.color).overlay(LegendHatch(color: p.fill1.color).clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))).opacity(0.5)
            }
            legendItem("Friend", p) {
                RoundedRectangle(cornerRadius: 5, style: .continuous).fill(p.fill2.color)
                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).inset(by: -1.5).strokeBorder(Color(hex: "#FF8FB1"), lineWidth: 1.5))
            }
            Spacer(minLength: 0)
            Text("A F window · C D aisle").font(.mr(.mono, size: 11, weight: 500)).foregroundStyle(p.text3.color)
        }
        .font(.mr(.ui, size: 12, weight: 500)).foregroundStyle(p.text2.color)
        .frame(width: 724, height: 16, alignment: .leading)
        .accessibilityHidden(true)
    }

    private func legendItem<S: View>(_ title: String, _ p: MRPalette, @ViewBuilder _ swatch: () -> S) -> some View {
        HStack(spacing: 8) { swatch().frame(width: 16, height: 16); Text(title) }
    }

    private func topicField(_ p: MRPalette) -> some View {
        let focused = topicFocused || pinnedHover == "topic"
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return HStack(spacing: 12) {
            MRIcon(.pencil, size: 20).foregroundStyle(p.text2.color)
            TextField("", text: $topic, prompt: Text("What are you working on?").foregroundStyle(p.text3.color))
                .textFieldStyle(.plain).font(.mr(.ui, size: 16, weight: 500)).foregroundStyle(p.text1.color)
                .focused($topicFocused)
                .onChange(of: topic) { _, new in if new.count > 48 { topic = String(new.prefix(48)) } }
                .accessibilityLabel("What are you working on?")
            TopicChip(scenario: scenario, palette: p)
        }
        .padding(.leading, 18).padding(.trailing, 10)
        .frame(width: 740, height: 56)
        .mrGlass(cornerRadius: 20, elevation: .e2)
        .overlay {
            if focused { shape.inset(by: -2).strokeBorder(p.accent1.color, lineWidth: 2).allowsHitTesting(false) }
        }
        .animation(MRMotion.ease(MRMotion.d2), value: focused)
    }

    private func togetherCard(_ p: MRPalette) -> some View {
        HStack(spacing: 14) {
            HStack(spacing: -8) {
                ForEach(Array(zip(["A", "M", "S"], ["#FFB86B", "#7ADDB2", "#FF8FB1"])), id: \.0) { ini, hex in
                    MRAvatar(ini, tint: Color(hex: hex)).overlay(Circle().strokeBorder(p.bg1.color, lineWidth: 2).padding(-2))
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("Fly together").font(.mr(.ui, size: 14, weight: 600)).frame(height: 18)
                Text("Invite friends to this flight. They pick seats next to yours.").mrText(.callout).foregroundStyle(p.text2.color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {} label: { HStack(spacing: 6) { MRIcon(.link, size: 14); Text("Copy invite link") } }
                .buttonStyle(MRButtonStyle(.secondary, size: .sm))
            Toggle(isOn: $together) { EmptyView() }.toggleStyle(MRToggleStyle()).labelsHidden().fixedSize()
                .accessibilityLabel("Fly together")
        }
        .foregroundStyle(p.text1.color)
        .padding(.horizontal, 18)
        .frame(width: 740, height: 68)
        .mrGlass(cornerRadius: 22, elevation: .e1)
    }

    // MARK: matched seat flight

    /// The seat number travels from the chosen seat to the ticket's seat field (RIT-1).
    private func startFly(_ code: String) {
        guard live, !reduceMotion else { return }
        flyCode = code; flyProgress = 0
        withAnimation(.timingCurve(0.2, 0, 0, 1, duration: 0.42)) { flyProgress = 1 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(460))
            if flyCode == code { flyCode = nil }
        }
    }

    private struct SeatFlyer: View {
        let code: String
        let progress: Double
        let palette: MRPalette
        var body: some View {
            // from the seat (map scale .92 at 264,136) to the ticket's seat value (design reference: 1163, 310)
            let c = RitualSeatMap.center(of: code)
            let from = CGPoint(x: 264 + c.x * 0.92, y: 136 + c.y * 0.92), to = CGPoint(x: 1163, y: 310)
            let x = from.x + (to.x - from.x) * progress, y = from.y + (to.y - from.y) * progress
            Text(code).font(.mr(.mono, size: 11, weight: 700)).foregroundStyle(palette.text1.color)
                .scaleEffect(1 - 0.2 * progress)
                .opacity(progress < 0.8 ? 1 : max(0, 1 - (progress - 0.8) / 0.2))
                .position(x: x, y: y)
                .shadow(color: palette.accent1.color.opacity(0.6 * (1 - progress)), radius: 6)
        }
    }
}

/// `.chip` with the scenario's color (height 36).
private struct TopicChip: View {
    let scenario: PaperScenario
    let palette: MRPalette
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let sc = RGB(hex: scenario.hex)
        let ink = scheme == .dark ? sc : sc.mixed(with: RGB(hex: "#14161C"), amount: 0.54)
        HStack(spacing: 8) {
            MRIcon(scenario.icon, size: 14)
            Text(scenario.label).font(.mr(.ui, size: 13, weight: 500))
        }
        .foregroundStyle(Color(ink))
        .padding(.leading, 12).padding(.trailing, 14).frame(height: 36)
        .background(Capsule().fill(palette.fill1.color))
        .overlay(Capsule().strokeBorder(palette.strokeHair.color, lineWidth: 1))
        .overlay(MRInsetShadow(Capsule(), color: palette.strokeGlow.color, y: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Scenario \(scenario.label)")
    }
}

private struct LegendHatch: View {
    let color: Color
    var body: some View {
        Canvas { ctx, size in
            let period = 6 * 2.0.squareRoot(), band = 3 * 2.0.squareRoot()
            var s = 0.0
            while s < size.width + size.height {
                var path = Path()
                path.move(to: CGPoint(x: s, y: 0)); path.addLine(to: CGPoint(x: s + band, y: 0))
                path.addLine(to: CGPoint(x: 0, y: s + band)); path.addLine(to: CGPoint(x: 0, y: s)); path.closeSubpath()
                ctx.fill(path, with: .color(color))
                s += period
            }
        }
    }
}

/// Pins the hover look of the primary button for the design reference (`.is-hover`).
private struct PinnedHover: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View { content.brightness(on ? 0.06 : 0) }
}


