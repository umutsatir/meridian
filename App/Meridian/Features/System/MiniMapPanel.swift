import AppKit
import SwiftUI

/// SYS-2: the floating mini map. A non-activating `NSPanel` above other windows on every Space, draggable,
/// snapping to the nearest corner of its screen, three sizes, opacity, click-through. Size and corner are
/// remembered per display. Hidden while there is no flight.
@MainActor
final class MiniMapPanelController: NSObject {
    private let surfaces: SystemSurfaces
    private var panel: MiniMapPanel?
    private var dragStartMouse: NSPoint = .zero
    private var dragStartOrigin: NSPoint = .zero
    private var resizeStartMouse: NSPoint = .zero
    private var resizeStartWidth: CGFloat = 0
    private var resizeTop: CGFloat = 0
    private var resizeLeft: CGFloat = 0
    private var dragging = false

    static let margin: CGFloat = 16

    init(surfaces: SystemSurfaces) {
        self.surfaces = surfaces
        super.init()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition(animated: false) }
        }
    }

    /// Called every second and when a setting changes.
    func refresh() {
        let wanted = surfaces.settings.miniMapEnabled && surfaces.info.kind != .idle && surfaces.info.kind != .landed
        if wanted {
            let panel = ensurePanel()
            panel.ignoresMouseEvents = surfaces.settings.clickThrough
            panel.alphaValue = 1
            if !panel.isVisible {
                reposition(animated: false)
                panel.orderFrontRegardless()
            } else if !dragging {
                reposition(animated: true)
            }
        } else if let panel, panel.isVisible {
            panel.orderOut(nil)
        }
    }

    private var screenKey: String { SystemSettings.key(for: panel?.screen ?? NSScreen.main) }

    private func ensurePanel() -> MiniMapPanel {
        if let panel { return panel }
        let panel = MiniMapPanel(contentRect: NSRect(x: 0, y: 0, width: 480, height: 270),
                                 styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.setAccessibilityLabel("Mini map")
        let host = NSHostingView(rootView: MiniMapPanelRoot(surfaces: surfaces, controller: self))
        host.sizingOptions = []
        panel.contentView = host
        self.panel = panel
        return panel
    }

    // MARK: Geometry

    private func targetScreen() -> NSScreen { panel?.screen ?? NSScreen.main ?? NSScreen.screens[0] }

    static func frame(corner: MiniMapCorner, size: CGSize, in visible: NSRect) -> NSRect {
        let m = margin
        let x = (corner == .tl || corner == .bl) ? visible.minX + m : visible.maxX - size.width - m
        let y = (corner == .tl || corner == .tr) ? visible.maxY - size.height - m : visible.minY + m
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    private func reposition(animated: Bool) {
        guard let panel else { return }
        let screen = targetScreen()
        let state = surfaces.settings.state(for: SystemSettings.key(for: screen))
        let frame = Self.frame(corner: state.corner, size: state.size.dimensions, in: screen.visibleFrame)
        if panel.frame != frame {
            let animate = animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion && panel.isVisible
            panel.setFrame(frame, display: true, animate: animate)
        }
    }

    // MARK: Drag

    func dragChanged() {
        guard let panel else { return }
        if !dragging {
            dragging = true
            dragStartMouse = NSEvent.mouseLocation
            dragStartOrigin = panel.frame.origin
        }
        let m = NSEvent.mouseLocation
        panel.setFrameOrigin(NSPoint(x: dragStartOrigin.x + m.x - dragStartMouse.x, y: dragStartOrigin.y + m.y - dragStartMouse.y))
    }

    func dragEnded() {
        guard let panel, dragging else { return }
        dragging = false
        // Nearest corner of the display under the panel centre.
        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(center) } ?? targetScreen()
        let v = screen.visibleFrame
        let left = center.x < v.midX, top = center.y > v.midY
        let corner: MiniMapCorner = top ? (left ? .tl : .tr) : (left ? .bl : .br)
        surfaces.settings.update(SystemSettings.key(for: screen)) { $0.corner = corner }
        let size = surfaces.settings.state(for: SystemSettings.key(for: screen)).size.dimensions
        let frame = Self.frame(corner: corner, size: size, in: v)
        let animate = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        panel.setFrame(frame, display: true, animate: animate)
    }

    // MARK: Size

    func cycleSize() {
        let key = screenKey
        surfaces.settings.update(key) { $0.size = $0.size.next }
        reposition(animated: true)
    }

    func setSize(_ size: MiniMapSize) {
        surfaces.settings.update(screenKey) { $0.size = size }
        reposition(animated: true)
    }

    func resizeChanged() {
        guard let panel else { return }
        if resizeStartWidth == 0 {
            resizeStartMouse = NSEvent.mouseLocation
            resizeStartWidth = panel.frame.width
            resizeTop = panel.frame.maxY
            resizeLeft = panel.frame.minX
            dragging = true
        }
        let dx = NSEvent.mouseLocation.x - resizeStartMouse.x
        let width = max(300, min(700, resizeStartWidth + dx))
        let size = CGSize(width: width.rounded(), height: (width * 9 / 16).rounded())
        panel.setFrame(NSRect(x: resizeLeft, y: resizeTop - size.height, width: size.width, height: size.height), display: true)
    }

    func resizeEnded() {
        guard let panel, resizeStartWidth != 0 else { return }
        resizeStartWidth = 0
        dragging = false
        let preset = MiniMapSize.nearest(width: panel.frame.width)
        surfaces.settings.update(screenKey) { $0.size = preset }
        reposition(animated: true)
    }
}

final class MiniMapPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct MiniMapPanelRoot: View {
    var surfaces: SystemSurfaces
    var controller: MiniMapPanelController

    var body: some View {
        let state = surfaces.settings.state(for: SystemSettings.key(for: NSScreen.main))
        MiniMapView(
            info: surfaces.info, size: state.size.dimensions,
            opacity: surfaces.settings.miniMapOpacity, clickThrough: surfaces.settings.clickThrough,
            drawsShadow: false, follows: true,
            actions: MiniMapActions(
                pause: { surfaces.togglePause() },
                sound: { surfaces.settings.soundOn.toggle() },
                size: { controller.cycleSize() },
                close: { surfaces.settings.miniMapEnabled = false },
                dragChanged: { controller.dragChanged() }, dragEnded: { controller.dragEnded() },
                resizeChanged: { controller.resizeChanged() }, resizeEnded: { controller.resizeEnded() }))
            .gesture(DragGesture(minimumDistance: 4, coordinateSpace: .global)
                .onChanged { _ in controller.dragChanged() }
                .onEnded { _ in controller.dragEnded() })
            .ignoresSafeArea()
    }
}
