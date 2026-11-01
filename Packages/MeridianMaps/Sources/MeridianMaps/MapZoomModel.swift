import CoreGraphics
import Foundation

/// Pure zoom state of the World map (globe and flat). No UI: gestures, buttons and keys all go through these functions,
/// so the arithmetic is unit-tested.
///
/// The model is an affine map from "zoom 1" screen coordinates `p` (where the canvas layout puts the map) to the zoomed
/// screen coordinates `q = p * scale + offset`. `MapZoomModel()` is the identity, so zoom 1 is the canvas layout exactly.
public struct MapZoomModel: Equatable, Sendable {
    public static let minScale = 0.6
    public static let maxScale = 6.0
    public static let range: ClosedRange<Double> = minScale...maxScale
    /// Factor of one `+` / `-` button or key press.
    public static let step = 1.5

    public var scale: Double
    public var offset: CGPoint

    public init(scale: Double = 1, offset: CGPoint = .zero) {
        self.scale = Self.clampScale(scale)
        self.offset = offset
    }

    public static func clampScale(_ s: Double) -> Double {
        guard s.isFinite else { return 1 }
        return min(maxScale, max(minScale, s))
    }

    public var isDefault: Bool { scale == 1 && offset == .zero }
    public var canZoomIn: Bool { scale < Self.maxScale - 1e-9 }
    public var canZoomOut: Bool { scale > Self.minScale + 1e-9 }

    // MARK: transform

    /// Zoom-1 point -> zoomed screen point.
    public func apply(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * scale + offset.x, y: p.y * scale + offset.y) }
    /// Zoomed screen point -> zoom-1 point.
    public func invert(_ q: CGPoint) -> CGPoint { CGPoint(x: (q.x - offset.x) / scale, y: (q.y - offset.y) / scale) }

    // MARK: zoom

    /// Multiplies the scale by `factor` (clamped to the range) keeping the content under screen point `anchor` fixed:
    /// the point of the map that is under the cursor stays under the cursor.
    public func zoomed(by factor: Double, about anchor: CGPoint) -> MapZoomModel {
        guard factor.isFinite, factor > 0 else { return self }
        return zoomed(to: scale * factor, about: anchor)
    }

    public func zoomed(to newScale: Double, about anchor: CGPoint) -> MapZoomModel {
        let s = Self.clampScale(newScale)
        let k = s / scale
        // q = p*scale + o fixed at `anchor`  =>  o' = anchor - (anchor - o) * k
        return MapZoomModel(scale: s, offset: CGPoint(x: anchor.x - (anchor.x - offset.x) * k, y: anchor.y - (anchor.y - offset.y) * k))
    }

    /// Pinch: `self` is the state when the pinch began, `magnification` the gesture's cumulative factor (1 = no change).
    public func pinched(magnification: Double, about anchor: CGPoint) -> MapZoomModel { zoomed(by: magnification, about: anchor) }

    public func steppedIn(about anchor: CGPoint) -> MapZoomModel { zoomed(by: Self.step, about: anchor) }
    public func steppedOut(about anchor: CGPoint) -> MapZoomModel { zoomed(by: 1 / Self.step, about: anchor) }

    /// Scroll-wheel zoom factor for a vertical scroll delta (positive = scroll up = zoom in). `precise` is a trackpad.
    public static func wheelFactor(deltaY: Double, precise: Bool) -> Double {
        let k = precise ? 0.01 : 0.05
        return exp(max(-60, min(60, deltaY)) * k)
    }

    /// Back to the default view (zoom 1, canvas layout).
    public func reset() -> MapZoomModel { MapZoomModel() }

    public func panned(by d: CGSize) -> MapZoomModel { MapZoomModel(scale: scale, offset: CGPoint(x: offset.x + d.width, y: offset.y + d.height)) }

    // MARK: limits

    /// Flat map: keeps the world rectangle `content` (zoom-1 coordinates) from leaving the viewport. When the zoomed map is
    /// larger than the viewport its edges stop at the viewport edges; when it is smaller it stays fully inside.
    public func clamped(toRect content: CGRect, viewport: CGSize) -> MapZoomModel {
        MapZoomModel(scale: scale, offset: CGPoint(x: Self.clampAxis(o: offset.x, a: content.minX * scale, b: content.maxX * scale, v: viewport.width),
                                                  y: Self.clampAxis(o: offset.y, a: content.minY * scale, b: content.maxY * scale, v: viewport.height)))
    }

    private static func clampAxis(o: Double, a: Double, b: Double, v: Double) -> Double {
        // content spans [a + o, b + o]
        let lo: Double, hi: Double
        if b - a >= v { lo = v - b; hi = -a } else { lo = -a; hi = v - b }
        return min(max(o, lo), hi)
    }

    /// Globe: the sphere (centre `center`, radius `radius`, zoom-1 coordinates) may drift away from its canvas position only
    /// as far as the extra size gained by zooming in, so zoom 1 (and below) always shows the globe where the canvas has it.
    public func clamped(toGlobeCenter center: CGPoint, radius: Double) -> MapZoomModel {
        let home = apply(center)
        let dx = home.x - center.x, dy = home.y - center.y
        let limit = max(0, scale - 1) * radius
        let len = (dx * dx + dy * dy).squareRoot()
        guard len > limit else { return self }
        let f = len == 0 ? 0 : limit / len
        return MapZoomModel(scale: scale, offset: CGPoint(x: offset.x - dx * (1 - f), y: offset.y - dy * (1 - f)))
    }

    // MARK: derived quantities

    /// Drag-to-rotate speed multiplier: the globe turns slower the closer you are (inverse to the scale).
    public var rotationFactor: Double { 1 / scale }

    /// How many airport labels to draw: `base` at zoom 1, fewer far away, all of them when close.
    public func labelBudget(total: Int, base: Int = 5) -> Int {
        let n: Int
        switch scale {
        case ..<0.8: n = max(1, base - 2)
        case ..<1.15: n = base
        case ..<1.6: n = base + 1
        case ..<2.2: n = base + 2
        default: n = total
        }
        return min(total, max(0, n))
    }

    /// Pin and route-width multiplier: 1 at zoom 1, grows slowly when close, shrinks a little when far.
    public var markScale: Double { min(1.7, max(0.75, pow(scale, 0.3))) }
}
