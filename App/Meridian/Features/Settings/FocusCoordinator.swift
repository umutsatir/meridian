import AppKit
import MeridianCore
import MeridianFocus
import MeridianUI
import SwiftUI

extension Notification.Name {
    /// Posted when the user picks "Take a break" on the focus overlay; the cruise feature starts the meal break.
    static let meridianFocusTakeBreak = Notification.Name("app.meridian.focus.takeBreak")
}

/// Connects `MeridianFocus.FocusEnforcer` to the running app: watches the frontmost app during a
/// flight and shows the Nudge banner or the Strict overlay in a panel of our own. Meridian never
/// quits, hides or controls another app (PRD BLK-1).
@MainActor
final class FocusCoordinator {
    static let shared = FocusCoordinator()
    private var task: Task<Void, Never>?
    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?
    private var enforcer = FocusEnforcer(mode: .off, list: BlockList(), ownBundleIDs: [Bundle.main.bundleIdentifier ?? "app.meridian.Meridian"])

    func run(model: AppModel) {
        guard task == nil else { return }
        task = Task { [weak self] in
            for await app in NSWorkspaceFrontmostSource().changes {
                self?.handle(app, model: model)
            }
        }
    }

    private func handle(_ app: AppInfo, model: AppModel) {
        guard let flight = model.activeFlight else { dismiss(); return }
        let settings = FocusStore.shared.settings
        enforcer.mode = settings.mode
        enforcer.list = settings.list
        let city = model.airport(flight.destinationIata)?.city
        switch enforcer.evaluate(flight: flight, destinationName: city, app: app, now: .now) {
        case .none: break
        case .nudge(let toast): showNudge(toast, flight: flight)
        case .overlay(let overlay): showOverlay(overlay, flight: flight, model: model)
        }
    }

    private func sentence(destination: String?, minutes: Int?) -> String {
        switch (destination, minutes) {
        case let (d?, m?): L("You’re in flight to %@ — %lld min left.", d, m)
        case let (d?, nil): L("You’re in flight to %@.", d)
        case let (nil, m?): L("You’re in flight — %lld min left.", m)
        default: L("You’re in flight.")
        }
    }

    private func showNudge(_ toast: NudgeToast, flight: Flight) {
        let view = NudgeCard(title: sentence(destination: toast.destinationName, minutes: toast.remainingMinutes), action: L("Return to focus"))
            .frame(width: 360).padding(20)
        present(AnyView(view), nonActivating: true, fullScreen: false)
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            if !Task.isCancelled { self?.dismiss() }
        }
    }

    private func showOverlay(_ overlay: BlockOverlay, flight: Flight, model: AppModel) {
        let now = Date.now
        let elapsed = Int(flight.elapsedSec(at: now) / 60)
        let total = flight.durationSec.map { Int($0 / 60) }
        let progress = flight.durationSec.map { min(1, flight.elapsedSec(at: now) / max($0, 1)) } ?? 0
        let route = "\(flight.originIata) → \(flight.destinationIata ?? "—")"
        let canLand = overlay.actions.contains(.landEarly)
        let view = StrictCard(
            route: route, title: sentence(destination: overlay.destinationName, minutes: overlay.remainingMinutes),
            progress: progress, left: total.map { L("%lld of %lld min", elapsed, $0) } ?? L("%lld min", elapsed),
            right: flight.durationSec.map { L("ETA %@", Self.timeText((flight.startedAt ?? now).addingTimeInterval($0))) } ?? "",
            actions: (returnToFocus: { [weak self] in self?.dismiss(); NSApp.activate(ignoringOtherApps: true) },
                      takeBreak: { [weak self] in self?.dismiss(); NotificationCenter.default.post(name: .meridianFocusTakeBreak, object: nil) },
                      landEarly: canLand ? { [weak self] in self?.dismiss(); model.landEarly() } : nil))
            .frame(width: 392)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.35).background(.ultraThinMaterial))
        present(AnyView(view), nonActivating: false, fullScreen: true)
    }

    private static func timeText(_ d: Date) -> String {
        d.formatted(date: .omitted, time: .shortened)
    }

    private func present(_ view: AnyView, nonActivating: Bool, fullScreen: Bool) {
        dismiss()
        guard let screen = NSScreen.main else { return }
        let frame: NSRect = fullScreen ? screen.frame : NSRect(x: screen.visibleFrame.midX - 200, y: screen.visibleFrame.maxY - 140, width: 400, height: 120)
        let style: NSWindow.StyleMask = nonActivating ? [.borderless, .nonactivatingPanel] : [.borderless]
        let p = NSPanel(contentRect: frame, styleMask: style, backing: .buffered, defer: false)
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.contentView = NSHostingView(rootView: view)
        p.setFrame(frame, display: true)
        if nonActivating { p.orderFrontRegardless() } else { p.makeKeyAndOrderFront(nil) }
        panel = p
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }
}
