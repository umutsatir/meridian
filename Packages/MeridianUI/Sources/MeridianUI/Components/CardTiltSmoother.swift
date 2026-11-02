import SwiftUI

/// Low-pass filter for pointer-driven tilt (membership card, boarding pass).
///
/// The pointer is only ever a *target*; the pose that is drawn is advanced every frame towards it with a critically
/// damped spring (exact analytic step, so it is stable at any frame rate). Entering the card therefore starts from the
/// rest pose and glides to the pointer pose, moving the pointer never makes the tilt jump, and leaving glides back.
/// A critically damped spring never overshoots a fixed target when it starts at rest.
public struct CardTiltSmoother: Equatable, Sendable {
    /// Smoothed pointer position (-0.5...0.5 on both axes) and hover amount (0 = at rest, 1 = hovered).
    public private(set) var x = 0.0, y = 0.0, hover = 0.0
    private var vx = 0.0, vy = 0.0, vh = 0.0
    public private(set) var targetX = 0.0, targetY = 0.0, targetHover = 0.0
    /// Spring response (seconds, the period of the undamped spring) for the pointer position and for lift / hover amount.
    public var pointerResponse: Double
    public var hoverResponse: Double

    public init(pointerResponse: Double = 0.35, hoverResponse: Double = 0.55) {
        self.pointerResponse = pointerResponse; self.hoverResponse = hoverResponse
    }

    /// New pointer target in -0.5...0.5, or nil when the pointer left (target returns to rest).
    public mutating func setTarget(_ p: CGPoint?) {
        if let p {
            targetX = min(0.5, max(-0.5, Double(p.x))); targetY = min(0.5, max(-0.5, Double(p.y))); targetHover = 1
        } else {
            targetX = 0; targetY = 0; targetHover = 0
        }
    }

    /// Advances by `dt` seconds (clamped to 50 ms so a stalled frame cannot teleport the pose).
    public mutating func step(_ dt: Double) {
        let dt = min(max(dt, 0), 0.05)
        Self.advance(&x, &vx, targetX, pointerResponse, dt)
        Self.advance(&y, &vy, targetY, pointerResponse, dt)
        Self.advance(&hover, &vh, targetHover, hoverResponse, dt)
    }

    public var isSettled: Bool {
        abs(x - targetX) < 5e-4 && abs(y - targetY) < 5e-4 && abs(hover - targetHover) < 5e-4
            && abs(vx) < 5e-3 && abs(vy) < 5e-3 && abs(vh) < 5e-3
    }

    /// Jumps to the target (Reduce Motion, previews).
    public mutating func snap() {
        x = targetX; y = targetY; hover = targetHover; vx = 0; vy = 0; vh = 0
    }

    /// Critically damped spring, closed form: x(t) = target + (A + B t) e^(-w t), A = x0 - target, B = v0 + w A.
    static func advance(_ value: inout Double, _ velocity: inout Double, _ target: Double, _ response: Double, _ dt: Double) {
        guard dt > 0 else { return }
        let w = 2 * Double.pi / max(response, 0.01)
        let a = value - target, b = velocity + w * a
        let e = exp(-w * dt)
        value = target + (a + b * dt) * e
        velocity = (b - w * (a + b * dt)) * e
    }
}

/// Reference-type frame clock for `CardTiltSmoother`, read from inside a `TimelineView(.animation)` closure.
@MainActor
final class CardTiltDriver {
    var smoother = CardTiltSmoother()
    private var last: Date?

    func setTarget(_ p: CGPoint?) { smoother.setTarget(p) }
    func resume() { last = nil }

    func sample(at date: Date, reduceMotion: Bool) -> CardTiltSmoother {
        if reduceMotion { smoother.snap(); last = date; return smoother }
        if let l = last { smoother.step(date.timeIntervalSince(l)) }
        last = date
        return smoother
    }
}

/// Hosts a pointer-tilted view. `content` receives the smoothed pointer (-0.5...0.5) and hover amount (0...1) every frame.
/// The pointer is read by an overlay of the whole frame (`Color.clear` + `contentShape`), which is the topmost hit target
/// for hover, so no child (chip, lock ring, label) can swallow it; taps and keys still reach the host's own modifiers.
struct CardTiltHost<Content: View>: View {
    /// Maps a location in the host's frame to -0.5...0.5.
    let normalize: (CGPoint) -> CGPoint
    let enabled: Bool
    let content: (_ px: Double, _ py: Double, _ hover: Double) -> Content

    @State private var driver = CardTiltDriver()
    @State private var running = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: !running)) { ctx in
            let s = driver.sample(at: ctx.date, reduceMotion: reduceMotion)
            content(s.x, s.y, s.hover)
                .onChange(of: ctx.date) { _, _ in
                    if running && driver.smoother.isSettled { running = false }
                }
        }
        .overlay {
            Color.clear.contentShape(Rectangle())
                .onContinuousHover { phase in
                    guard enabled else { return }
                    switch phase {
                    case .active(let l): driver.setTarget(normalize(l)); wake()
                    case .ended: driver.setTarget(nil); wake()
                    }
                }
        }
    }

    private func wake() { if !running { driver.resume(); running = true } }
}
