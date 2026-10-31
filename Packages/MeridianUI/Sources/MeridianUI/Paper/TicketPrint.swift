import SwiftUI
import Observation

/// Timeline of the ticket printer (C02 / T01 / R03). A pure function of time, so it can be tested and scrubbed.
///
///     0-200 ms   LED blinks (60 on / 50 off / 60 on)
///     200-1800   14 feed steps, each 114 ms = 84 ms easeOutCubic + 30 ms hold
///     1800-2100  settle: 6 pt sine bounce, +-1.5 degrees (seeded sign)
///     2100+      ready ("Tear here")
public enum TicketPrintTimeline {
    public static let steps = 14
    public static let startMs = 200.0
    public static let stepMs = 114.0
    public static let feedMs = 84.0
    public static let settleStartMs = 1800.0
    public static let readyMs = 2100.0
    public static let totalMs = 2400.0

    public struct Frame: Equatable, Sendable {
        /// Printed fraction of the pass, 0...1 (quantized into 14 stutter steps).
        public var printed: Double
        /// Index of the last feed step that started, -1 before the first.
        public var step: Int
        public var settleOffset: Double
        public var rotationDegrees: Double
        /// Opacity of the 120 pt development veil (fades out 1800-2060 ms).
        public var veilOpacity: Double
        public var ledOn: Bool
        public var glow: Double
        public var isReady: Bool
    }

    static func easeOutCubic(_ u: Double) -> Double { 1 - pow(1 - u, 3) }

    /// `seed` = `hash(from + to)`; its parity picks the rotation direction.
    public static func frame(atMs t: Double, seed: UInt32 = 0) -> Frame {
        var pf = 0.0
        var step = -1
        if t >= startMs {
            let k = Int(floor((t - startMs) / stepMs))
            step = min(steps - 1, k)
            if k >= steps { pf = 1 } else {
                let local = t - startMs - Double(k) * stepMs
                let e = local < feedMs ? easeOutCubic(local / feedMs) : 1
                pf = (Double(k) + e) / Double(steps)
            }
        }
        let u2 = max(0, min(1, (t - settleStartMs) / 300))
        let sgn: Double = seed % 2 == 1 ? 1 : -1
        let ledOn = t < startMs ? (t < 60 || (t >= 110 && t < 170)) : t < readyMs
        return Frame(printed: min(1, pf), step: step,
                     settleOffset: 6 * sin(.pi * u2) * (1 - 0.4 * u2),
                     rotationDegrees: sgn * 1.5 * easeOutCubic(u2),
                     veilOpacity: t < settleStartMs ? 1 : max(0, 1 - (t - settleStartMs) / 260),
                     ledOn: ledOn, glow: t < readyMs ? 0.5 + 0.5 * pf : 0, isReady: t >= readyMs)
    }

    /// Feed steps whose start lies in (previous, now]: for per-step sound and haptic ticks.
    public static func stepsStarted(from previousMs: Double, to nowMs: Double) -> [Int] {
        let a = frame(atMs: previousMs).step, b = frame(atMs: nowMs).step
        return b > a ? Array((a + 1)...b) : []
    }
}

/// Drives a print. `onStep(i)` fires once per feed step (0...13) for the stepper chirp and the trackpad tick,
/// `onSettle` at 1800 ms (soft tick, heavier haptic), `onReady` at 2100 ms. `skip()` jumps to the end (Space / Return).
@MainActor @Observable
public final class TicketPrintClock {
    public private(set) var elapsedMs: Double = 0
    public private(set) var isRunning = false
    @ObservationIgnored public var onStep: ((Int) -> Void)?
    @ObservationIgnored public var onSettle: (() -> Void)?
    @ObservationIgnored public var onReady: (() -> Void)?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var settled = false

    public init() {}

    public func start(reduceMotion: Bool = false) {
        task?.cancel()
        settled = false
        if reduceMotion {
            // no printer: the pass appears at rest (200 ms cross-fade is the view's job), one soft tick, no haptic steps
            elapsedMs = Self.totalMs
            isRunning = false
            onSettle?(); onReady?()
            return
        }
        elapsedMs = 0; isRunning = true
        let t0 = Date()
        task = Task { @MainActor [weak self] in
            var last = 0.0
            while let self, !Task.isCancelled, self.isRunning {
                let now = min(Self.totalMs, Date().timeIntervalSince(t0) * 1000)
                self.advance(from: last, to: now)
                last = now
                if now >= Self.totalMs { break }
                try? await Task.sleep(for: .milliseconds(8))
            }
        }
    }

    public func skip() {
        guard isRunning else { return }
        advance(from: elapsedMs, to: TicketPrintTimeline.readyMs)
        elapsedMs = Self.totalMs
        isRunning = false
        task?.cancel()
    }

    private static let totalMs = TicketPrintTimeline.totalMs

    private func advance(from a: Double, to b: Double) {
        elapsedMs = b
        for s in TicketPrintTimeline.stepsStarted(from: a, to: b) { onStep?(s) }
        if !settled, b >= TicketPrintTimeline.settleStartMs { settled = true; onSettle?() }
        if b >= TicketPrintTimeline.readyMs, isRunning, a < TicketPrintTimeline.readyMs { onReady?() }
        if b >= Self.totalMs { isRunning = false }
    }
}

/// The printer stage: housing, slit, lip, LED, vents, amber glow and the pass being pushed out (R03).
/// Transparent: draw it over the dimmed map. Coordinates follow Ritual.dc.html (`cx` = pass centre, `slotTop` = 56 default).
public struct TicketPrinterStage: View {
    let model: BoardingPassModel
    let frame: TicketPrintTimeline.Frame
    let stage: CGSize
    let cx: CGFloat
    let slotTop: CGFloat
    let reduceMotion: Bool

    public init(model: BoardingPassModel, frame: TicketPrintTimeline.Frame, stage: CGSize = CGSize(width: 1280, height: 800),
                centerX: CGFloat? = nil, slotTop: CGFloat = 56, reduceMotion: Bool = false) {
        self.model = model; self.frame = frame; self.stage = stage
        self.cx = centerX ?? stage.width / 2; self.slotTop = slotTop; self.reduceMotion = reduceMotion
    }

    private var ty0: CGFloat { slotTop + 14 + 6 }
    private var slotY: CGFloat { ty0 + 600 }

    public var body: some View {
        let pf = CGFloat(frame.printed)
        let feedY = ty0 + 600 * (1 - pf) + CGFloat(frame.settleOffset)
        ZStack(alignment: .topLeading) {
            if !reduceMotion {
                glow
                housing
                slit
            }
            // the pass: clipped at the slit's near lip while it feeds, rotating about its tail
            ticket(feedY: feedY, pf: pf)
            if !reduceMotion { lip }
        }
        .frame(width: stage.width, height: stage.height, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    private func ticket(feedY: CGFloat, pf: CGFloat) -> some View {
        let clipBottom = frame.isReady ? 0 : max(0, feedY + 600 - slotY)
        return ZStack(alignment: .topLeading) {
            PassPaper(model: model, state: .printed, side: .front)
            if frame.veilOpacity > 0 && !frame.isReady {
                Rectangle()
                    .fill(LinearGradient(colors: [Color(hex: "#F5F0E6").opacity(0), Color(red: 247 / 255, green: 226 / 255, blue: 190 / 255).opacity(0.9)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 360, height: 120).opacity(frame.veilOpacity)
                    .at(0, max(0, 600 * pf - 120))
            }
        }
        .frame(width: 360, height: 600, alignment: .topLeading)
        .shadow(color: .black.opacity(0.42), radius: (12 + 12 * pf) / 2, x: 0, y: 10 + 14 * pf)
        .mask(alignment: .topLeading) {
            Rectangle().frame(width: 480, height: 660 - clipBottom).offset(x: -60, y: -60)
        }
        .rotationEffect(.degrees(frame.rotationDegrees), anchor: UnitPoint(x: 0.5, y: 1))
        .at(cx - 180, feedY)
    }

    private var glow: some View {
        Ellipse()
            .fill(RadialGradient(colors: [Color(hex: "#FFB547").opacity(0.30 * frame.glow), .clear], center: .center, startRadius: 0, endRadius: 55))
            .frame(width: 520, height: 110)
            .at(cx - 260, slotY - 62)
    }

    private var housing: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 28, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 28)
        let h = max(70, stage.height - (slotY - 16))
        return ZStack(alignment: .topLeading) {
            shape.fill(LinearGradient(stops: [.init(color: Color(hex: "#3A4258"), location: 0), .init(color: Color(hex: "#222839"), location: 0.09),
                                              .init(color: Color(hex: "#161B29"), location: 0.38), .init(color: Color(hex: "#0F131E"), location: 1)],
                                      startPoint: .top, endPoint: .bottom))
            shape.strokeBorder(.white.opacity(0.07), lineWidth: 1)
            shape.fill(.clear).overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.3)).frame(height: 1) }.clipShape(shape)
            Circle().fill(Color(hex: frame.ledOn ? "#FFB547" : "#4A3A1E")).frame(width: 7, height: 7)
                .shadow(color: frame.ledOn ? Color(hex: "#FFB547").opacity(0.8) : .clear, radius: 4)
                .at(28, 44)
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2).fill(.black.opacity(0.55)).frame(width: 44, height: 3)
                    .shadow(color: .white.opacity(0.08), radius: 0, y: 1)
                    .at(500 - 26 - 44, CGFloat(44 + 8 * i))
            }
        }
        .frame(width: 500, height: h, alignment: .topLeading)
        .shadow(color: .black.opacity(0.5), radius: 25, y: -18)
        .at(cx - 250, slotY - 16)
    }

    private var slit: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(LinearGradient(colors: [Color(hex: "#010208"), Color(hex: "#0A0D18")], startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .top) {
                LinearGradient(colors: [.black.opacity(0.95), .clear], startPoint: .top, endPoint: .bottom).frame(height: 7)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: .white.opacity(0.16), radius: 0, y: 1)
            .frame(width: 428, height: 12)
            .at(cx - 214, slotY - 8)
    }

    private var lip: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 9, bottomTrailingRadius: 9, topTrailingRadius: 0)
        return shape.fill(LinearGradient(colors: [Color(hex: "#434B63"), Color(hex: "#252C3F")], startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.18)).frame(height: 1) }
            .clipShape(shape)
            .shadow(color: .black.opacity(0.5), radius: 6, y: 5)
            .frame(width: 428, height: 10)
            .at(cx - 214, slotY)
    }
}

/// Stage + clock in one view. Create a `TicketPrintClock`, set its callbacks (sound, haptics), call `start()`.
public struct TicketPrintAnimation: View {
    let model: BoardingPassModel
    let clock: TicketPrintClock
    let stage: CGSize
    let centerX: CGFloat?
    let slotTop: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: BoardingPassModel, clock: TicketPrintClock, stage: CGSize = CGSize(width: 1280, height: 800),
                centerX: CGFloat? = nil, slotTop: CGFloat = 56) {
        self.model = model; self.clock = clock; self.stage = stage; self.centerX = centerX; self.slotTop = slotTop
    }

    public var body: some View {
        let seed = PaperHash.fnv1a(model.originCode + model.destinationCode)
        TicketPrinterStage(model: model, frame: TicketPrintTimeline.frame(atMs: clock.elapsedMs, seed: seed), stage: stage,
                           centerX: centerX, slotTop: slotTop, reduceMotion: reduceMotion)
            .opacity(reduceMotion ? (clock.elapsedMs >= TicketPrintTimeline.totalMs ? 1 : 0) : 1)
            .animation(reduceMotion ? .easeOut(duration: 0.2) : nil, value: clock.elapsedMs >= TicketPrintTimeline.totalMs)
            .onAppear { if !clock.isRunning && clock.elapsedMs == 0 { clock.start(reduceMotion: reduceMotion) } }
            .onKeyPress(.space) { clock.skip(); return .handled }
            .onKeyPress(.return) { clock.skip(); return .handled }
    }
}
