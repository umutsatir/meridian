import AppKit
import SwiftUI

/// CSS `backdrop-filter: blur(40px) saturate(1.6)` for real: a Core Animation backdrop layer with a gaussian blur
/// and a saturation filter (the same layer NSVisualEffectView uses internally, but with the canvas numbers instead of
/// a fixed system material). Looked up at runtime; if the classes are not there the view falls back to
/// `NSVisualEffectView(.underWindowBackground, withinWindow)` so the surface still blurs.
struct MRBackdrop: NSViewRepresentable {
    var blur: CGFloat = MRGlass.blur
    var saturation: Double = MRGlass.saturation

    func makeNSView(context: Context) -> NSView {
        if let v = BackdropView.make(blur: blur, saturation: saturation) { return v }
        let v = NSVisualEffectView()
        v.material = .underWindowBackground
        v.blendingMode = .withinWindow
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    final class BackdropView: NSView {
        static func make(blur: CGFloat, saturation: Double) -> BackdropView? {
            guard let layerClass = NSClassFromString("CABackdropLayer") as? CALayer.Type,
                  let filterClass = NSClassFromString("CAFilter") as? NSObject.Type else { return nil }
            let sel = NSSelectorFromString("filterWithType:")
            guard filterClass.responds(to: sel) else { return nil }
            func filter(_ type: String, _ set: (NSObject) -> Void) -> NSObject? {
                guard let f = filterClass.perform(sel, with: type)?.takeUnretainedValue() as? NSObject else { return nil }
                set(f); return f
            }
            guard let sat = filter("colorSaturate", { $0.setValue(saturation, forKey: "inputAmount") }),
                  let gauss = filter("gaussianBlur", { $0.setValue(blur, forKey: "inputRadius"); $0.setValue(true, forKey: "inputNormalizeEdges") })
            else { return nil }
            let v = BackdropView()
            v.wantsLayer = true
            let l = layerClass.init()
            l.setValue(true, forKey: "windowServerAware")
            l.setValue(1.0, forKey: "scale")
            l.setValue("meridian-\(UUID().uuidString)", forKey: "groupName")
            l.setValue([sat, gauss], forKey: "filters")
            v.layer = l
            return v
        }
        override var isFlipped: Bool { true }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
