import Foundation
import Testing
@testable import MeridianCore

@Suite struct FlightTests {
    let t0 = Fixtures.t0
    func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }

    @Test func progressIsComputedFromTimestamps() {
        let f = Fixtures.flight()
        #expect(f.elapsedSec(at: at(0)) == 0)
        #expect(f.progress(at: at(21)) == 0.5)
        #expect(f.remainingSec(at: at(30)) == 720.0)
        #expect(f.eta(at: at(10)) == at(42))
    }

    @Test func plannedAndBoardingFlightsHaveNoElapsedTime() throws {
        var f = Flight(originIata: "LHR", destinationIata: "CDG", scenarioID: "study", durationSec: 2520, routeDistanceKm: 348)
        #expect(f.elapsedSec(at: at(5)) == 0)
        try f.board()
        #expect(f.elapsedSec(at: at(5)) == 0)
        #expect(throws: FlightError.invalidTransition(from: .boarding)) { try f.board() }
    }

    @Test func sleepingForHoursStillLandsOnTime() {
        var f = Fixtures.flight()
        let settled = f.settle(at: at(600))
        #expect(settled)
        #expect(f.status == .landed)
        #expect(f.endedAt == at(42))
        #expect(f.focusedFraction == 1)
        #expect(f.creditedKm == 348)
    }

    @Test func settleBeforeTheEndIsANoOp() {
        var f = Fixtures.flight()
        let settled = f.settle(at: at(41))
        #expect(!settled)
        #expect(f.status == .inFlight)
    }

    @Test func settleIsIdempotent() {
        var f = Fixtures.flight()
        f.settle(at: at(50))
        let snapshot = f
        f.settle(at: at(500))
        #expect(f == snapshot)
    }

    @Test func codableRoundTripKeepsProgress() throws {
        var f = Fixtures.flight(policy: .flexible)
        try f.startPause(at: at(10))
        let data = try JSONEncoder().encode(f)
        let restored = try JSONDecoder().decode(Flight.self, from: data)
        #expect(restored == f)
        #expect(restored.elapsedSec(at: at(18)) == 600.0)
    }

    // MARK: Early landing

    @Test func strictPolicyRefusesEarlyLanding() {
        var f = Fixtures.flight(policy: .strict)
        #expect(throws: FlightError.earlyLandingNotAllowed) { try f.landEarly(at: at(5)) }
        #expect(f.status == .inFlight)
    }

    @Test func normalEarlyLandingSavesProportionalDistance() throws {
        var f = Fixtures.flight(policy: .normal)
        try f.landEarly(at: at(31))
        #expect(f.status == .diverted)
        #expect(abs(f.focusedFraction - 31.0 / 42) < 1e-9)
        #expect(abs(f.creditedKm - 348 * 31 / 42) < 1e-6)
        #expect(f.elapsedSec(at: at(999)) == 31 * 60)
    }

    @Test func finishedFlightRejectsFurtherActions() throws {
        var f = Fixtures.flight(policy: .flexible)
        try f.landEarly(at: at(5))
        #expect(throws: FlightError.invalidTransition(from: .diverted)) { try f.startBreak(at: at(6)) }
        #expect(throws: FlightError.invalidTransition(from: .diverted)) { try f.landEarly(at: at(6)) }
    }

    // MARK: Pause

    @Test func pauseIsOnlyForFlexible() {
        var f = Fixtures.flight(policy: .normal)
        #expect(throws: FlightError.pauseNotAllowed) { try f.startPause(at: at(5)) }
    }

    @Test func pauseHoldsTheClockAndSlidesTheEta() throws {
        var f = Fixtures.flight(policy: .flexible)
        try f.startPause(at: at(10))
        #expect(f.elapsedSec(at: at(15)) == 10 * 60)
        #expect(f.eta(at: at(15)) == at(15 + 32))
        try f.resume(at: at(15))
        #expect(f.elapsedSec(at: at(20)) == 15 * 60)
        #expect(f.pausedTotalSec == 5 * 60)
    }

    @Test func pauseBudgetIsTenMinutesTotalAndExpiresOnItsOwn() throws {
        var f = Fixtures.flight(policy: .flexible)
        try f.startPause(at: at(5))
        #expect(f.pauseBudgetRemaining(at: at(8)) == 7 * 60)
        // Left paused: only 10 minutes are held, then the clock runs again.
        #expect(f.elapsedSec(at: at(20)) == 10 * 60) // 5 before pause + 5 after budget ran out
        try f.resume(at: at(20))
        #expect(f.pausedTotalSec == 10 * 60)
        #expect(throws: FlightError.pauseBudgetExhausted) { try f.startPause(at: at(21)) }
    }

    @Test func doubleHoldAndResumeWithoutHoldFail() throws {
        var f = Fixtures.flight(policy: .flexible)
        #expect(throws: FlightError.notHeld) { try f.resume(at: at(1)) }
        try f.startPause(at: at(2))
        #expect(throws: FlightError.alreadyHeld) { try f.startBreak(at: at(3)) }
    }

    // MARK: Meal breaks

    @Test func breakMinutesAreNeverFocusOrDistance() throws {
        var f = Fixtures.flight(policy: .strict)
        try f.startBreak(at: at(10))
        #expect(f.status == .onBreak)
        try f.resume(at: at(40)) // 30 minute break, longer than the pause budget
        #expect(f.status == .inFlight)
        #expect(f.breakTotalSec == 30 * 60)
        #expect(f.elapsedSec(at: at(40)) == 10 * 60)
        #expect(f.eta(at: at(40)) == at(40 + 32))
        f.settle(at: at(72))
        #expect(f.status == .landed)
        #expect(f.endedAt == at(72))
        #expect(f.creditedKm == 348)
    }

    @Test func landingWhileOnBreakCountsOnlyFocusedTime() throws {
        var f = Fixtures.flight(policy: .normal)
        try f.startBreak(at: at(14))
        try f.landEarly(at: at(60))
        #expect(f.finalFocusedSec == 840.0)
        #expect(abs(f.creditedKm - 348 / 3) < 1e-6)
    }

    @Test func breakStartedAfterPlannedEndLandsInstead() {
        var f = Fixtures.flight()
        #expect(throws: FlightError.invalidTransition(from: .landed)) { try f.startBreak(at: at(50)) }
        #expect(f.status == .landed)
        #expect(f.endedAt == at(42))
    }

    // MARK: Free flight

    @Test func freeFlightHasNoEndAndCreditsByTime() throws {
        var f = Fixtures.flight(policy: .strict, minutes: nil)
        #expect(f.isFreeFlight)
        #expect(f.progress(at: at(100)) == nil)
        let settled = f.settle(at: at(1000))
        #expect(!settled)
        try f.landEarly(at: at(60)) // allowed even under strict
        #expect(f.status == .landed)
        #expect(abs(f.creditedKm - FlightTiming.km(forMinutes: 60)) < 1e-9)
    }

    // MARK: Phases

    @Test func phasesFollowTheFlightProfile() {
        let d: TimeInterval = 42 * 60
        #expect(FlightPhase.at(elapsed: 0, duration: d) == .taxi)
        #expect(FlightPhase.at(elapsed: 60, duration: d) == .takeoff)
        #expect(FlightPhase.at(elapsed: 3 * 60, duration: d) == .climb)
        #expect(FlightPhase.at(elapsed: 20 * 60, duration: d) == .cruise)
        #expect(FlightPhase.at(elapsed: 40 * 60, duration: d) == .descent)
        #expect(FlightPhase.at(elapsed: d, duration: d) == .landing)
    }

    @Test func longFlightsCapTheirClimbAndDescent() {
        let d: TimeInterval = 6 * 3600
        #expect(FlightPhase.at(elapsed: 30 * 60, duration: d) == .cruise)
        #expect(FlightPhase.at(elapsed: d - 25 * 60, duration: d) == .cruise)
        #expect(FlightPhase.at(elapsed: d - 10 * 60, duration: d) == .descent)
    }

    @Test func freeFlightPhasesNeverDescend() {
        #expect(FlightPhase.at(elapsed: 30, duration: nil) == .takeoff)
        #expect(FlightPhase.at(elapsed: 10 * 3600, duration: nil) == .cruise)
    }
}
