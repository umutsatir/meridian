import CoreGraphics
import Foundation

/// Pure gesture -> camera arithmetic of the Home globe and the Plan map. No UI: scroll, drag, pinch, buttons and keys all go
/// through these functions so the rules are unit-tested.
///
/// The rules the owner asked for: two-finger scroll / drag only MOVES the map (pan, or turns the globe); zoom comes only from
/// pinch, the on-screen buttons, the keys and (optionally) Command + scroll.

// MARK: - Globe

/// What the Home globe looks at: the point facing the viewer and a zoom multiplier (1 = the canvas framing).
public struct GlobeCamera: Equatable, Sendable {
    /// The globe may not be turned past this latitude (the poles stay out of reach, like `GlobeView`).
    public static let latitudeLimit = 70.0
    public static let zoomRange: ClosedRange<Double> = 0.6...6.0
    /// Factor of one zoom button / key press.
    public static let step = 1.5

    public var lon: Double
    public var lat: Double
    public var zoom: Double

    public init(lon: Double, lat: Double, zoom: Double = 1) {
        self.lon = Self.wrapLongitude(lon)
        self.lat = Self.clampLatitude(lat)
        self.zoom = Self.clampZoom(zoom)
    }

    public static func wrapLongitude(_ l: Double) -> Double {
        guard l.isFinite else { return 0 }
        var x = l.truncatingRemainder(dividingBy: 360)
        if x > 180 { x -= 360 } else if x <= -180 { x += 360 }
        return x
    }
    public static func clampLatitude(_ l: Double) -> Double { l.isFinite ? min(latitudeLimit, max(-latitudeLimit, l)) : 0 }
    public static func clampZoom(_ z: Double) -> Double { z.isFinite ? min(zoomRange.upperBound, max(zoomRange.lowerBound, z)) : 1 }

    /// Degrees of longitude / latitude under one screen point at the centre of a sphere drawn with `screenRadius` points.
    public static func degreesPerPoint(screenRadius: Double) -> Double { screenRadius > 0 ? 180 / .pi / screenRadius : 0 }

    /// Pan: the content follows the fingers. Scroll delta `dx` > 0 moves the content right, so the viewing longitude decreases;
    /// dragging down shows more of the north.
    public func panned(dx: Double, dy: Double, degreesPerPoint k: Double) -> GlobeCamera {
        guard dx.isFinite, dy.isFinite, k.isFinite else { return self }
        return GlobeCamera(lon: lon - dx * k, lat: lat + dy * k, zoom: zoom)
    }

    public func zoomed(by factor: Double) -> GlobeCamera {
        guard factor.isFinite, factor > 0 else { return self }
        return GlobeCamera(lon: lon, lat: lat, zoom: zoom * factor)
    }
    public func steppedIn() -> GlobeCamera { zoomed(by: Self.step) }
    public func steppedOut() -> GlobeCamera { zoomed(by: 1 / Self.step) }
    /// Pinch: `self` is the state when the pinch began.
    public func pinched(magnification: Double) -> GlobeCamera { zoomed(by: magnification) }

    /// True when the globe was moved or zoomed away from `home` (the "Recenter" control shows).
    public func isDisplaced(from home: GlobeCamera, epsilon: Double = 0.25) -> Bool {
        abs(Self.angleDelta(lon, home.lon)) > epsilon || abs(lat - home.lat) > epsilon || abs(zoom / home.zoom - 1) > 0.01
    }
    public var canZoomIn: Bool { zoom < Self.zoomRange.upperBound - 1e-9 }
    public var canZoomOut: Bool { zoom > Self.zoomRange.lowerBound + 1e-9 }

    /// Shortest signed difference a - b in degrees.
    static func angleDelta(_ a: Double, _ b: Double) -> Double {
        var d = (a - b).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 } else if d <= -180 { d += 360 }
        return d
    }
}

// MARK: - Plan map

/// The user's view of the Plan map on top of the automatic framing (origin at the ring centre, zoom by duration).
/// The range ring and the tags are bound to the origin, so they move with the map: `pan` is the screen displacement of the origin
/// from its automatic position, `zoom` the absolute plane scale (nil = automatic).
public struct PlanMapCamera: Equatable, Sendable {
    /// Plane scale limits: from the ring (about 2.6 at the shortest flights) out to the whole world (a 1280 pt wide window).
    public static let worldZoom = 0.11
    public static let maxZoom = 8.0
    public static let step = 1.5

    public var pan: CGSize
    public var zoom: Double?

    public init(pan: CGSize = .zero, zoom: Double? = nil) { self.pan = pan; self.zoom = zoom.map { Self.clampZoom($0) } }

    public static func clampZoom(_ z: Double, minimum: Double = worldZoom) -> Double {
        z.isFinite ? min(maxZoom, max(minimum, z)) : 1
    }

    /// The user has moved or zoomed the map by hand: duration changes no longer reframe it.
    public var isManual: Bool { pan != .zero || zoom != nil }

    public func effectiveZoom(auto: Double, minimum: Double = worldZoom) -> Double { zoom.map { Self.clampZoom($0, minimum: minimum) } ?? auto }

    public func panned(by d: CGSize) -> PlanMapCamera {
        guard d.width.isFinite, d.height.isFinite else { return self }
        return PlanMapCamera(pan: CGSize(width: pan.width + d.width, height: pan.height + d.height), zoom: zoom)
    }

    /// Zoom by `factor` keeping the map point under `anchor` (screen coordinates) fixed. `autoCenter` is where the origin sits
    /// without panning, `autoZoom` the automatic plane scale.
    public func zoomed(by factor: Double, about anchor: CGPoint, autoCenter: CGPoint, autoZoom: Double, minimum: Double = worldZoom) -> PlanMapCamera {
        guard factor.isFinite, factor > 0 else { return self }
        let z0 = effectiveZoom(auto: autoZoom, minimum: minimum)
        let z1 = Self.clampZoom(z0 * factor, minimum: minimum)
        let k = z1 / z0
        let c0 = CGPoint(x: autoCenter.x + pan.width, y: autoCenter.y + pan.height)   // where the origin is now
        let c1 = CGPoint(x: anchor.x + (c0.x - anchor.x) * k, y: anchor.y + (c0.y - anchor.y) * k)
        return PlanMapCamera(pan: CGSize(width: c1.x - autoCenter.x, height: c1.y - autoCenter.y), zoom: z1)
    }

    /// Back to the automatic framing.
    public func recentered() -> PlanMapCamera { PlanMapCamera() }

    /// The "Recenter on origin" control shows when the map has slid away from the origin or is zoomed away from the framing.
    public func showsRecenter(autoZoom: Double, minPan: Double = 8) -> Bool {
        hypot(pan.width, pan.height) > minPan || (zoom.map { abs($0 / autoZoom - 1) > 0.04 } ?? false)
    }

    /// A new origin always reframes; a new duration only when the user has not moved the map.
    public func afterChange(originChanged: Bool) -> PlanMapCamera { originChanged ? PlanMapCamera() : self }

    /// How many tags to draw at all (`full` at the automatic zoom, fewer the farther out the user went; never fewer than 6).
    public static func tagBudget(full: Int, zoom: Double, autoZoom: Double) -> Int {
        guard autoZoom > 0, zoom.isFinite else { return full }
        let r = min(1, max(0.2, zoom / autoZoom))
        return min(full, max(6, Int((Double(full) * r).rounded())))
    }
}
