import MeridianPro
import MeridianUI
import SwiftUI

/// S53: the Meridian Pro sheet (1040 x 700, glass e3, radius 30).
/// Honesty rules (PRD §9.13): "What stays free" comes first, the trial timeline shows real dates,
/// and there is no countdown, no struck-through price and no "sale" badge. Prices are `$XX` placeholders
/// until StoreKit returns real ones.
struct PaywallView: View {
    var initialPlan: Plan = .lifetime
    var onClose: () -> Void = {}
    @State private var pro = ProModel.shared
    @Environment(\.mrPalette) private var p
    @Environment(\.colorScheme) private var scheme

    static let freeList = [
        "Unlimited flights, any length", "Every scenario, tag and cabin class", "Tickets, wallet, passport and stats",
        "Terra, Mono and Standard maps", "Window view, cabin sound and announcements", "Friend flights with up to 4 people",
        "Menu bar, mini map and widgets",
    ]

    private var selected: Plan { pro.paywall.selectedPlan }

    private func priceText(_ plan: Plan) -> String {
        let price = pro.paywall.price(for: plan)
        if price.isPlaceholder { return plan == .lifetime ? "$XX" : "$X" }
        return price.text
    }

    private func perText(_ plan: Plan) -> String {
        switch plan { case .lifetime: L("once"); case .annual: L("per year"); case .monthly: L("per month") }
    }

    var body: some View {
        HStack(spacing: 0) {
            left.frame(width: 432)
            right.frame(maxWidth: .infinity)
        }
        .frame(width: 1040, height: 700)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .mrGlass(cornerRadius: 30, elevation: .e3)
        .onAppear { pro.select(initialPlan) }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel("Meridian Pro")
    }

    // MARK: Left

    private var left: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                RadialGradient(colors: [Color(red: 27 / 255, green: 30 / 255, blue: 39 / 255), Color(red: 7 / 255, green: 8 / 255, blue: 11 / 255)],
                               center: UnitPoint(x: 0.72, y: 0.38), startRadius: 0, endRadius: 330)
                Capsule().fill(MRSky.sunset.gradient).frame(width: 148, height: 262)
                    .overlay(Capsule().strokeBorder(Color(red: 0.2, green: 0.21, blue: 0.25), lineWidth: 9))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
                    .opacity(0.9)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(.leading, 230).padding(.top, 6)
                LinearGradient(colors: [Color(red: 6 / 255, green: 8 / 255, blue: 13 / 255).opacity(0), Color(red: 6 / 255, green: 8 / 255, blue: 13 / 255).opacity(0.9)],
                               startPoint: .top, endPoint: .bottom).frame(height: 170).frame(maxHeight: .infinity, alignment: .bottom)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Meridian Pro").mrText(.eyebrow).foregroundStyle(Color(red: 243 / 255, green: 245 / 255, blue: 250 / 255).opacity(0.85))
                    Text(L("Pay once.\nFly on every device."))
                        .font(.mr(.serif, size: 36, weight: 500)).tracking(-0.02 * 36).lineSpacing(0)
                        .foregroundStyle(Color(red: 243 / 255, green: 245 / 255, blue: 250 / 255))
                }
                .padding(.horizontal, 28).padding(.bottom, 14)
            }
            .frame(height: 300).clipped()

            VStack(alignment: .leading, spacing: 0) {
                Text(L("What stays free")).mrText(.eyebrow).foregroundStyle(p.text1.color).padding(.bottom, 10)
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(Self.freeList, id: \.self) { item in
                        HStack(alignment: .top, spacing: 10) {
                            MRIcon(.check, size: 12).foregroundStyle(p.ok.color)
                                .frame(width: 18, height: 18).background(Circle().fill(p.fill2.color))
                            Text(L(item)).font(.mr(.ui, size: 13, weight: 400)).foregroundStyle(p.text1.color)
                        }
                    }
                }
                Text(L("Pro never takes these away, and Pro never adds a timer to them."))
                    .font(.mr(.ui, size: 13, weight: 400)).foregroundStyle(p.text2.color).padding(.top, 14)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28).padding(.top, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: Right

    private var right: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(L("Meridian Pro adds")).mrText(.eyebrow).foregroundStyle(p.text1.color)
                Spacer()
                HStack(spacing: 6) {
                    Button(action: onClose) { Text(L("Not now")).font(.mr(.ui, size: 13, weight: 600)).foregroundStyle(p.text2.color).padding(.horizontal, 10).frame(height: 32) }.buttonStyle(.plain)
                    Button(action: onClose) { MRIcon(.x, size: 16).foregroundStyle(p.text2.color) }
                        .buttonStyle(MRRoundButtonStyle(small: true)).accessibilityLabel(L("Close"))
                }.padding(.top, -6).padding(.trailing, -4)
            }
            VStack(alignment: .leading, spacing: 8) {
                add(.globe, L("Satellite map and flyover views"))
                add(.users, L("Friend flights with up to 12 people"))
                add(.sound, L("Twelve more cabin soundscapes"))
            }.padding(.top, 10).padding(.bottom, 18)

            VStack(spacing: 10) {
                ForEach(pro.paywall.plans, id: \.self) { plan in planRow(plan) }
            }
            .accessibilityElement(children: .contain).accessibilityLabel(L("Plan"))

            timelineBox.padding(.top, 16)
            Spacer(minLength: 0)

            Button { Task { await pro.purchaseSelected() } } label: { Text(cta).frame(maxWidth: .infinity) }
                .buttonStyle(MRButtonStyle(.primary, size: .lg)).disabled(pro.isWorking)
            Text(chargeLine).font(.mr(.ui, size: 12, weight: 400)).foregroundStyle(p.text2.color)
                .frame(maxWidth: .infinity).multilineTextAlignment(.center).padding(.top, 10)
            HStack(spacing: 6) {
                Text(L("Cancel anytime in")).font(.mr(.ui, size: 12, weight: 400)).foregroundStyle(p.text2.color)
                link(L("System Settings")) { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane")!) }
                dot; link(L("Restore purchases")) { Task { await pro.restore() } }
                dot; link(L("Terms")) { NSWorkspace.shared.open(PrivacyPane.termsURL) }
                dot; link(L("Privacy")) { NSWorkspace.shared.open(PrivacyPane.privacyURL) }
            }.frame(maxWidth: .infinity).padding(.top, 12)
        }
        .padding(.top, 30).padding(.trailing, 32).padding(.leading, 28).padding(.bottom, 22)
        .background(LinearGradient(colors: [.white.opacity(0.025), .clear], startPoint: .top, endPoint: .bottom))
    }

    private var dot: some View { Text("·").font(.mr(.ui, size: 12, weight: 400)).foregroundStyle(p.text3.color) }

    private func link(_ t: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.mr(.ui, size: 12, weight: 500)).underline(true).foregroundStyle(scheme == .dark ? p.accent1.color : Color(red: 20 / 255, green: 80 / 255, blue: 200 / 255))
        }.buttonStyle(.plain)
    }

    private func add(_ icon: MRIconName, _ text: String) -> some View {
        HStack(spacing: 10) {
            MRIcon(icon, size: 16).foregroundStyle(p.accent1.color)
            Text(text).font(.mr(.ui, size: 13, weight: 500))
        }
    }

    private func planRow(_ plan: Plan) -> some View {
        let isSel = selected == plan
        let title: String, sub: String
        switch plan {
        case .lifetime: title = L("Lifetime"); sub = L("One purchase · all Apple devices · Family Sharing")
        case .annual: title = L("Annual"); sub = L("7 days free, then billed yearly")
        case .monthly: title = L("Monthly"); sub = L("7 days free, then billed monthly")
        }
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return Button { pro.select(plan) } label: {
            HStack(spacing: 14) {
                Circle().strokeBorder(isSel ? p.accent1.color : p.text3.color, lineWidth: 1.5).frame(width: 20, height: 20)
                    .overlay { if isSel { Circle().fill(p.accent1.color).frame(width: 10, height: 10) } }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.mr(.ui, size: 15, weight: 600)).foregroundStyle(p.text1.color)
                    Text(sub).font(.mr(.ui, size: 12, weight: 400)).foregroundStyle(p.text2.color)
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(priceText(plan)).font(.mr(.serif, size: 24, weight: 500)).tracking(-0.01 * 24).foregroundStyle(p.text1.color)
                    Text(perText(plan)).font(.mr(.ui, size: 11, weight: 400)).foregroundStyle(p.text2.color)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(isSel ? p.fill2.color : p.fill1.color, in: shape)
            .overlay(shape.strokeBorder(isSel ? p.accent1.color : p.strokeHair.color, lineWidth: isSel ? 2 : 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(priceText(plan)) \(perText(plan)). \(sub)")
        .accessibilityAddTraits(isSel ? .isSelected : [])
    }

    private var timeline: TrialTimeline? { pro.paywall.trialTimeline(startingAt: .now) }

    @ViewBuilder private var timelineBox: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        Group {
            if timeline != nil {
                ZStack(alignment: .topLeading) {
                    p.strokeGlow.color.opacity(0.6).frame(height: 2).padding(.leading, 6).padding(.trailing, 40).padding(.top, 5)
                    HStack(alignment: .top, spacing: 8) {
                        step(.now, L("Today"), L("Free access to everything in Pro"))
                        step(.reminder, L("Day 5"), L("We send you a reminder"))
                        step(.end, L("Day 7"), L("Charge of %@ unless canceled", priceText(selected)))
                    }
                }
            } else {
                HStack(spacing: 12) {
                    MRIcon(.check, size: 18).foregroundStyle(p.ok.color)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(L("No trial, no renewal")).font(.mr(.ui, size: 13, weight: 600))
                        Text(L("You pay once. It unlocks on every Mac, iPhone and iPad you own, and with Family Sharing."))
                            .font(.mr(.ui, size: 12, weight: 400)).foregroundStyle(p.text2.color).fixedSize(horizontal: false, vertical: true)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 12)
        .background(p.fill1.color, in: shape)
        .overlay(shape.strokeBorder(p.strokeHair.color, lineWidth: 1))
    }

    private enum StepKind { case now, reminder, end }

    private func step(_ kind: StepKind, _ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.mr(.ui, size: 12, weight: 600))
            Text(sub).font(.mr(.ui, size: 12, weight: 400)).foregroundStyle(p.text2.color).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 20).frame(maxWidth: .infinity, alignment: .topLeading)
        .overlay(alignment: .topLeading) {
            Circle().fill(kind == .now ? p.accent1.color : p.bg2.color).frame(width: 12, height: 12)
                .overlay(Circle().strokeBorder(kind == .end ? p.amber.color : kind == .now ? .clear : p.text3.color, lineWidth: 2))
                .background { if kind == .now { Circle().fill(p.accent1.color.opacity(0.25)).frame(width: 20, height: 20) } }
        }
    }

    private var cta: String { selected.hasTrial ? L("Start 7-day free trial") : L("Buy Lifetime") }

    private var chargeLine: String {
        if let t = timeline {
            let day = t.chargeDate.formatted(.dateTime.month(.abbreviated).day())
            return L("No surprises: you’ll be charged %@ on %@ unless you cancel.", priceText(selected), day)
        }
        return L("You’ll be charged %@ once. Nothing renews.", priceText(.lifetime))
    }
}

/// The paywall as drawn on the canvas: Settings > Account behind a scrim, the sheet on top.
struct PaywallScreen: View {
    var plan: Plan
    var onClose: () -> Void = {}
    @Environment(\.mrPalette) private var p

    var body: some View {
        ZStack(alignment: .topLeading) {
            SettingsView(pane: .account, showsChrome: true)
            Rectangle().fill(p.scrim.color).background(.ultraThinMaterial.opacity(0.7))
            PaywallView(initialPlan: plan, onClose: onClose).offset(x: 120, y: 50)
            SettingsTrafficLights().offset(x: 20, y: 18)
        }
    }
}
