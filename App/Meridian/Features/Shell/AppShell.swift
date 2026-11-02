import AppKit
import MeridianUI
import SwiftUI

/// Leading space the floating sidebar takes (236 = 8 + 220 + 8, rail 72). Section views inset their content by it,
/// like the canvas screens that start at x = 236.
private struct SidebarInsetKey: EnvironmentKey { static let defaultValue: CGFloat = 0 }
extension EnvironmentValues {
    var shellSidebarInset: CGFloat {
        get { self[SidebarInsetKey.self] }
        set { self[SidebarInsetKey.self] = newValue }
    }
}

/// Frame of the sidebar's Tickets row in the shell's `ritual` coordinate space (the landing ticket flies to its icon).
private struct ShellTicketsFrameKey: EnvironmentKey { static let defaultValue: CGRect = .zero }
extension EnvironmentValues {
    var shellTicketsFrame: CGRect {
        get { self[ShellTicketsFrameKey.self] }
        set { self[ShellTicketsFrameKey.self] = newValue }
    }
}

/// The window content: section view plus the floating sidebar. Home, Plan and the in-flight screen are full bleed
/// (no sidebar), as in the canvas.
struct AppShell: View {
    @Environment(AppModel.self) private var model
    /// Harness: the canvas persona for the sidebar footer.
    var persona: (name: String, km: Double)?
    @State private var ticketsFrame: CGRect = .zero

    var body: some View {
        GeometryReader { geo in
            let rail = geo.size.width < 1000 || model.section == .map
            let showsSidebar = (!(model.section == .fly) || (model.landingPresented && model.activeFlight == nil)) && !model.sidebarHidden
            let inset: CGFloat = showsSidebar ? (rail ? 72 : 236) : 0
            ZStack(alignment: .topLeading) {
                Group {
                    switch model.section {
                    case .fly:
                        FlySectionView()
                    case .together where TogetherAvailability.isEnabled:
                        TogetherRoot()
                    case .wallet:
                        WalletView()
                    case .map: WorldMapView()
                    case .stats: StatsView()
                    case .cards:
                        CardsScreen()
                    case .passport:
                        PassportScreen()
                    case .together:
                        ComingSoonView(section: model.section)
                    }
                }
                .environment(\.shellSidebarInset, inset)
                .environment(\.shellTicketsFrame, ticketsFrame)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if showsSidebar {
                    SidebarView(isRail: rail, profileName: persona?.name ?? (NSFullUserName().isEmpty ? "You" : NSFullUserName()), km: persona?.km).padding(8).transition(.opacity)
                }
            }
            .coordinateSpace(name: "ritual")
            .onPreferenceChange(SidebarTicketsFrameKey.self) { if $0 != .zero { ticketsFrame = $0 } }
            .animation(MRMotion.ease(MRMotion.d3), value: showsSidebar)
            .overlay { RitualHost() }
        }
        .modifier(CardUnlockHost())
        .onAppear { TakeoffImages.prewarm() }
        .mrWindowChrome()
    }
}

extension View {
    /// The canvas `.win` shell: 26 pt radius with a 1 pt inner border and a top highlight.
    func mrWindowChrome() -> some View { modifier(WindowChrome()) }
}

private struct WindowChrome: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        let dark = scheme == .dark
        let shape = RoundedRectangle(cornerRadius: MRRadius.window, style: .continuous)
        content
            .background(MRPalette.resolve(scheme).bg1.color)
            .clipShape(shape)
            .overlay {
                ZStack {
                    shape.strokeBorder(dark ? Color.white.opacity(0.14) : MRColorToken(20, 22, 28, 0.12).color, lineWidth: 1)
                    MRInsetShadow(shape, color: dark ? .white.opacity(0.2) : .white.opacity(0.9), y: 1)
                }
                .allowsHitTesting(false)
            }
    }
}

/// Hidden title bar, transparent window (the content draws the 26 pt rounded shell) and traffic lights at the
/// canvas position (x = 20, y = 18).
struct WindowStyler: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = StylerView()
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class StylerView: NSView {
        private var observers: [NSObjectProtocol] = []
        override func viewDidMoveToWindow() {
            guard let w = window else { return }
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.styleMask.insert(.fullSizeContentView)
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = true
            w.isMovableByWindowBackground = true
            // no layer of the hosting stack may paint outside the rounded shell
            w.contentView?.wantsLayer = true
            w.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
            w.invalidateShadow()
            place(w)
            observers = [NSWindow.didResizeNotification, NSWindow.didEndLiveResizeNotification, NSWindow.didBecomeKeyNotification].map {
                NotificationCenter.default.addObserver(forName: $0, object: w, queue: .main) { [weak self, weak w] _ in
                    MainActor.assumeIsolated {
                        if let w { self?.place(w) }
                    }
                }
            }
        }
        /// Close / minimise / zoom: horizontal position of the canvas dots (x = 20, 20 pt pitch).
        private func place(_ w: NSWindow) {
            let kinds: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
            // Canvas `.tl{left:20px;top:18px}` with 12 pt dots: centre 24 pt from the top. The system title bar is only
            // ~28 pt tall, so grow it to 48 pt (top aligned) and centre the dots at y = 24 inside it.
            if let titlebar = w.standardWindowButton(.closeButton)?.superview, let container = titlebar.superview, !w.styleMask.contains(.fullScreen) {
                var cf = container.frame
                cf.size.height = 48
                cf.origin.y = w.frame.height - 48
                container.frame = cf
                var tf = titlebar.frame
                tf.size.height = 48
                tf.origin.y = 0
                titlebar.frame = tf
            }
            for (i, k) in kinds.enumerated() {
                guard let b = w.standardWindowButton(k), let host = b.superview else { continue }
                var f = b.frame
                f.origin.y = host.bounds.height - 24 - f.height / 2
                f.origin.x = 20 + CGFloat(i) * 20 - (f.width - 12) / 2
                b.setFrameOrigin(f.origin)
            }
        }
    }
}
