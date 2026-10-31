import SwiftUI
import Observation

public enum TearGrabSide: Sendable { case left, right }

/// Geometry of a partial tear (Ritual.dc.html `renderVals`). All coordinates are in the 360 x 600 pass space.
public enum TicketTearGeometry {
    public struct Cut: Sendable {
        public var front: CGPoint          // tear front (xf, yf)
        public var body: [CGPoint]         // polygon that stays on the pass
        public var piece: [CGPoint]        // polygon of the torn-away stub
        public var rim: [CGPoint]          // fibrous rim along the new edge (y + .6)
    }

    /// Seeded tear line, closed with (0, 450) when the last point misses x = 0.
    static func line(seed: UInt64) -> [CGPoint] {
        var pts = TornEdge.polyline(seed: seed)
        if let l = pts.last, l.x > 0 { pts.append(CGPoint(x: 0, y: 450)) }
        return pts
    }

    static func yAt(_ pts: [CGPoint], x: CGFloat) -> CGFloat {
        for i in 0..<(pts.count - 1) {
            let a = pts[i], b = pts[i + 1]
            if x <= a.x && x >= b.x {
                let f = a.x == b.x ? 0 : (a.x - x) / (a.x - b.x)
                return a.y + (b.y - a.y) * f
            }
        }
        return 450
    }

    /// Front position: `x_f = 360 (1 - p)` pulling from the right, `360 p` from the left.
    public static func frontX(progress p: Double, grab: TearGrabSide) -> CGFloat { grab == .right ? 360 * (1 - p) : 360 * p }

    public static func cut(seed: UInt64, progress p: Double, grab: TearGrabSide) -> Cut {
        let pts = line(seed: seed)
        let xf = frontX(progress: p, grab: grab), yf = yAt(pts, x: xf)
        let zone = pts.filter { grab == .right ? $0.x >= xf : $0.x <= xf }
        let front = CGPoint(x: xf, y: yf)
        let body: [CGPoint], piece: [CGPoint]
        if grab == .right {
            body = [CGPoint(x: 0, y: 0), CGPoint(x: 360, y: 0)] + zone + [front, CGPoint(x: xf, y: 600), CGPoint(x: 0, y: 600)]
            piece = [front] + zone.reversed() + [CGPoint(x: 360, y: 600), CGPoint(x: xf, y: 600)]
        } else {
            body = [CGPoint(x: 0, y: 0), CGPoint(x: 360, y: 0), CGPoint(x: 360, y: 600), CGPoint(x: xf, y: 600), front] + zone
            // the canvas starts this polygon at (0, 0), which would carry the top-left of the pass along; start on the tear line
            piece = zone.reversed() + [front, CGPoint(x: xf, y: 600), CGPoint(x: 0, y: 600)]
        }
        return Cut(front: front, body: body, piece: piece, rim: ([front] + zone).map { CGPoint(x: $0.x, y: $0.y + 0.6) })
    }

    /// Pose of the attached stub while it is dragged: rotation about the front, drift and drop.
    public static func piecePose(progress p: Double, grab: TearGrabSide, dy: CGFloat) -> (degrees: Double, dx: CGFloat, dy: CGFloat) {
        let s: Double = grab == .right ? 1 : -1
        return (s * TearState.stubAngle(atProgress: p), CGFloat(s) * CGFloat(p) * 14, 4 + CGFloat(p) * 22 + dy * 0.5)
    }
}

public struct TearParticle: Sendable, Equatable {
    var x: Double, y: Double, vx: Double, vy: Double, r: Double, vr: Double, size: Double, alpha: Double
    /// One physics step: gravity 900 pt/s2, fades over 0.9 s.
    mutating func step(_ dtMs: Double) {
        let dt = dtMs / 1000
        x += vx * dt; y += vy * dt; vy += 900 * dt; r += vr * dt; alpha -= dtMs / 900
    }
    static func burst(at x: Double, grab: TearGrabSide, random: () -> Double) -> [TearParticle] {
        let n = 3 + Int(random() * 4)
        return (0..<n).map { _ in
            TearParticle(x: x, y: 450, vx: (random() - 0.5) * 90 + (grab == .right ? 30 : -30), vy: -40 - random() * 90,
                         r: random() * 360, vr: (random() - 0.5) * 600, size: 1 + random() * 2, alpha: 1)
        }
    }
}

public enum TearPhase: Sendable, Equatable { case ready, dragging, finishing, flying, done }

/// State machine behind `TearGesture`. Everything the sound/haptic code needs is a closure:
/// - `onBegin`: pointer down (start the rip noise, gated at 0)
/// - `onTick(n)`: haptic tick, every 6 % of progress
/// - `onVelocity(v)`: smoothed pointer speed 0...1 for the rip sound (0 when the pointer rests)
/// - `onFinish`: the auto-finish starts (>= 72 %): rip accelerates
/// - `onRelease(progress)`: released below 72 %, the partial tear stays
/// - `onTorn`: the stub left (heavy release tick, 150 Hz thump when the fly ends)
@MainActor @Observable
public final class TicketTearModel {
    public private(set) var state = TearState()
    public private(set) var grab: TearGrabSide = .right
    public private(set) var phase: TearPhase = .ready
    public private(set) var dy: CGFloat = 0
    public private(set) var velocity: Double = 0
    public private(set) var flyProgress: Double = 0
    public private(set) var particles: [TearParticle] = []
    public private(set) var isDragging = false

    @ObservationIgnored public var onBegin: (() -> Void)?
    @ObservationIgnored public var onTick: ((Int) -> Void)?
    @ObservationIgnored public var onVelocity: ((Double) -> Void)?
    @ObservationIgnored public var onFinish: (() -> Void)?
    @ObservationIgnored public var onRelease: ((Double) -> Void)?
    @ObservationIgnored public var onTorn: (() -> Void)?
    @ObservationIgnored public var onFlyEnd: (() -> Void)?

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var startX: CGFloat = 0
    @ObservationIgnored private var startY: CGFloat = 0
    @ObservationIgnored private var startRaw = 0.0
    @ObservationIgnored private var lastX: CGFloat = 0
    @ObservationIgnored private var lastT = Date()
    @ObservationIgnored private var lastMove = Date()
    @ObservationIgnored private var rng = PaperRandom(seed: 99)

    public init() {}

    public var progress: Double { state.progress }

    /// Static pose for previews, snapshots and design comparison (no animation, no callbacks).
    public func preview(progress: Double, grab: TearGrabSide = .right, flyProgress: Double = 0) {
        task?.cancel()
        self.grab = grab
        state = TearState(); state.drag(to: TearState.rawDrag(forProgress: progress))
        self.flyProgress = flyProgress
        if flyProgress > 0 { state.complete(); phase = flyProgress >= 1 ? .done : .flying } else { phase = progress > 0 ? .dragging : .ready }
    }

    public func reset() {
        task?.cancel(); state = TearState(); phase = .ready; dy = 0; velocity = 0; flyProgress = 0; particles = []; isDragging = false
    }

    // MARK: drag

    public func begin(x: CGFloat, y: CGFloat) {
        guard phase == .ready || phase == .dragging else { return }
        if state.progress < 0.001 { grab = x < 180 ? .left : .right }
        startX = x; startY = y; startRaw = state.raw; lastX = x; lastT = Date(); lastMove = Date(); velocity = 0
        isDragging = true; phase = .dragging
        onBegin?()
        startLoop()
    }

    public func move(x: CGFloat, y: CGFloat) {
        guard isDragging, phase == .dragging else { return }
        let now = Date()
        velocity = TearState.smoothedVelocity(previous: velocity, dx: Double(x - lastX), dtMs: now.timeIntervalSince(lastT) * 1000)
        lastMove = now; lastX = x; lastT = now
        let delta = Double(grab == .left ? x - startX : startX - x) / 360
        let before = state.progress
        let ticks = state.drag(to: startRaw + delta)
        dy = max(-6, min(46, (y - startY) * 0.6))
        if ticks > 0, state.progress > 0 { onTick?(ticks) }
        onVelocity?(velocity)
        if Int(state.progress * 33) != Int(before * 33), state.progress > 0.1 { spawn() }
        if state.hasPassedThreshold { isDragging = false; finishAuto(duration: 0.26, curve: { $0 * $0 }) }
    }

    public func end() {
        guard isDragging else { return }
        isDragging = false; velocity = 0; dy = 0
        onVelocity?(0)
        if phase == .dragging { phase = .ready; onRelease?(state.progress) }
    }

    // MARK: button, Space/Return, VoiceOver

    /// The visible "Tear" button path: accelerating rip over 650 ms, then the same finish as a drag.
    public func tearWithButton(reduceMotion: Bool = false) {
        guard phase == .ready || phase == .dragging else { return }
        isDragging = false
        if reduceMotion { state.complete(); onFinish?(); phase = .flying; flyProgress = 0.999; startFly(); return }
        finishAuto(duration: 0.65, curve: { $0 * $0 * 0.6 + $0 * 0.4 })
    }

    private func finishAuto(duration: Double, curve: @escaping (Double) -> Double) {
        phase = .finishing
        onFinish?()
        let p0 = state.progress, t0 = Date()
        task?.cancel()
        task = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                let u = min(1, Date().timeIntervalSince(t0) / duration)
                let p = p0 + (1 - p0) * curve(u)
                self.state.drag(to: TearState.rawDrag(forProgress: p))
                self.velocity = 0.6 + u * 0.4
                self.onVelocity?(self.velocity)
                if self.rng.next() < 0.5 { self.spawn() }
                self.stepParticles(8)
                if u >= 1 { break }
                try? await Task.sleep(for: .milliseconds(8))
            }
            guard let self, !Task.isCancelled else { return }
            self.state.complete()
            self.velocity = 0; self.onVelocity?(0)
            self.onTorn?()
            self.phase = .flying
            self.startFly()
        }
    }

    private func startFly() {
        task?.cancel()
        let t0 = Date()
        flyProgress = flyProgress > 0.99 ? 0.999 : 0
        task = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                let u = flyProgressNow(t0)
                self.flyProgress = u
                self.stepParticles(8)
                if u >= 1 { break }
                try? await Task.sleep(for: .milliseconds(8))
            }
            guard let self, !Task.isCancelled else { return }
            self.phase = .done
            self.onFlyEnd?()
        }
    }

    // MARK: loop (velocity decay, particles)

    private func startLoop() {
        task?.cancel()
        task = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled, self.phase == .dragging || !self.particles.isEmpty {
                if self.isDragging {
                    let idle = Date().timeIntervalSince(self.lastMove) * 1000
                    let v = TearState.decayedVelocity(self.velocity, idleMs: idle)
                    if v != self.velocity { self.velocity = v; self.onVelocity?(v) }
                }
                self.stepParticles(16)
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    private func spawn() {
        let xf = Double(TicketTearGeometry.frontX(progress: state.progress, grab: grab))
        particles = Array((particles + TearParticle.burst(at: xf, grab: grab, random: { rng.next() })).suffix(28))
    }

    private func stepParticles(_ ms: Double) {
        guard !particles.isEmpty else { return }
        for i in particles.indices { particles[i].step(ms) }
        particles.removeAll { $0.alpha <= 0 }
    }
}

private func flyProgressNow(_ t0: Date) -> Double { min(1, Date().timeIntervalSince(t0) / 0.72) }

// MARK: - View

/// The interactive tear-off: grab the stub, pull along the perforation, past 72 % it finishes itself and flies to `flyTarget`
/// (pass-local coordinates; default is 142 pt left of and 300 pt above the pass, where the sidebar's Wallet icon sits in the printing screen).
/// Keyboard: Space / Return tears. VoiceOver: custom action "Tear off the stub". Reduce Motion: no fly, quick fade.
public struct TearGesture: View {
    let model: BoardingPassModel
    let tear: TicketTearModel
    let flyTarget: CGPoint
    let showHint: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focused: Bool

    public init(model: BoardingPassModel, tear: TicketTearModel, flyTarget: CGPoint = CGPoint(x: -142, y: -300), showHint: Bool = true) {
        self.model = model; self.tear = tear; self.flyTarget = flyTarget; self.showHint = showHint
    }

    public var body: some View {
        let p = tear.progress
        let grab = tear.grab
        let done = tear.phase == .flying || tear.phase == .done
        let cut = TicketTearGeometry.cut(seed: model.seed, progress: p, grab: grab)
        let pose = TicketTearGeometry.piecePose(progress: p, grab: grab, dy: tear.dy)
        let tension: CGFloat = tear.isDragging ? (grab == .right ? -1 : 1) * 1.5 * CGFloat(min(1, p * 4)) : 0
        ZStack(alignment: .topLeading) {
            if done {
                PassPaper(model: model, state: .torn, side: .front)
                    .shadow(color: .black.opacity(0.42), radius: 12, y: 24)
            } else {
                ZStack(alignment: .topLeading) {
                    PassPaper(model: model, state: .printed, side: .front)
                        .mask(PolygonShape(points: p > 0.002 ? cut.body : [CGPoint(x: -20, y: -20), CGPoint(x: 400, y: -20), CGPoint(x: 400, y: 700), CGPoint(x: -20, y: 700)]))
                    if p > 0.002 { Rim(points: cut.rim) }
                }
                .shadow(color: .black.opacity(0.42), radius: 12 + 12 * 0, y: 24)
                .offset(x: reduceMotion ? 0 : tension)
                if p > 0.002 { piece(cut: cut, pose: pose) }
                if p < 0.002 && showHint && tear.phase == .ready { PerforationGlow() }
            }
            particles
        }
        .frame(width: 360, height: 600, alignment: .topLeading)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { g in
                guard g.startLocation.y >= 450 || tear.progress > 0 else { return }
                if !tear.isDragging { tear.begin(x: g.startLocation.x, y: g.startLocation.y) }
                tear.move(x: g.location.x, y: g.location.y)
            }
            .onEnded { _ in tear.end() })
        .onHover { inside in
            #if os(macOS)
            if inside && tear.phase == .ready { NSCursor.openHand.set() } else { NSCursor.arrow.set() }
            #endif
        }
        .focusable().focused($focused)
        .onKeyPress(.space) { tear.tearWithButton(reduceMotion: reduceMotion); return .handled }
        .onKeyPress(.return) { tear.tearWithButton(reduceMotion: reduceMotion); return .handled }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Boarding pass printed. Stub, seat \(model.seat). Drag, or press Return, to tear.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Tear off the stub") { tear.tearWithButton(reduceMotion: reduceMotion) }
    }

    @ViewBuilder private func piece(cut: TicketTearGeometry.Cut, pose: (degrees: Double, dx: CGFloat, dy: CGFloat)) -> some View {
        let flying = tear.phase == .flying || tear.phase == .done
        let u = tear.flyProgress
        let s: CGFloat = tear.grab == .right ? 1 : -1
        let content = ZStack(alignment: .topLeading) {
            PassPaper(model: model, state: .printed, side: .front)
                .mask(PolygonShape(points: cut.piece))
            // curl shade next to the front
            Rectangle()
                .fill(LinearGradient(colors: [Color(red: 60 / 255, green: 48 / 255, blue: 30 / 255).opacity(0.26), .clear],
                                     startPoint: tear.grab == .right ? .leading : .trailing, endPoint: tear.grab == .right ? .trailing : .leading))
                .frame(width: 46, height: 150)
                .at(tear.grab == .right ? cut.front.x : cut.front.x - 46, 450)
                .mask(PolygonShape(points: cut.piece))
            Rim(points: cut.rim, opacity: 0.9)
        }
        .frame(width: 360, height: 600, alignment: .topLeading)
        .shadow(color: .black.opacity(0.45), radius: (8 + CGFloat(tear.progress) * 10) / 2, y: 6 + CGFloat(tear.progress) * 12)
        if flying {
            let th = 25.0 * Double(s)
            let c = CGPoint(x: 180, y: 525)
            let rc = rotate(c, about: CGPoint(x: tear.grab == .right ? 0 : 360, y: 450), degrees: th)
            let d0 = CGPoint(x: rc.x - c.x + s * 14, y: rc.y - c.y + 26)
            let p0 = CGPoint(x: rc.x + s * 14, y: rc.y + 26)
            let ctl = CGPoint(x: (p0.x + flyTarget.x) / 2 + 40, y: min(p0.y, flyTarget.y) - 150)
            let uu = CGFloat(max(0, min(1, u)))
            let w0: CGFloat = (1 - uu) * (1 - uu), w1: CGFloat = 2 * (1 - uu) * uu, w2: CGFloat = uu * uu
            let bx: CGFloat = w0 * p0.x + w1 * ctl.x + w2 * flyTarget.x
            let by: CGFloat = w0 * p0.y + w1 * ctl.y + w2 * flyTarget.y
            let b = CGPoint(x: bx, y: by)
            let e = uu * uu * (3 - 2 * uu), sc = 1 - 0.9 * pow(uu, 1.1)
            content
                .scaleEffect(reduceMotion ? 1 : sc, anchor: UnitPoint(x: 0.5, y: 525 / 600))
                .rotationEffect(.degrees(th + Double(s) * 320 * Double(e)), anchor: UnitPoint(x: 0.5, y: 525 / 600))
                .offset(x: d0.x + b.x - p0.x, y: d0.y + b.y - p0.y)
                .opacity(reduceMotion ? Double(1 - uu) : (uu > 0.86 ? max(0, 1 - Double(uu - 0.86) / 0.14) : 1))
        } else {
            content
                .rotationEffect(.degrees(reduceMotion ? 0 : pose.degrees), anchor: UnitPoint(x: cut.front.x / 360, y: 450 / 600))
                .offset(x: reduceMotion ? 0 : pose.dx, y: reduceMotion ? 0 : pose.dy)
        }
    }

    private func rotate(_ p: CGPoint, about h: CGPoint, degrees: Double) -> CGPoint {
        let a = degrees * .pi / 180
        let dx = p.x - h.x, dy = p.y - h.y
        return CGPoint(x: dx * cos(a) - dy * sin(a) + h.x, y: dx * sin(a) + dy * cos(a) + h.y)
    }

    private var particles: some View {
        Canvas { ctx, _ in
            for q in tear.particles where q.alpha > 0 {
                var c = ctx
                c.translateBy(x: q.x, y: q.y); c.rotate(by: .degrees(q.r))
                c.fill(Path(CGRect(x: 0, y: 0, width: q.size, height: q.size * 0.7)), with: .color(Color(hex: "#EFE7D4").opacity(max(0, q.alpha))))
            }
        }
        .frame(width: 360, height: 600).allowsHitTesting(false)
    }
}

struct PolygonShape: Shape {
    var points: [CGPoint]
    func path(in rect: CGRect) -> Path {
        var p = Path(); p.addLines(points); p.closeSubpath(); return p
    }
}

private struct Rim: View {
    var points: [CGPoint]
    var opacity = 0.85
    var body: some View {
        Path { p in p.addLines(points) }
            .stroke(.white.opacity(opacity), style: StrokeStyle(lineWidth: 1.1, lineJoin: .round))
            .allowsHitTesting(false)
    }
}

/// `rt-perf`: the perforation glows while the pass waits to be torn.
private struct PerforationGlow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.6) / 1.6
            let tri = t < 0.5 ? t * 2 : (1 - t) * 2
            let o = reduceMotion ? 0.7 : 0.35 + 0.65 * (tri * tri * (3 - 2 * tri))
            Rectangle()
                .fill(LinearGradient(colors: [.clear, Color(hex: "#6AB7FF"), .clear], startPoint: .leading, endPoint: .trailing))
                .frame(width: 332, height: 2)
                .shadow(color: Color(hex: "#6AB7FF").opacity(0.55), radius: 6)
                .opacity(o)
                .at(14, 449)
        }
        .allowsHitTesting(false)
    }
}

#if os(macOS)
import AppKit
#endif

/// Trackpad haptics and sounds are the caller's business; this is the macOS haptic the design names (`.alignment`).
public enum PaperHaptics {
    @MainActor public static func tick() {
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        #endif
    }
    @MainActor public static func release() {
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        #endif
    }
}
