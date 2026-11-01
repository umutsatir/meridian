import MeridianUI
import SwiftUI

/// S14B: the boarding gate (`Gate.dc.html`). The torn pass is pinned top left, a departures board with split-flap rows,
/// a 3-second countdown ring and the blocking chip. Enter / Space boards immediately; at 0 the doors close.
struct RitualGateView: View {
    var info: RitualFlightInfo
    var seat: String
    var topic: String
    /// Design reference: a fixed count (3, 2, 1, 0) and no clock.
    var staticCount: Int?
    var sidebarInset: CGFloat = 236
    var blockingChip: String? = "Soft blocking is on"
    var onBoard: () -> Void = {}

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focused: Bool
    @State private var startedAt = Date()
    @State private var lastCount = 3
    @State private var boarded = false

    private var live: Bool { staticCount == nil }

    var body: some View {
        GeometryReader { geo in
            let free = geo.size.width - sidebarInset - 20
            let s = min(1, free / 1024, geo.size.height / 800)
            let dx = sidebarInset + (free - 1024 * s) / 2 - 236 * s
            let dy = max(0, (geo.size.height - 800 * s) / 2)
            // the board grows with a wider window; a narrower one scales the whole layout
            TimelineView(.animation(paused: !live || boarded)) { tl in
                let e = live ? tl.date.timeIntervalSince(startedAt) : 0
                let n = staticCount ?? max(0, 3 - Int(e))
                let tf = live ? min(1, e / 3.0) : Double(3 - n) / 3
                design(count: n, fraction: tf)
                    .onChange(of: n) { _, new in countChanged(new) }
                    .onChange(of: e >= 3.5) { _, done in if done && live { board() } }
            }
            .frame(width: 1280, height: 800, alignment: .topLeading)
            .scaleEffect(s, anchor: .topLeading)
            .offset(x: dx, y: dy)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onKeyPress(.return) { board(); return live ? .handled : .ignored }
        .onKeyPress(.space) { board(); return live ? .handled : .ignored }
        .onAppear { startedAt = Date(); focused = true }
    }

    private func countChanged(_ n: Int) {
        guard live else { return }
        MRSound.shared.play(.tick(heavy: n == 0))
        if n == 0 { PaperHaptics.release() } else { PaperHaptics.tick() }
    }

    /// Boards now (Enter / Space) or when the doors have been closed for a beat.
    private func board() {
        guard live, !boarded else { return }
        boarded = true
        onBoard()
    }

    private func design(count n: Int, fraction tf: Double) -> some View {
        let p = MRPalette.resolve(scheme)
        let closing = n == 0
        let pass = info.passModel(seat: seat, topic: topic)
        let type = RitualSeatMap.type(of: String(seat.suffix(1)))
        return ZStack(alignment: .topLeading) {
            // pinned ticket
            BoardingPassView(pass, state: .torn, scale: 0.56)
                .offset(x: 262, y: 76)

            // departures board
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Departures").mrText(.eyebrow).foregroundStyle(p.text2.color)
                    Spacer(minLength: 0)
                    Text("\(info.clock) · \(info.originName)").font(.mr(.mono, size: 13, weight: 500)).foregroundStyle(p.text2.color)
                }
                .frame(height: 16)
                HStack(alignment: .top, spacing: 24) {
                    column("Flight", p) { SplitFlapText(info.flightNumber, size: .xs, onFlap: Self.flap) }
                    column("Route", p) { SplitFlapText(info.routeText, size: .xs, tone: .white, onFlap: Self.flap) }
                    column("Gate", p) { SplitFlapText(info.gate, size: .xs, onFlap: Self.flap) }
                    column("Status", p) { SplitFlapText(closing ? "CLOSED" : "BOARDING", length: 8, size: .xs, onFlap: Self.flap) }
                }
                .padding(.top, 22)
                MRDivider().padding(.top, 24).padding(.bottom, 18)
                HStack(spacing: 22) {
                    VStack(alignment: .leading, spacing: 0) {
                        cap("Passenger", p); Text(info.passenger).font(.mr(.ui, size: 15, weight: 600)).frame(height: 18)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        cap("Seat", p); Text("\(seat) · \(type)").font(.mr(.mono, size: 15, weight: 500)).frame(height: 18)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        cap("Flight time", p); Text(info.flightTimeText).font(.mr(.mono, size: 15, weight: 500)).frame(height: 18)
                    }
                    Spacer(minLength: 0)
                    MRPill(closing ? "Doors closed" : "Boarding", kind: closing ? .warn : .ok, pulsingDot: true)
                }
                .foregroundStyle(p.text1.color)
            }
            .padding(.horizontal, 26).padding(.vertical, 22)
            .frame(width: 748, height: 253, alignment: .topLeading)
            .mrGlass(cornerRadius: 26, elevation: .e3)
            .offset(x: 492, y: 76)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Departures. Flight \(info.flightNumber), \(info.originCity) to \(info.destinationCity), gate \(info.gate), \(closing ? "doors closed" : "boarding").")

            // countdown
            VStack(spacing: 0) {
                ZStack {
                    Circle().stroke(p.fill2.color, lineWidth: 3).frame(width: 208, height: 208)
                    Circle().trim(from: 0, to: 1 - tf)
                        .stroke(LinearGradient(colors: [Color(hex: "#6AB7FF"), Color(hex: "#8BF3D8")], startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 208, height: 208)
                        .rotationEffect(.degrees(-90))
                    Text("\(n)").font(.mr(.mono, size: 132, weight: 500)).tracking(-5.28).foregroundStyle(p.text1.color)
                }
                .frame(width: 224, height: 224)
                Text("Doors close in \(n)…").mrText(.title2).foregroundStyle(p.text1.color).padding(.top, 22)
                Text("Boarding").mrText(.callout).foregroundStyle(p.text2.color).padding(.top, 6)
            }
            .frame(width: 1280 - 236 - 20)
            .offset(x: 236, y: 372)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Doors close in \(n). Press Return or Space to board now.")

            if let blockingChip {
                HStack(spacing: 14) {
                    MRIcon(.shield, size: 20).foregroundStyle(p.text2.color)
                    Text("Close your other windows?").font(.mr(.ui, size: 14, weight: 500)).foregroundStyle(p.text1.color)
                    DotPill(text: blockingChip, palette: p)
                }
                .padding(.leading, 18).padding(.trailing, 8).frame(height: 52)
                .mrGlass(cornerRadius: 26, elevation: .e2)
                .offset(x: 236 + ((1024 - 560) / 2).rounded(), y: 800 - 34 - 52)
            }
        }
        .frame(width: 1280, height: 800, alignment: .topLeading)
    }

    private nonisolated static let flap: @Sendable (Int) -> Void = { _ in Task { @MainActor in MRSound.shared.play(.flap) } }

    private func cap(_ t: String, _ p: MRPalette) -> some View {
        Text(t).font(.mr(.ui, size: 10, weight: 600)).tracking(1.4).textCase(.uppercase).foregroundStyle(p.text3.color)
            .frame(height: 12).padding(.bottom, 8)
    }

    private func column<C: View>(_ title: String, _ p: MRPalette, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) { cap(title, p); content() }
    }
}

/// `.pill.accent` with the static `.dotp` dot ("Soft blocking is on").
private struct DotPill: View {
    let text: String
    let palette: MRPalette
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let dark = scheme == .dark
        HStack(spacing: 6) {
            MRDot()
            Text(text).font(.mr(.ui, size: 11, weight: 600)).tracking(11 * 0.04).textCase(.uppercase)
        }
        .foregroundStyle(palette.accentPillText.color)
        .padding(.horizontal, 10).frame(height: 24)
        .background((dark ? Color(red: 106 / 255, green: 183 / 255, blue: 1).opacity(0.16) : Color(red: 30 / 255, green: 107 / 255, blue: 1).opacity(0.10)), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
