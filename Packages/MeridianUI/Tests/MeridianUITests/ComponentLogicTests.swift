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

    @Test func barcodeIsDeterministic() {
        let w = TornEdge.barWidths(seed: 9, count: 30)
        #expect(w == TornEdge.barWidths(seed: 9, count: 30))
        #expect(w.count == 30 && w.allSatisfy { (1...4).contains($0) })
    }

    @Test func sameTicketSeedGivesSamePanelPath() {
        let rect = CGRect(x: 0, y: 0, width: 128, height: 208)
        let a = TicketPanelShape(side: .stub, seed: 5, tearProgress: 0.6).path(in: rect)
        let b = TicketPanelShape(side: .stub, seed: 5, tearProgress: 0.6).path(in: rect)
        let c = TicketPanelShape(side: .stub, seed: 6, tearProgress: 0.6).path(in: rect)
        #expect(a == b)
        #expect(a != c)
    }

    @Test func untornEdgeIgnoresTheSeed() {
        let rect = CGRect(x: 0, y: 0, width: 430, height: 208)
        #expect(TicketPanelShape(side: .main, seed: 1, tearProgress: 0).path(in: rect)
            == TicketPanelShape(side: .main, seed: 2, tearProgress: 0).path(in: rect))
    }

    @Test func splitFlapNormalizes() {
        #expect(SplitFlapSequence.normalize("paris", count: 8) == "PARIS   ")
        #expect(SplitFlapSequence.normalize("İstanbul!", count: 4) == "İSTA".map { SplitFlapSequence.charset.contains($0) ? String($0) : " " }.joined())
        #expect(SplitFlapSequence.normalize("ab", count: 1) == "A")
    }

    @Test func splitFlapFramesEndOnTargetAndStayShort() {
        let frames = SplitFlapSequence.frames(from: "PARIS   ", to: "TOKYO   ")
        #expect(frames.last == "TOKYO   ")
        #expect(!frames.isEmpty && frames.count <= SplitFlapSequence.maxFlipsPerCell + 8 * SplitFlapSequence.staggerFrames)
        #expect(frames.allSatisfy { $0.count == 8 })
    }

    @Test func splitFlapNoChangeAndLengthChange() {
        #expect(SplitFlapSequence.frames(from: "CDG", to: "CDG").isEmpty)
        #expect(SplitFlapSequence.frames(from: "CDG", to: "CDGX").last == "CDGX")
        #expect(SplitFlapSequence.frames(from: "", to: "A").last == "A")
    }

    @Test func splitFlapFirstFrameIsStillMidFlip() {
        let frames = SplitFlapSequence.frames(from: "AAAA", to: "ZZZZ")
        #expect(frames.first != "ZZZZ")
    }

    @Test func durationText() {
        var m = BoardingPassModel.sample
        #expect(m.durationText == "42 MIN")
        m.durationMinutes = 60
        #expect(m.durationText == "1 H")
        m.durationMinutes = 90
        #expect(m.durationText == "1 H 30 MIN")
        m.durationMinutes = nil
        #expect(m.durationText == "FREE")
    }

    @Test func voiceOverDescriptionFollowsPRD() {
        let text = BoardingPassModel.sample.accessibilityDescription(canTear: true)
        #expect(text.hasPrefix("Boarding pass, London Heathrow to Paris Charles de Gaulle"))
        #expect(text.hasSuffix("Activate to tear off the stub."))
        #expect(!BoardingPassModel.sample.accessibilityDescription(canTear: false).contains("tear"))
    }

    @Test func airportTagSpeaksCityCodeAndTime() {
        #expect(AirportTag.spokenLabel(code: "CDG", city: "Paris", minutes: 42) == "Paris, CDG, 42 minutes")
        #expect(AirportTag.spokenLabel(code: "AMS", city: nil, minutes: nil) == "AMS")
    }
}

import Foundation
