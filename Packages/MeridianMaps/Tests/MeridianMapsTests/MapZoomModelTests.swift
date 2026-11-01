import XCTest
import CoreGraphics
@testable import MeridianMaps

final class MapZoomModelTests: XCTestCase {
    private func near(_ a: CGPoint, _ b: CGPoint, _ eps: Double = 1e-9, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(a.x, b.x, accuracy: eps, file: file, line: line)
        XCTAssertEqual(a.y, b.y, accuracy: eps, file: file, line: line)
    }

    func testDefaultIsIdentity() {
        let m = MapZoomModel()
        XCTAssertTrue(m.isDefault)
        near(m.apply(CGPoint(x: 90, y: -50)), CGPoint(x: 90, y: -50))
    }

    func testClampsScaleToRange() {
        XCTAssertEqual(MapZoomModel().zoomed(by: 100, about: .zero).scale, 6)
        XCTAssertEqual(MapZoomModel().zoomed(by: 0.001, about: .zero).scale, 0.6)
        XCTAssertEqual(MapZoomModel(scale: 99).scale, 6)
        XCTAssertEqual(MapZoomModel(scale: .nan).scale, 1)
        XCTAssertTrue(MapZoomModel().zoomed(by: 100, about: .zero).canZoomIn == false)
        XCTAssertTrue(MapZoomModel().zoomed(by: 0.001, about: .zero).canZoomOut == false)
    }

    func testZoomKeepsAnchorFixed() {
        let anchor = CGPoint(x: 300, y: 500)
        var m = MapZoomModel()
        for f in [1.5, 1.5, 0.8, 2.0, 0.5, 3.0] {
            let underCursor = m.invert(anchor)
            m = m.zoomed(by: f, about: anchor)
            near(m.apply(underCursor), anchor, 1e-7)
        }
    }

    func testZoomKeepsAnchorFixedWhenClamped() {
        let anchor = CGPoint(x: 200, y: 100)
        let m = MapZoomModel(scale: 5).zoomed(by: 10, about: anchor)
        XCTAssertEqual(m.scale, 6)
        let under = MapZoomModel(scale: 5).invert(anchor)
        near(m.apply(under), anchor, 1e-7)
    }

    func testPinchIsRelativeToStartState() {
        let start = MapZoomModel(scale: 2, offset: CGPoint(x: -100, y: 30))
        let anchor = CGPoint(x: 640, y: 400)
        let p = start.pinched(magnification: 1.5, about: anchor)
        XCTAssertEqual(p.scale, 3, accuracy: 1e-12)
        near(p.apply(start.invert(anchor)), anchor, 1e-7)
        // a pinch back to 1 returns to the start state
        let back = p.pinched(magnification: 1 / 1.5, about: anchor)
        XCTAssertEqual(back.scale, 2, accuracy: 1e-12)
        near(back.offset, start.offset, 1e-7)
        // magnification 1 is a no-op
        XCTAssertEqual(start.pinched(magnification: 1, about: anchor), start)
    }

    func testStepsAndReset() {
        let c = CGPoint(x: 640, y: 400)
        let a = MapZoomModel().steppedIn(about: c)
        XCTAssertEqual(a.scale, 1.5)
        let b = a.steppedOut(about: c)
        XCTAssertEqual(b.scale, 1, accuracy: 1e-12)
        near(b.offset, .zero, 1e-9)
        XCTAssertEqual(a.zoomed(by: 3, about: CGPoint(x: 10, y: 10)).reset(), MapZoomModel())
        XCTAssertTrue(MapZoomModel(scale: 4, offset: CGPoint(x: 5, y: 5)).reset().isDefault)
    }

    func testWheelFactorDirectionAndSymmetry() {
        XCTAssertGreaterThan(MapZoomModel.wheelFactor(deltaY: 3, precise: false), 1)
        XCTAssertLessThan(MapZoomModel.wheelFactor(deltaY: -3, precise: false), 1)
        XCTAssertEqual(MapZoomModel.wheelFactor(deltaY: 4, precise: true) * MapZoomModel.wheelFactor(deltaY: -4, precise: true), 1, accuracy: 1e-12)
        XCTAssertEqual(MapZoomModel.wheelFactor(deltaY: 0, precise: true), 1)
        XCTAssertTrue(MapZoomModel.wheelFactor(deltaY: 1e9, precise: false).isFinite)
    }

    // The flat world rectangle the app uses: x 0...1280, y 152...(152 + 484).
    private let world = CGRect(x: 0, y: 152, width: 1280, height: 484)
    private let view = CGSize(width: 1280, height: 800)

    func testFlatClampDefaultViewIsUntouched() {
        XCTAssertEqual(MapZoomModel().clamped(toRect: world, viewport: view), MapZoomModel())
        // a larger window than the canvas also leaves zoom 1 alone
        XCTAssertEqual(MapZoomModel().clamped(toRect: world, viewport: CGSize(width: 1600, height: 1000)), MapZoomModel())
    }

    func testFlatClampStopsAtWorldEdges() {
        var m = MapZoomModel(scale: 3).panned(by: CGSize(width: 99999, height: 99999)).clamped(toRect: world, viewport: view)
        // left/top edges of the world sit on the viewport edges
        near(m.apply(CGPoint(x: world.minX, y: world.minY)), CGPoint(x: 0, y: 0))
        m = MapZoomModel(scale: 3).panned(by: CGSize(width: -99999, height: -99999)).clamped(toRect: world, viewport: view)
        near(m.apply(CGPoint(x: world.maxX, y: world.maxY)), CGPoint(x: 1280, y: 800))
        // inside the allowed band nothing changes
        let mid = MapZoomModel(scale: 3, offset: CGPoint(x: -1000, y: -500))
        XCTAssertEqual(mid.clamped(toRect: world, viewport: view), mid)
    }

    func testFlatClampKeepsSmallMapInside() {
        let m = MapZoomModel(scale: 0.6).panned(by: CGSize(width: 5000, height: -5000)).clamped(toRect: world, viewport: view)
        let tl = m.apply(CGPoint(x: world.minX, y: world.minY)), br = m.apply(CGPoint(x: world.maxX, y: world.maxY))
        XCTAssertGreaterThanOrEqual(tl.x, -1e-9); XCTAssertGreaterThanOrEqual(tl.y, -1e-9)
        XCTAssertLessThanOrEqual(br.x, 1280 + 1e-9); XCTAssertLessThanOrEqual(br.y, 800 + 1e-9)
    }

    func testFlatClampFollowsWindowResize() {
        // panned to the far right in a 1280-wide window (world's right edge on the viewport edge) ...
        let m = MapZoomModel(scale: 2, offset: CGPoint(x: -1280, y: -304))
        XCTAssertEqual(m.clamped(toRect: world, viewport: view), m)
        // ... a wider window must pull the map back so its right edge meets the new viewport edge (no gap on the right)
        let wide = m.clamped(toRect: world, viewport: CGSize(width: 1600, height: 800))
        XCTAssertNotEqual(wide, m)
        near(wide.apply(CGPoint(x: world.maxX, y: 0)), CGPoint(x: 1600, y: wide.apply(CGPoint(x: 0, y: 0)).y))
        // a narrower window keeps the state (it is still valid)
        XCTAssertEqual(m.clamped(toRect: world, viewport: CGSize(width: 900, height: 600)).offset.x, -1280)
    }

    func testGlobeDriftIsZeroAtOrBelowOne() {
        let c = CGPoint(x: 540, y: 400), r = 387.0
        for s in [0.6, 0.9, 1.0] {
            let m = MapZoomModel().zoomed(to: s, about: CGPoint(x: 100, y: 100)).clamped(toGlobeCenter: c, radius: r)
            near(m.apply(c), c, 1e-9)
        }
    }

    func testGlobeDriftIsLimitedWhenZoomedIn() {
        let c = CGPoint(x: 540, y: 400), r = 387.0
        // zoom 3 about the far corner would push the globe centre by (3-1) * distance; clamp to (scale-1) * radius
        let m = MapZoomModel().zoomed(to: 3, about: CGPoint(x: 1280, y: 800)).clamped(toGlobeCenter: c, radius: r)
        let home = m.apply(c)
        XCTAssertLessThanOrEqual(hypot(home.x - c.x, home.y - c.y), 2 * r + 1e-9)
        // a centred zoom is not clamped at all
        let centred = MapZoomModel().zoomed(to: 3, about: c)
        XCTAssertEqual(centred.clamped(toGlobeCenter: c, radius: r), centred)
        // scale is never changed by the clamp
        XCTAssertEqual(m.scale, 3)
    }

    func testRotationSlowsDownWithZoom() {
        XCTAssertEqual(MapZoomModel().rotationFactor, 1)
        XCTAssertEqual(MapZoomModel(scale: 4).rotationFactor, 0.25)
        XCTAssertGreaterThan(MapZoomModel(scale: 0.6).rotationFactor, 1)
    }

    func testLabelDensityGrowsWithZoom() {
        func n(_ s: Double) -> Int { MapZoomModel(scale: s).labelBudget(total: 8) }
        XCTAssertEqual(n(1), 5)           // canvas
        XCTAssertLessThan(n(0.6), n(1))
        XCTAssertGreaterThan(n(1.4), n(1))
        XCTAssertEqual(n(6), 8)
        XCTAssertEqual(MapZoomModel(scale: 6).labelBudget(total: 3), 3)
        var last = 0
        for s in stride(from: 0.6, through: 6.0, by: 0.1) { let v = n(s); XCTAssertGreaterThanOrEqual(v, last); last = v }
    }

    func testMarkScaleIsOneAtDefault() {
        XCTAssertEqual(MapZoomModel().markScale, 1)
        XCTAssertGreaterThan(MapZoomModel(scale: 4).markScale, 1)
        XCTAssertLessThan(MapZoomModel(scale: 0.6).markScale, 1)
    }
}
