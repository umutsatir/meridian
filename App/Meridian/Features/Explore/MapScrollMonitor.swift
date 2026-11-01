import AppKit
import SwiftUI

/// One scroll-wheel / trackpad scroll event, in the coordinates of the view that hosts the monitor (origin top-left).
struct MapScrollEvent {
    var dx: Double
    var dy: Double
    /// Trackpad / Magic Mouse (continuous deltas) as opposed to a notched wheel.
    var precise: Bool
    var location: CGPoint
    var modifiers: NSEvent.ModifierFlags
    /// Momentum phase of a trackpad flick (the fingers are already up).
    var isMomentum: Bool
    /// Zoom modifier held: Option or Control.
    var zoomModifier: Bool { modifiers.contains(.option) || modifiers.contains(.control) }
}

/// SwiftUI has no scroll-wheel event for a plain view, so a local `NSEvent` monitor reports them. `handler` returns `true`
/// when it used the event (it is then swallowed); events outside the view's bounds are never reported.
struct MapScrollMonitor: NSViewRepresentable {
    var handler: (MapScrollEvent) -> Bool

    func makeNSView(context: Context) -> MonitorView { let v = MonitorView(); v.handler = handler; return v }
    func updateNSView(_ v: MonitorView, context: Context) { v.handler = handler }

    final class MonitorView: NSView {
        var handler: ((MapScrollEvent) -> Bool)?
        private var token: Any?
        override var isFlipped: Bool { true }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let token { NSEvent.removeMonitor(token); self.token = nil }
            guard window != nil else { return }
            token = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] e in
                guard let self, let win = self.window, e.window === win else { return e }
                let p = self.convert(e.locationInWindow, from: nil)
                guard self.bounds.contains(p) else { return e }
                let ev = MapScrollEvent(dx: e.scrollingDeltaX, dy: e.scrollingDeltaY, precise: e.hasPreciseScrollingDeltas, location: p,
                                        modifiers: e.modifierFlags, isMomentum: e.momentumPhase != [])
                return (self.handler?(ev) ?? false) ? nil : e
            }
        }
    }
}
