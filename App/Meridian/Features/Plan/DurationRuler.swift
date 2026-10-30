import AppKit
import MeridianPlan
import MeridianUI
import SwiftUI

/// The duration ruler (`.ruler` in `Planner.dc.html`): a 760 x 56 track inside a glass pill, scrubbed by two-finger
/// scrolling, dragging or the arrow keys. `DurationScrub` (MeridianPlan) owns the numbers; this view draws them and
/// forwards events.
struct DurationRuler: View {
    /// Position on the track in minutes (`rawMinutes` while scrubbing, the committed duration at rest; 372 is "∞").
    let minutes: Double
    let flagText: String
    let isDragging: Bool
    let onBegin: (Double) -> Void
    let onDrag: (Double) -> Void
    let onScroll: (Double, _ ended: Bool) -> Void
    let onEnd: () -> Void
    let onKey: (Int, Bool) -> Void
    @Environment(\.colorScheme) private var scheme
    @FocusState private var focused: Bool

    static let rulerWidth: CGFloat = 760
    private let px = DurationScrub.pixelsPerMinute

    var body: some View {
        let p = MRPalette.resolve(scheme)
        let left = Self.rulerWidth / 2 + DurationScrub.trackOffset(forMinutes: minutes)
        ZStack(alignment: .topLeading) {
            RulerTrack(palette: p)
                .frame(width: (380 - 10) * px + 40, height: 56)
                .offset(x: left)
                .animation(isDragging ? nil : MRMotion.snappy, value: minutes)
                .frame(width: Self.rulerWidth, height: 56, alignment: .topLeading)
                .clipped()
                .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.14),
                                             .init(color: .black, location: 0.86), .init(color: .clear, location: 1)],
                                     startPoint: .leading, endPoint: .trailing))
                .padding(.top, 6)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        if !isDragging { onBegin(g.startLocation.x) }
                        onDrag(g.location.x)
                    }
                    .onEnded { _ in onEnd() })
                .focusable()
                .focused($focused)
                .focusEffectDisabled()
                .onKeyPress(.leftArrow, phases: [.down, .repeat]) { press in onKey(-1, press.modifiers.contains(.shift)); return .handled }
                .onKeyPress(.rightArrow, phases: [.down, .repeat]) { press in onKey(1, press.modifiers.contains(.shift)); return .handled }
                .background(ScrollCatcher(onScroll: onScroll))
        }
        .padding(.horizontal, 12).padding(.top, 8)
        .frame(width: Self.rulerWidth + 24, height: 72, alignment: .topLeading)
        .mrGlass(cornerRadius: 36, elevation: .e2)
        .overlay(alignment: .topLeading) {
            VStack(spacing: 0) {
                Text(flagText)
                    .font(.mr(.mono, size: 13, weight: 600)).foregroundStyle(p.text1.color).lineLimit(1).fixedSize()
                    .padding(.horizontal, 12).frame(height: 26)
                    .mrGlass(in: Capsule(), elevation: .e3)
                RoundedRectangle(cornerRadius: 1).fill(p.accentGradient).frame(width: 2, height: 24)
                    .shadow(color: MRColorToken(106, 183, 255, 0.7).color, radius: 5)
            }
            .frame(width: 200)
            .position(x: Self.rulerWidth / 2 + 12, y: -18 + 25)
            .allowsHitTesting(false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Flight duration")
        .accessibilityValue(flagText)
        .accessibilityAdjustableAction { dir in onKey(dir == .increment ? 1 : -1, false) }
    }
}

private struct RulerTrack: View {
    let palette: MRPalette

    var body: some View {
        Canvas { ctx, size in
            let px = DurationScrub.pixelsPerMinute
            let total = (380 - 10) * px
            var small = Path()
            var x = 0.0
            while x < total { small.addRect(CGRect(x: x, y: 18, width: 1, height: 18)); x += 18 }
            ctx.fill(small, with: .color(palette.text3.color.opacity(0.75)))
            var big = Path()
            x = 72
            while x < total { big.addRect(CGRect(x: x, y: 10, width: 1.5, height: 26)); x += 108 }
            ctx.fill(big, with: .color(palette.text2.color.opacity(0.95)))
            func label(_ t: String, at x: Double) {
                ctx.draw(Text(t).font(.mr(.mono, size: 12, weight: 500)).foregroundColor(palette.text2.color), at: CGPoint(x: x, y: 44), anchor: .center)
            }
            for m in stride(from: 30, through: 360, by: 30) {
                let t = m < 60 ? "\(m)m" : (m % 60 != 0 ? "\(m / 60)h 30" : "\(m / 60)h")
                label(t, at: DurationScrub.trackX(forMinutes: Double(m)))
            }
            label("∞", at: DurationScrub.trackX(forMinutes: 376))
        }
    }
}

/// Catches trackpad / wheel scrolling over its frame without blocking clicks (local event monitor).
private struct ScrollCatcher: NSViewRepresentable {
    let onScroll: (Double, Bool) -> Void

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        context.coordinator.view = v
        context.coordinator.install()
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) { context.coordinator.onScroll = onScroll }
    func makeCoordinator() -> Coordinator { Coordinator(onScroll) }
    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) { coordinator.remove() }

    @MainActor final class Coordinator {
        var onScroll: (Double, Bool) -> Void
        weak var view: NSView?
        private var monitor: Any?
        private var debounce: Task<Void, Never>?
        init(_ onScroll: @escaping (Double, Bool) -> Void) { self.onScroll = onScroll }

        func install() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, let view = self.view, view.window === event.window else { return event }
                let p = view.convert(event.locationInWindow, from: nil)
                guard view.bounds.contains(p) else { return event }
                let delta = DurationScrub.dominantScrollDelta(dx: Double(event.scrollingDeltaX), dy: Double(event.scrollingDeltaY))
                let hasPhase = event.phase != [] || event.momentumPhase != []
                let ended = event.phase == .ended || event.phase == .cancelled || event.momentumPhase == .ended
                if event.momentumPhase != [] && event.momentumPhase != .ended { return nil }   // ignore momentum, the ruler snaps on release
                self.onScroll(delta, ended)
                if !hasPhase {
                    self.debounce?.cancel()
                    self.debounce = Task { [weak self] in
                        try? await Task.sleep(for: .milliseconds(160))
                        if !Task.isCancelled { self?.onScroll(0, true) }
                    }
                }
                return nil
            }
        }

        func remove() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil }
    }
}
