import AppKit
import SwiftUI

/// DEBUG pointer simulator for `--screen cards-sim` / `wallet-sim`: replays `--sim "<script>"` against the app's own window by
/// sending synthesized `NSEvent`s to it (the real cursor is untouched). Items are separated by `;`:
///   `m x,y` move  ·  `g x0,y0 x1,y1 steps` glide  ·  `c x,y` click  ·  `w sec` wait  ·  `snap name` save `<name>.png`
/// Coordinates are window-content points, origin top-left.
@MainActor
enum CardSim {
    private static var started = false
    static func run(_ script: String) {
        guard !started else { return }
        started = true
        guard let window = DebugSnap.window else { return }
        window.acceptsMouseMovedEvents = true
        let h = window.contentView?.bounds.height ?? 800
        func event(_ type: NSEvent.EventType, _ p: CGPoint) -> NSEvent? {
            NSEvent.mouseEvent(with: type, location: CGPoint(x: p.x, y: h - p.y), modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                               windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1)
        }
        func pt(_ s: Substring) -> CGPoint {
            let v = s.split(separator: ",").compactMap { Double($0) }
            return CGPoint(x: v.count > 0 ? v[0] : 0, y: v.count > 1 ? v[1] : 0)
        }
        let items = script.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        Task { @MainActor in
            for item in items {
                let parts = item.split(separator: " ").map(String.init)
                guard let cmd = parts.first else { continue }
                switch cmd {
                case "m": if let e = event(.mouseMoved, pt(Substring(parts[1]))) { window.sendEvent(e) }
                case "g":
                    let a = pt(Substring(parts[1])), b = pt(Substring(parts[2])), n = Int(parts[3]) ?? 20
                    for i in 0...n {
                        let t = Double(i) / Double(n)
                        if let e = event(.mouseMoved, CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)) { window.sendEvent(e) }
                        try? await Task.sleep(for: .milliseconds(16))
                    }
                case "c":
                    let p = pt(Substring(parts[1]))
                    if let e = event(.mouseMoved, p) { window.sendEvent(e) }
                    try? await Task.sleep(for: .milliseconds(60))
                    if let e = event(.leftMouseDown, p) { window.sendEvent(e) }
                    try? await Task.sleep(for: .milliseconds(40))
                    if let e = event(.leftMouseUp, p) { window.sendEvent(e) }
                case "w": try? await Task.sleep(for: .milliseconds(Int((Double(parts[1]) ?? 0) * 1000)))
                case "snap": DebugSnap.save(parts[1])
                case "log": FileHandle.standardError.write(Data("sim \(parts[1]) t=\(Date().timeIntervalSince1970)\n".utf8))
                default: break
                }
            }
        }
    }

    static var script: String? {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "--sim"), i + 1 < a.count else { return nil }
        return a[i + 1]
    }
}

/// Runs the `--sim` script once the route has appeared (the harness captures its final screenshot after `--delay`).
struct CardSimHost<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content.onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { if let s = CardSim.script { CardSim.run(s) } }
        }
    }
}
