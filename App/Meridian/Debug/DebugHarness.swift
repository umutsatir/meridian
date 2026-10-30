import AppKit
import SwiftUI

/// Launch arguments of the screenshot harness:
///   --screen <route> --size 1280x800 --screenshot <out.png> [--delay 1.5] [--theme dark|light]
/// The app draws the registered screen in a window whose content is exactly <size> points,
/// writes a 1x PNG of the window content and exits. No screen-recording permission is needed.
struct DebugLaunch {
    let route: String
    let size: CGSize
    let output: URL
    let delay: Double
    let theme: ColorScheme
    /// "window" (default): WindowServer composite of our own window (glass blur, Map, Metal). "cache": NSView.cacheDisplay at 1x (misses materials and Map annotations).
    let capture: String

    /// nil unless `--screenshot` and `--screen` are present.
    static let current: DebugLaunch? = {
        let args = CommandLine.arguments
        func value(_ flag: String) -> String? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        guard let route = value("--screen"), let out = value("--screenshot") else { return nil }
        var size = CGSize(width: 1280, height: 800)
        if let s = value("--size") {
            let parts = s.lowercased().split(separator: "x").compactMap { Double($0) }
            if parts.count == 2 { size = CGSize(width: parts[0], height: parts[1]) }
        }
        let delay = value("--delay").flatMap(Double.init) ?? 1.5
        let theme: ColorScheme = value("--theme") == "light" ? .light : .dark
        return DebugLaunch(route: route, size: size, output: URL(fileURLWithPath: out), delay: delay, theme: theme,
                           capture: value("--capture") ?? "window")
    }()
}

/// Root view used instead of RootView when the harness is active.
struct DebugHost: View {
    let launch: DebugLaunch
    @State private var model: AppModel
    private let preferencesBackup: Data?
    private static let preferencesKey = "plan.preferences"

    init(launch: DebugLaunch) {
        self.launch = launch
        // Deterministic first-run state: hide the developer's saved plan preferences
        // while the harness runs, restore them afterwards (AppModel persists on change).
        let backup = UserDefaults.standard.data(forKey: Self.preferencesKey)
        UserDefaults.standard.removeObject(forKey: Self.preferencesKey)
        preferencesBackup = backup
        let model = AppModel()
        _model = State(initialValue: model)
        ScreenRegistry.entry(for: launch.route)?.setup(model)
    }

    var body: some View {
        Group {
            if let entry = ScreenRegistry.entry(for: launch.route) {
                entry.make()
            } else {
                Text("Unknown route '\(launch.route)'. Known: \(ScreenRegistry.names.joined(separator: ", "))")
                    .padding()
            }
        }
        .environment(model)
        .frame(width: launch.size.width, height: launch.size.height)
        .preferredColorScheme(launch.theme)
        .background(WindowCapture(launch: launch, restore: preferencesBackup))
    }
}

/// Invisible helper that sizes the window, waits, captures and quits.
private struct WindowCapture: NSViewRepresentable {
    let launch: DebugLaunch
    let restore: Data?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            guard let window = view?.window else { fail("no window") }
            // Borderless: window content == window frame, no title bar inset, exactly <size> points.
            window.styleMask = [.borderless]
            window.setContentSize(launch.size)
            window.center()
            window.makeKeyAndOrderFront(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + launch.delay) {
                capture(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private func capture(_ window: NSWindow) {
        guard let content = window.contentView else { fail("no content view") }
        let bounds = content.bounds
        // 1x bitmap regardless of the display's backing scale.
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(launch.size.width), pixelsHigh: Int(launch.size.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { fail("bitmap") }
        rep.size = bounds.size
        if launch.capture == "window", let image = windowServerImage(of: window) {
            rep.size = bounds.size
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            NSGraphicsContext.current?.cgContext.draw(image, in: CGRect(origin: .zero, size: launch.size))
            NSGraphicsContext.restoreGraphicsState()
        } else {
            content.cacheDisplay(in: bounds, to: rep)
        }
        guard let png = rep.representation(using: .png, properties: [:]) else { fail("png") }
        // The app is sandboxed: it can only write inside its container, so the PNG goes to the
        // container's tmp directory under the requested file name. Scripts/app-shot.sh copies it out.
        let contained = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(launch.output.lastPathComponent)
        do { try png.write(to: contained) } catch { fail("write \(contained.path): \(error)") }
        let report = "screenshot: container=\(contained.path) "
            + "content=\(Int(bounds.width))x\(Int(bounds.height)) window=\(Int(window.frame.width))x\(Int(window.frame.height))\n"
        FileHandle.standardError.write(Data(report.utf8))
        finish(0)
    }

    /// Composite of our own window as the WindowServer drew it (includes blur/materials, Metal, Map).
    /// Own-window capture needs no screen-recording permission. Looked up dynamically because the
    /// symbol is deprecated in recent SDKs.
    private func windowServerImage(of window: NSWindow) -> CGImage? {
        typealias Fn = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
        guard let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGWindowListCreateImage") else { return nil }
        let fn = unsafeBitCast(sym, to: Fn.self)
        let optionIncludingWindow: UInt32 = 1 << 3
        let boundsIgnoreFraming: UInt32 = 1 << 0
        let nominalResolution: UInt32 = 1 << 4
        return fn(.null, optionIncludingWindow, UInt32(window.windowNumber), boundsIgnoreFraming | nominalResolution)?.takeRetainedValue()
    }

    private func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("debug harness: \(message)\n".utf8))
        finish(1)
    }

    private func finish(_ code: Int32) -> Never {
        let key = "plan.preferences"
        if let restore { UserDefaults.standard.set(restore, forKey: key) } else { UserDefaults.standard.removeObject(forKey: key) }
        UserDefaults.standard.synchronize()
        exit(code)
    }
}
