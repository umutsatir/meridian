import XCTest
@testable import Meridian

final class CoverflowHitTestTests: XCTestCase {
    private func idx(_ x: CGFloat, _ y: CGFloat = 170, sel: Int = 3, n: Int = 6) -> Int? {
        CoverflowHitTest.index(forX: x, y: y, selected: sel, count: n)
    }

    func testHeroCentreAndEdgesDoNotChangeSelection() {
        XCTAssertNil(idx(530)); XCTAssertNil(idx(300)); XCTAssertNil(idx(760))
        XCTAssertEqual(CoverflowHitTest.offset(at: CGPoint(x: 530, y: 170), selected: 3, count: 6), 0)
    }
    func testNearSlotsAreMinusOneAndPlusOne() {
        XCTAssertEqual(idx(200), 2)
        XCTAssertEqual(idx(860), 4)
    }
    func testNeighbourSpansAndFarSlotsOutsideTheArea() {
        // +-1 is drawn between x = 100 and 350 (left) and 710 and 960 (right); the hero covers 281...779 at its widest.
        let l = CoverflowHitTest.quad(offset: -1), r = CoverflowHitTest.quad(offset: 1)
        XCTAssertGreaterThan(l.map(\.x).min()!, 90); XCTAssertLessThan(r.map(\.x).max()!, 970)
        XCTAssertEqual(idx(l.map(\.x).min()! + 8), 2); XCTAssertEqual(idx(r.map(\.x).max()! - 8), 4)
        XCTAssertNil(idx(l.map(\.x).min()! - 8)); XCTAssertNil(idx(r.map(\.x).max()! + 8))
        // +-2 sit at x = 530 -+ 840: outside the 1060 pt coverflow, so a tap inside it can never mean +-2.
        XCTAssertLessThan(CoverflowHitTest.quad(offset: -2).map(\.x).max()!, 0)
        XCTAssertGreaterThan(CoverflowHitTest.quad(offset: 2).map(\.x).min()!, 1060)
    }
    func testHeroWinsWhereItOverlapsANeighbour() {
        let q = CoverflowHitTest.quad(offset: 0)
        XCTAssertNil(idx(q[0].x + 6, 170))
    }
    func testEmptySpaceAndEnds() {
        XCTAssertNil(idx(200, 335)); XCTAssertNil(idx(530, 2))
        XCTAssertNil(idx(200, sel: 0))
        XCTAssertEqual(idx(860, sel: 0), 1)
        XCTAssertNil(idx(860, sel: 5))
    }
}
