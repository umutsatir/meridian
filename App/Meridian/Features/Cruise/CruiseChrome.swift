import MeridianCore
import MeridianMaps
import MeridianUI
import SwiftUI

// MARK: - Top left: pause and sound

struct CruiseTopLeft: View {
    let frame: CruiseFrame
    @Bindable var ui: CruiseUI
    let actions: CruiseActions

    var body: some View {
        HStack(spacing: 10) {
            CruiseRoundButton(icon: frame.paused ? .play : .pause, on: frame.paused, label: frame.paused ? "Resume" : "Pause", kbd: "Space",
                              a11y: "\(frame.paused ? "Resume" : "Pause") (Space)") { pauseTapped() }
            CruiseRoundButton(icon: ui.sound ? .sound : .soundOff, on: !ui.sound, label: "Sound", kbd: nil, a11y: "Sound") {
                ui.sound.toggle(); actions.toggleSound(ui.sound)
            }
        }
        .offset(x: 20, y: 18)
        .zIndex(30)
    }

    /// Pause is a real action only under the Flexible policy; otherwise the "Leaving early?" sheet explains the options.
    private func pauseTapped() {
        if frame.policy.allowsPause || frame.paused { actions.togglePause() } else { ui.policySheet = true }
    }
}

/// `.fl-ctl.btn-round.glass.glass-ctl` with its `.tip-b` tooltip.
struct CruiseRoundButton: View {
    let icon: MRIconName
    var on = false
    let label: String
    var kbd: String?
    let a11y: String
    var pinnedTip = false
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) { MRIcon(icon, size: 18) }
            .buttonStyle(MRRoundButtonStyle(on: on))
            .accessibilityLabel(a11y)
            .onHover { hv in withAnimation(MRMotion.hover) { hover = hv } }
            .overlay(alignment: .top) {
                CruiseTip(text: label, kbd: kbd)
                    .offset(y: 40 + 8)
                    .opacity(hover || pinnedTip ? 1 : 0)
                    .animation(MRMotion.ease(MRMotion.d2), value: hover)
                    .allowsHitTesting(false)
                    .fixedSize()
            }
    }
}

// MARK: - Top right: map controls and zoom

struct CruiseMapControls: View {
    let frame: CruiseFrame
    @Bindable var ui: CruiseUI
    let size: CGSize
    let onWindow: () -> Void
    @State private var hover = false
    @Environment(\.colorScheme) private var scheme

    private var styleName: String {
        switch ui.style { case .terra: "Terra"; case .mono: "Monochrome"; case .standard: "Standard"; case .satellite: "Satellite" }
    }

    var body: some View {
        let expanded = (hover || ui.capLabels) && ui.menu == nil
        ZStack(alignment: .topTrailing) {
            capsule(expanded: expanded).padding(.trailing, 20).padding(.top, 18)
            CruiseZoomCapsule(ui: ui).padding(.trailing, 20).padding(.top, 202)
            if ui.menu == .style { styleMenu }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    private func capsule(expanded: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
                CapItem(icon: .navigate, label: ui.follow ? "Following plane" : "Follow plane", kbd: "F", on: ui.follow, expanded: expanded, a11y: "Follow plane") {
                    toggleFollow()
                }
                CapItem(icon: .route, label: "Route", kbd: nil, on: ui.route, expanded: expanded, a11y: "Show route") { ui.route.toggle() }
                CapItem(icon: .layers, label: "Map style · \(styleName)", kbd: nil, on: ui.menu == .style, expanded: expanded, a11y: "Map style: \(styleName)") {
                    ui.menu = ui.menu == .style ? nil : .style
                }
                CapItem(icon: .cabinWindow, label: "Window view", kbd: "W", on: false, expanded: expanded, a11y: "Window view", action: onWindow)
            }
            .padding(4)
            .fixedSize()
            .cruiseGlass(26, .e2, amber: frame.isAmber)
            .onHover { hv in withAnimation(MRMotion.hover) { hover = hv } }
            .animation(MRMotion.ease(MRMotion.d2), value: expanded)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Map controls")
    }

    private var styleMenu: some View {
        CruiseMenu(items: [("Terra", [cruiseRGBA(0x34, 0x67, 0x8F), cruiseRGBA(0x6B, 0x7A, 0x4E)], MapStyle.terra),
                           ("Monochrome", [cruiseRGBA(0x2A, 0x2F, 0x3A), cruiseRGBA(0xC9, 0xCE, 0xD8)], .mono),
                           ("Standard", [cruiseRGBA(0x9E, 0xC5, 0xE8), cruiseRGBA(0xE9, 0xE4, 0xD6)], .standard),
                           ("Satellite", [cruiseRGBA(0x1D, 0x3A, 0x5A), cruiseRGBA(0x3E, 0x5C, 0x3A)], .satellite)],
                   selected: ui.style, diagonal: true, a11y: "Map style") { if MapStyleAccess.isUnlocked($0) { ui.style = $0 }; ui.menu = nil }
            .padding(.trailing, ui.capLabels ? 244 : 78).padding(.top, 100)
    }

    private func toggleFollow() {
        let cam = CruiseCamera(frame: frame, ui: ui, size: size)
        if ui.follow { ui.follow = false; ui.cam = cam.center } else { ui.follow = true; ui.cam = nil }
    }
}

/// An item of the `.fl-cap` capsule: a 40 pt circle that widens to a labelled pill.
private struct CapItem: View {
    let icon: MRIconName
    let label: String
    var kbd: String?
    let on: Bool
    let expanded: Bool
    let a11y: String
    let action: () -> Void
    @State private var hover = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = MRPalette.resolve(scheme)
        let shape = RoundedRectangle(cornerRadius: expanded ? 20 : 20, style: .continuous)
        Button(action: action) {
            HStack(spacing: expanded ? 10 : 0) {
                MRIcon(icon, size: 18)
                if expanded {
                    HStack(spacing: 8) {
                        Text(label).font(.mr(.ui, size: 13, weight: 500)).lineLimit(1).fixedSize()
                        if let kbd {
                            MRKbd(kbd)
                                .environment(\.colorScheme, scheme)
                                .opacity(on ? 0.9 : 1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
                }
            }
            .foregroundStyle(on ? p.bg0.color : p.text1.color)
            .padding(.leading, expanded ? 11 : 0).padding(.trailing, expanded ? 14 : 0)
            .frame(width: expanded ? nil : 40, height: 40)
            .frame(maxWidth: expanded ? .infinity : 40, alignment: expanded ? .leading : .center)
            .background(shape.fill(on ? p.text1.color : (hover ? p.fill2.color : .clear)))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hv in withAnimation(MRMotion.hover) { hover = hv } }
        .animation(MRMotion.ease(MRMotion.d2), value: hover)
        .accessibilityLabel(a11y)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

struct CruiseZoomCapsule: View {
    @Bindable var ui: CruiseUI
    var body: some View {
        VStack(spacing: 2) {
            ZoomItem(icon: .plus, tip: "Zoom in", kbd: "+", a11y: "Zoom in") { ui.zoom(by: 0.18) }
            ZoomItem(icon: .minus, tip: "Zoom out", kbd: "−", a11y: "Zoom out") { ui.zoom(by: -0.18) }
        }
        .padding(4)
        .cruiseGlass(26, .e2)
        .accessibilityElement(children: .contain).accessibilityLabel("Zoom")
    }

    private struct ZoomItem: View {
        let icon: MRIconName, tip: String, kbd: String, a11y: String
        let action: () -> Void
        @State private var hover = false
        @Environment(\.colorScheme) private var scheme
        var body: some View {
            let p = MRPalette.resolve(scheme)
            Button(action: action) {
                MRIcon(icon, size: 18).foregroundStyle(p.text1.color)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(hover ? p.fill2.color : .clear))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .onHover { hv in withAnimation(MRMotion.hover) { hover = hv } }
            .accessibilityLabel(a11y)
            .overlay(alignment: .trailing) {
                CruiseTip(text: tip, kbd: kbd).offset(x: -(40 + 10)).opacity(hover ? 1 : 0)
                    .animation(MRMotion.ease(MRMotion.d2), value: hover).allowsHitTesting(false)
            }
        }
    }
}

/// `.fl-mi` menu: 212 pt glass list with a gradient swatch, the label and a check.
struct CruiseMenu<V: Hashable>: View {
    let items: [(String, [Color], V)]
    let selected: V
    let diagonal: Bool
    let a11y: String
    let pick: (V) -> Void
    @State private var hovered: V?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = MRPalette.resolve(scheme)
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                let on = item.2 == selected
                Button { pick(item.2) } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(LinearGradient(colors: item.1, startPoint: diagonal ? .topLeading : .top, endPoint: diagonal ? .bottomTrailing : .bottom))
                            .frame(width: 22, height: 22)
                            .overlay(Circle().strokeBorder(.white.opacity(0.28), lineWidth: 1))
                            .overlay(Circle().strokeBorder(.black.opacity(0.18), lineWidth: 1).padding(-1))
                        Text(item.0).font(.mr(.ui, size: 14, weight: 500))
                        Spacer(minLength: 0)
                        MRIcon(.check, size: 16).foregroundStyle(p.accent1.color).opacity(on ? 1 : 0)
                    }
                    .foregroundStyle(p.text1.color)
                    .padding(.leading, 10).padding(.trailing, 12)
                    .frame(height: 40)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(hovered == item.2 ? p.fill2.color : .clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { h in withAnimation(MRMotion.hover) { hovered = h ? item.2 : (hovered == item.2 ? nil : hovered) } }
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(6)
        .frame(width: 212)
        .mrGlass(cornerRadius: 20, elevation: .e3)
        .accessibilityElement(children: .contain).accessibilityLabel(a11y)
    }
}

// MARK: - Readouts

/// `.fl-ro` bottom corner readouts.
struct CruiseReadout: View {
    let key: String
    let parts: [(value: String, unit: String)]
    var trailing = false
    var ink: Color?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = MRPalette.resolve(scheme)
        let color = ink ?? p.text1.color
        let shadow = scheme == .dark ? Color.black.opacity(0.4) : Color.white.opacity(0.7)
        VStack(alignment: trailing ? .trailing : .leading, spacing: 2) {
            Text(key).font(.mr(.ui, size: 13, weight: 500)).opacity(0.82).frame(height: 16)
            HStack(alignment: .lastTextBaseline, spacing: 5) {
                ForEach(Array(parts.enumerated()), id: \.offset) { i, part in
                    Text(part.value).font(.mr(.ui, size: 36, weight: 600)).tracking(-0.54).monospacedDigit()
                    Text(part.unit).font(.mr(.ui, size: 19, weight: 500)).opacity(0.88)
                        .padding(.trailing, i == parts.count - 1 ? 0 : 7)
                }
            }
            .frame(height: 40)
        }
        .foregroundStyle(color)
        .shadow(color: shadow, radius: scheme == .dark ? 7 : 6, y: 1)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(key) \(parts.map { "\($0.value) \($0.unit)" }.joined(separator: " "))")
    }
}

// MARK: - Paused: resume or hold to land early

/// A hold-to-confirm pill: the ring fills while pressed and `onComplete` fires at 1.2 s. Release cancels.
struct HoldToLand: View {
    @Binding var progress: Double
    var duration: TimeInterval = 1.2
    var tinted = false
    var fixedProgress: Double?
    let onComplete: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var task: Task<Void, Never>?
    @State private var pressed = false
    @State private var hover = false

    var body: some View {
        let p = MRPalette.resolve(scheme)
        let value = fixedProgress ?? progress
        let danger = p.danger.color
        let ring = ZStack {
            Circle().stroke(tinted ? cruiseRGBA(255, 107, 107, 0.25) : p.fill3.color, lineWidth: 2.5)
            Circle().trim(from: 0, to: value).stroke(danger, style: StrokeStyle(lineWidth: 2.5, lineCap: .round)).rotationEffect(.degrees(-90))
        }
        .padding(1)
        .frame(width: 40, height: 40)
        .overlay(MRIcon(.plane, size: 18).foregroundStyle(tinted ? Color(RGB(hex: "#FF9A9A")) : p.text1.color))
        let content = HStack(spacing: 12) {
            ring
            Text("Hold to land early").font(.mr(.ui, size: 14, weight: 600)).foregroundStyle(tinted ? Color(RGB(hex: "#FF9A9A")) : p.text1.color)
        }
        .padding(.leading, 6).padding(.trailing, tinted ? 22 : 20).frame(height: 52)
        Group {
            if tinted {
                content
                    .background(Capsule().fill(cruiseRGBA(255, 107, 107, 0.14)))
                    .overlay(Capsule().strokeBorder(cruiseRGBA(255, 107, 107, 0.38), lineWidth: 1))
            } else {
                content.cruiseGlass(in: Capsule(), .e2)
                    .overlay(Capsule().strokeBorder(p.strokeGlow.color, lineWidth: hover ? 1 : 0))
            }
        }
        .scaleEffect(pressed && !reduceMotion ? 0.97 : 1)
        .animation(MRMotion.ease(MRMotion.d1), value: pressed)
        .onHover { hv in withAnimation(MRMotion.hover) { hover = hv } }
        .contentShape(Capsule())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in if !pressed { begin() } }
            .onEnded { _ in cancel() })
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hold to land early. Press and hold for \(String(format: "%.1f", duration)) seconds.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onComplete() }
    }

    private func begin() {
        pressed = true
        let t0 = Date()
        task = Task { @MainActor in
            while !Task.isCancelled {
                let h = min(1, Date().timeIntervalSince(t0) / duration)
                progress = h
                if h >= 1 { pressed = false; progress = 0; onComplete(); return }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    private func cancel() {
        task?.cancel(); task = nil
        pressed = false
        progress = 0
    }
}

struct CruiseHoldBar: View {
    let frame: CruiseFrame
    @Bindable var ui: CruiseUI
    let actions: CruiseActions
    @Environment(\.colorScheme) private var scheme
    @State private var resumeHover = false

    var body: some View {
        let p = MRPalette.resolve(scheme)
        HStack(spacing: 10) {
            Button { actions.togglePause() } label: {
                HStack(spacing: 10) {
                    MRIcon(.play, size: 18)
                    Text("Resume").font(.mr(.ui, size: 14, weight: 600))
                }
                .foregroundStyle(p.text1.color)
                .padding(.leading, 18).padding(.trailing, 20).frame(height: 52)
                .cruiseGlass(in: Capsule(), .e2)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Resume")
            HoldToLand(progress: $ui.holdProgress) { actions.landEarly() }
        }
    }
}

// MARK: - Landing heads-up toast and the resume banner

struct CruiseLandingToast: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let p = MRPalette.resolve(scheme)
        HStack(spacing: 14) {
            MRIcon(.seatbelt, size: 20).foregroundStyle(p.amber.color)
                .frame(width: 38, height: 38).background(Circle().fill(cruiseRGBA(255, 181, 71, 0.18)))
            VStack(alignment: .leading, spacing: 0) {
                Text("Cabin crew, prepare for landing.").font(.mr(.ui, size: 15, weight: 600)).frame(height: 20)
                Text("5 minutes to go.").font(.mr(.ui, size: 13)).foregroundStyle(p.text2.color).frame(height: 18)
            }
            .foregroundStyle(p.text1.color)
        }
        .padding(.leading, 14).padding(.trailing, 20).padding(.vertical, 14)
        .mrGlass(cornerRadius: 22, elevation: .e3)
        .accessibilityElement(children: .combine)
    }
}

struct CruiseResumedBanner: View {
    var title = "Flight resumed."
    var message = "Your plane kept flying while you were away."
    var onDismiss: () -> Void = {}
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let p = MRPalette.resolve(scheme)
        HStack(spacing: 12) {
            MRIcon(.refresh, size: 18).foregroundStyle(p.accent1.color)
                .frame(width: 34, height: 34).background(Circle().fill(cruiseRGBA(106, 183, 255, 0.16)))
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.mr(.ui, size: 14, weight: 600)).frame(height: 18)
                Text(message).font(.mr(.ui, size: 13)).foregroundStyle(p.text2.color).frame(height: 18)
            }
            .foregroundStyle(p.text1.color)
        }
        .padding(.leading, 12).padding(.trailing, 20).padding(.vertical, 12)
        .mrGlass(cornerRadius: 22, elevation: .e3)
        .onTapGesture(perform: onDismiss)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Policy sheet (S19)

struct CruisePolicySheet: View {
    let frame: CruiseFrame
    @Bindable var ui: CruiseUI
    let actions: CruiseActions
    var fixedHold: Double?
    let size: CGSize
    @Environment(\.colorScheme) private var scheme

    private struct Option { let policy: PausePolicy; let title: String; let desc: String; let rule: String; let icon: MRIconName }

    var body: some View {
        let p = MRPalette.resolve(scheme)
        let budget = Int((Double(frame.pauseBudgetSec) / 60).rounded(.down))
        let options = [
            Option(policy: .strict, title: "Strict", desc: "No pause. The plane keeps its schedule.", rule: "Land early: not available", icon: .lock),
            Option(policy: .normal, title: "Normal", desc: "Land early any time. The part you flew is saved.", rule: "Land early: partial flight saved", icon: .plane),
            Option(policy: .flexible, title: "Flexible", desc: "Pause for up to 10 minutes, then land early if needed.",
                   rule: "Pause: 10 min · \(budget):\(String(format: "%02d", frame.pauseBudgetSec % 60)) left", icon: .pause),
        ]
        ZStack(alignment: .topLeading) {
            Rectangle().fill(p.scrim.color).background(.ultraThinMaterial.opacity(0)).blur(radius: 0)
                .onTapGesture { ui.policySheet = false }
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Leaving early?").mrText(.title2).foregroundStyle(p.text1.color)
                        Text("Your flight policy decides what you can do. You chose it before takeoff.").mrText(.callout).foregroundStyle(p.text2.color)
                    }
                    Spacer()
                    Button { ui.policySheet = false } label: { MRIcon(.x, size: 18).foregroundStyle(p.text2.color) }
                        .buttonStyle(MRRoundButtonStyle(small: true)).accessibilityLabel("Close")
                }
                HStack(spacing: 14) {
                    ForEach(options, id: \.title) { o in card(o, on: o.policy == frame.policy, p: p) }
                }
                .padding(.top, 20)
                summary(p).padding(.top, 20)
            }
            .padding(.top, 26).padding(.horizontal, 28).padding(.bottom, 24)
            .frame(width: 800)
            .mrGlass(cornerRadius: 28, elevation: .e3)
            .offset(x: size.width / 2 - 400, y: (size.height * 0.17).rounded())
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .transition(.opacity)
    }

    private func card(_ o: Option, on: Bool, p: MRPalette) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                MRIcon(o.icon, size: 20).foregroundStyle(on ? p.accent1.color : p.text2.color)
                Spacer()
                if on { MRPill("Your policy", kind: .accent) }
            }
            Text(o.title).font(.mr(.ui, size: 17, weight: 600)).padding(.top, 12).frame(height: 22 + 12, alignment: .bottom)
            Text(o.desc).mrText(.callout).foregroundStyle(p.text2.color).padding(.top, 4)
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
            Text(o.rule).font(.mr(.mono, size: 11)).foregroundStyle(on ? p.accent1.color : p.text3.color).padding(.top, 10)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(p.text1.color)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading).frame(height: 186, alignment: .topLeading)
        .background(shape.fill(on ? AnyShapeStyle(LinearGradient(colors: [cruiseRGBA(106, 183, 255, 0.16), cruiseRGBA(139, 243, 216, 0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(p.fill1.color)))
        .overlay(shape.strokeBorder(on ? cruiseRGBA(106, 183, 255, 0.5) : p.strokeHair.color, lineWidth: 1))
    }

    private func summary(_ p: MRPalette) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 0) {
                Text("You flew \(frame.flownMin) of \(Int(frame.totalMin)) minutes.").font(.mr(.ui, size: 14, weight: 600)).frame(height: 18)
                Text("\(CruiseFrame.km(frame.flownKm)) km will be counted.").mrText(.callout).foregroundStyle(p.text2.color).padding(.top, 2)
                Text("Nothing is deleted. A partial ticket is saved to your wallet and marked as diverted.").mrText(.callout).foregroundStyle(p.text3.color).padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 10) {
                Button("Keep flying") { ui.policySheet = false }.buttonStyle(MRButtonStyle(.secondary))
                if frame.policy.allowsEarlyLanding {
                    HoldToLand(progress: $ui.holdProgress, tinted: true, fixedProgress: fixedHold) { ui.policySheet = false; actions.landEarly() }
                }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 16)
        .background(shape.fill(p.fill1.color))
        .overlay(shape.strokeBorder(p.strokeHair.color, lineWidth: 1))
    }
}

// MARK: - Dashboard (S18)

struct CruiseDashboard: View {
    let frame: CruiseFrame
    let size: CGSize
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = MRPalette.resolve(scheme)
        let H = size.height, W = size.width
        ZStack(alignment: .topLeading) {
            Color.black
            VStack(spacing: 0) {
                Text("Time remaining").font(.mr(.ui, size: 13, weight: 500)).tracking(13 * 0.16).textCase(.uppercase)
                    .foregroundStyle(p.text3.color).frame(height: 16)
                Text(frame.isFree ? Clock.format(TimeInterval(frame.elapsedSec)) ?? "" : frame.remainingMMSS)
                    .font(.mr(.mono, size: (H * 0.26).rounded(), weight: 500)).tracking(-(H * 0.26).rounded() * 0.03)
                    .foregroundStyle(p.text1.color).monospacedDigit()
                    .frame(height: (H * 0.26).rounded()).padding(.top, 6)
                Capsule().fill(.white.opacity(0.14)).frame(width: (W * 0.5).rounded(), height: 3).padding(.top, 22)
                    .overlay(alignment: .leading) {
                        Capsule().fill(p.accentGradient).frame(width: (W * 0.5).rounded() * frame.progress, height: 3)
                    }
                HStack(alignment: .lastTextBaseline, spacing: 20) {
                    Text(frame.origin.iata).font(.mr(.condensed, size: 44, weight: 600)).foregroundStyle(p.text2.color)
                    MRIcon(.plane, size: 20).foregroundStyle(p.text3.color).rotationEffect(.degrees(90))
                    Text(frame.destination?.iata ?? "").font(.mr(.condensed, size: 44, weight: 600))
                    Text(frame.destination?.city ?? "").font(.mr(.serif, size: 22, italic: true)).foregroundStyle(p.text2.color).padding(.leading, 6)
                }
                .padding(.top, 34)
            }
            .frame(maxWidth: .infinity)
            .offset(y: (H * 0.24).rounded())
            Text("\(frame.phaseName) · \(CruiseFrame.km(frame.distanceRemainingKm)) km to go")
                .font(.mr(.mono, size: 12)).foregroundStyle(p.text3.color)
                .offset(x: 36, y: H - 30 - 16)
        }
        .frame(width: W, height: H, alignment: .topLeading)
    }
}
