import MeridianCore
import MeridianUI
import Observation
import SwiftUI

/// The single call point for the "card unlocked" moment (S33). The landing flow calls
/// `CardUnlockPresenter.shared.present(tiers:)` with `LandingSummary.unlockedTiers`; each tier is shown once
/// (remembered in UserDefaults), several tiers queue one after the other.
@MainActor @Observable
final class CardUnlockPresenter {
    static let shared = CardUnlockPresenter()

    /// The tier whose unlock moment is on screen.
    private(set) var current: UITier?
    /// Fixed timeline position in ms (DEBUG route) instead of the running animation.
    private(set) var fixedT: Double?
    private(set) var fixtureContent: CardsContent?
    /// Set by "View card": the Cards screen consumes it and scrolls the coverflow to this tier.
    var focusTier: UITier?
    @ObservationIgnored private var queue: [UITier] = []
    private static let shownKey = "cards.unlockPresented"

    private var shown: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: Self.shownKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue).sorted(), forKey: Self.shownKey) }
    }

    /// Queues the unlock moment for tiers not shown before. The Departure card is the welcome card (no ceremony).
    func present(tiers: [CoreTier]) {
        var seen = shown
        for tier in tiers.sorted() where tier != .departure && !seen.contains(tier.rawValue) {
            seen.insert(tier.rawValue)
            queue.append(UITier(core: tier))
        }
        shown = seen
        advance()
    }

    /// DEBUG: draws the moment at a fixed time of its timeline.
    func presentFixture(tier: UITier, atMs t: Double, content: CardsContent? = nil) {
        fixedT = t
        fixtureContent = content
        current = tier
    }

    /// Closes the moment; `viewCard` jumps to the card on the Cards screen.
    func dismiss(viewCard: Bool, model: AppModel? = nil) {
        guard let tier = current else { return }
        if viewCard {
            focusTier = tier
            model?.section = .cards
        }
        current = nil
        fixedT = nil
        advance()
    }

    private func advance() {
        guard current == nil, !queue.isEmpty else { return }
        current = queue.removeFirst()
    }
}

/// Dims and blurs the window and shows the unlock moment over everything, sidebar included.
struct CardUnlockHost: ViewModifier {
    @Environment(AppModel.self) private var model
    private let presenter = CardUnlockPresenter.shared

    func body(content: Content) -> some View {
        content
            .overlay {
                if let tier = presenter.current {
                    Rectangle().fill(.ultraThinMaterial).opacity(0.5).allowsHitTesting(false)
                    CardUnlockOverlay(tier: tier, content: presenter.fixtureContent ?? CardsContent.live(model), fixedT: presenter.fixedT,
                                      onViewCard: { presenter.dismiss(viewCard: true, model: model) },
                                      onClose: { presenter.dismiss(viewCard: false) })
                        .id(tier)
                }
            }
    }
}

/// S33: sleeve, light burst, rising card, typed serif "Congratulations", 3.4 s timeline (CardsScreen.dc.html).
struct CardUnlockOverlay: View {
    let tier: UITier
    let content: CardsContent
    var fixedT: Double?
    var onViewCard: () -> Void
    var onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    @State private var start = Date()
    @State private var finished = false

    private static let full = "Congratulations"
    private static let duration = 3400.0

    var body: some View {
        let still = fixedT != nil || reduceMotion
        TimelineView(.animation(paused: still || finished)) { ctx in
            let t = fixedT ?? (reduceMotion ? Self.duration : ctx.date.timeIntervalSince(start) * 1000)
            scene(t: min(t, Self.duration + 1))
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.escape) { onClose(); return .handled }
        .task {
            guard fixedT == nil else { return }
            try? await Task.sleep(for: .milliseconds(1000))
            MRSound.shared.play(.chime(.land))
            try? await Task.sleep(for: .milliseconds(2500))
            finished = true
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private func cl(_ v: Double, _ a: Double = 0, _ b: Double = 1) -> Double { max(a, min(b, v)) }

    private func scene(t ut: Double) -> some View {
        let p = MRPalette.resolve(scheme)
        let ease = { (u: Double) in u * u * (3 - 2 * u) }
        let typedN = Int(cl((ut - 1300) / 40, 0, Double(Self.full.count)))
        let rise = ease(cl((ut - 400) / 900))
        let next = tier.next ?? tier
        let cardTop = 176 + (1 - rise) * 330
        let caret = typedN < Self.full.count || ut < 2600
        return ZStack(alignment: .top) {
            Color(red: 3 / 255, green: 5 / 255, blue: 10 / 255).opacity(0.78 * cl(ut / 300))
                .contentShape(Rectangle())
            // light burst
            Circle()
                .fill(RadialGradient(stops: [
                    .init(color: Color(red: 1, green: 244 / 255, blue: 205 / 255).opacity(0.9), location: 0),
                    .init(color: Color(red: 1, green: 233 / 255, blue: 168 / 255).opacity(0.35), location: 0.38 * 297 / 210),
                    .init(color: Color(red: 1, green: 233 / 255, blue: 168 / 255).opacity(0), location: 0.68 * 297 / 210),
                ], center: .center, startRadius: 0, endRadius: 210))
                .frame(width: 420, height: 420)
                .scaleEffect(0.3 + cl((ut - 800) / 1200) * 1.6)
                .opacity(cl(1 - abs((ut - 1100) / 700)))
                .padding(.top, 330 - 210)
            particles(ut)
            MembershipCardView(tier: tier, size: .hero, locked: false, info: content.info, live: false)
                .frame(width: 480, height: 302)
                .shadow(color: .black.opacity(0.55), radius: 20, x: 0, y: 30)
                .opacity(rise < 0.02 ? 0 : 1)
                .padding(.top, cardTop)
            // sleeve
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [mrHex("#1B2133"), mrHex("#0E1322")], startPoint: .top, endPoint: .bottom))
                .overlay(MRInsetShadow(RoundedRectangle(cornerRadius: 12, style: .continuous), color: .white.opacity(0.14), y: 1))
                .shadow(color: .black.opacity(0.6), radius: 20, x: 0, y: 20)
                .overlay {
                    Text("Meridian").mrEyebrow().tracking(11 * 0.3)
                }
                .frame(width: 600, height: 46)
                .opacity(cl((ut - 150) / 250))
                .padding(.top, 440)
            // copy
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text(String(Self.full.prefix(typedN)))
                        .font(.mr(.serif, size: 52, weight: 500)).tracking(-0.015 * 52)
                    Rectangle().fill(p.accent1.color).frame(width: 2, height: 44).padding(.leading, 4).offset(y: -4)
                        .opacity(caret ? (reduceMotion || fixedT != nil ? 1 : (Int(ut / 500) % 2 == 0 ? 1 : 0)) : 0)
                }
                .foregroundStyle(p.text1.color)
                .frame(minHeight: 56)
                Text("You have reached \(tier.title). \(PlanKit.fmtKm(Double(tier.thresholdKm))) kilometres of focused time, one quiet session at a time. This card is yours to keep, and your next stop, \(next.title), is waiting at \(PlanKit.fmtKm(Double(next.thresholdKm))) km.")
                    .font(.mr(.serif, size: 19, weight: 500, italic: true))
                    .lineSpacing(8.7)
                    .foregroundStyle(p.text2.color)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)
                    .padding(.top, 12)
                    .opacity(cl((ut - 2000) / 500))
                HStack(spacing: 12) {
                    Button(action: onViewCard) { Text("View card") }
                        .buttonStyle(MRButtonStyle(.primary, size: .lg))
                    ShareLink(item: "I reached \(tier.title) on Meridian: \(PlanKit.fmtKm(Double(tier.thresholdKm))) km of focused flight.") {
                        HStack(spacing: 8) { MRIcon(.share, size: 18); Text("Share") }
                    }
                    .buttonStyle(MRButtonStyle(.secondary, size: .lg))
                }
                .padding(.top, 25)
                .opacity(cl((ut - 2400) / 400))
            }
            .padding(.top, 510)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func particles(_ ut: Double) -> some View {
        var rng = PaperRandom(seed: 21)
        var items: [(x: Double, y: Double, dx: Double, dy: Double, r: Double, del: Double)] = []
        for i in 0..<12 {
            let x = 140 + rng.next() * 1000, y = 560 + rng.next() * 140, dx = (rng.next() - 0.5) * 120
            let dy = -(160 + rng.next() * 220), r = (-30 + rng.next() * 80).rounded(), del = 900 + Double(i) * 120
            items.append((x, y, dx, dy, r, del))
        }
        return ZStack(alignment: .topLeading) {
            ForEach(0..<items.count, id: \.self) { i in
                let it = items[i]
                let u = cl((ut - it.del) / 2200)
                let op = (u <= 0 || u >= 1) ? 0 : (u < 0.15 ? u / 0.15 * 0.9 : 0.9 * (1 - (u - 0.15) / 0.85))
                PaperPlane()
                    .stroke(mrHex("#FFE9A8"), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    .frame(width: 22, height: 18)
                    .rotationEffect(.degrees(it.r + 40 * u))
                    .opacity(op)
                    .offset(x: it.x + it.dx * u, y: it.y + it.dy * u)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}

/// `M1 8L21 1L14 17L10 10Z  M21 1L10 10` in a 22 x 18 box.
private struct PaperPlane: Shape {
    nonisolated func path(in r: CGRect) -> Path {
        var p = Path()
        let sx = r.width / 22, sy = r.height / 18
        func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }
        p.move(to: pt(1, 8)); p.addLine(to: pt(21, 1)); p.addLine(to: pt(14, 17)); p.addLine(to: pt(10, 10)); p.closeSubpath()
        p.move(to: pt(21, 1)); p.addLine(to: pt(10, 10))
        return p
    }
}
