import XCTest
import CoreGraphics
import MeridianCore
@testable import MeridianMaps

final class FollowCameraModelTests: XCTestCase {
    private let size = CGSize(width: 1280, height: 800)
    private let lhr = Coordinate(latitude: 51.47, longitude: -0.4543), cdg = Coordinate(latitude: 49.0097, longitude: 2.5479)

    private func near(_ a: CGPoint, _ b: CGPoint, _ eps: Double = 1e-6, line: UInt = #line) {
        XCTAssertEqual(a.x, b.x, accuracy: eps, line: line); XCTAssertEqual(a.y, b.y, accuracy: eps, line: line)
    }
    private func cam(_ c: CGPoint, scale: Double = 4, bearing: Double = 0, frac: Double = 0.56) -> FollowCamera {
        FollowCamera(centerP: c, scale: scale, bearing: bearing, pivot: FollowCameraModel.pivot(size: size, fraction: frac), size: size)
    }
    private func step(_ st: inout FollowCameraState, _ m: FollowCameraModel, _ p: CGPoint, heading: Double = 120, fit: Double = 3,
                      snap: Bool = false) -> FollowCamera {
        st.advance(model: m, planeP: p, heading: heading, fit: fit, engine: .appleMaps, size: size, dt: 1 / 30, snapRotation: snap)
    }

    // MARK: target / geometry

    func testPlaneIsDrawnAtPivotWhenFollowing() {
        let p = EuropeProjection.xy(lhr)
        for b in [0.0, 37, 90, 181, 270] { near(cam(p, bearing: b).screen(p), CGPoint(x: 640, y: 800 * 0.56)) }
    }

    func testNorthUpOffsetsAheadAreAbove() {
        let p = EuropeProjection.xy(lhr)
        let ahead = CGPoint(x: p.x, y: p.y - 10)
        XCTAssertLessThan(cam(p).screen(ahead).y, 800 * 0.56)
    }

    func testHeadingUpPutsDirectionOfTravelStraightUp() {
        let p = EuropeProjection.xy(Geo.interpolate(from: lhr, to: cdg, fraction: 0.4))
        let h = FollowCameraModel.planeHeading(from: lhr, to: cdg, fraction: 0.4)
        let q = EuropeProjection.xy(Geo.interpolate(from: lhr, to: cdg, fraction: 0.41))
        let c = cam(p, bearing: h)
        let s = c.screen(q)
        XCTAssertEqual(s.x, c.pivot.x, accuracy: 0.5)
        XCTAssertLessThan(s.y, c.pivot.y)
    }

    func testHeadingEastRotatesEastToTop() {
        let c = cam(CGPoint(x: 100, y: 100), scale: 1, bearing: 90)
        near(c.screen(CGPoint(x: 110, y: 100)), CGPoint(x: c.pivot.x, y: c.pivot.y - 10), 1e-9)
    }

    func testScreenPlaneRoundTrip() {
        let c = cam(CGPoint(x: 1234, y: 567), scale: 12.5, bearing: 143.5)
        let pt = CGPoint(x: 301, y: 88)
        near(c.plane(fromScreen: c.screen(pt)), pt, 1e-7)
    }

    func testViewCenterIsAheadOfPlaneInHeadingUp() {
        let p = CGPoint(x: 500, y: 500)
        let v = cam(p, scale: 2, bearing: 0, frac: 0.66).viewCenterP
        XCTAssertEqual(v.x, 500, accuracy: 1e-9)
        XCTAssertEqual(v.y, 500 - (800 * 0.16) / 2, accuracy: 1e-9)
        let e = cam(p, scale: 2, bearing: 90, frac: 0.66).viewCenterP
        XCTAssertEqual(e.y, 500, accuracy: 1e-9)
        XCTAssertGreaterThan(e.x, 500)
    }

    func testCoordinateInverse() {
        let c = EuropeProjection.coordinate(EuropeProjection.xy(cdg))
        XCTAssertEqual(c.latitude, cdg.latitude, accuracy: 1e-9)
        XCTAssertEqual(c.longitude, cdg.longitude, accuracy: 1e-9)
    }

    func testPlaneHeadingMatchesGeography() {
        let o = Coordinate(latitude: 0, longitude: 0)
        XCTAssertEqual(FollowCameraModel.planeHeading(from: o, to: Coordinate(latitude: 0, longitude: 20), fraction: 0.5), 90, accuracy: 0.1)
        XCTAssertEqual(FollowCameraModel.planeHeading(from: o, to: Coordinate(latitude: 20, longitude: 0), fraction: 0.5), 0, accuracy: 0.1)
        XCTAssertEqual(FollowCameraModel.planeHeading(from: Coordinate(latitude: 20, longitude: 0), to: o, fraction: 0.99), 180, accuracy: 0.1)
        let h = FollowCameraModel.planeHeading(from: lhr, to: cdg, fraction: 0.5)
        XCTAssertTrue((100...170).contains(h), "\(h)")
    }

    // MARK: zoom

    func testZoomMappingIsLogarithmicAndCoversWholeRange() {
        for e in [FollowCameraModel.Engine.appleMaps, .illustrated] {
            let r = FollowCameraModel.scaleRange(e)
            XCTAssertEqual(FollowCameraModel.scale(forK: 0, e), r.lowerBound, accuracy: 1e-9)
            XCTAssertEqual(FollowCameraModel.scale(forK: 1, e), r.upperBound, accuracy: 1e-6)
            let mid = FollowCameraModel.scale(forK: 0.5, e)
            XCTAssertEqual(mid, (r.lowerBound * r.upperBound).squareRoot(), accuracy: mid * 1e-9)
            for k in stride(from: 0.0, through: 1.0, by: 0.125) {
                XCTAssertEqual(FollowCameraModel.k(forScale: FollowCameraModel.scale(forK: k, e), e), k, accuracy: 1e-9)
            }
        }
    }

    func testAppleRangeReachesStreetAndWorldScale() {
        func widthKm(_ s: Double) -> Double { 1280 / (EuropeProjection.k * s) * 6371 * cos(51 * .pi / 180) }
        XCTAssertLessThanOrEqual(widthKm(FollowCameraModel.scaleRange(.appleMaps).upperBound), 1.2)
        XCTAssertGreaterThanOrEqual(widthKm(FollowCameraModel.scaleRange(.appleMaps).lowerBound), 5000)
    }

    func testStepsAndClamp() {
        var m = FollowCameraModel()
        XCTAssertEqual(m.effectiveScale(fit: 3, .appleMaps), 3)
        m.zoom(by: FollowCameraModel.step, fit: 3, .appleMaps)
        XCTAssertEqual(m.scale!, 3 * 1.7, accuracy: 1e-9)
        for _ in 0..<60 { m.zoom(by: FollowCameraModel.step, fit: 3, .appleMaps) }
        XCTAssertEqual(m.scale, 6000)
        XCTAssertFalse(m.canZoomIn(fit: 3, .appleMaps))
        for _ in 0..<80 { m.zoom(by: 1 / FollowCameraModel.step, fit: 3, .appleMaps) }
        XCTAssertEqual(m.scale!, 0.3, accuracy: 1e-12)
        XCTAssertFalse(m.canZoomOut(fit: 3, .appleMaps))
        XCTAssertTrue(m.canZoomIn(fit: 3, .appleMaps))
    }

    func testZoomWhileFollowingKeepsPlaneAtPivot() {
        let p = EuropeProjection.xy(lhr)
        var st = FollowCameraState()
        var m = FollowCameraModel()
        var c = step(&st, m, p)
        for _ in 0..<40 {
            m.zoom(by: 1.1, fit: 3, .appleMaps)
            c = step(&st, m, p)
            near(c.screen(p), c.pivot, 1e-6)
        }
        XCTAssertGreaterThan(c.scale, 3)
    }

    func testFreeZoomKeepsAnchorUnderCursor() {
        let p = EuropeProjection.xy(lhr)
        var m = FollowCameraModel(following: false, scale: 4)
        m.freeCenterP = p
        let old = cam(p, scale: 4, bearing: 30)
        let anchor = CGPoint(x: 200, y: 150)
        let under = old.plane(fromScreen: anchor)
        m.keepAnchor(anchor, camera: old, newScale: 40)
        var c = old; c.centerP = m.freeCenterP!; c.scale = 40
        near(c.screen(under), anchor, 1e-6)
    }

    // MARK: follow / free state machine

    func testPanLeavesFollowAndRecenterReturns() {
        let p = EuropeProjection.xy(lhr)
        var m = FollowCameraModel()
        XCTAssertTrue(m.following)
        let c = cam(p, bearing: 0)
        m.userMoved(camera: c)
        XCTAssertFalse(m.following)
        near(m.freeCenterP!, p)
        m.pan(by: CGSize(width: 100, height: 40), camera: c)
        XCTAssertEqual(m.freeCenterP!.x, p.x - 100 / 4, accuracy: 1e-9)
        XCTAssertEqual(m.freeCenterP!.y, p.y - 40 / 4, accuracy: 1e-9)
        m.recenter()
        XCTAssertTrue(m.following)
        XCTAssertNil(m.freeCenterP)
    }

    func testPanFollowsPointerWhenRotated() {
        var m = FollowCameraModel()
        let c = cam(.zero, scale: 2, bearing: 90)
        m.userMoved(camera: c)
        let grabbed = c.plane(fromScreen: CGPoint(x: 300, y: 300))
        m.pan(by: CGSize(width: 50, height: -20), camera: c)
        var c2 = c; c2.centerP = m.freeCenterP!
        near(c2.screen(grabbed), CGPoint(x: 350, y: 280), 1e-6)
    }

    func testToggleFollowRoundTrip() {
        var m = FollowCameraModel()
        let c = cam(CGPoint(x: 1, y: 2))
        m.toggleFollow(camera: c); XCTAssertFalse(m.following)
        m.toggleFollow(camera: c); XCTAssertTrue(m.following)
        m.userMoved(camera: c); m.userMoved(camera: cam(CGPoint(x: 9, y: 9)))
        near(m.freeCenterP!, CGPoint(x: 1, y: 2))
    }

    func testFreeCameraStaysPutWhilePlaneMoves() {
        var st = FollowCameraState()
        var m = FollowCameraModel()
        let a = EuropeProjection.xy(lhr), b = EuropeProjection.xy(cdg)
        var c = step(&st, m, a)
        m.userMoved(camera: c)
        let before = c.screen(a)
        c = step(&st, m, b)
        near(c.centerP, m.freeCenterP!)
        XCTAssertNotEqual(c.screen(b).x, before.x)
    }

    func testRecenterGlidesBackAndLocksOnPlane() {
        var st = FollowCameraState()
        var m = FollowCameraModel()
        let a = EuropeProjection.xy(lhr), b = EuropeProjection.xy(cdg)
        _ = step(&st, m, a)
        m.following = false; m.freeCenterP = CGPoint(x: a.x + 80, y: a.y - 50)
        _ = step(&st, m, a)
        m.recenter()
        var last = Double.infinity
        var c = cam(.zero)
        var plane = a
        for i in 0..<240 {
            plane = CGPoint(x: a.x + (b.x - a.x) * Double(i) / 240, y: a.y + (b.y - a.y) * Double(i) / 240)
            c = step(&st, m, plane)
            let d = hypot(c.centerP.x - plane.x, c.centerP.y - plane.y)
            XCTAssertLessThanOrEqual(d, last + 1e-9)
            last = d
        }
        XCTAssertEqual(last, 0, accuracy: 1e-3)
        near(c.screen(plane), c.pivot, 1e-2)
    }

    func testFollowHasNoLagOnMovingPlane() {
        var st = FollowCameraState()
        let m = FollowCameraModel()
        var plane = EuropeProjection.xy(lhr)
        for _ in 0..<120 {
            plane.x += 3; plane.y -= 1
            let c = step(&st, m, plane, heading: 70, fit: 5)
            near(c.screen(plane), c.pivot, 1e-6)
        }
    }

    // MARK: orientation

    func testToggleOrientationAndTargets() {
        var m = FollowCameraModel()
        XCTAssertEqual(m.targetBearing(heading: 123), 0)
        m.toggleOrientation()
        XCTAssertEqual(m.orientation, .headingUp)
        XCTAssertEqual(m.targetBearing(heading: 123), 123)
        m.userMoved(camera: cam(.zero, bearing: 123))
        XCTAssertEqual(m.targetBearing(heading: 200), 123)
        m.toggleOrientation()
        XCTAssertEqual(m.targetBearing(heading: 200), 0)
    }

    func testHeadingUpDefaultIsCloserThanTheRouteFit() {
        var m = FollowCameraModel()
        XCTAssertEqual(m.effectiveScale(fit: 1.2, .appleMaps), 1.2)
        m.toggleOrientation()
        XCTAssertEqual(m.effectiveScale(fit: 1.2, .appleMaps), 80)
        XCTAssertEqual(m.effectiveScale(fit: 9, .appleMaps), 80)
        m.scale = 2                      // the user's choice always wins
        XCTAssertEqual(m.effectiveScale(fit: 9, .appleMaps), 2)
    }

    func testFollowDefaultsAreCityScaleHeadingUp() {
        var m = FollowCameraModel(following: false, orientation: .northUp, scale: 3)
        m.freeCenterP = CGPoint(x: 5, y: 5)
        m.applyFollowDefaults(orientation: .headingUp)
        XCTAssertTrue(m.following)
        XCTAssertEqual(m.orientation, .headingUp)
        XCTAssertNil(m.scale)
        XCTAssertNil(m.freeCenterP)
        let s = m.effectiveScale(fit: 2, .appleMaps)
        XCTAssertEqual(s, FollowCameraModel.followDefaultScale)
        // 20 to 45 km of ground across a 1000 to 1400 pt wide view over Europe
        for lat in [40.0, 50.0, 60.0] {
            let mpp = FollowCameraModel.groundMetresPerPoint(scale: s, latitude: lat)
            XCTAssertGreaterThan(1000 * mpp, 15_000, "lat \(lat)")
            XCTAssertLessThan(1400 * mpp, 45_000, "lat \(lat)")
        }
        // 3 to 4 times closer than the previous heading-up default (6) or more
        XCTAssertGreaterThanOrEqual(s / 6, 3)
        // rotation is allowed there (Apple Maps refuses below about 2.8)
        XCTAssertGreaterThan(s, FollowCameraModel.minRotationScale(viewHeight: 800, latitude: 50))
        // north up preference: same close zoom, north stays up
        m.applyFollowDefaults(orientation: .northUp)
        XCTAssertEqual(m.effectiveScale(fit: 2, .appleMaps), FollowCameraModel.followDefaultScale)
        XCTAssertEqual(m.targetBearing(heading: 77), 0)
    }

    func testRecenterTransitionTakesAboutHalfASecond() {
        var st = FollowCameraState()
        var m = FollowCameraModel(orientation: .northUp, scale: nil)
        _ = st.advance(model: m, planeP: .zero, heading: 90, fit: 2, engine: .appleMaps, size: size, dt: 1 / 30)
        m.applyFollowDefaults(orientation: .headingUp)
        var c = FollowCamera(centerP: .zero, scale: 1, bearing: 0, pivot: .zero, size: size)
        for _ in 0..<18 { c = st.advance(model: m, planeP: .zero, heading: 90, fit: 2, engine: .appleMaps, size: size, dt: 1 / 30, rotationMinScale: 3) }   // 0.6 s
        XCTAssertEqual(log(c.scale), log(80), accuracy: 0.12 * log(80 / 2))      // within ~12 % of the log distance
        XCTAssertEqual(c.bearing, 90, accuracy: 6)
    }

    func testRotationDroppedWhenTooFarOutForAppleMaps() {
        let minS = FollowCameraModel.minRotationScale(viewHeight: 800, latitude: 50.8)
        XCTAssertEqual(minS, 2.8, accuracy: 0.3)            // measured: MapKit rotated at 2.9 and refused at 2.7
        var st = FollowCameraState()
        var m = FollowCameraModel(); m.toggleOrientation(); m.scale = minS * 0.5
        var c = st.advance(model: m, planeP: .zero, heading: 120, fit: 3, engine: .appleMaps, size: size, dt: 1 / 30, rotationMinScale: minS)
        XCTAssertEqual(c.bearing, 0)
        m.scale = minS * 2
        for _ in 0..<90 { c = st.advance(model: m, planeP: .zero, heading: 120, fit: 3, engine: .appleMaps, size: size, dt: 1 / 30, rotationMinScale: minS) }
        XCTAssertEqual(c.bearing, 120, accuracy: 0.5)
    }

    func testPivotIsLowerInHeadingUp() {
        XCTAssertGreaterThan(FollowCameraModel.pivotFraction(headUp: true), FollowCameraModel.pivotFraction(headUp: false))
        XCTAssertGreaterThanOrEqual(FollowCameraModel.pivotFraction(headUp: true), 0.6)
        XCTAssertEqual(FollowCameraModel.pivotFraction(headUp: true), 0.72)
        XCTAssertEqual(FollowCameraModel.pivotFraction(headUp: false), 0.45)   // the canvas
    }

    func testBearingTurnsTheShortWay() {
        XCTAssertEqual(FollowCamera.signedDelta(from: 350, to: 10), 20, accuracy: 1e-9)
        XCTAssertEqual(FollowCamera.signedDelta(from: 10, to: 350), -20, accuracy: 1e-9)
        let a = FollowCameraModel.approachAngle(350, to: 10, dt: 0.1, tau: 0.2)
        XCTAssertTrue(a > 350 || a < 10)
        XCTAssertEqual(FollowCameraModel.approachAngle(0, to: 90, dt: 1, tau: 0), 90, accuracy: 1e-9)
    }

    func testHeadingUpSwitchRotatesGraduallyThenSettles() {
        var st = FollowCameraState()
        var m = FollowCameraModel()
        let p = EuropeProjection.xy(lhr)
        var c = step(&st, m, p)
        XCTAssertEqual(c.bearing, 0, accuracy: 1e-9)
        m.toggleOrientation()
        c = step(&st, m, p)
        XCTAssertTrue(c.bearing > 0 && c.bearing < 120, "\(c.bearing)")
        for _ in 0..<150 { c = step(&st, m, p) }
        XCTAssertEqual(c.bearing, 120, accuracy: 0.01)
        XCTAssertEqual(st.markerRotation(c), 0, accuracy: 0.01)
        near(c.screen(p), c.pivot, 1e-6)
    }

    func testNorthUpMarkerRotatesWithHeading() {
        var st = FollowCameraState()
        let c = step(&st, FollowCameraModel(), .zero, heading: 135)
        XCTAssertEqual(st.markerRotation(c), 135, accuracy: 1e-9)
    }

    func testReduceMotionSnapsRotation() {
        var st = FollowCameraState()
        var m = FollowCameraModel()
        _ = step(&st, m, .zero, heading: 80, snap: true)
        m.toggleOrientation()
        let c = step(&st, m, .zero, heading: 80, snap: true)
        XCTAssertEqual(c.bearing, 80, accuracy: 1e-9)
    }
}
