import Testing
import SwiftUI
@testable import MeridianUI

/// The tear follows the perforation: scalloped edges, bridges that break one by one, no part of the pass is lost.
@MainActor
@Suite struct TearGeometryTests {
    let edges = PerforationEdge(seed: 42)

    @Test func perforationHasFortyHolesAndFortyOneBridges() {
        #expect(PerforationEdge.holeCenters.count == 40)
        #expect(PerforationEdge.bridgeCenters.count == 41)
        #expect(PerforationEdge.bridgeCenters.first == 12 && PerforationEdge.bridgeCenters.last == 348)
    }

    @Test func bridgesBreakOneAfterAnotherFromTheGrabbedSide() {
        #expect(PerforationEdge.brokenCount(frontX: 360, grab: .right) == 0)
        #expect(PerforationEdge.brokenCount(frontX: 348, grab: .right) == 1)
        #expect(PerforationEdge.brokenCount(frontX: 339, grab: .right) == 1)
        #expect(PerforationEdge.brokenCount(frontX: 332, grab: .right) == 2)
        #expect(PerforationEdge.brokenCount(frontX: 0, grab: .left) == 0)
        #expect(PerforationEdge.brokenCount(frontX: 12, grab: .left) == 1)
        #expect(PerforationEdge.brokenCount(frontX: 180, grab: .right) == PerforationEdge.brokenCount(frontX: 180, grab: .left))   // symmetric
        #expect(PerforationEdge.quantizedFront(frontX: 340, grab: .right) == 348)
        #expect(PerforationEdge.quantizedFront(frontX: 20, grab: .left) == 12)
    }

    @Test func edgesAreScallopedAndNeverCrossEachOther() {
        // body bites up into the ticket at every hole, the stub bites down; the stub edge is never above the body edge
        #expect(edges.body.count == edges.stub.count)
        for (b, s) in zip(edges.body, edges.stub) {
            #expect(b.x == s.x)
            #expect(s.y >= b.y)
            #expect(abs(b.y - 450) <= PerforationEdge.holeRadius + 1e-9)
        }
        let minBody = edges.body.map(\.y).min()!, maxStub = edges.stub.map(\.y).max()!
        #expect(minBody < 450 - PerforationEdge.holeRadius + 0.01)
        #expect(maxStub > 450 + PerforationEdge.holeRadius - 0.01)
    }

    @Test func edgeIsDeterministicPerSeed() {
        #expect(PerforationEdge(seed: 7).body == PerforationEdge(seed: 7).body)
        #expect(PerforationEdge(seed: 7).body != PerforationEdge(seed: 8).body)
    }

    @Test func bodyAndStubKeepTheWholePassAtEveryPhase() {
        for grab in [TearGrabSide.right, .left] {
            for pct in stride(from: 0, through: 100, by: 5) {
                let c = TicketTearGeometry.cut(edges: edges, progress: Double(pct) / 100, grab: grab)
                let sum = TicketTearGeometry.area(c.body) + TicketTearGeometry.area(c.piece)
                // 360 x 600 = 216000; the holes remove about 450 pt2, the 1.8 pt overlap of the flat part adds at most 650 pt2
                #expect(sum > 216000 - 700 && sum < 216000 + 700, "\(grab) \(pct)% area \(sum)")
                #expect(TicketTearGeometry.area(c.body) > 160_000 && TicketTearGeometry.area(c.piece) > 53_000, "\(grab) \(pct)%")
                // nothing of the pass is cut off at the bottom
                #expect(c.piece.map(\.y).max() == 600 && c.body.map(\.y).min() == 0)
                #expect(c.piece.map(\.x).min() == 0 && c.piece.map(\.x).max() == 360)
            }
        }
    }

    @Test func tornAreaGrowsMonotonicallyWithProgress() {
        var lastBody = CGFloat.infinity
        for pct in stride(from: 0, through: 100, by: 5) {
            let c = TicketTearGeometry.cut(edges: edges, progress: Double(pct) / 100, grab: .right)
            let a = TicketTearGeometry.area(c.body)
            #expect(a <= lastBody + 1)
            lastBody = a
        }
    }

    @Test func tornPassPolygonEndsOnTheScallopedEdge() {
        let poly = PaperShape.tornPolygon(seed: 42)
        #expect(poly.first == CGPoint(x: 0, y: 0))
        #expect(poly.last == CGPoint(x: 0, y: 450))
        #expect(poly.count > 300)
        // the fully torn cut equals the torn pass shape
        let full = TicketTearGeometry.cut(edges: PerforationEdge(seed: 42), progress: 1, grab: .right)
        #expect(abs(TicketTearGeometry.area(full.body) - TicketTearGeometry.area(poly)) < 1)
    }

    @Test func stubTopEdgeIsFlatWhereNothingIsTorn() {
        #expect(edges.stubTopY(at: 100, front: 220, grab: .right) == PerforationEdge.stubFlatY)
        #expect(edges.stubTopY(at: 300, front: 220, grab: .right) != PerforationEdge.stubFlatY)
        #expect(edges.stubTopY(at: 300, front: 220, grab: .left) == PerforationEdge.stubFlatY)
    }

    @Test func bentStubKeepsEveryStripAndReachesTheBottomOfThePass() {
        for grab in [TearGrabSide.right, .left] {
            let info = TearRender.pose(edges: edges, front: grab == .right ? 220 : 140, grab: grab, hinge: 18, curl: 8)
            let xs = info.strips.flatMap { $0.poly.map(\.x) }
            #expect(xs.min()! <= 0.0001 && xs.max()! >= 359.9)
            #expect(info.strips.allSatisfy { $0.poly.map(\.y).max()! >= 600 })
            let attached = info.strips.filter { !$0.free && $0.shade == 0 }
            #expect(!attached.isEmpty && attached.allSatisfy { $0.transform.isIdentity })
        }
    }

    @Test func bendStaysFlatLeftOfTheBendZoneAndTurnsToTheHingeAngle() {
        let b = StubBend(front: 200, hinge: 20, curl: 6)
        #expect(b.angle(at: 100) == 0)
        #expect(abs(b.angle(at: 200) - 20) < 1e-9)
        #expect(b.angle(at: 185) > 0 && b.angle(at: 185) < 20)
        #expect(b.angle(at: 300) > 20)
    }
}

/// Easier tearing (S14A): light start, early auto-finish, less drag, one event per broken bridge.
@MainActor
@Suite struct TearEaseTests {
    @Test func theTearFinishesAtFiftyFivePercentAndNeedsLessThanTheTicketWidth() {
        #expect(TearState.completionThreshold == 0.55)
        #expect(TearState.dragSpan * TearState.completionThreshold < 160)   // about 137 pt of pull
    }

    @Test func pullingPastTheThresholdTearsTheStubOff() {
        let t = TicketTearModel()
        t.begin(x: 340, y: 520)
        t.move(x: 340 - 150, y: 520)   // 150 pt / 250 = 60 %
        #expect(t.phase == .finishing)
    }

    @Test func aShortPullDoesNotFinish() {
        let t = TicketTearModel()
        t.begin(x: 340, y: 520)
        t.move(x: 340 - 80, y: 520)    // 32 %
        #expect(t.phase == .dragging && t.progress > 0.3 && t.progress < 0.34)
    }

    @Test func everyBrokenBridgeIsReportedOnce() {
        let t = TicketTearModel()
        var total = 0
        t.onBridges = { total += $0 }
        t.begin(x: 340, y: 520)
        t.move(x: 340 - 60, y: 520)    // 24 %
        #expect(total == PerforationEdge.brokenCount(frontX: 360 * (1 - t.progress), grab: .right))
        #expect(total > 5)
        let before = total
        t.move(x: 340 - 60, y: 520)    // no movement, no new bridge
        #expect(total == before)
    }

    @Test func untouchedNothingBreaks() {
        let t = TicketTearModel()
        var total = 0
        t.onBridges = { total += $0 }
        t.begin(x: 340, y: 520)
        #expect(total == 0 && t.bridgeCount == 0)
    }
}
