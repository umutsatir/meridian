import Testing
@testable import MeridianUI

@Suite struct ComponentLogicTests {
    @Test func tornEdgeIsDeterministicAndSeedSensitive() {
        let a = TornEdge.offsets(seed: 42, count: 29)
        #expect(a == TornEdge.offsets(seed: 42, count: 29))
        #expect(a != TornEdge.offsets(seed: 43, count: 29))
        #expect(a.count == 29 && a.allSatisfy { (-1...1).contains($0) })
        #expect(TornEdge.offsets(seed: 1, count: 0).isEmpty)
    }

    @Test func mulberryAndHashMatchTheCanvas() {
        // values computed with meridian-kit.js: hash('LHRCDGMR 0142'), rng(seed)()
        #expect(PaperHash.fnv1a("") == 2166136261)
        #expect(PaperHash.fnv1a("a") == 0xE40C292C)
        var r = PaperRandom(seed: 1)
        #expect(abs(r.next() - 0.6270739405881613) < 1e-12)
    }

    @Test func tornLineIsSeededAndBounded() {
        let a = TornEdge.polyline(seed: 42), b = TornEdge.polyline(seed: 42), c = TornEdge.polyline(seed: 43)
        #expect(a == b && a != c)
        #expect(a.first?.x == 360 && a.last?.x == 0)
        #expect(zip(a, a.dropFirst()).allSatisfy { $0.x >= $1.x })
        // amplitude 1.5-2.5 pt around y = 450
        #expect(a.allSatisfy { abs($0.y - 450) <= 2.5 + 1e-9 })
    }

    @Test func designSeedIsHashOfRouteAndFlight() {
        let m = BoardingPassModel.sample
        #expect(m.seed == UInt64(PaperHash.fnv1a("LHRCDGMR 0142")))
        #expect(m.month == Int(m.seed % 12))
    }

    @Test func cabinFollowsMinutes() {
        #expect(BoardingPassCabin.cabin(forMinutes: 42) == .economy)
        #expect(BoardingPassCabin.cabin(forMinutes: 45) == .premium)
        #expect(BoardingPassCabin.cabin(forMinutes: 180) == .first)
        #expect(BoardingPassCabin.cabin(forMinutes: 300) == .longHaul)
    }

    @Test func barcodeIsDeterministic() {
        #expect(TornEdge.barcode(seed: 7, width: 300, height: 56) == TornEdge.barcode(seed: 7, width: 300, height: 56))
        #expect(TornEdge.barcode(seed: 7, width: 300, height: 56) != TornEdge.barcode(seed: 8, width: 300, height: 56))
    }

    @Test func tearCutKeepsBodyAndPieceDisjointAtTheFront() {
        let c = TicketTearGeometry.cut(seed: 5, progress: 0.4, grab: .right)
        // the front rests on the last broken bridge (x = 12 + 8k): 216 pt of raw front -> bridge at 220
        #expect(abs(c.front.x - 220) < 1e-9)
        #expect(c.body.contains(c.front) && c.piece.contains { $0.x == c.front.x })   // body and stub meet at the last broken bridge
        let l = TicketTearGeometry.cut(seed: 5, progress: 0.4, grab: .left)
        #expect(abs(l.front.x - 140) < 1e-9)
    }

    @Test func printTimelineMatchesTheSpec() {
        typealias T = TicketPrintTimeline
        #expect(T.frame(atMs: 0).printed == 0 && T.frame(atMs: 199).step == -1)
        #expect(T.frame(atMs: 200).step == 0)
        // 84 ms ease-out then a 30 ms hold: at 84 ms the first step is complete, held to 114 ms
        #expect(abs(T.frame(atMs: 284).printed - 1.0 / 14) < 1e-9)
        #expect(abs(T.frame(atMs: 310).printed - 1.0 / 14) < 1e-9)
        #expect(T.frame(atMs: 200 + 114 * 14).printed == 1)
        #expect(T.frame(atMs: 1800).step == 13 && T.frame(atMs: 2100).isReady && !T.frame(atMs: 2099).isReady)
        #expect(T.frame(atMs: 1800).settleOffset == 0)
        #expect(T.frame(atMs: 1950).settleOffset > 3)
        #expect(abs(T.frame(atMs: 2400, seed: 1).rotationDegrees - 1.5) < 1e-9)
        #expect(abs(T.frame(atMs: 2400, seed: 2).rotationDegrees + 1.5) < 1e-9)
        #expect(T.stepsStarted(from: 0, to: 2400) == Array(0..<14))
        #expect(T.stepsStarted(from: 320, to: 340).isEmpty)
        #expect(T.frame(atMs: 30).ledOn && !T.frame(atMs: 80).ledOn && T.frame(atMs: 120).ledOn && T.frame(atMs: 500).ledOn)
    }

    @Test func splitFlapChainEndsOnTargetAndIsBounded() {
        var n = 0.0
        let chain = SplitFlapLogic.chain(from: "A", to: "Z", random: { n += 0.13; return n.truncatingRemainder(dividingBy: 1) })
        #expect(chain.last == "Z" && chain.count <= SplitFlapLogic.maxFlips)
        #expect(SplitFlapLogic.chain(from: "A", to: "A", random: { 0.5 }).isEmpty)
        #expect(SplitFlapLogic.normalize("ab", count: 4) == ["A", "B", " ", " "])
    }

    @Test func flapFoldAnglesFollowTheTwoHalfFlip() {
        #expect(SplitFlapLogic.angles(at: 0).top == 0 && SplitFlapLogic.angles(at: 0).bottom == 90)
        #expect(abs(SplitFlapLogic.angles(at: 0.062).top + 90) < 1e-6)
        #expect(abs(SplitFlapLogic.angles(at: 0.124).bottom) < 1e-6)
    }

    @Test func tierThresholdsAndNext() {
        #expect(MembershipTier.highest(forKm: 12022) == .cruise || MembershipTier.highest(forKm: 12022) == .jetstream)
        #expect(MembershipTier.gold.next == .equator && MembershipTier.obsidian.next == nil)
        #expect(MembershipTier.allCases.map(\.thresholdKm) == [0, 1000, 5000, 20000, 40075, 100000])
    }

    @Test func durationText() {
        var m = BoardingPassModel.sample
        #expect(m.durationText == "42 min")
        m.durationMinutes = nil
        #expect(m.durationText == "Free")
    }

    @Test func voiceOverDescriptionFollowsPRD() {
        let text = BoardingPassModel.sample.accessibilityDescription(canTear: true)
        #expect(text.hasPrefix("Boarding pass, London to Paris"))
        #expect(text.hasSuffix("Activate to tear off the stub."))
        #expect(!BoardingPassModel.sample.accessibilityDescription(canTear: false).contains("tear"))
    }

    @Test func airportTagSpeaksCityCodeAndTime() {
        #expect(AirportTag.spokenLabel(code: "CDG", city: "Paris", minutes: 42) == "Paris, CDG, 42 minutes")
        #expect(AirportTag.spokenLabel(code: "AMS", city: nil, minutes: nil) == "AMS")
    }
}

import Foundation
