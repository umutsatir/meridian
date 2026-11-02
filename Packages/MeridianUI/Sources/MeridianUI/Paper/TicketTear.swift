import SwiftUI
import Observation

public enum TearGrabSide: Sendable { case left, right }

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
/// - `onBridges(n)`: n perforation bridges broke since the last call (the "tak" of the tear; fires while dragging and during the auto-finish)
/// - `onVelocity(v)`: smoothed pointer speed 0...1 for the rip sound (0 when the pointer rests)
/// - `onFinish`: the auto-finish starts (>= 55 % or a fast flick): the remaining bridges give way in one stroke
/// - `onRelease(progress)`: released below the threshold, the partial tear stays
/// - `onTorn`: the stub came free (separation sound, heavy release tick); the fly starts, 150 Hz thump when it lands
@MainActor @Observable
public final class TicketTearModel {
    public private(set) var state = TearState()
    public private(set) var grab: TearGrabSide = .right
    public private(set) var phase: TearPhase = .ready
    public private(set) var dy: CGFloat = 0
    /// Extra swing of the stub in degrees from the vertical pointer offset (positive = pulled down).
    public private(set) var pullAngle: Double = 0
    public private(set) var velocity: Double = 0
    public private(set) var flyProgress: Double = 0
    public private(set) var particles: [TearParticle] = []
    public private(set) var isDragging = false

    @ObservationIgnored public var onBegin: (() -> Void)?
    @ObservationIgnored public var onTick: ((Int) -> Void)?
    @ObservationIgnored public var onBridges: ((Int) -> Void)?
    @ObservationIgnored public var onVelocity: ((Double) -> Void)?
    @ObservationIgnored public var onFinish: (() -> Void)?
    @ObservationIgnored public var onRelease: ((Double) -> Void)?
    @ObservationIgnored public var onTorn: (() -> Void)?
    @ObservationIgnored public var onFlyEnd: (() -> Void)?

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var startX: CGFloat = 0
    @ObservationIgnored private var startY: CGFloat = 0
    @ObservationIgnored private var startRaw = 0.0
    /// The tear runs the way the pointer is dragged: the side is chosen from the first horizontal movement,
    /// not from where the stub was grabbed. A partial tear keeps its side.
    @ObservationIgnored private var directionLocked = false
    @ObservationIgnored private static let directionDeadZone: CGFloat = 5
    @ObservationIgnored private var lastX: CGFloat = 0
    @ObservationIgnored private var lastT = Date()
    @ObservationIgnored private var lastMove = Date()
    @ObservationIgnored private var rng = PaperRandom(seed: 99)
    @ObservationIgnored private var bridgesSeen = 0
    @ObservationIgnored private var beganAt = Date()
    /// Smoothed speed (0...1) above which a pull past `flickProgress` finishes by itself ("one stroke").
    @ObservationIgnored static let flickVelocity = 0.62
    @ObservationIgnored static let flickProgress = 0.15

    public init() {}

    public var progress: Double { state.progress }

    /// Bridges broken at the current front.
    public var bridgeCount: Int {
        state.isTorn ? PerforationEdge.bridgeCenters.count : PerforationEdge.brokenCount(frontX: TicketTearGeometry.frontX(progress: state.progress, grab: grab), grab: grab)
    }

    private func emitBridges() {
        let n = bridgeCount
        if n > bridgesSeen { onBridges?(n - bridgesSeen) }
        bridgesSeen = n
    }

    /// Static pose for previews, snapshots and design comparison (no animation, no callbacks).
    public func preview(progress: Double, grab: TearGrabSide = .right, flyProgress: Double = 0) {
        task?.cancel()
        self.grab = grab
        state = TearState(); state.drag(to: TearState.rawDrag(forProgress: progress)); bridgesSeen = bridgeCount
        self.flyProgress = flyProgress
        if flyProgress > 0 { state.complete(); phase = flyProgress >= 1 ? .done : .flying } else { phase = progress > 0 ? .dragging : .ready }
    }

    public func reset() {
        task?.cancel(); state = TearState(); phase = .ready; dy = 0; pullAngle = 0; velocity = 0; flyProgress = 0; particles = []; isDragging = false; directionLocked = false; bridgesSeen = 0
    }

    // MARK: drag

    public func begin(x: CGFloat, y: CGFloat) {
        guard phase == .ready || phase == .dragging else { return }
        directionLocked = state.progress >= 0.001
        startX = x; startY = y; startRaw = state.raw; lastX = x; lastT = Date(); lastMove = Date(); beganAt = Date(); velocity = 0
        isDragging = true; phase = .dragging
        onBegin?()
        startLoop()
    }

    public func move(x: CGFloat, y: CGFloat) {
        guard isDragging, phase == .dragging else { return }
        let now = Date()
        velocity = TearState.smoothedVelocity(previous: velocity, dx: Double(x - lastX), dtMs: now.timeIntervalSince(lastT) * 1000)
        lastMove = now; lastX = x; lastT = now
        dy = max(-6, min(46, (y - startY) * 0.6))
        pullAngle = max(-6, min(12, Double(y - startY) * 0.1))
        if !directionLocked {
            let ddx = x - startX
            guard abs(ddx) >= Self.directionDeadZone else { onVelocity?(velocity); return }
            grab = ddx < 0 ? .right : .left
            directionLocked = true
            startRaw = state.raw
        }
        let delta = Double(grab == .left ? x - startX : startX - x) / TearState.dragSpan
        let before = state.progress
        let ticks = state.drag(to: startRaw + delta)
        if ticks > 0, state.progress > 0 { onTick?(ticks) }
        onVelocity?(velocity)
        if Int(state.progress * 33) != Int(before * 33), state.progress > 0.1 { spawn() }
        emitBridges()
        if state.hasPassedThreshold { isDragging = false; finishAuto(duration: 0.2, curve: { $0 * $0 }) }
        else if isFlick(velocity) { isDragging = false; finishAuto(duration: 0.14, curve: { $0 }) }
    }

    private func isFlick(_ v: Double) -> Bool {
        v >= Self.flickVelocity && state.progress >= Self.flickProgress && Date().timeIntervalSince(beganAt) > 0.05
    }

    public func end() {
        guard isDragging else { return }
        let v = velocity
        isDragging = false; velocity = 0; dy = 0; pullAngle = 0
        onVelocity?(0)
        if phase == .dragging, isFlick(v) { finishAuto(duration: 0.14, curve: { $0 }); return }
        if phase == .dragging { phase = .ready; onRelease?(state.progress) }
    }

    // MARK: button, Space/Return, VoiceOver

    /// The visible "Tear" button path: accelerating rip over 650 ms, then the same finish as a drag.
    public func tearWithButton(reduceMotion: Bool = false) {
        guard phase == .ready || phase == .dragging else { return }
        isDragging = false
        if reduceMotion { state.complete(); emitBridges(); onFinish?(); phase = .flying; flyProgress = 0.999; startFly(); return }
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
                self.emitBridges()
                if self.rng.next() < 0.5 { self.spawn() }
                self.stepParticles(8)
                if u >= 1 { break }
                try? await Task.sleep(for: .milliseconds(8))
            }
            guard let self, !Task.isCancelled else { return }
            self.state.complete()
            self.emitBridges()
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

/// The freed stub flies to the wallet over this long (seconds).
let tearFlyDuration = 0.82
private func flyProgressNow(_ t0: Date) -> Double { min(1, Date().timeIntervalSince(t0) / tearFlyDuration) }

// MARK: - View

/// The interactive tear-off: grab the stub and pull; the tear runs the way you drag (left or right along the perforation), the bridges of the
/// perforation give way one by one, past 55 % (or on a quick flick) it finishes itself and the freed stub flies to `flyTarget`
/// (pass-local coordinates; default is 142 pt left of and 300 pt above the pass, where the sidebar's Wallet icon sits in the printing screen).
/// Keyboard: Space / Return tears. VoiceOver: custom action "Tear off the stub". Reduce Motion: no bend, no fly, quick fade.
///
/// Drawing: the printed pass is rasterised once; the body is that raster clipped above the perforation, the stub is the same raster sliced
/// into 3 pt strips that are bent about the tear front (paper curl with a shade that follows the curvature).
public struct TearGesture: View {
    let model: BoardingPassModel
    let tear: TicketTearModel
    let flyTarget: CGPoint
    let showHint: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focused: Bool
    @State private var raster: CGImage?

    private static let canvasOrigin = CGPoint(x: 160, y: 160)
    private static let canvasSize = CGSize(width: 680, height: 1250)

    public init(model: BoardingPassModel, tear: TicketTearModel, flyTarget: CGPoint = CGPoint(x: -142, y: -300), showHint: Bool = true) {
        self.model = model; self.tear = tear; self.flyTarget = flyTarget; self.showHint = showHint
    }

    public var body: some View {
        let p = tear.progress
        let grab = tear.grab
        let done = tear.phase == .flying || tear.phase == .done
        let tension: CGFloat = tear.isDragging ? (grab == .right ? -1 : 1) * 1.5 * CGFloat(min(1, p * 4)) : 0
        ZStack(alignment: .topLeading) {
            if done {
                PassPaper(model: model, state: .torn, side: .front)
                    .shadow(color: .black.opacity(0.42), radius: 12, y: 24)
                if tear.flyProgress < 1 { flyingStub() }
            } else if p > 0.002, let raster {
                tornPass(raster)
                    .offset(x: reduceMotion ? 0 : tension)
            } else {
                PassPaper(model: model, state: .printed, side: .front)
                    .shadow(color: .black.opacity(0.42), radius: 12, y: 24)
                    .offset(x: reduceMotion ? 0 : tension)
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
        .onAppear { if raster == nil { raster = Self.rasterise(model) } }
        .focusable().focused($focused)
        .onKeyPress(.space) { tear.tearWithButton(reduceMotion: reduceMotion); return .handled }
        .onKeyPress(.return) { tear.tearWithButton(reduceMotion: reduceMotion); return .handled }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.accessibilityDescription(canTear: true))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Tear off the stub") { tear.tearWithButton(reduceMotion: reduceMotion) }
    }

    @MainActor private static func rasterise(_ model: BoardingPassModel) -> CGImage? {
        let r = ImageRenderer(content: PassPaper(model: model, state: .printed, side: .front).frame(width: 360, height: 600))
        r.scale = 3
        return r.cgImage
    }

    // MARK: pose

    /// Hinge angle (degrees) while the stub is dragged.
    private func hingeAngle() -> Double {
        if reduceMotion { return 0 }
        let pose = TicketTearGeometry.piecePose(progress: tear.progress, grab: tear.grab, dy: tear.dy, pull: tear.pullAngle)
        return min(30, abs(pose.degrees) * 0.7)
    }

    private func canvasPlacement<Content: View>(_ v: Content) -> some View {
        v.frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
            .offset(x: -Self.canvasOrigin.x, y: -Self.canvasOrigin.y)
            .allowsHitTesting(false)
    }

    // MARK: pass while it is being torn

    private func tornPass(_ cg: CGImage) -> some View {
        let p = tear.progress, grab = tear.grab
        let edges = PerforationEdge(seed: model.seed)
        let cut = TicketTearGeometry.cut(edges: edges, progress: p, grab: grab)
        let n = cut.brokenBridges
        let front = PerforationEdge.quantizedFront(frontX: TicketTearGeometry.frontX(progress: p, grab: grab), grab: grab)
        let hinge = n == 0 || reduceMotion ? 0 : hingeAngle() + 4 * min(1, Double(n) / 3)   // the first bridges open the gap at once
        let curl = n == 0 || reduceMotion ? 0 : 10 * min(1, p * 3) + tear.pullAngle * 0.6
        let pose = TearRender.pose(edges: edges, front: front, grab: grab, hinge: hinge, curl: curl)
        let strips = pose.strips
        let img = Image(decorative: cg, scale: 3)
        let o = Self.canvasOrigin
        let fibres = TearRender.fibres(edges: edges, front: front, grab: grab, seed: model.seed)
        return ZStack(alignment: .topLeading) {
            canvasPlacement(Canvas { ctx, _ in
                var c = ctx; c.translateBy(x: o.x, y: o.y)
                // one drop shadow for everything that is still flat; the freed part lifts, so its shadow is longer and softer
                c.drawLayer { l in
                    l.addFilter(.shadow(color: .black.opacity(0.42), radius: 12, x: 0, y: 24, options: .shadowOnly))
                    var sil = TearRender.polygon(cut.body)
                    sil.addPath(TearRender.silhouette(strips, free: false))
                    l.fill(sil, with: .color(.black))
                }
                if n > 0 {
                    c.drawLayer { l in
                        l.addFilter(.shadow(color: .black.opacity(0.34), radius: 8 + 10 * p, x: 0, y: 14 + 22 * p, options: .shadowOnly))
                        l.fill(TearRender.silhouette(strips, free: true), with: .color(.black))
                    }
                }
            })
            canvasPlacement(Canvas { ctx, _ in
                var c = ctx; c.translateBy(x: o.x, y: o.y)
                TearRender.drawStub(c, image: img, strips: strips, shadowOnAttached: n > 0)
            })
            canvasPlacement(Canvas { ctx, _ in
                var c = ctx; c.translateBy(x: o.x, y: o.y)
                let rs = c.resolve(img)
                c.drawLayer { l in
                    l.clip(to: TearRender.polygon(cut.body))
                    l.draw(rs, in: CGRect(x: 0, y: 0, width: 360, height: 600))
                }
                if cut.rim.count > 1 {
                    var rim = Path(); rim.addLines(cut.rim.filter { $0.x > 14 && $0.x < 346 })
                    c.stroke(rim, with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: 1.0, lineJoin: .round))
                    c.stroke(fibres, with: .color(.white.opacity(0.75)), style: StrokeStyle(lineWidth: 0.5, lineCap: .round))
                }
            })
        }
        .frame(width: 360, height: 600, alignment: .topLeading)
    }

    // MARK: the freed stub

    /// Curl and bend of the stub in flight, from the pose it had when the last bridge gave way.
    private func flightFrame(u: Double) -> StubPoseInfo {
        let edges = PerforationEdge(seed: model.seed)
        let end = reduceMotion ? 0 : hingeAngle()
        let uu = min(1, max(0, u))
        let relax = 1 - pow(min(1, uu / 0.4), 0.8)
        let hinge = end * relax
        let curl = reduceMotion ? 0 : 26 * sin(min(1, uu / 0.8) * .pi) * (1 - 0.3 * uu) + 7 * sin(uu * 17) * (1 - uu)
        let f: CGFloat = tear.grab == .right ? 0 : 360
        return TearRender.pose(edges: edges, front: f, grab: tear.grab, hinge: hinge, curl: curl, bendLength: 0)
    }

    @ViewBuilder private func flyingStub() -> some View {
        if let raster {
            let s: CGFloat = tear.grab == .right ? 1 : -1
            let u = tear.flyProgress
            let uu = CGFloat(max(0, min(1, u)))
            let info = flightFrame(u: u)
            let img = Image(decorative: raster, scale: 3)
            let o = Self.canvasOrigin
            let c0 = info.center
            let anchor = UnitPoint(x: c0.x / 360, y: c0.y / 600)
            // path: quadratic arc from where the stub hangs to the wallet, a small hop at the release and a sideways drift
            let ctl = CGPoint(x: (c0.x + flyTarget.x) / 2 + 40 * s, y: min(c0.y, flyTarget.y) - 170)
            let tb = uu * uu * (3 - 2 * uu) * 0.5 + uu * 0.5   // eases out of the release, then keeps moving
            let w0 = (1 - tb) * (1 - tb), w1 = 2 * (1 - tb) * tb, w2 = tb * tb
            let b = CGPoint(x: w0 * c0.x + w1 * ctl.x + w2 * flyTarget.x, y: w0 * c0.y + w1 * ctl.y + w2 * flyTarget.y)
            let hop = -18 * CGFloat(sin(Double(min(1, uu / 0.16)) * .pi)) * (1 - uu)
            let drift = 16 * CGFloat(sin(Double(uu) * 2 * .pi)) * (1 - uu) * s
            let e = Double(uu * uu * (3 - 2 * uu))
            let spin = reduceMotion ? 0 : Double(s) * (260 * e + 9 * sin(Double(uu) * 11) * Double(1 - uu))
            let scale = reduceMotion ? 1 : (1 + 0.07 * sin(Double(min(1, uu / 0.25)) * .pi)) * (1 - 0.88 * pow(Double(uu), 1.15))
            let tilt = reduceMotion ? 0 : 38 * sin(Double(uu) * .pi) * Double(1 - uu * 0.4)
            let fade = reduceMotion ? Double(1 - uu) : (uu > 0.86 ? max(0, 1 - Double(uu - 0.86) / 0.14) : 1)
            let moveX = reduceMotion ? 0 : b.x - c0.x + drift, moveY = reduceMotion ? 0 : b.y - c0.y + hop
            ZStack(alignment: .topLeading) {
                canvasPlacement(Canvas { ctx, _ in
                    var c = ctx; c.translateBy(x: o.x, y: o.y)
                    c.drawLayer { l in
                        l.addFilter(.shadow(color: .black.opacity(0.4 * fade), radius: 8, x: 0, y: 0, options: .shadowOnly))
                        l.fill(TearRender.silhouette(info.strips, free: nil), with: .color(.black))
                    }
                    TearRender.drawStub(c, image: img, strips: info.strips, opacity: fade)
                })
            }
            .frame(width: 360, height: 600, alignment: .topLeading)
            .scaleEffect(scale, anchor: anchor)
            .rotationEffect(.degrees(spin), anchor: anchor)
            .rotation3DEffect(.degrees(tilt), axis: (x: 1, y: 0.35 * Double(s), z: 0), anchor: anchor, perspective: 0.5)
            .offset(x: moveX, y: moveY)
        }
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
