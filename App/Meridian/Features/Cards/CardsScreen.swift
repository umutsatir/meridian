import MeridianCore
import MeridianUI
import SwiftUI

/// S32 / S32L: membership cards (CardsScreen.dc.html). A 3D coverflow of the six tiers (drag, arrows, dots, click),
/// the hero card tilts with the pointer and flips on click, and a progress panel shows the distance to the next card.
struct CardsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.shellSidebarInset) private var inset
    @Environment(\.colorScheme) private var scheme
    @Environment(\.cardsFixture) private var fixture
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var idx: Int = 0
    @State private var didStart = false
    @State private var drag: CGFloat = 0
    @State private var overSide = false
    @FocusState private var focused: Bool

    private var content: CardsContent { fixture ?? CardsContent.live(model) }

    var body: some View {
        let p = MRPalette.resolve(scheme)
        let c = content
        let tiers = UITier.allCases
        let T = tiers[idx], nxt: UITier? = idx + 1 < tiers.count ? tiers[idx + 1] : nil
        let km = c.km
        let locked = Double(T.thresholdKm) > km
        let tint = mrHex(T.tintHex)
        let togo = locked ? Double(T.thresholdKm) - km : (nxt.map { Double($0.thresholdKm) - km } ?? 0)
        let from = Double(T.thresholdKm), to = Double((nxt ?? T).thresholdKm)
        let pct = locked ? min(1, km / Double(T.thresholdKm)) : (nxt != nil ? min(1, (km - from) / (to - from)) : 1)
        ZStack {
        Color.clear.focusable().focusEffectDisabled().focused($focused)
        GeometryReader { geo in
            let W = geo.size.width
            let L = inset + 16
            let zoneLeft = inset - 16
            let flowLeft = zoneLeft + (W - zoneLeft - 1060) / 2
            ZStack(alignment: .topLeading) {
                EllipticalGlow(color: tint.opacity(Double(0x22) / 255))
                    .animation(MRMotion.ease(MRMotion.d4), value: idx)

                // header
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Membership").mrEyebrow().frame(height: 14)
                        Text(T.title).font(.mr(.serif, size: 44, weight: 500)).tracking(-0.015 * 44)
                            .foregroundStyle(p.text1.color).frame(height: 48).padding(.top, 4)
                        Text(T.tagline).font(.mr(.serif, size: 18, weight: 500, italic: true))
                            .foregroundStyle(p.text2.color).padding(.top, 2)
                    }
                    Spacer(minLength: 0)
                    statusPill(locked: locked, km: Double(T.thresholdKm) - km)
                }
                .frame(width: W - L - 32, alignment: .leading)
                .offset(x: L, y: 52)

                coverflow(tiers: tiers, km: km, info: c.info)
                    .frame(width: 1060, height: 340, alignment: .topLeading)
                    .offset(x: flowLeft, y: 150)
                    .gesture(DragGesture(minimumDistance: 12)
                        .onEnded { v in
                            if v.translation.width < -40 { go(1) } else if v.translation.width > 40 { go(-1) }
                        })

                Button { go(-1) } label: { MRIcon(.chevL, size: 18) }
                    .buttonStyle(MRRoundButtonStyle())
                    .accessibilityLabel("Previous card")
                    .offset(x: inset, y: 296)
                Button { go(1) } label: { MRIcon(.chevR, size: 18) }
                    .buttonStyle(MRRoundButtonStyle())
                    .accessibilityLabel("Next card")
                    .offset(x: W - 88, y: 296)

                HStack(spacing: 8) {
                    ForEach(0..<tiers.count, id: \.self) { i in
                        Capsule()
                            .fill(i == idx ? AnyShapeStyle(p.accentGradient) : AnyShapeStyle(p.fill3.color))
                            .frame(width: i == idx ? 22 : 7, height: 7)
                            .contentShape(Rectangle().inset(by: -6))
                            .onTapGesture { select(i) }
                            .accessibilityLabel(tiers[i].title)
                            .accessibilityAddTraits(.isButton)
                    }
                }
                .animation(MRMotion.ease(MRMotion.d2), value: idx)
                .frame(width: 1060)
                .offset(x: flowLeft, y: 496)

                progressPanel(p: p, c: c, T: T, nxt: nxt, locked: locked, togo: togo, from: from, to: to, pct: pct, tint: tint)
                    .frame(width: W - L - 32, height: 196)
                    .offset(x: L, y: 540)
            }
            .frame(width: W, height: geo.size.height, alignment: .topLeading)
        }
        }
        .onKeyPress(.leftArrow) { go(-1); return .handled }
        .onKeyPress(.rightArrow) { go(1); return .handled }
        .onAppear {
            if !didStart {
                didStart = true
                idx = content.startIndex ?? UITier.highest(forKm: Int(content.km)).index
                if let t = CardUnlockPresenter.shared.focusTier { idx = t.index; CardUnlockPresenter.shared.focusTier = nil }
            }
            focused = true
        }
        .onChange(of: CardUnlockPresenter.shared.focusTier) { _, t in
            if let t { select(t.index); CardUnlockPresenter.shared.focusTier = nil }
        }
    }

    private func go(_ d: Int) {
        let n = max(0, min(UITier.allCases.count - 1, idx + d))
        guard n != idx else { return }
        MRSound.shared.play(.click)
        select(n)
    }

    private func select(_ i: Int) {
        withAnimation(reduceMotion ? MRMotion.ease(MRMotion.d2) : MRMotion.smooth) { idx = i }
    }

    // MARK: Coverflow

    private func coverflow(tiers: [UITier], km: Double, info: MembershipCardInfo) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(tiers.enumerated()), id: \.offset) { i, t in
                let off = i - idx, a = abs(off), isC = off == 0
                MembershipCardView(tier: t, size: isC ? .hero : .list, locked: Double(t.thresholdKm) > km, info: info, live: isC)
                    .modifier(CoverflowEffect(off: Double(off), reduceMotion: reduceMotion))
                    .opacity(a > 2 ? 0 : (isC ? 1 : (a == 1 ? 0.9 : 0.5)))
                    .blur(radius: isC || reduceMotion ? 0 : CGFloat(2 * a))
                    .allowsHitTesting(isC)   // side cards are hit-tested by `CoverflowHitTest` on the container
                    .accessibilityAction(named: isC ? "Flip card" : "Show \(t.title) card") { if !isC { select(i) } }
                    .zIndex(Double(100 - a * 10))
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(SpatialTapGesture().onEnded { v in
            if let t = CoverflowHitTest.index(forX: v.location.x, y: v.location.y, selected: idx, count: tiers.count) { select(t) }
        })
        .onContinuousHover { phase in
            switch phase {
            case .active(let l):
                let side = CoverflowHitTest.index(forX: l.x, y: l.y, selected: idx, count: tiers.count) != nil
                if side != overSide { overSide = side; if side { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
            case .ended:
                if overSide { overSide = false; NSCursor.pop() }
            }
        }
    }

    // MARK: Pill

    private func statusPill(locked: Bool, km: Double) -> some View {
        let p = MRPalette.resolve(scheme)
        let dark = scheme == .dark
        let bg: Color = locked ? p.fill2.color : (dark ? MRColorToken(91, 227, 160, 0.16).color : MRColorToken(14, 138, 90, 0.12).color)
        let fg: Color = locked ? p.text2.color : p.ok.color
        return HStack(spacing: 6) {
            MRIcon(locked ? .lock : .check, size: 12)
            Text(locked ? "\(PlanKit.fmtKm(km)) km to unlock" : "Unlocked")
                .font(.mr(.ui, size: 11, weight: 600)).tracking(11 * 0.04).textCase(.uppercase)
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: Progress

    private func progressPanel(p: MRPalette, c: CardsContent, T: UITier, nxt: UITier?, locked: Bool,
                               togo: Double, from: Double, to: Double, pct: Double, tint: Color) -> some View {
        let label = locked ? "To unlock \(T.title)" : (nxt.map { "Next card · \($0.title)" } ?? "Highest card reached")
        let unit = (nxt != nil || locked) ? " km to go" : " km flown"
        let frac = min(1, c.km / 40075)
        let times = String(format: "%.1f", frac)
        return HStack(alignment: .top, spacing: 34) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(label).mrEyebrow().frame(height: 14)
                    (Text(PlanKit.fmtKm(togo)).font(.mr(.serif, size: 34, weight: 500))
                        + Text(unit).font(.mr(.serif, size: 16, weight: 500, italic: true)).foregroundColor(p.text2.color))
                        .foregroundStyle(p.text1.color)
                        .frame(height: 38, alignment: .leading).padding(.top, 6)
                }
                Spacer(minLength: 0)
                VStack(spacing: 8) {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(p.fill2.color)
                            Capsule().fill(tint).frame(width: g.size.width * pct)
                                .shadow(color: tint, radius: 5)
                        }
                        .clipShape(Capsule())
                    }
                    .frame(height: 6)
                    HStack {
                        Text("\(PlanKit.fmtKm(locked ? 0 : from)) km")
                        Spacer()
                        Text("\(PlanKit.fmtKm(locked ? Double(T.thresholdKm) : to)) km")
                    }
                    .font(.mr(.mono, size: 11, weight: 500)).foregroundStyle(p.text3.color)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .layoutPriority(1.5)
            .frame(width: 372, alignment: .leading)

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Member").mrEyebrow().frame(height: 14)
                    Text(c.name).font(.mr(.ui, size: 17, weight: 600)).foregroundStyle(p.text1.color).frame(height: 22).padding(.top, 8)
                    Text("Joined \(c.joined) · \(c.daysFlown) days flown").mrText(.callout).foregroundStyle(p.text2.color).padding(.top, 2)
                }
                Spacer(minLength: 0)
                Text(c.memberNumber).font(.mr(.mono, size: 12, weight: 500)).foregroundStyle(p.text3.color)
            }
            .frame(width: 248, alignment: .topLeading)
            .frame(maxHeight: .infinity, alignment: .topLeading)

            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(p.fill2.color, lineWidth: 6)
                    Circle().trim(from: 0, to: frac).stroke(p.accent1.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 72, height: 72).padding(7)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(times)×").font(.mr(.serif, size: 34, weight: 500)).foregroundStyle(p.text1.color).frame(height: 36, alignment: .leading)
                    Text("around the world").mrText(.callout).foregroundStyle(p.text2.color).padding(.top, 4)
                    Text("\(PlanKit.fmtKm(c.km)) of 40,075 km").font(.mr(.mono, size: 11, weight: 500)).foregroundStyle(p.text3.color).padding(.top, 4)
                }
            }
            .frame(width: 248, alignment: .leading)
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 30).padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mrGlass(cornerRadius: 28, elevation: .e2)
    }
}
