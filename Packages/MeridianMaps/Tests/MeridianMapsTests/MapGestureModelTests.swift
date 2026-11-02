import XCTest
import CoreGraphics
@testable import MeridianMaps

final class MapGestureModelTests: XCTestCase {
    private let autoCenter = CGPoint(x: 640, y: 272)

    func testGlobePanFollowsFingers() {
        let c = GlobeCamera(lon: 10, lat: 20).panned(dx: 100, dy: 50, degreesPerPoint: 0.1)
        XCTAssertEqual(c.lon, 0, accuracy: 1e-9)
        XCTAssertEqual(c.lat, 25, accuracy: 1e-9)
        XCTAssertEqual(c.zoom, 1)
    }

    func testGlobePanWrapsLongitudeAndStopsAtPoles() {
        XCTAssertEqual(GlobeCamera(lon: 175, lat: 0).panned(dx: -100, dy: 0, degreesPerPoint: 0.1).lon, -175, accuracy: 1e-9)
        XCTAssertEqual(GlobeCamera(lon: -179, lat: 0).panned(dx: 30, dy: 0, degreesPerPoint: 0.1).lon, 178, accuracy: 1e-9)
        XCTAssertEqual(GlobeCamera(lon: 0, lat: 60).panned(dx: 0, dy: 10_000, degreesPerPoint: 1).lat, 70)
        XCTAssertEqual(GlobeCamera(lon: 0, lat: -60).panned(dx: 0, dy: -10_000, degreesPerPoint: 1).lat, -70)
        XCTAssertEqual(GlobeCamera(lon: 0, lat: 120).lat, 70)
    }

    func testGlobePinchOnlyChangesZoomAndClamps() {
        let c = GlobeCamera(lon: 5, lat: 7)
        let p = c.pinched(magnification: 2)
        XCTAssertEqual(p.zoom, 2); XCTAssertEqual(p.lon, 5); XCTAssertEqual(p.lat, 7)
        XCTAssertEqual(c.zoomed(by: 1000).zoom, 6)
        XCTAssertEqual(c.zoomed(by: 0.0001).zoom, 0.6)
        XCTAssertEqual(c.zoomed(by: .nan), c)
        XCTAssertEqual(c.zoomed(by: -1), c)
        XCTAssertFalse(c.zoomed(by: 1000).canZoomIn)
        XCTAssertEqual(c.steppedIn().steppedOut().zoom, 1, accuracy: 1e-12)
    }

    func testGlobeDisplacedFromHome() {
        let home = GlobeCamera(lon: 179.9, lat: 30)
        XCTAssertFalse(home.isDisplaced(from: home))
        XCTAssertFalse(GlobeCamera(lon: -179.9, lat: 30).isDisplaced(from: home))
        XCTAssertTrue(home.panned(dx: 40, dy: 0, degreesPerPoint: 0.1).isDisplaced(from: home))
        XCTAssertTrue(home.zoomed(by: 1.5).isDisplaced(from: home))
    }

    func testDegreesPerPoint() {
        XCTAssertEqual(GlobeCamera.degreesPerPoint(screenRadius: 180 / .pi), 1, accuracy: 1e-12)
        XCTAssertEqual(GlobeCamera.degreesPerPoint(screenRadius: 0), 0)
    }

    // MARK: Plan

    func testPlanPanAddsUp() {
        let c = PlanMapCamera().panned(by: CGSize(width: 30, height: -10)).panned(by: CGSize(width: 5, height: 5))
        XCTAssertEqual(c.pan, CGSize(width: 35, height: -5))
        XCTAssertNil(c.zoom)
        XCTAssertTrue(c.isManual)
        XCTAssertFalse(PlanMapCamera().isManual)
    }

    func testPlanZoomKeepsAnchorFixed() {
        var cam = PlanMapCamera().panned(by: CGSize(width: 40, height: 25))
        let anchor = CGPoint(x: 300, y: 200)
        var z = cam.effectiveZoom(auto: 0.9)
        // a map point (offset from the origin in zoom-1 plane units) that starts under the anchor
        let probe = CGPoint(x: (anchor.x - (autoCenter.x + cam.pan.width)) / z, y: (anchor.y - (autoCenter.y + cam.pan.height)) / z)
        for f in [1.5, 1.5, 0.7, 2.0, 0.4] {
            cam = cam.zoomed(by: f, about: anchor, autoCenter: autoCenter, autoZoom: 0.9)
            z = cam.effectiveZoom(auto: 0.9)
            let now = CGPoint(x: autoCenter.x + cam.pan.width + probe.x * z, y: autoCenter.y + cam.pan.height + probe.y * z)
            XCTAssertEqual(now.x, anchor.x, accuracy: 1e-9)
            XCTAssertEqual(now.y, anchor.y, accuracy: 1e-9)
        }
    }

    func testPlanZoomLimits() {
        let big = PlanMapCamera().zoomed(by: 1e6, about: .zero, autoCenter: autoCenter, autoZoom: 1)
        XCTAssertEqual(big.zoom, PlanMapCamera.maxZoom)
        let small = PlanMapCamera().zoomed(by: 1e-6, about: .zero, autoCenter: autoCenter, autoZoom: 1)
        XCTAssertEqual(small.zoom, PlanMapCamera.worldZoom)
        XCTAssertLessThan(PlanMapCamera.worldZoom, 0.45 / 3)   // the world is reachable from the longest-flight framing
        let illustrated = PlanMapCamera().zoomed(by: 1e-6, about: .zero, autoCenter: autoCenter, autoZoom: 1, minimum: 0.3)
        XCTAssertEqual(illustrated.zoom, 0.3)
    }

    func testRecenterCondition() {
        XCTAssertFalse(PlanMapCamera().showsRecenter(autoZoom: 0.45))
        XCTAssertFalse(PlanMapCamera(pan: CGSize(width: 3, height: 3)).showsRecenter(autoZoom: 0.45))
        XCTAssertTrue(PlanMapCamera(pan: CGSize(width: 30, height: 0)).showsRecenter(autoZoom: 0.45))
        XCTAssertTrue(PlanMapCamera(zoom: 0.9).showsRecenter(autoZoom: 0.45))
        XCTAssertFalse(PlanMapCamera(zoom: 0.451).showsRecenter(autoZoom: 0.45))
        XCTAssertEqual(PlanMapCamera(pan: CGSize(width: 30, height: 0), zoom: 2).recentered(), PlanMapCamera())
    }

    func testOriginChangeReframesButDurationDoesNot() {
        let moved = PlanMapCamera(pan: CGSize(width: 90, height: 40), zoom: 1.2)
        XCTAssertEqual(moved.afterChange(originChanged: false), moved)
        XCTAssertEqual(moved.afterChange(originChanged: true), PlanMapCamera())
        XCTAssertEqual(PlanMapCamera().effectiveZoom(auto: 0.7), 0.7)
        XCTAssertEqual(moved.effectiveZoom(auto: 0.7), 1.2)
    }

    func testTagBudgetThinsOutWithZoom() {
        XCTAssertEqual(PlanMapCamera.tagBudget(full: 26, zoom: 1, autoZoom: 1), 26)
        XCTAssertEqual(PlanMapCamera.tagBudget(full: 26, zoom: 2, autoZoom: 1), 26)
        XCTAssertEqual(PlanMapCamera.tagBudget(full: 26, zoom: 0.5, autoZoom: 1), 13)
        XCTAssertEqual(PlanMapCamera.tagBudget(full: 26, zoom: 0.01, autoZoom: 1), 6)
    }
}
