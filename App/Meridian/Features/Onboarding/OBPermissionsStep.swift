import MeridianUI
import SwiftUI
import UserNotifications

/// S05A/B/C: permission warm-ups (ONB-5). Each ask explains its purpose before any system prompt,
/// and "Not now" never blocks.
struct OBPermissionsStep: View {
    @Bindable var model: OnboardingModel
    let onAdvance: () -> Void
    @Environment(\.colorScheme) private var scheme

    private struct Ask {
        let title: LocalizedStringKey, detail: LocalizedStringKey, icon: MRIconName
        let eyebrow: LocalizedStringKey, heading: LocalizedStringKey, body: LocalizedStringKey
        let cta: LocalizedStringKey, alt: LocalizedStringKey
        let dTitle: LocalizedStringKey, dBody: LocalizedStringKey, dNo: LocalizedStringKey, dYes: LocalizedStringKey
        let bullets: [(MRIconName, LocalizedStringKey)]
    }

    private static let asks: [Ask] = [
        .init(title: "Notifications", detail: "Boarding call, landing soon", icon: .bell,
              eyebrow: "Step 1 of 3 · Notifications", heading: "Boarding calls and landing alerts",
              body: "We tell you when boarding opens and when you are five minutes out. Nothing else, no marketing, and you can mute any of it.",
              cta: "Turn on notifications", alt: "Not now",
              dTitle: "“Meridian” would like to send you notifications", dBody: "Notifications may include alerts and sounds.",
              dNo: "Don’t Allow", dYes: "Allow",
              bullets: [(.bell, "Boarding call"), (.seatbelt, "Prepare for landing"), (.users, "Friends joining")]),
        .init(title: "Focus filter", detail: "Do Not Disturb in flight", icon: .moon,
              eyebrow: "Step 2 of 3 · Focus filter", heading: "Quiet while you fly",
              body: "Meridian can switch on a Focus when you take off and switch it off when you land. You choose which Focus, and you can turn it off per flight.",
              cta: "Choose a Focus", alt: "Not now",
              dTitle: "Allow Meridian to use Focus filters", dBody: "Meridian can turn a Focus on and off.",
              dNo: "Don’t Allow", dYes: "Allow",
              bullets: [(.moon, "On at take-off"), (.sun, "Off at landing"), (.settings, "Pick your Focus")]),
        // TODO(Q12, ADR 0006): v1 does not request Accessibility (frontmost app comes from NSWorkspace).
        // The copy is kept as designed; the primary action only moves on and never opens a system prompt.
        .init(title: "Soft blocking", detail: "Accessibility access", icon: .shield,
              eyebrow: "Step 3 of 3 · Accessibility", heading: "A gentle nudge back to focus",
              body: "To nudge you back, Meridian needs to know which app is in front. That is all this access is used for.",
              cta: "Open System Settings", alt: "Use Nudge only",
              dTitle: "Privacy & Security › Accessibility", dBody: "Allow Meridian to control this computer.",
              dNo: "Deny", dYes: "Allow", bullets: []),
    ]

    var body: some View {
        let p = MRPalette.resolve(scheme)
        let sub = model.sub
        let ask = Self.asks[min(max(sub, 1), 3) - 1]
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                OT("Stay in the moment.").obType(.serif, 48, 500, lh: 52, tracking: -0.02).foregroundStyle(p.text1.color)
                OT("Three quick asks. Each one is optional, and you can change them later.")
                    .obType(.ui, 17, 400, lh: 26).foregroundStyle(p.text2.color).padding(.top, 12)
            }
            .frame(width: 700, alignment: .leading)
            .obAt(96, 96)

            VStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in stepRow(i, p) }
            }
            .frame(width: 300)
            .obAt(96, 236)

            panel(ask, sub: sub, p).obAt(428, 236)
        }
        .frame(width: obCanvasWidth, height: obCanvasHeight, alignment: .topLeading)
    }

    private func stepRow(_ i: Int, _ p: MRPalette) -> some View {
        let a = Self.asks[i]
        let cur = i + 1 == model.sub, done = i + 1 < model.sub
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(cur ? AnyShapeStyle(p.accentGradient) : AnyShapeStyle(done ? obRGBA(91, 227, 160, 0.18) : p.fill2.color))
                if done { MRIcon(.check, size: 14).foregroundStyle(p.ok.color) }
                else { Text("\(i + 1)").font(.mr(.mono, size: 13, weight: 600)).foregroundStyle(cur ? MRColorToken.hex("#04101A") : p.text2.color) }
            }
            .frame(width: 30, height: 30)
            .shadow(color: cur ? obRGBA(106, 183, 255, 0.5) : .clear, radius: 8)
            VStack(alignment: .leading, spacing: 0) {
                OT(a.title).obType(.ui, 15, 600, lh: 18).foregroundStyle(p.text1.color)
                OT(a.detail).mrText(.callout).foregroundStyle(p.text2.color)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background { if cur { shape.fill(p.fill1.color) } }
        .overlay { if cur { shape.strokeBorder(p.strokeHair.color, lineWidth: 1) } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(cur ? [.isSelected] : [])
    }

    private func panel(_ ask: Ask, sub: Int, _ p: MRPalette) -> some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 18) {
                    MRIcon(ask.icon, size: 24).foregroundStyle(MRColorToken.hex("#04101A"))
                        .frame(width: 56, height: 56)
                        .background(p.accentGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: obRGBA(106, 183, 255, 0.35), radius: 15, y: 10)
                    OT(ask.eyebrow).mrText(.eyebrow).foregroundStyle(p.text2.color)
                }
                OT(ask.heading).mrText(.title2).foregroundStyle(p.text1.color).padding(.top, 20)
                OT(ask.body).mrText(.body).foregroundStyle(p.text2.color).padding(.top, 10)
                if sub == 3 { readsGrid(p).padding(.top, 20) }
                else {
                    HStack(spacing: 8) {
                        ForEach(Array(ask.bullets.enumerated()), id: \.offset) { _, b in staticChip(b.0, b.1, p) }
                    }
                    .padding(.top, 20)
                }
            }
            .frame(width: 392, alignment: .leading)
            .obAt(36, 34)

            HStack(spacing: 10) {
                Button { primary(sub) } label: { OT(ask.cta) }.buttonStyle(MRButtonStyle(.primary))
                Button { alternate(sub) } label: { OT(ask.alt) }.buttonStyle(MRButtonStyle(.tertiary))
            }
            .obAt(36, 430 - 32 - 44)

            preview(ask, p).obAt(756 - 28 - 268, 28)
        }
        .frame(width: 756, height: 430, alignment: .topLeading)
        .mrGlass(cornerRadius: 30, elevation: .e3)
    }

    private func staticChip(_ icon: MRIconName, _ title: LocalizedStringKey, _ p: MRPalette) -> some View {
        HStack(spacing: 8) {
            MRIcon(icon, size: 14)
            OT(title).obType(.ui, 13, 500, lh: 13).lineLimit(1).fixedSize()
        }
        .foregroundStyle(p.text1.color)
        .padding(.leading, 12).padding(.trailing, 14).frame(height: 34)
        .background(p.fill1.color, in: Capsule())
        .overlay(Capsule().strokeBorder(p.strokeHair.color, lineWidth: 1))
    }

    private func readsGrid(_ p: MRPalette) -> some View {
        func box(_ title: LocalizedStringKey, _ text: LocalizedStringKey, _ icon: MRIconName, _ tint: Color, _ bg: Color, _ ring: Color) -> some View {
            let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
            return VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) { MRIcon(icon, size: 12); OT(title) }.mrText(.eyebrow).foregroundStyle(tint)
                OT(text).obType(.ui, 13, 400, lh: 19).foregroundStyle(p.text1.color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(bg, in: shape)
            .overlay(shape.strokeBorder(ring, lineWidth: 1))
        }
        return HStack(alignment: .top, spacing: 12) {
            box("Reads", "The name of the app in front. Nothing else.", .eye, p.ok.color, obRGBA(91, 227, 160, 0.08), obRGBA(91, 227, 160, 0.24))
            box("Never reads", "Window contents, keystrokes or your screen.", .lock, p.danger.color, obRGBA(255, 107, 107, 0.07), obRGBA(255, 107, 107, 0.24))
        }
    }

    /// The fake system dialog of the design ("You'll see next").
    private func preview(_ ask: Ask, _ p: MRPalette) -> some View {
        let dark = p.isDark
        let fg = dark ? MRColorToken.hex("#F3F5FA") : MRColorToken.hex("#14161C")
        let btn = dark ? Color.white.opacity(0.14) : Color.black.opacity(0.07)
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return VStack(spacing: 14) {
            OT("You'll see next").mrText(.eyebrow).foregroundStyle(p.text3.color)
            VStack(spacing: 0) {
                OT(ask.dTitle).obType(.ui, 13, 600, lh: 17)
                OT(ask.dBody).obType(.ui, 11, 400, lh: 15).opacity(0.75).padding(.top, 4).padding(.bottom, 12)
                HStack(spacing: 8) {
                    OT(ask.dNo).obType(.ui, 12, 500, lh: 24).frame(maxWidth: .infinity).frame(height: 24)
                        .background(btn, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    OT(ask.dYes).obType(.ui, 12, 500, lh: 24).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 24)
                        .background(MRColorToken.hex("#0A6CE0"), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(fg)
            .padding(.top, 16).padding(.horizontal, 16).padding(.bottom, 12)
            .frame(width: 232)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(dark ? obRGBA(40, 44, 56, 0.82) : obRGBA(246, 246, 248, 0.9))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(dark ? 0.22 : 0), lineWidth: 0.5))
            .shadow(color: dark ? .black.opacity(0.5) : obRGBA(40, 34, 20, 0.25), radius: 25, y: 20)
        }
        .frame(width: 268)
        .frame(maxHeight: .infinity)
        .frame(height: 430 - 56)
        .background(p.fill1.color, in: shape)
        .overlay(shape.strokeBorder(p.strokeHair.color, lineWidth: 1))
        .accessibilityHidden(true)
    }

    // MARK: Actions

    private func primary(_ sub: Int) {
        switch sub {
        case 1:
            // The explanation was shown; now the real system prompt.
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
            model.notificationsAnswered = true
        case 2:
            // TODO(onboarding): the Focus filter is configured in Settings (MeridianFocus); nothing to request here.
            model.focusAnswered = true
        default:
            break // TODO(Q12): no Accessibility prompt in v1 (ADR 0006).
        }
        onAdvance()
    }

    private func alternate(_ sub: Int) { onAdvance() }
}
