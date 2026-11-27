import CoreGraphics
import Foundation
import MeridianCore

/// Pure logic of the cruise "follow" camera (Google Maps style): where the camera looks, how far, how it is rotated, and
/// when following starts and stops. No UI and no clock: the view feeds it the plane position of the current frame, so the
/// arithmetic is unit-tested.
///
/// Coordinates: *plane* coordinates are the Mercator plane of `EuropeProjection` (1 plane unit = 1 pt at scale 1). A
/// `FollowCamera` maps the plane to the screen: the plane point `centerP` is drawn at `pivot`, the plane is scaled by `scale`
/// and rotated so that compass direction `bearing` points up the screen (0 = north up).
public struct FollowCameraModel: Equatable, Sendable {
    public enum Orientation: String, Sendable { case northUp, headingUp }
    public enum Engine: Sendable { case appleMaps, illustrated }

    // MARK: State

    public var following = true
    public var orientation: Orientation = .northUp
    /// Plane scale the user chose; `nil` = the default that fits the route.
    public var scale: Double?
    /// Plane point the free camera looks at (set while `following` is false).
    public var freeCenterP: CGPoint?
    /// Bearing the free camera keeps (heading-up: the last bearing before the user let go).
    public var freeBearing = 0.0

    public init(following: Bool = true, orientation: Orientation = .northUp, scale: Double? = nil) {
        self.following = following; self.orientation = orientation; self.scale = scale
    }

    // MARK: Zoom <-> scale (logarithmic)

    /// Plane scale range. Apple Maps: whole world (about 15 000 km across 1280 pt) down to about 1 km across; the
    /// illustrated vector map is allowed far in as well, its data is coarse but crisp.
    public static func scaleRange(_ engine: Engine) -> ClosedRange<Double> {
        switch engine {
        case .appleMaps: 0.3...6000
        case .illustrated: 0.3...120
        }
    }

    public static func clamp(_ s: Double, _ engine: Engine) -> Double {
        let r = scaleRange(engine)
        guard s.isFinite, s > 0 else { return 1 }
        return min(r.upperBound, max(r.lowerBound, s))
    }

    /// Slider position 0...1 (logarithmic over the whole range) to plane scale.
    public static func scale(forK k: Double, _ engine: Engine) -> Double {
        let r = scaleRange(engine)
        let t = min(1, max(0, k.isFinite ? k : 0))
        return r.lowerBound * pow(r.upperBound / r.lowerBound, t)
    }

    public static func k(forScale s: Double, _ engine: Engine) -> Double {
        let r = scaleRange(engine)
        let c = clamp(s, engine)
        return log(c / r.lowerBound) / log(r.upperBound / r.lowerBound)
    }

    /// Factor of one `+` / `-` press.
    public static let step = 1.7

    /// The scale in effect: the user's, else the route-fit default.
    public func effectiveScale(fit: Double, _ engine: Engine) -> Double {
        Self.clamp(scale ?? (orientation == .headingUp ? max(fit, Self.headingUpDefaultScale) : fit), engine)
    }

    /// Heading up is a "what is ahead of me" view (Google navigation): by default much closer than the whole-route fit.
    public static let headingUpDefaultScale = followDefaultScale
    /// The default follow zoom: city / district scale, about 25 to 45 km across a window (see `groundMetresPerPoint`).
    public static let followDefaultScale = 80.0

    /// Metres of ground per screen point at plane scale `scale` and `latitude` (Mercator: 1 plane unit is R cos(lat) / k metres).
    public static func groundMetresPerPoint(scale: Double, latitude: Double) -> Double {
        6_378_137.0 * cos(latitude * .pi / 180) / (EuropeProjection.k * max(scale, 1e-9))
    }

    /// Following starts (or restarts with Recenter): the given orientation and the default close zoom.
    public mutating func applyFollowDefaults(orientation preferred: Orientation) {
        orientation = preferred
        scale = preferred == .headingUp ? nil : Self.followDefaultScale
        following = true
        freeCenterP = nil
    }

    /// Apple Maps refuses to rotate when the camera is higher than about 1.1 million metres (it keeps north up that far
    /// out). Below this plane scale the rotation is therefore dropped (north up), like Apple Maps does. `viewHeight` in
    /// points, latitude in degrees; 1.94 is MapKit's camera distance per visible metre of height.
    public static func minRotationScale(viewHeight: Double, latitude: Double) -> Double {
        let cameraDistanceLimit = 1.05e6, ratio = 1.94, earthRadius = 6_378_137.0
        return ratio * viewHeight * earthRadius * cos(latitude * .pi / 180) / (EuropeProjection.k * cameraDistanceLimit)
    }

    public mutating func zoom(by factor: Double, fit: Double, _ engine: Engine) {
        guard factor.isFinite, factor > 0 else { return }
        scale = Self.clamp(effectiveScale(fit: fit, engine) * factor, engine)
    }
    public mutating func setK(_ k: Double, _ engine: Engine) { scale = Self.scale(forK: k, engine) }

    /// Wheel / two-finger scroll factor for a vertical delta (positive = zoom in).
    public static func wheelFactor(delta: Double) -> Double { exp(max(-60, min(60, delta)) * 0.012) }

    public func canZoomIn(fit: Double, _ e: Engine) -> Bool { effectiveScale(fit: fit, e) < Self.scaleRange(e).upperBound * 0.999 }
    public func canZoomOut(fit: Double, _ e: Engine) -> Bool { effectiveScale(fit: fit, e) > Self.scaleRange(e).lowerBound * 1.001 }

    // MARK: Tilt (the "navigation" look)

    /// Tilt of the heading-up follow camera once it is close to the ground, degrees.
    public static let followPitch = 58.0
    /// The tilt fades in between these plane scales: far out the map stays flat (Apple Maps cannot tilt a high camera).
    public static let pitchScales = (flat: 14.0, full: 44.0)

    /// The tilt the camera should have: only while following heading-up on Apple Maps, and only close to the ground.
    /// A free camera (after a drag) is flat, so panning and zooming work in plain map coordinates.
    public func targetPitch(scale: Double, engine: Engine) -> Double {
        guard following, orientation == .headingUp, engine == .appleMaps else { return 0 }
        let u = min(1, max(0, (log(scale) - log(Self.pitchScales.flat)) / (log(Self.pitchScales.full) - log(Self.pitchScales.flat))))
        return Self.followPitch * u * u * (3 - 2 * u)
    }

    // MARK: Layout

    /// Where the plane sits on screen. North up: where the canvas puts it (45 % from the top, near the centre). Heading up (Google navigation): in the lower
    /// part (72 %) so most of the screen shows what is ahead.
    public static func pivotFraction(headUp: Bool) -> Double { headUp ? 0.72 : 0.45 }

    public static func pivot(size: CGSize, fraction: Double) -> CGPoint { CGPoint(x: size.width / 2, y: size.height * fraction) }

    // MARK: Follow state machine

    /// Pan, pinch-pan or any manual camera move: following stops (Google Maps) and the camera stays where it is.
    public mutating func userMoved(camera: FollowCamera) {
        guard following else { return }
        following = false
        freeCenterP = camera.centerP
        freeBearing = camera.bearing
    }

    /// The Recenter button / `F` while free: the camera glides back to the plane and follows again.
    public mutating func recenter() { following = true; freeCenterP = nil }

    /// `F` / the Follow button.
    public mutating func toggleFollow(camera: FollowCamera) {
        if following { userMoved(camera: camera) } else { recenter() }
    }

    public mutating func toggleOrientation() { orientation = orientation == .northUp ? .headingUp : .northUp }

    /// Free camera shifted by a drag of `translation` screen points (the map follows the pointer).
    public mutating func pan(by translation: CGSize, camera: FollowCamera) {
        guard let c = freeCenterP else { return }
        // the plane point under the pivot moves opposite to the drag, in map space (undo the rotation)
        let d = FollowCamera.rotate(CGPoint(x: -translation.width, y: -translation.height), degrees: camera.bearing)
        freeCenterP = CGPoint(x: c.x + d.x / camera.scale, y: c.y + d.y / camera.scale)
    }

    /// Zoom while the camera is free: keeps the plane point under `anchor` fixed (cursor / pinch centre). While following
    /// the plane stays at the pivot, so nothing to do.
    public mutating func keepAnchor(_ anchor: CGPoint, camera old: FollowCamera, newScale: Double) {
        guard !following else { return }
        let ap = old.plane(fromScreen: anchor)
        let off = FollowCamera.rotate(CGPoint(x: (anchor.x - old.pivot.x) / newScale, y: (anchor.y - old.pivot.y) / newScale), degrees: old.bearing)
        freeCenterP = CGPoint(x: ap.x - off.x, y: ap.y - off.y)
    }

    // MARK: Orientation targets

    /// Compass direction that should point up: 0 for north up, the plane's heading for heading up, the held bearing while free.
    public func targetBearing(heading: Double) -> Double {
        if !following { return orientation == .headingUp ? freeBearing : 0 }
        return orientation == .headingUp ? heading : 0
    }

    // MARK: Geometry

    /// Direction of travel on the Mercator plane at route fraction `f`, degrees clockwise from north.
    public static func planeHeading(from a: Coordinate, to b: Coordinate, fraction f: Double) -> Double {
        let f0 = max(0, min(1, f) - 0.004), f1 = min(1, max(0, f) + 0.004)
        let p0 = EuropeProjection.xy(Geo.interpolate(from: a, to: b, fraction: f0))
        let p1 = EuropeProjection.xy(Geo.interpolate(from: a, to: b, fraction: max(f1, f0 + 0.004)))
        let dx = Double(p1.x - p0.x), dy = Double(p1.y - p0.y)
        guard abs(dx) + abs(dy) > 1e-9 else { return 0 }
        return FollowCamera.normalize(atan2(dx, -dy) * 180 / .pi)
    }

    // MARK: Smoothing

    /// Fraction of the remaining distance covered after `dt` for an exponential approach with time constant `tau`.
    public static func blend(dt: Double, tau: Double) -> Double { tau <= 0 ? 1 : 1 - exp(-max(0, dt) / tau) }

    /// Moves angle `a` towards `b` along the shortest way round.
    public static func approachAngle(_ a: Double, to b: Double, dt: Double, tau: Double) -> Double {
        FollowCamera.normalize(a + FollowCamera.signedDelta(from: a, to: b) * blend(dt: dt, tau: tau))
    }
}

// MARK: - FollowCamera

public struct FollowCamera: Equatable, Sendable {
    public var centerP: CGPoint
    public var scale: Double
    public var bearing: Double
    public var pivot: CGPoint
    public var size: CGSize
    /// Tilt of the camera away from straight down, degrees (0 = the flat top-down camera all the plane maths here describes).
    /// A tilted camera is only drawn by Apple Maps; overlays then ask the map where things are (`MapProjector`).
    public var pitch = 0.0

    public init(centerP: CGPoint, scale: Double, bearing: Double, pivot: CGPoint, size: CGSize, pitch: Double = 0) {
        self.centerP = centerP; self.scale = scale; self.bearing = bearing; self.pivot = pivot; self.size = size; self.pitch = pitch
    }

    /// 0..<360
    public static func normalize(_ d: Double) -> Double { let r = d.truncatingRemainder(dividingBy: 360); return r < 0 ? r + 360 : r }
    /// Shortest signed turn from `a` to `b`, in (-180, 180].
    public static func signedDelta(from a: Double, to b: Double) -> Double {
        var d = (b - a).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 } else if d <= -180 { d += 360 }
        return d
    }

    /// Clockwise (on screen, y down) rotation by `degrees`.
    public static func rotate(_ p: CGPoint, degrees: Double) -> CGPoint {
        let a = degrees * .pi / 180, c = cos(a), s = sin(a)
        return CGPoint(x: p.x * c - p.y * s, y: p.x * s + p.y * c)
    }

    public func screen(_ p: CGPoint) -> CGPoint {
        let d = FollowCamera.rotate(CGPoint(x: (p.x - centerP.x) * scale, y: (p.y - centerP.y) * scale), degrees: -bearing)
        return CGPoint(x: pivot.x + d.x, y: pivot.y + d.y)
    }

    public func screen(_ c: Coordinate) -> CGPoint { screen(EuropeProjection.xy(c)) }

    public func plane(fromScreen s: CGPoint) -> CGPoint {
        let d = FollowCamera.rotate(CGPoint(x: s.x - pivot.x, y: s.y - pivot.y), degrees: bearing)
        return CGPoint(x: centerP.x + d.x / scale, y: centerP.y + d.y / scale)
    }

    /// Plane point at the middle of the view (what the map engine centres on).
    public var viewCenterP: CGPoint { plane(fromScreen: CGPoint(x: size.width / 2, y: size.height / 2)) }
    public var viewCenter: Coordinate { EuropeProjection.coordinate(viewCenterP) }
}

public extension EuropeProjection {
    /// Inverse of `xy`.
    static func coordinate(_ p: CGPoint) -> Coordinate {
        let rr = Double.pi / 180
        let myf1 = log(tan(.pi / 4 + lat1 * rr / 2))
        return Coordinate(latitude: (2 * atan(exp(myf1 - Double(p.y) / k)) - .pi / 2) / rr, longitude: Double(p.x) / (k * rr) + lon0)
    }
}

// MARK: - Per-frame state

/// The smoothed camera state between frames. `advance` is called once per rendered frame with the plane position computed
/// from the clock of that frame. While following, the camera sits exactly on the plane (no lag); only the *changes*
/// (recenter, orientation switch, zoom steps, heading turns) are eased.
public struct FollowCameraState: Equatable, Sendable {
    public var bearing = 0.0
    public var heading = 0.0
    public var pivotFraction = FollowCameraModel.pivotFraction(headUp: false)
    public var logScale = 0.0
    /// FollowCamera centre minus plane position (plane units): decays to zero while following, which is the glide back.
    public var offset = CGPoint.zero
    public var pitch = 0.0
    public var initialized = false

    public static let bearingTau = 0.18, headingTau = 0.3, pivotTau = 0.2, scaleTau = 0.14, recenterTau = 0.30, pitchTau = 0.32

    public init() {}

    /// `snapRotation` skips the easing of turns (Reduce Motion).
    public mutating func advance(model: FollowCameraModel, planeP: CGPoint, heading rawHeading: Double, fit: Double,
                                 engine: FollowCameraModel.Engine, size: CGSize, dt: Double, snapRotation: Bool = false,
                                 rotationMinScale: Double = 0, scripted: (scale: Double, pitch: Double)? = nil) -> FollowCamera {
        let targetScale = model.effectiveScale(fit: fit, engine)
        let targetPivot = FollowCameraModel.pivotFraction(headUp: scripted != nil || model.orientation == .headingUp)
        if !initialized {
            initialized = true
            heading = rawHeading; logScale = log(targetScale); pivotFraction = targetPivot
            bearing = model.targetBearing(heading: rawHeading)
            offset = .zero
            pitch = model.targetPitch(scale: targetScale, engine: engine)
        }
        heading = FollowCameraModel.approachAngle(heading, to: rawHeading, dt: dt, tau: snapRotation ? 0 : Self.headingTau)
        if let scripted {
            // a scripted move (take-off): the caller flies scale and tilt, the camera looks along the heading and sits on the plane
            bearing = heading; pivotFraction = targetPivot; logScale = log(max(scripted.scale, 1e-6)); pitch = scripted.pitch
            offset = .zero
            return FollowCamera(centerP: planeP, scale: scripted.scale, bearing: bearing,
                                pivot: FollowCameraModel.pivot(size: size, fraction: pivotFraction), size: size, pitch: pitch)
        }
        bearing = FollowCameraModel.approachAngle(bearing, to: model.targetBearing(heading: heading), dt: dt, tau: snapRotation ? 0 : Self.bearingTau)
        pivotFraction += (targetPivot - pivotFraction) * FollowCameraModel.blend(dt: dt, tau: Self.pivotTau)
        logScale += (log(targetScale) - logScale) * FollowCameraModel.blend(dt: dt, tau: Self.scaleTau)
        let scale = exp(logScale)
        if scale < rotationMinScale { bearing = 0 }      // too far out to rotate (Apple Maps): north up, no easing
        pitch += (model.targetPitch(scale: scale, engine: engine) - pitch) * FollowCameraModel.blend(dt: dt, tau: snapRotation ? 0 : Self.pitchTau)
        if pitch < 0.05 { pitch = 0 }

        let center: CGPoint
        if model.following {
            let k = exp(-max(0, dt) / Self.recenterTau)
            offset = CGPoint(x: offset.x * k, y: offset.y * k)
            if abs(offset.x) + abs(offset.y) < 1e-6 / scale { offset = .zero }
            center = CGPoint(x: planeP.x + offset.x, y: planeP.y + offset.y)
        } else {
            center = model.freeCenterP ?? planeP
            offset = CGPoint(x: center.x - planeP.x, y: center.y - planeP.y)
        }
        return FollowCamera(centerP: center, scale: scale, bearing: bearing,
                      pivot: FollowCameraModel.pivot(size: size, fraction: pivotFraction), size: size, pitch: pitch)
    }

    /// The plane marker's angle on screen: its heading relative to the up direction.
    public func markerRotation(_ camera: FollowCamera) -> Double { FollowCamera.signedDelta(from: camera.bearing, to: heading) }
}
