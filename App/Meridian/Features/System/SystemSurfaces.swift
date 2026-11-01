import AppKit
import IOKit.pwr_mgt
import MeridianCore
import MeridianCruise
import MeridianUI
import Observation
import SwiftUI
import UserNotifications

/// Owner of every system surface: menu bar item, mini map panel, Seat TV, Dock tile, notifications, wake lock.
/// `attach(model:)` starts a one second clock that refreshes all of them from `AppModel.activeFlight`.
@MainActor
@Observable
final class SystemSurfaces {
    static let shared = SystemSurfaces()

    let settings = SystemSettings()
    private(set) var info = SystemFlightInfo()
    private(set) var now = Date()
    var seatMode: SeatTVMode = .map

    @ObservationIgnored private(set) weak var model: AppModel?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var miniPanel: MiniMapPanelController?
    @ObservationIgnored private var seatTV: SeatTVController?
    @ObservationIgnored private let wakeLock = WakeLock()
    @ObservationIgnored private let notifications = SystemNotifications()
    @ObservationIgnored private let dock = DockTileController()
    @ObservationIgnored private var alert = LandingAlert()
    @ObservationIgnored private var lastFlightID: UUID?
    @ObservationIgnored private var lastPublish = Date.distantPast

    func attach(model: AppModel) {
        guard self.model == nil else { return }
        self.model = model
        miniPanel = MiniMapPanelController(surfaces: self)
        seatTV = SeatTVController(surfaces: self)
        notifications.configure(settings: settings) { [weak self] in self?.openApp(section: .fly) }
        notifications.requestAuthorization()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        // NSApp does not exist yet while the App struct initialises.
        DispatchQueue.main.async { [weak self] in self?.tick() }
    }

    private func tick() {
        guard let model else { return }
        now = .now
        let next = SystemFlightInfo.live(model: model, now: now)
        if next != info { info = next }
        let flight = model.activeFlight
        let defaults = UserDefaults(suiteName: WidgetSnapshot.groupID) ?? .standard
        if defaults.object(forKey: WidgetSnapshot.commandKey) != nil {
            defaults.removeObject(forKey: WidgetSnapshot.commandKey)
            model.togglePause()
        }

        wakeLock.set(held: settings.keepAwake && flight != nil)
        if let flight {
            if lastFlightID != flight.id {
                lastFlightID = flight.id
                notifications.scheduleLanding(for: flight)
            }
            if let trigger = alert.poll(flight: flight, at: now, isEnabled: settings.notifyLanding) {
                notifications.landingHeadsUp(minutes: Int((trigger.remainingSec / 60).rounded(.up)), flight: flight)
            }
        } else if lastFlightID != nil {
            notifications.cancelLanding(flightID: lastFlightID!)
            lastFlightID = nil
        }
        miniPanel?.refresh()
        dock.update(info: info)
        if now.timeIntervalSince(lastPublish) > 30 || next.kind != info.kind {
            lastPublish = now
            WidgetPublisher.publish(model: model, info: info, flight: flight, now: now)
        }
    }

    // MARK: Actions

    func togglePause() { model?.togglePause() }

    func openApp(section: AppSection? = nil) {
        if let section { model?.section = section }
        NSApp.activate(ignoringOtherApps: true)
        for w in NSApp.windows where w.canBecomeMain && !(w is NSPanel) {
            w.makeKeyAndOrderFront(nil)
            break
        }
    }

    func toggleMiniMap() { settings.miniMapEnabled.toggle(); miniPanel?.refresh() }
    func toggleSeatTV() { seatTV?.toggle() }

    func notifyFriendJoined(name: String, aboard: Int, of total: Int, route: String, flightID: UUID) {
        notifications.friendJoined(name: name, aboard: aboard, of: total, route: route, flightID: flightID)
    }
    func notifyBoardingCall(flightNumber: String, gate: String, flightID: UUID) {
        notifications.boardingCall(flightNumber: flightNumber, gate: gate, flightID: flightID)
    }
    func scheduleGateOpens(at date: Date, destination: String, time: String, flightID: UUID) {
        notifications.gateOpens(at: date, destination: destination, time: time, flightID: flightID)
    }
}

// MARK: - Menu bar item (M01)

/// The status item label: plane glyph and the time left, digits tabular so the item never jitters.
struct MenuBarItemLabel: View {
    var surfaces: SystemSurfaces

    var body: some View {
        let info = surfaces.info
        HStack(spacing: 6) {
            if info.kind == .boarding { Image(nsImage: Self.dot) }
            Image(nsImage: info.kind == .landed ? Self.check : Self.plane)
            if let text = Self.text(info) {
                Text(text).font(MRFonts.font(.ui, size: 13, weight: 500)).monospacedDigit()
            }
        }
        .accessibilityLabel("Meridian: \(Self.name(info.kind))")
    }

    static func text(_ info: SystemFlightInfo) -> String? {
        switch info.kind {
        case .idle: nil
        case .boarding: SystemFlightInfo.mmss(252)
        case .flight, .last: info.timeString
        case .landed: "Landed"
        }
    }

    static func name(_ kind: SystemFlightKind) -> String {
        switch kind {
        case .idle: "Idle"
        case .boarding: "Boarding"
        case .flight: "In flight"
        case .last: "Last minute"
        case .landed: "Landed"
        }
    }

    @MainActor private static func render(_ view: AnyView, template: Bool) -> NSImage {
        let r = ImageRenderer(content: view)
        r.scale = 2
        let image = r.nsImage ?? NSImage()
        image.isTemplate = template
        return image
    }
    @MainActor static let plane = render(AnyView(MRIcon(.plane, size: 14).foregroundStyle(.black)), template: true)
    @MainActor static let check = render(AnyView(MRIcon(.check, size: 14).foregroundStyle(.black)), template: true)
    @MainActor static let dot = render(AnyView(Circle().fill(MRPalette.dark.amber.color).frame(width: 6, height: 6)), template: false)
}

struct MenuPopoverHost: View {
    var surfaces: SystemSurfaces

    var body: some View {
        let s = surfaces
        MenuPopoverView(
            info: s.info,
            options: Binding(
                get: { MenuPopoverOptions(miniOn: s.settings.miniMapEnabled, size: s.settings.state(for: SystemSettings.key(for: NSScreen.main)).size,
                                          opacity: s.settings.miniMapOpacity, clickThrough: s.settings.clickThrough, soundOn: s.settings.soundOn) },
                set: { o in
                    s.settings.miniMapEnabled = o.miniOn
                    s.settings.miniMapOpacity = o.opacity
                    s.settings.clickThrough = o.clickThrough
                    s.settings.soundOn = o.soundOn
                    s.settings.update(SystemSettings.key(for: NSScreen.main)) { $0.size = o.size }
                }),
            actions: MenuPopoverActions(
                pause: { s.togglePause() },
                landEarly: { s.model?.landEarly() },
                planFlight: { s.openApp(section: .fly) },
                openBoardingPass: { s.openApp(section: .fly) },
                dismissBoarding: {},
                addToWallet: { s.openApp(section: .wallet) },
                flyAgain: { s.openApp(section: .fly) },
                openApp: { s.openApp() },
                openSettings: { s.openApp() }))
            .padding(8)
            .keyboardShortcut("o", modifiers: .command)
    }
}

// MARK: - Commands

struct SystemCommands: Commands {
    var body: some Commands {
        CommandMenu("Cabin") {
            Button("Show or Hide Mini Map") { SystemSurfaces.shared.toggleMiniMap() }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            Button("Seat-back Screen") { SystemSurfaces.shared.toggleSeatTV() }
                .keyboardShortcut("t", modifiers: [.command, .shift])
        }
    }
}

// MARK: - Seat TV window (M03)

/// Borderless window above the menu bar on the second display (or the main one when there is only one).
@MainActor
final class SeatTVController {
    private let surfaces: SystemSurfaces
    private var window: NSWindow?
    private var cursorTimer: Timer?

    init(surfaces: SystemSurfaces) { self.surfaces = surfaces }

    func toggle() { window == nil ? open() : close() }

    func open() {
        guard window == nil else { return }
        let screens = NSScreen.screens
        let screen = screens.count > 1 ? screens[1] : (NSScreen.main ?? screens[0])
        let w = SeatTVWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false, screen: screen)
        w.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)
        w.backgroundColor = .black
        w.isReleasedWhenClosed = false
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let host = NSHostingView(rootView: SeatTVRoot(surfaces: surfaces) { [weak self] in self?.close() })
        w.contentView = host
        w.setFrame(screen.frame, display: true)
        w.makeKeyAndOrderFront(nil)
        w.makeFirstResponder(host)
        window = w
        // Hide the cursor after 3 s without movement.
        let watch = CursorWatch()
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated {
                let m = NSEvent.mouseLocation
                if m == watch.last { watch.still += 1 } else { watch.still = 0; watch.last = m; NSCursor.unhide() }
                if watch.still >= 3 { NSCursor.setHiddenUntilMouseMoves(true) }
            }
        }
    }

    func close() {
        cursorTimer?.invalidate()
        cursorTimer = nil
        NSCursor.unhide()
        window?.orderOut(nil)
        window = nil
    }
}

/// Mouse-idle state for the seat-TV cursor timer (the timer closure cannot capture mutable locals).
private final class CursorWatch: @unchecked Sendable {
    var last = NSEvent.mouseLocation
    var still = 0
}

final class SeatTVWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

private struct SeatTVRoot: View {
    @Bindable var surfaces: SystemSurfaces
    var onClose: () -> Void
    var body: some View {
        SeatTVView(info: surfaces.info.kind == .idle ? .preview(.flight) : surfaces.info, mode: $surfaces.seatMode, onClose: onClose)
    }
}

// MARK: - SYS-6 wake lock

/// Keeps the display awake while a flight is active (IOPMAssertion), releases it on landing.
@MainActor
final class WakeLock {
    private var id: IOPMAssertionID = 0
    private var held = false

    func set(held want: Bool) {
        if want, !held {
            let r = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                "Meridian flight in progress" as CFString, &id)
            held = r == kIOReturnSuccess
        } else if !want, held {
            IOPMAssertionRelease(id)
            held = false
        }
    }
    var isHeld: Bool { held }
}

// MARK: - Dock tile (M06)

@MainActor
final class DockTileController {
    private var host: NSHostingView<DockTileView>?
    private var lastKey = ""

    func update(info: SystemFlightInfo) {
        let flying = info.kind == .flight || info.kind == .last
        let key = flying ? "\(info.timeString)|\(Int(info.progress * 100))" : "idle"
        guard key != lastKey else { return }
        lastKey = key
        let tile = NSApp.dockTile
        if flying {
            let view = DockTileView(progress: info.progress, pill: info.timeString)
            if let host { host.rootView = view } else {
                let h = NSHostingView(rootView: view)
                h.frame = NSRect(origin: .zero, size: tile.size)
                host = h
                tile.contentView = h
            }
            host?.frame = NSRect(origin: .zero, size: tile.size)
        } else if host != nil {
            tile.contentView = nil
            host = nil
        }
        tile.display()
    }

    func setBadge(_ count: Int) { NSApp.dockTile.badgeLabel = count > 0 ? String(count) : nil }
}

/// Icon with the progress ring 5 pt outside it and the time left in a pill.
struct DockTileView: View {
    var progress: Double
    var pill: String

    var body: some View {
        GeometryReader { g in
            let s = min(g.size.width, g.size.height)
            let icon = s * 0.76
            ZStack {
                AppIconArt(variant: .standard, size: icon)
                RoundedRectangle(cornerRadius: icon * 0.2237 + 5, style: .continuous)
                    .stroke(.white.opacity(0.2), lineWidth: 3.5)
                    .frame(width: icon + 10, height: icon + 10)
                RoundedRectangle(cornerRadius: icon * 0.2237 + 5, style: .continuous)
                    .trim(from: 0, to: progress)
                    .stroke(LinearGradient(colors: [sysRGBA(106, 183, 255), sysRGBA(139, 243, 216)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .frame(width: icon + 10, height: icon + 10)
                Text(pill)
                    .font(MRFonts.font(.mono, size: s * 0.1, weight: 500)).foregroundStyle(sysRGBA(243, 245, 250))
                    .padding(.horizontal, s * 0.06).frame(height: s * 0.16)
                    .background(Capsule().fill(sysRGBA(10, 14, 28, 0.82)))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))
                    .offset(y: icon / 2 + 2)
            }
            .frame(width: g.size.width, height: g.size.height)
        }
    }
}
