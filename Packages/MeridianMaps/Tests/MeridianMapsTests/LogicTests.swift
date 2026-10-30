import XCTest
import SwiftUI
import MeridianCore
@testable import MeridianMaps

final class SVGPathParserTests: XCTestCase {
    func testAbsoluteLinesAndClose() {
        let p = SVGPathParser.path(d: "M10,20L30,20 L30.5,40Z")
        XCTAssertEqual(p.boundingRect, CGRect(x: 10, y: 20, width: 20.5, height: 20))
        var closes = 0
        p.forEach { if case .closeSubpath = $0 { closes += 1 } }
        XCTAssertEqual(closes, 1)
    }

    func testRelativeAndImplicitLineto() {
        // "m" followed by extra pairs is an implicit relative lineto; h/v are single numbers
        let p = SVGPathParser.path(d: "m10 10 5 0 0 5h-5v-5z")
        XCTAssertEqual(p.boundingRect, CGRect(x: 10, y: 10, width: 5, height: 5))
    }

    func testCompactNumbersAndExponents() {
        let p = SVGPathParser.path(d: "M-.5.5L1e1-2.5E0")
        XCTAssertEqual(p.boundingRect, CGRect(x: -0.5, y: -2.5, width: 10.5, height: 3))
    }

    func testCurves() {
        let p = SVGPathParser.path(d: "M0,0C0,10 10,10 10,0S20,-10 20,0Q25,5 30,0T40,0")
        XCTAssertFalse(p.isEmpty)
        XCTAssertEqual(p.currentPoint, CGPoint(x: 40, y: 0))
    }

    func testMultiplePathsInSVG() {
        let p = SVGPathParser.path(svg: ##"<svg><path fill="#fff" d="M0,0L1,1"/><path d="M5,5L6,6"/></svg>"##)
        XCTAssertEqual(p.boundingRect, CGRect(x: 0, y: 0, width: 6, height: 6))
    }

    func testBundledEuropeFiles() {
        XCTAssertEqual(MapResources.europeLand.boundingRect.width, 3200, accuracy: 1)
        XCTAssertFalse(MapResources.europeBorders.isEmpty)
        XCTAssertEqual(MapResources.world.land.ranges.count, 129)
    }
}

@MainActor
final class ProjectionTests: XCTestCase {
    func testEuropeProjectionMatchesDesignKit() {
        // values computed with EU.xy of meridian-kit.js (k = 1929.963099388036, lon0 = -35, lat1 = 70)
        let lhr = EuropeProjection.xy(latitude: 51.47, longitude: -0.4543)
        XCTAssertEqual(lhr.x, 1929.963099388036 * (-0.4543 + 35) * .pi / 180, accuracy: 1e-9)
        let corner = EuropeProjection.xy(latitude: 70, longitude: -35)
        XCTAssertEqual(corner.x, 0, accuracy: 1e-9); XCTAssertEqual(corner.y, 0, accuracy: 1e-9)
        // the plane is 3200 wide for lon -35...60
        XCTAssertEqual(EuropeProjection.xy(latitude: 70, longitude: 60).x, 3200, accuracy: 0.5)
    }

    func testGlobeProjectionCenterAndLimb() {
        let c = GlobeMath.proj(lon: 10, lat: 28, l0: 10, p0: 28, R: 100)
        XCTAssertEqual(c.x, 0, accuracy: 1e-9); XCTAssertEqual(c.y, 0, accuracy: 1e-9); XCTAssertEqual(c.c, 1, accuracy: 1e-9)
        let back = GlobeMath.proj(lon: 190, lat: -28, l0: 10, p0: 28, R: 100)
        XCTAssertEqual(back.c, -1, accuracy: 1e-9)
        let east = GlobeMath.proj(lon: 100, lat: 0, l0: 10, p0: 0, R: 100)
        XCTAssertEqual(east.x, 100, accuracy: 1e-9); XCTAssertEqual(east.c, 0, accuracy: 1e-9)
    }

    func testPretrigProjectionEqualsDirect() {
        // the Float fast path used for polygons must agree with the double-precision JS port
        let ring = [[-1230, 515]]  // lon -123.0, lat 51.5 (as lon*10, lat*10)
        let D = Double.pi / 180
        let lon = -123.0 * D, lat = 51.5 * D
        let pts: [Float] = [Float(cos(lat)), Float(sin(lat)), Float(cos(lon)), Float(sin(lon))]
        let v = GlobeMath.View(l0: -100, p0: 30, R: 200)
        let fast = pts.withUnsafeBufferPointer { v.project($0, 0) }
        let slow = GlobeMath.proj(lon: Double(ring[0][0]) / 10, lat: Double(ring[0][1]) / 10, l0: -100, p0: 30, R: 200)
        XCTAssertEqual(Double(fast.x), slow.x, accuracy: 1e-3)
        XCTAssertEqual(Double(fast.y), slow.y, accuracy: 1e-3)
        XCTAssertEqual(Double(fast.c), slow.c, accuracy: 1e-5)
    }

    func testCameraAnimatableDataInterpolatesLikeCSSTransform() {
        var a = EuropeMapView(center: Coordinate(latitude: 51.47, longitude: -0.45), zoom: 1)
        let b = EuropeMapView(center: Coordinate(latitude: 48.86, longitude: 2.35), zoom: 3)
        var d = a.animatableData
        d.scale(by: 0)  // zero vector
        d += b.animatableData
        a.animatableData = d
        XCTAssertEqual(a.animatableData.first, 3)
        XCTAssertEqual(a.animatableData.second.first, b.animatableData.second.first, accuracy: 1e-9)
    }
}

final class AirportConsistencyTests: XCTestCase {
    /// MeridianCore's airport database (OurAirports) vs the design kit's `K.airports`: how far apart are the coordinates?
    func testDesignAirportsMatchCore() throws {
        let index = try AirportIndex.bundled()
        var worstKm = 0.0, worstCode = "", missing: [String] = []
        for (code, a) in MapResources.designAirports {
            guard let core = index.airport(iata: code) else { missing.append(code); continue }
            let km = Geo.distanceKm(from: core.coordinate, to: a.coordinate)
            if km > worstKm { worstKm = km; worstCode = code }
        }
        print("design airports: \(MapResources.designAirports.count), missing in Core: \(missing), worst deviation \(worstCode) \(String(format: "%.2f", worstKm)) km")
        XCTAssertEqual(MapResources.designAirports.count, 96)
        // Core only has airports with scheduled service; the few design-only strips are served by MapAirports' design fallback
        XCTAssertLessThan(missing.count, 12, "Core lacks \(missing)")
        for code in missing { XCTAssertNotNil(MapAirports.bundled.coordinate(code), code) }
        XCTAssertLessThan(worstKm, 5, "coordinates of \(worstCode) differ by \(worstKm) km")
    }

    func testBundledResolverFallsBackToDesign() {
        XCTAssertNotNil(MapAirports.bundled.coordinate("lhr"))
        XCTAssertNil(MapAirports.design.coordinate("ZZZ"))
    }
}
