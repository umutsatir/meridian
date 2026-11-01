import MeridianUI
import Observation
import SwiftUI

/// Drives S13 (printing) and S14A (tear): the printer clock, the tear model, sound, haptics, the "+1" and the hand-off to the gate.
/// Sound and haptics follow the design's Ritual.dc.html: stepper chirp + tick per step, soft tick on settle, rip that follows the
/// pointer, 150 Hz thump when the stub lands in the wallet.
@MainActor @Observable
final class RitualStageController {
    enum Phase: Equatable { case print, ready, tearing, flying, slide, done }

    let clock = TicketPrintClock()
    let tear = TicketTearModel()
    private(set) var phase: Phase = .print
    private(set) var toast = false
    private(set) var badge = false
    /// 0...1: the torn pass slides to its pinned place (Gate layout).
    private(set) var slide: Double = 0
    /// Called when the torn pass is pinned; the host then shows the gate.
    @ObservationIgnored var onFinished: () -> Void = {}
    @ObservationIgnored private var ripOn = false
    @ObservationIgnored private var silent = false
    @ObservationIgnored private var feedback = true
    @ObservationIgnored private var started = false
    @ObservationIgnored private var reduceMotion = false
    @ObservationIgnored private var task: Task<Void, Never>?

    var sound: MRSound { MRSound.shared }

    func begin(reduceMotion: Bool) {
        guard !started else { return }
        started = true
        self.reduceMotion = reduceMotion
        feedback = SettingsKeys.tearFeedback.current
        let quick = RitualPolicy.printing == .quick
        MRSound.shared.prewarm()
        clock.onStep = { [weak self] i in
            guard let self, !self.silent else { return }
            self.sound.play(.printerStep(i)); PaperHaptics.tick()
        }
        clock.onSettle = { [weak self] in
            guard let self else { return }
            self.sound.play(.tick(heavy: true)); if !self.silent { PaperHaptics.release() }
        }
        clock.onReady = { [weak self] in self?.phase = .ready }
        tear.onBegin = { [weak self] in
            guard let self, self.feedback else { return }
            self.sound.rip.start(); self.ripOn = true
            self.phase = .tearing
        }
        tear.onTick = { [weak self] _ in
            guard let self, self.feedback else { return }
            self.sound.play(.tick(heavy: false)); PaperHaptics.tick()
        }
        tear.onVelocity = { [weak self] v in
            guard let self, self.feedback, self.ripOn else { return }
            self.sound.rip.set(v)
        }
        tear.onFinish = { [weak self] in
            guard let self else { return }
            self.phase = .tearing
            guard self.feedback else { return }
            if !self.ripOn { self.sound.rip.start(); self.ripOn = true }
            self.sound.rip.set(0.9)
        }
        tear.onRelease = { [weak self] _ in
            guard let self else { return }
            if self.ripOn { self.sound.rip.stop(); self.ripOn = false }
            self.phase = .ready
        }
        tear.onTorn = { [weak self] in
            guard let self else { return }
            self.phase = .flying
            if self.feedback { self.sound.rip.finish(); PaperHaptics.release() }
            self.ripOn = false
        }
        tear.onFlyEnd = { [weak self] in self?.flyEnded() }
        if !reduceMotion { sound.play(.paperSlide) }
        clock.start(reduceMotion: reduceMotion)
        if quick && !reduceMotion { silent = true; clock.skip(); silent = false }
    }

    func skipPrinting() {
        guard phase == .print else { return }
        sound.play(.tick(heavy: true))
        clock.skip()
    }

    func tearNow() { tear.tearWithButton(reduceMotion: reduceMotion) }

    /// Stops sound and timers (the ritual was cancelled).
    func stop() {
        task?.cancel()
        if ripOn { sound.rip.stop(); ripOn = false }
    }

    private func flyEnded() {
        if feedback { sound.play(.thump) }
        phase = .slide
        toast = true; badge = true
        task?.cancel()
        task = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(420))
            guard let self, !Task.isCancelled else { return }
            withAnimation(.timingCurve(0.36, 0, 0.64, 1, duration: self.reduceMotion ? 0.2 : 0.7)) { self.slide = 1 }
            try? await Task.sleep(for: .milliseconds(self.reduceMotion ? 220 : 720))
            guard !Task.isCancelled else { return }
            self.phase = .done
            self.toast = false
            self.onFinished()
        }
    }
}

/// A frozen frame of the stage for the design reference (S13 `t`, S14A `tear`).
struct RitualStill: Equatable {
    var t: Double = 2400
    var tear: Double = 0
    var grab: TearGrabSide = .right
    var annotate = false
}

/// S13 + S14A: the printer pushes the pass out, then the user tears the stub. Canvas coordinates (`Ritual.dc.html`): pass centre
/// `cx = 236 + (W - 256) / 2`, slot top 56, pass top 76. Designed for 800 pt of height; shorter windows scale the stage.
struct RitualStageView: View {
    let model: BoardingPassModel
    var controller: RitualStageController?
    var still: RitualStill?
    var sidebarInset: CGFloat = 236
    /// Centre of the sidebar's Tickets icon in window coordinates (where the stub flies).
    var ticketsIcon: CGPoint?
    var onCancel: () -> Void = {}

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focused: Bool
    @State private var stillTear = TicketTearModel()

    var body: some View {
        GeometryReader { geo in
            let s = min(1, geo.size.height / 800)
            let Wd = geo.size.width / s, Hd = geo.size.height / s
            stage(W: Wd, H: Hd, s: s)
                .frame(width: Wd, height: Hd, alignment: .topLeading)
                .scaleEffect(s, anchor: .topLeading)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
    }

    private func stage(W: CGFloat, H: CGFloat, s: CGFloat) -> some View {
        let inset = sidebarInset / s
        let cx = (inset + (W - inset - 20) / 2).rounded()
        let slotTop: CGFloat = 56, ty0 = slotTop + 14 + 6, tx0 = cx - 180
        let seed = PaperHashSeed.printer(model)
        let ms = still?.t ?? controller?.clock.elapsedMs ?? TicketPrintTimeline.totalMs
        let f = TicketPrintTimeline.frame(atMs: reduceMotion && still == nil ? TicketPrintTimeline.totalMs : ms, seed: seed)
        let phase = controller?.phase ?? (still.map { $0.tear > 0 ? .tearing : (f.isReady ? .ready : .print) } ?? .ready)
        let se = controller.map { $0.slide } ?? 0
        let ready = f.isReady || phase != .print
        let p = MRPalette.resolve(scheme)
        let pinX = inset + 26, pinY: CGFloat = 76
        let tear = controller?.tear ?? stillTear
        let tearing = tear.isDragging || tear.progress > 0.001
        let target: CGPoint = ticketsIcon.map { CGPoint(x: $0.x / s - tx0, y: $0.y / s - ty0) } ?? CGPoint(x: -142, y: -300)
        return ZStack(alignment: .topLeading) {
            TicketPrinterStage(model: model, frame: f, stage: CGSize(width: W, height: H), centerX: cx, slotTop: slotTop,
                               reduceMotion: reduceMotion, showsPass: !ready)
                .opacity(1 - se)
                .allowsHitTesting(false)

            if ready {
                TearGesture(model: model, tear: tear, flyTarget: target)
                    .rotationEffect(.degrees(f.rotationDegrees * (1 - se)), anchor: UnitPoint(x: 0.5, y: 1))
                    .scaleEffect(1 - (1 - 0.56) * se, anchor: .topLeading)
                    .offset(x: tx0 + (pinX - tx0) * se, y: ty0 + (pinY - ty0) * se)
                    .allowsHitTesting(phase == .ready || phase == .tearing)
                    .opacity(reduceMotion && still == nil && !f.isReady ? 0 : 1)
            }

            // "Tear here" pill along the perforation
            if phase == .ready && !tearing && still == nil {
                TearHint(palette: p)
                    .offset(x: tx0 - 150, y: ty0 + 450 - 17)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            // caption + actions
            ZStack {
                if phase == .print {
                    HStack(spacing: 12) {
                        Text("Printing your boarding pass").mrText(.callout).foregroundStyle(p.text2.color)
                        Text("Space to skip").font(.mr(.mono, size: 11, weight: 500)).foregroundStyle(p.text3.color)
                    }
                } else if phase == .ready && !tearing && controller != nil {
                    Button { controller?.tearNow() } label: {
                        HStack(spacing: 8) { MRIcon(.scissors, size: 16); Text("Tear"); MRKbd("Space") }
                    }
                    .buttonStyle(MRButtonStyle(.secondary))
                }
            }
            .frame(width: 360, height: 44)
            .offset(x: cx - 180, y: min(ty0 + 634, H - 54))

            if controller?.toast == true {
                HStack(spacing: 12) {
                    Circle().fill(p.ok.opacity(0.16)).frame(width: 34, height: 34)
                        .overlay(MRIcon(.check, size: 18).foregroundStyle(p.ok.color))
                    Text("Boarding complete. Have a calm flight.").font(.mr(.ui, size: 15, weight: 600)).foregroundStyle(p.text1.color)
                }
                .padding(.leading, 14).padding(.trailing, 20).padding(.vertical, 12)
                .mrGlass(cornerRadius: 22, elevation: .e3)
                .fixedSize()
                .frame(width: cx * 2, alignment: .center)
                .offset(x: 0, y: 22)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityElement(children: .combine)
            }

            if let still, still.annotate {
                RitualAnnotation(snd: "Stepper chirp ×14 (≈60 Hz gate, square) + 3–5 kHz noise tick", hap: "Trackpad tick ×14, heavier on settle",
                                 lit: Int((f.printed * 14).rounded()), palette: p)
                    .offset(x: cx + 220, y: ty0 + 60)
            }
        }
        .frame(width: W, height: H, alignment: .topLeading)
        .animation(MRMotion.smooth, value: controller?.toast)
        .contentShape(Rectangle())
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onKeyPress(.space) { handleAction() }
        .onKeyPress(.return) { handleAction() }
        .onKeyPress(.escape) { if let c = controller, c.phase == .print || c.phase == .ready { onCancel(); return .handled }; return .ignored }
        .onAppear {
            if let c = controller { c.begin(reduceMotion: reduceMotion); focused = true }
            else if let still, still.tear > 0 { stillTear.preview(progress: still.tear, grab: still.grab) }
        }
    }

    private func handleAction() -> KeyPress.Result {
        guard let c = controller else { return .ignored }
        switch c.phase {
        case .print: c.skipPrinting(); return .handled
        case .ready: c.tearNow(); return .handled
        default: return .ignored
        }
    }
}

/// The printer's rotation seed (`hash(from + to)` parity), as `TicketPrintAnimation` computes it.
enum PaperHashSeed {
    static func printer(_ m: BoardingPassModel) -> UInt32 { BoardingPassModel.designSeed(from: String(m.originCode.prefix(3)), to: String(m.destinationCode.prefix(3)), flight: "") }
}

/// `.glass.e2.rt-hint`: "Tear here" with two chevrons that slide right (1.1 s).
private struct TearHint: View {
    let palette: MRPalette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static func wave(_ t: Double, delay: Double) -> Double {
        let period = 1.1
        let raw: Double = (t - delay).truncatingRemainder(dividingBy: period)
        let u: Double = (raw < 0 ? raw + period : raw) / period
        let tri: Double = u < 0.5 ? u * 2 : (1 - u) * 2
        return tri * tri * (3 - 2 * tri)
    }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            HStack(spacing: 4) {
                Text("Tear here").font(.mr(.ui, size: 14, weight: 600))
                chev(reduceMotion ? 1 : Self.wave(t, delay: 0), 0)
                chev(reduceMotion ? 1 : Self.wave(t, delay: 0.15), -8)
            }
            .foregroundStyle(palette.text1.color)
            .padding(.horizontal, 14).frame(height: 34)
            .mrGlass(cornerRadius: 17, elevation: .e2)
        }
        .accessibilityHidden(true)
    }

    private func chev(_ w: Double, _ lead: CGFloat) -> some View {
        MRIcon(.chevR, size: 14)
            .opacity(reduceMotion ? 0.7 : 0.35 + 0.65 * w)
            .offset(x: reduceMotion ? 0 : 5 * w)
            .padding(.leading, lead)
    }
}

/// `.rt-anno`: the dashed design annotation of S13 / S14A (reference states only).
struct RitualAnnotation: View {
    let snd: String, hap: String
    let lit: Int
    let palette: MRPalette
    var body: some View {
        let p = palette
        VStack(alignment: .leading, spacing: 10) {
            row("Sound") { Text(snd) }
            row("Haptic") {
                Text(hap)
                HStack(spacing: 3) {
                    ForEach(0..<14, id: \.self) { i in
                        Circle().fill(i < lit ? p.accent1.color : p.fill3.color).frame(width: 12, height: 12)
                            .shadow(color: i < lit ? p.accent1.color : .clear, radius: 4)
                    }
                }.padding(.top, 6)
            }
            row("Native") { Text("NSHapticFeedbackManager .alignment per step; AVAudioEngine buffers synthesized offline.") }
        }
        .font(.mr(.mono, size: 11, weight: 500)).foregroundStyle(p.text2.color)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(width: 268, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(red: 6 / 255, green: 8 / 255, blue: 13 / 255).opacity(0.72)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color(red: 106 / 255, green: 183 / 255, blue: 1).opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        .accessibilityHidden(true)
    }
    private func row<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.mr(.ui, size: 10, weight: 600)).tracking(1.4).textCase(.uppercase).foregroundStyle(palette.accent1.color)
            content().lineSpacing(1.5)
        }
    }
}
