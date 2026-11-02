import MeridianUI
import SwiftUI

struct MenuPopoverActions {
    var pause: () -> Void = {}
    var landEarly: () -> Void = {}
    var planFlight: () -> Void = {}
    var openBoardingPass: () -> Void = {}
    var dismissBoarding: () -> Void = {}
    var addToWallet: () -> Void = {}
    var flyAgain: () -> Void = {}
    var openApp: () -> Void = {}
    var openSettings: () -> Void = {}
}

/// Mutable options shown in the popover (mini map toggle, size, opacity, click-through, sound).
struct MenuPopoverOptions {
    var miniOn = true
    var size: MiniMapSize = .m
    var opacity = 1.0
    var clickThrough = false
    var soundOn = true
}

/// `MenuPopover.dc.html`: the 340 pt glass popover of the menu bar item.
struct MenuPopoverView: View {
    var info: SystemFlightInfo
    @Binding var options: MenuPopoverOptions
    var actions = MenuPopoverActions()
    /// The artboards draw the arrow; the system popover supplies its own.
    var arrowLeft: CGFloat?
    /// Pinned hover state of a button (`pause`, `land`, `sound`), for the state artboards.
    var pinnedButton: String?

    @Environment(\.colorScheme) private var scheme

    private var isFlight: Bool { info.kind == .flight || info.kind == .last }
    private var hasMap: Bool { isFlight || info.kind == .landed || info.kind == .boarding }

    var body: some View {
        let p = MRPalette.resolve(scheme)
        VStack(alignment: .leading, spacing: 12) {
            header(p)
            if hasMap { map } else { idlePlaceholder(p) }
            if info.kind != .idle { timeBlock(p) }
            buttons(p)
            if isFlight { miniSection(p) }
            MRDivider()
            footer
        }
        .padding(14)
        .frame(width: 340)
        .mrGlass(cornerRadius: 22, elevation: .e3)
        .overlay(alignment: .topLeading) {
            if let arrowLeft {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(p.glassTint.color)
                    .frame(width: 12, height: 12)
                    .rotationEffect(.degrees(45))
                    .offset(x: arrowLeft, y: -6)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Meridian flight status")
    }

    // MARK: Pieces

    private func header(_ p: MRPalette) -> some View {
        HStack {
            StatusPill(kind: info.kind, paused: info.paused)
            Spacer(minLength: 0)
            Text(info.route).font(MRFonts.font(.mono, size: 12, weight: 500)).foregroundStyle(p.text2.color)
        }
    }

    private var map: some View {
        MiniMapView(info: info, size: CGSize(width: 310, height: 140), chip: chipText,
                    drawsShadow: false, interactive: false, follows: arrowLeft == nil)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .frame(width: 310, height: 140)
    }

    private var chipText: String? {
        switch info.kind {
        case .boarding: "Gate \(info.gate)"
        case .landed: "Landed"
        default: nil
        }
    }

    private func idlePlaceholder(_ p: MRPalette) -> some View {
        VStack(spacing: 6) {
            Canvas { ctx, _ in
                var path = Path()
                path.move(to: CGPoint(x: 4, y: 32))
                path.addCurve(to: CGPoint(x: 60, y: 32), control1: CGPoint(x: 20, y: 6), control2: CGPoint(x: 44, y: 6))
                ctx.stroke(path, with: .color(p.accent1.color), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 4]))
            }
            .frame(width: 64, height: 40)
            Text("No flight yet").font(MRFonts.font(.ui, size: 14, weight: 600)).foregroundStyle(p.text1.color)
            Text("Pick a destination to begin.").mrText(.callout).foregroundStyle(p.text2.color)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(p.fill1.color))
    }

    private func timeBlock(_ p: MRPalette) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(info.timeLabel).mrText(.eyebrow).foregroundStyle(p.text2.color)
                Text(info.timeString)
                    .font(MRFonts.font(.mono, size: 44, weight: 500)).tracking(-0.04 * 44).monospacedDigit()
                    .foregroundStyle(info.kind == .last ? p.accent1.color : p.text1.color)
                    .frame(height: 46, alignment: .leading)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 3) {
                Text(info.phaseTitle).font(MRFonts.font(.ui, size: 13, weight: 600)).foregroundStyle(p.text1.color)
                Text(info.phaseSub).font(MRFonts.font(.mono, size: 11, weight: 500)).foregroundStyle(p.text3.color)
            }
        }
    }

    @ViewBuilder
    private func buttons(_ p: MRPalette) -> some View {
        switch info.kind {
        case .flight, .last:
            HStack(spacing: 10) {
                Button(action: actions.pause) {
                    HStack(spacing: 6) { MRIcon(info.paused ? .play : .pause, size: 14); Text(info.paused ? "Resume" : "Pause") }.frame(maxWidth: .infinity)
                }
                .buttonStyle(MRButtonStyle(.secondary, size: .sm))
                .frame(width: 100)
                HoldToLandButton(action: actions.landEarly)
                    .frame(width: 156)
                Button { options.soundOn.toggle() } label: { MRIcon(options.soundOn ? .sound : .soundOff, size: 14) }
                    .buttonStyle(MRRoundButtonStyle(small: true))
                    .accessibilityLabel("Sound")
                    .accessibilityValue(options.soundOn ? "On" : "Off")
            }
        case .boarding:
            HStack(spacing: 10) {
                Button(action: actions.openBoardingPass) { Text("Open boarding pass").frame(maxWidth: .infinity) }
                    .buttonStyle(MRButtonStyle(.primary, size: .sm))
                Button("Not now", action: actions.dismissBoarding).buttonStyle(MRButtonStyle(.secondary, size: .sm))
            }
        case .idle:
            Button(action: actions.planFlight) {
                HStack(spacing: 8) { MRIcon(.plane, size: 16); Text("Plan a flight") }.frame(maxWidth: .infinity)
            }
            .buttonStyle(MRButtonStyle(.primary))
            .frame(maxWidth: .infinity)
        case .landed:
            HStack(spacing: 10) {
                Button(action: actions.addToWallet) {
                    HStack(spacing: 6) { MRIcon(.wallet, size: 14); Text("Add to wallet") }.frame(maxWidth: .infinity)
                }
                .buttonStyle(MRButtonStyle(.primary, size: .sm)).frame(maxWidth: .infinity)
                Button("Fly again from \(info.destinationCode)", action: actions.flyAgain)
                    .buttonStyle(MRButtonStyle(.secondary, size: .sm))
            }
        }
    }

    @ViewBuilder
    private func miniSection(_ p: MRPalette) -> some View {
        MRDivider()
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Mini map").font(MRFonts.font(.ui, size: 13, weight: 600)).foregroundStyle(p.text1.color)
                Text("Floats above your other windows").mrText(.callout).font(MRFonts.font(.ui, size: 12, weight: 400))
                    .foregroundStyle(p.text3.color)
            }
            Spacer(minLength: 0)
            Toggle(isOn: $options.miniOn) { EmptyView() }.toggleStyle(MRToggleStyle()).accessibilityLabel("Mini map")
        }
        if options.miniOn {
            FlexSegmented(selection: $options.size)
            HStack(spacing: 10) {
                Text("Opacity").font(MRFonts.font(.ui, size: 12, weight: 400)).foregroundStyle(p.text2.color).frame(width: 58, alignment: .leading)
                MRSlider(value: $options.opacity, in: 0.3...1, step: 0.01)
                Text("\(Int((options.opacity * 100).rounded()))%")
                    .font(MRFonts.font(.mono, size: 12, weight: 500)).foregroundStyle(p.text2.color)
                    .frame(width: 36, alignment: .trailing)
            }
            HStack {
                Text("Click-through").font(MRFonts.font(.ui, size: 12, weight: 400)).foregroundStyle(p.text2.color)
                Spacer(minLength: 0)
                Toggle(isOn: $options.clickThrough) { EmptyView() }.toggleStyle(MRToggleStyle()).accessibilityLabel("Click-through")
            }
        }
    }

    private var footer: some View {
        HStack {
            Button(action: actions.openApp) {
                HStack(spacing: 6) { Text("Open Meridian"); MRKbd("⌘O") }
            }
            .buttonStyle(MRButtonStyle(.tertiary, size: .sm))
            Spacer(minLength: 0)
            Button(action: actions.openSettings) { MRIcon(.settings, size: 14) }
                .buttonStyle(MRRoundButtonStyle(small: true))
                .accessibilityLabel("Settings")
        }
    }
}

/// `.pill` with its leading dot (`.dotp`), per state: Idle, Boarding, In flight / Paused, Last minute, Landed.
struct StatusPill: View {
    var kind: SystemFlightKind
    var paused: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = MRPalette.resolve(scheme)
        let dark = scheme == .dark
        let (bg, fg, text): (Color, Color, String) = {
            switch kind {
            case .idle: (p.fill2.color, p.text2.color, "Idle")
            case .boarding: (dark ? sysRGBA(255, 181, 71, 0.16) : sysRGBA(168, 98, 10, 0.12), p.warn.color, "Boarding")
            case .flight: (dark ? sysRGBA(91, 227, 160, 0.16) : sysRGBA(14, 138, 90, 0.12), p.ok.color, paused ? "Paused" : "In flight")
            case .last: (dark ? sysRGBA(106, 183, 255, 0.16) : sysRGBA(30, 107, 255, 0.10), p.accentPillText.color, "Last minute")
            case .landed: (dark ? sysRGBA(91, 227, 160, 0.16) : sysRGBA(14, 138, 90, 0.12), p.ok.color, "Landed")
            }
        }()
        HStack(spacing: 6) {
            MRDot(pulsing: kind == .last)
            Text(text).font(MRFonts.font(.ui, size: 11, weight: 600)).tracking(11 * 0.04).textCase(.uppercase)
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(Capsule().fill(bg))
        .accessibilityElement(children: .combine)
    }
}

/// "Hold to land early": a danger button that fires after a one second hold (PRD: no accidental early landing).
private struct HoldToLandButton: View {
    var action: () -> Void
    @State private var holding = false

    var body: some View {
        Button {} label: {
            HStack(spacing: 6) { MRIcon(.plane, size: 14); Text("Hold to land early").lineLimit(1).minimumScaleFactor(0.85) }.frame(maxWidth: .infinity)
        }
        .buttonStyle(MRButtonStyle(.danger, size: .sm))
        .scaleEffect(holding ? 0.97 : 1)
        .onLongPressGesture(minimumDuration: 1, maximumDistance: 40, perform: action, onPressingChanged: { holding = $0 })
        .accessibilityLabel("Land early")
        .accessibilityHint("Press and hold to land early")
        .accessibilityAction(named: "Land early", action)
    }
}

/// The popover's size picker: `.seg` with every item stretched (`.mp-sz>*{flex:1}`).
private struct FlexSegmented: View {
    @Binding var selection: MiniMapSize
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = MRPalette.resolve(scheme)
        let track = RoundedRectangle(cornerRadius: 12, style: .continuous)
        HStack(spacing: 2) {
            ForEach(MiniMapSize.allCases, id: \.self) { size in
                let on = size == selection
                let item = RoundedRectangle(cornerRadius: 9, style: .continuous)
                Button { selection = size } label: {
                    Text(size.title).font(MRFonts.font(.ui, size: 13, weight: 500)).lineLimit(1)
                        .foregroundStyle(on ? p.text1.color : p.text2.color)
                        .frame(maxWidth: .infinity).frame(height: 28)
                        .background {
                            if on {
                                item.fill(p.segOn.color)
                                    .shadow(color: scheme == .dark ? .black.opacity(0.25) : sysRGBA(40, 34, 20, 0.18), radius: 1.5, y: 1)
                                    .overlay(MRInsetShadow(item, color: p.strokeGlow.color, y: 1))
                            }
                        }
                        .contentShape(item)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(p.fill1.color, in: track)
        .overlay(track.strokeBorder(p.strokeHair.color, lineWidth: 1))
        .animation(MRMotion.snappy, value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mini map size")
    }
}
