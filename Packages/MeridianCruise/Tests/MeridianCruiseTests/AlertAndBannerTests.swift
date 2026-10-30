import Foundation
import Testing
import MeridianCore
@testable import MeridianCruise

@Suite struct AlertAndBannerTests {
    @Test func levelsFollowTheRemainingTime() {
        let f = Fx.flight()
        #expect(LandingAlert.level(for: f, at: Fx.at(30)) == .none)
        #expect(LandingAlert.level(for: f, at: Fx.at(37)) == .prepare)
        #expect(LandingAlert.level(for: f, at: Fx.at(41.5)) == .lastMinute)
        #expect(LandingAlert.level(for: f, at: Fx.at(42)) == .none)
    }

    @Test func prepareForLandingFiresOnceAtFiveMinutes() {
        let f = Fx.flight()
        var alert = LandingAlert()
        #expect(alert.poll(flight: f, at: Fx.at(36), isEnabled: true) == nil)
        #expect(alert.poll(flight: f, at: Fx.at(37), isEnabled: true)?.flightID == f.id)
        #expect(alert.poll(flight: f, at: Fx.at(38), isEnabled: true) == nil)
    }

    @Test func aDisabledSettingStaysSilentAndDoesNotConsumeTheAlert() {
        let f = Fx.flight()
        var alert = LandingAlert()
        #expect(alert.poll(flight: f, at: Fx.at(38), isEnabled: false) == nil)
        #expect(alert.firedFlightIDs.isEmpty)
        #expect(alert.poll(flight: f, at: Fx.at(39), isEnabled: true) != nil)
    }

    @Test func theChimeNeverInterruptsABreak() throws {
        var f = Fx.flight()
        try f.startBreak(at: Fx.at(38))
        var alert = LandingAlert()
        #expect(alert.poll(flight: f, at: Fx.at(40), isEnabled: true) == nil)
        try f.resume(at: Fx.at(45))
        #expect(alert.poll(flight: f, at: Fx.at(45), isEnabled: true) != nil)
    }

    @Test func notificationDateIsFiveMinutesBeforeTheEta() {
        let f = Fx.flight()
        #expect(LandingAlert.notificationDate(for: f, at: Fx.at(10)) == Fx.at(37))
        #expect(LandingAlert.notificationDate(for: f, at: Fx.at(39)) == nil)
    }

    @Test func alertStateSurvivesRelaunch() throws {
        let f = Fx.flight()
        var alert = LandingAlert()
        _ = alert.poll(flight: f, at: Fx.at(38), isEnabled: true)
        var restored = try JSONDecoder().decode(LandingAlert.self, from: JSONEncoder().encode(alert))
        #expect(restored.poll(flight: f, at: Fx.at(39), isEnabled: true) == nil)
    }

    // MARK: Banners

    @Test func relaunchAndWakeBannersDiffer() {
        let f = Fx.flight()
        let quit = ResumeBanner.select(flight: f, cause: .launch, lastActiveAt: Fx.at(10), now: Fx.at(20), destinationCity: "Paris")
        let sleep = ResumeBanner.select(flight: f, cause: .wake, lastActiveAt: Fx.at(10), now: Fx.at(20), destinationCity: "Paris")
        #expect(quit?.kind == .afterQuit && sleep?.kind == .afterSleep)
        #expect(quit?.arguments == [.minutes(22)])
        #expect(quit?.titleKey == "flight.resumed.title")
    }

    @Test func tinyGapsAndUnstartedFlightsGetNoBanner() {
        let f = Fx.flight()
        #expect(ResumeBanner.select(flight: f, cause: .wake, lastActiveAt: Fx.at(10), now: Fx.at(10).addingTimeInterval(2), destinationCity: nil) == nil)
        let planned = Flight(originIata: "LHR", destinationIata: "CDG", scenarioID: "study", durationSec: 2520, routeDistanceKm: 348)
        #expect(ResumeBanner.select(flight: planned, cause: .launch, lastActiveAt: Fx.at(0), now: Fx.at(10), destinationCity: nil) == nil)
    }

    @Test func landingWhileAwayNamesTheCity() {
        var f = Fx.flight()
        f.settle(at: Fx.at(100))
        let b = ResumeBanner.select(flight: f, cause: .launch, lastActiveAt: Fx.at(30), now: Fx.at(100), destinationCity: "Paris")
        #expect(b?.kind == .landedWhileAway)
        #expect(b?.arguments == [.text("Paris")])
        // A landing the user already saw is not announced again.
        #expect(ResumeBanner.select(flight: f, cause: .launch, lastActiveAt: Fx.at(50), now: Fx.at(100), destinationCity: "Paris") == nil)
    }

    @Test func bannerPolicyConstants() {
        #expect(ResumeBanner.autoDismissAfterSec == 8)
        #expect(!ResumeBanner.stealsFocus && ResumeBanner.voiceOverReadsOnce)
    }
}
