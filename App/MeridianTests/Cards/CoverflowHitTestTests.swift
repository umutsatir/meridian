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

    // MARK: Left / right symmetry (the right side used to be dead: the container was only 480 x 302 wide)

    private func centre(_ q: [CGPoint]) -> CGPoint {
        CGPoint(x: q.map(\.x).reduce(0, +) / 4, y: q.map(\.y).reduce(0, +) / 4)
    }
    /// Midpoint of the part of a neighbour that the hero does not cover (the visible strip).
    private func visibleStripMid(_ off: Int) -> CGPoint {
        let q = CoverflowHitTest.quad(offset: off), hero = CoverflowHitTest.quad(offset: 0)
        let heroMin = hero.map(\.x).min()!, heroMax = hero.map(\.x).max()!
        let lo = q.map(\.x).min()!, hi = q.map(\.x).max()!
        let (a, b) = off < 0 ? (lo, min(hi, heroMin)) : (max(lo, heroMax), hi)
        return CGPoint(x: (a + b) / 2, y: centre(q).y)
    }

    func testVisibleStripCentresMapToTheirOwnIndexOnBothSides() {
        for sel in 0..<6 {
            for off in [-1, 1] where sel + off >= 0 && sel + off < 6 {
                let p = visibleStripMid(off)
                XCTAssertEqual(idx(p.x, p.y, sel: sel), sel + off, "sel \(sel) off \(off) at \(p)")
            }
        }
    }
    func testQuadsAreMirrorImagesAboutTheCoverflowCentre() {
        let l = CoverflowHitTest.quad(offset: -1), r = CoverflowHitTest.quad(offset: 1)
        XCTAssertEqual(l.map(\.x).min()!, 1060 - r.map(\.x).max()!, accuracy: 1e-6)
        XCTAssertEqual(l.map(\.x).max()!, 1060 - r.map(\.x).min()!, accuracy: 1e-6)
        XCTAssertEqual(centre(l).y, centre(r).y, accuracy: 1e-6)
        // Equal hit widths: the same number of points selects the left and the right neighbour.
        XCTAssertEqual(visibleWidth(-1), visibleWidth(1), accuracy: 1e-6)
    }
    private func visibleWidth(_ off: Int) -> Double {
        let q = CoverflowHitTest.quad(offset: off), hero = CoverflowHitTest.quad(offset: 0)
        let lo = q.map(\.x).min()!, hi = q.map(\.x).max()!
        return off < 0 ? min(hi, hero.map(\.x).min()!) - lo : hi - max(lo, hero.map(\.x).max()!)
    }
    func testEveryPointOfTheVisibleStripsSelectsTheNeighbour() {
        for off in [-1, 1] {
            let q = CoverflowHitTest.quad(offset: off)
            let y = centre(q).y
            let lo = q.map(\.x).min()!, hi = q.map(\.x).max()!
            let hero = CoverflowHitTest.quad(offset: 0)
            var x = lo + 6
            while x < hi - 6 {
                let underHero = x >= hero.map(\.x).min()! && x <= hero.map(\.x).max()!
                if !underHero { XCTAssertEqual(idx(CGFloat(x), CGFloat(y)), 3 + off, "x \(x) off \(off)") }
                x += 5
            }
        }
    }
    func testHeroPointerCoversTheWholeHeroIncludingTheMiddleAndIsNilOutside() {
        let q = CoverflowHitTest.quad(offset: 0)
        let c = centre(q)
        let mid = CoverflowHitTest.heroPointer(at: c)!
        XCTAssertEqual(Double(mid.x), 0, accuracy: 1e-9); XCTAssertEqual(Double(mid.y), 0, accuracy: 1e-9)
        // the old hover area ended at x = 480 (layout frame); the hero is drawn right of it
        XCTAssertGreaterThan(q.map(\.x).max()!, 480)
        let right = CoverflowHitTest.heroPointer(at: CGPoint(x: q.map(\.x).max()! - 2, y: c.y))!
        let left = CoverflowHitTest.heroPointer(at: CGPoint(x: q.map(\.x).min()! + 2, y: c.y))!
        XCTAssertEqual(Double(right.x), -Double(left.x), accuracy: 0.02)
        XCTAssertGreaterThan(Double(right.x), 0.45)
        XCTAssertNil(CoverflowHitTest.heroPointer(at: CGPoint(x: q.map(\.x).max()! + 3, y: c.y)))
        XCTAssertNil(CoverflowHitTest.heroPointer(at: CGPoint(x: c.x, y: q.map(\.y).max()! + 3)))
    }
    func testHeroTapIsNeverASideSelection() {
        let c = centre(CoverflowHitTest.quad(offset: 0))
        for sel in 0..<6 { XCTAssertNil(idx(c.x, c.y, sel: sel)) }
    }
    func testFirstAndLastCardHaveOnlyTheirOneNeighbour() {
        let l = visibleStripMid(-1), r = visibleStripMid(1)
        XCTAssertNil(idx(l.x, l.y, sel: 0)); XCTAssertEqual(idx(r.x, r.y, sel: 0), 1)
        XCTAssertNil(idx(r.x, r.y, sel: 5)); XCTAssertEqual(idx(l.x, l.y, sel: 5), 4)
    }
}
