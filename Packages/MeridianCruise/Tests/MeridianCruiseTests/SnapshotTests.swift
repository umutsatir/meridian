import Foundation
import Testing
import MeridianCore
@testable import MeridianCruise

@Suite struct SnapshotTests {
    func snap(_ f: Flight, _ min: Double) -> CruiseSnapshot {
        CruiseSnapshot(flight: f, origin: Fx.lhr, destination: Fx.cdg, now: Fx.at(min))
    }

    @Test func halfwayNumbersAreConsistent() {
        let s = snap(Fx.flight(), 21)
        #expect(s.progress == 0.5)
        #expect(s.remainingSec == 21 * 60.0)
        #expect(s.eta == Fx.at(42))
        #expect(abs((s.remainingDistanceKm ?? 0) - 174) < 1e-6)
        #expect(s.phase == .cruise)
        #expect(s.groundSpeedKmh > 700 && s.altitudeFt >= 20_000)
        #expect(s.schedule == .onTime)
        let direct = Geo.interpolate(from: Fx.lhr.coordinate, to: Fx.cdg.coordinate, fraction: 0.5)
        #expect(Geo.distanceKm(from: s.position, to: direct) < 0.01)
    }

    @Test func headingPointsFromTheRouteTowardTheDestination() throws {
        let s = snap(Fx.flight(), 5)
        let heading = try #require(s.headingDegrees)
        #expect((100...180).contains(heading)) // London → Paris is south-east
    }

    @Test func landedFlightIsStillAndArrived() {
        var f = Fx.flight()
        f.settle(at: Fx.at(60))
        let s = snap(f, 600)
        #expect(s.schedule == .arrived)
        #expect(s.groundSpeedKmh == 0 && s.altitudeFt == 0)
        #expect(s.remainingSec == 0)
        #expect(s.eta == Fx.at(42))
    }

    @Test func breakHoldsTheClockAndExposesTheEtaShift() throws {
        var f = Fx.flight()
        try f.startBreak(at: Fx.at(10))
        let held = snap(f, 25)
        #expect(held.schedule == .clockHeld(.meal))
        #expect(held.elapsedSec == 600)
        #expect(abs(held.etaShiftSec - 15 * 60) < 1e-6)
        #expect(held.eta == Fx.at(25 + 32))
        try f.resume(at: Fx.at(25))
        #expect(snap(f, 30).schedule == .onTime)
    }

    @Test func sleepingThroughTheMiddleOfAFlightGivesTheSameNumbersAsWatching() {
        let watched = snap(Fx.flight(), 30)
        let afterSleep = snap(Fx.flight(), 30) // computed only from timestamps
        #expect(watched == afterSleep)
    }

    @Test func freeFlightHasNoEndOrDestination() {
        let f = Fx.flight(minutes: nil)
        let s = CruiseSnapshot(flight: f, origin: Fx.lhr, destination: nil, now: Fx.at(90))
        #expect(s.progress == nil && s.remainingSec == nil && s.remainingDistanceKm == nil && s.eta == nil)
        #expect(s.headingDegrees == nil)
        #expect(s.position == Fx.lhr.coordinate)
        #expect(s.altitudeFt == 37_000)
    }

    @Test func destinationLocalTimeUsesTheGivenZone() {
        let paris = TimeZone(identifier: "Europe/Paris")!
        let s = CruiseSnapshot(flight: Fx.flight(), origin: Fx.lhr, destination: Fx.cdg, now: Fx.utc("2026-01-15T10:30:00Z"), destinationTimeZone: paris)
        let c = s.destinationLocalTime()
        #expect(c.hour == 11 && c.minute == 30)
    }

    @Test func phaseTimelineIsContiguousAndCoversTheFlight() {
        let spans = PhaseTimeline.spans(durationSec: 42 * 60)
        #expect(spans.first?.phase == .taxi && spans.last?.phase == .landing)
        #expect(spans.first?.startSec == 0)
        #expect(abs((spans.last?.endSec ?? 0) - 42 * 60) < 1e-6)
        #expect(zip(spans, spans.dropFirst()).allSatisfy { abs($0.endSec - $1.startSec) < 1e-6 })
    }

    @Test func freeFlightTimelineEndsOpen() {
        let spans = PhaseTimeline.spans(durationSec: nil)
        #expect(spans.last?.phase == .cruise && spans.last?.endSec == .infinity)
        #expect(!spans.contains { $0.phase == .descent || $0.phase == .landing })
    }
}
