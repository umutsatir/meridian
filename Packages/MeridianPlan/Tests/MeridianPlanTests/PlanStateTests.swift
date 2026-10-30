import Foundation
import Testing
import MeridianCore
@testable import MeridianPlan

private func airport(_ iata: String, lat: Double, lon: Double, city: String? = nil) -> Airport {
    Airport(iata: iata, name: iata, city: city ?? iata, countryCode: "XX", continent: .europe, coordinate: .init(latitude: lat, longitude: lon))
}

/// Origin AAA at (0,0); destinations along the equator, 1° ≈ 111.2 km.
private let origin = airport("AAA", lat: 0, lon: 0)
private let near = airport("NEAR", lat: 0, lon: 1)    // ~111 km  -> 17 min
private let mid = airport("MID", lat: 0, lon: 3)       // ~334 km  -> 41 min
private let mid2 = airport("MID2", lat: 0, lon: 3.2)   // ~356 km  -> 43 min
private let far = airport("FAR", lat: 0, lon: 30)      // ~3336 km -> 274 min
private let smallIndex = AirportIndex(airports: [origin, near, mid, mid2, far])

private func state(_ prefs: PlanPreferences = .init(homeIata: "AAA")) -> PlanState {
    PlanState(index: smallIndex, preferences: prefs, fallbackOriginIata: "AAA")
}

@Suite struct DurationTests {
    @Test func snapsToFiveMinuteDetentsAndClamps() {
        #expect(PlanState.snap(42) == 40)
        #expect(PlanState.snap(43) == 45)
        #expect(PlanState.snap(3) == 10)
        #expect(PlanState.snap(0) == 10)
        #expect(PlanState.snap(-50) == 10)
        #expect(PlanState.snap(9999) == 360)
    }

    @Test func setDurationSnapsAndRecomputes() {
        var s = state()
        s.setDuration(minutes: 42)
        #expect(s.durationMinutes == 40)
        #expect(s.rangeRing?.minutes == 40)
    }

    @Test func arrowKeysStepByFiveAndStopAtTheLowerBound() {
        var s = state()
        s.setDuration(minutes: 50)
        s.stepDuration(by: 1)
        #expect(s.durationMinutes == 55)
        s.stepDuration(by: -2)
        #expect(s.durationMinutes == 45)
        s.setDuration(minutes: 10)
        s.stepDuration(by: -1)
        #expect(s.durationMinutes == 10)
    }

    @Test func stepRightPastSixHoursEntersFreeFlightAndBack() {
        var s = state()
        s.setDuration(minutes: 360)
        s.stepDuration(by: 1)
        #expect(s.isFreeFlight)
        s.stepDuration(by: -1) // nothing happens going left from Free
        #expect(s.isFreeFlight)
        s.stepDuration(by: 1)
        #expect(s.durationMinutes == PlanState.defaultDurationMinutes)
    }

    @Test func quickChipsMatchThePRD() {
        #expect(PlanState.quickChipMinutes == [15, 25, 50, 90, 120])
        var s = state()
        for chip in PlanState.quickChipMinutes {
            s.applyQuickChip(minutes: chip)
            #expect(s.durationMinutes == chip)
        }
    }

    @Test func freeFlightHasNoRingNoDestinationsAndCanConfirm() throws {
        var s = state()
        s.setFreeFlight()
        #expect(s.rangeRing == nil)
        #expect(s.destinations.isEmpty)
        let selection = try #require(s.confirm())
        #expect(selection.destination == nil && selection.duration == .free)
    }
}

@Suite struct DestinationTests {
    @Test func destinationsAreTheAirportsInsideTheRing() {
        var s = state()
        s.setDuration(minutes: 40)
        #expect(Set(s.destinations.map(\.iata)) == ["MID", "MID2"])
        let ring = s.rangeRing!
        #expect(s.destinations.allSatisfy(ring.contains))
        #expect(!ring.contains(far) && !ring.contains(near))
    }

    @Test func nearestMatchIsSelectedFirst() {
        var s = state()
        s.setDuration(minutes: 40)
        #expect(s.selectedDestination?.iata == "MID")
        #expect(s.selectedIndex == 0)
    }

    @Test func arrowsCycleAndWrap() {
        var s = state()
        s.setDuration(minutes: 40)
        s.selectNextDestination()
        #expect(s.selectedDestination?.iata == "MID2")
        s.selectNextDestination()
        #expect(s.selectedDestination?.iata == "MID")
        s.selectPreviousDestination()
        #expect(s.selectedDestination?.iata == "MID2")
    }

    @Test func selectionSurvivesADurationChangeWhileStillInTheRing() {
        var s = state()
        s.setDuration(minutes: 40)
        s.select(iata: "MID2")
        s.setDuration(minutes: 45) // 43 min is within ±3 of 45; MID (41) is too
        #expect(s.selectedDestination?.iata == "MID2")
        s.setDuration(minutes: 275) // only FAR is in the ring
        #expect(s.selectedDestination?.iata == "FAR")
    }

    @Test func selectingAnAirportOutsideTheRingIsIgnored() {
        var s = state()
        s.setDuration(minutes: 40)
        s.select(iata: "FAR")
        #expect(s.selectedDestination?.iata == "MID")
    }

    @Test func emptyRingHasNothingToConfirm() {
        var s = state()
        s.setDuration(minutes: 120)
        #expect(s.destinations.isEmpty)
        #expect(s.selectedDestination == nil)
        #expect(s.confirm() == nil)
        #expect(s.makeFlight() == nil)
        s.selectNextDestination() // no crash on an empty list
        s.selectPreviousDestination()
        #expect(s.selectedDestination == nil)
    }

    @Test func confirmReturnsTheChosenRoute() throws {
        var s = state()
        s.setDuration(minutes: 40)
        s.select(iata: "MID2")
        let selection = try #require(s.confirm())
        #expect(selection.origin.iata == "AAA" && selection.destination?.iata == "MID2")
        #expect(selection.duration == .minutes(40))
    }
}

@Suite struct SurpriseTests {
    @Test func resultIsInsideTheRingAndSelected() {
        var s = state()
        s.setDuration(minutes: 40)
        var rng = SplitMix64(seed: 1)
        guard case .picked(let pick) = s.surpriseMe(using: &rng) else { Issue.record("expected a pick"); return }
        #expect(s.destinations.contains(pick))
        #expect(s.selectedDestination == pick)
    }

    @Test func sameSeedGivesSameResultAndAllAirportsAreReachable() {
        var seen = Set<String>()
        for seed in 0..<40 as Range<UInt64> {
            var a = state(), b = state()
            a.setDuration(minutes: 40); b.setDuration(minutes: 40)
            var r1 = SplitMix64(seed: seed), r2 = SplitMix64(seed: seed)
            let x = a.surpriseMe(using: &r1), y = b.surpriseMe(using: &r2)
            #expect(x == y)
            if case .picked(let p) = x { seen.insert(p.iata) }
        }
        #expect(seen == ["MID", "MID2"])
    }

    @Test func emptyRingAndFreeFlightHaveDistinctResults() {
        var s = state()
        var rng = SplitMix64(seed: 3)
        s.setDuration(minutes: 120)
        let r = s.surpriseMe(using: &rng)
        #expect(r == .emptyRing)
        s.setFreeFlight()
        let free = s.surpriseMe(using: &rng)
        #expect(free == .freeFlight)
    }
}

@Suite struct OriginTests {
    @Test func changingOriginRedrawsAndPersistsAsDefault() {
        var s = state()
        s.setDuration(minutes: 40)
        let result = s.setOrigin(iata: "FAR")
        #expect(result)
        #expect(s.origin.iata == "FAR")
        #expect(s.preferences.homeIata == "FAR")
        #expect(!s.destinations.contains { $0.iata == "FAR" })
        #expect(s.rangeRing?.center == far.coordinate)
    }

    @Test func unknownOriginIsRejectedAndNothingChanges() {
        var s = state()
        let result = s.setOrigin(iata: "ZZZ")
        #expect(!result)
        #expect(s.origin.iata == "AAA")
    }

    @Test func continueFromLastLanding() {
        var s = state()
        let result = s.continueFromLastLanding()
        #expect(!result)
        s.preferences.lastLandingIata = "MID"
        let continued = s.continueFromLastLanding()
        #expect(continued)
        #expect(s.origin.iata == "MID")
    }

    @Test func favoritesToggle() {
        var s = state()
        s.toggleFavoriteOrigin()
        #expect(s.isFavoriteOrigin && s.favoriteAirports.map(\.iata) == ["AAA"])
        s.toggleFavoriteOrigin()
        #expect(!s.isFavoriteOrigin && s.favoriteAirports.isEmpty)
    }

    @Test func initialOriginFallsBackFromHomeToLandingToDefault() {
        #expect(state(.init(homeIata: "MID")).origin.iata == "MID")
        #expect(state(.init(homeIata: "ZZZ", lastLandingIata: "NEAR")).origin.iata == "NEAR")
        #expect(state(.init()).origin.iata == "AAA")
    }

    @Test func searchDelegatesToTheIndex() {
        #expect(state().searchAirports("mid").map(\.iata).first == "MID")
    }
}

@Suite struct FlightFactoryTests {
    @Test func makeFlightCarriesDurationDistanceAndChoices() throws {
        var s = state(.init(homeIata: "AAA", scenarioID: "code", topic: "Parser", pausePolicy: .flexible))
        s.setDuration(minutes: 40)
        let f = try #require(s.makeFlight(seed: 9))
        #expect(f.originIata == "AAA" && f.destinationIata == "MID")
        #expect(f.durationSec == 2400)
        #expect(abs(f.routeDistanceKm - Geo.distanceKm(from: origin.coordinate, to: mid.coordinate)) < 1e-9)
        #expect(f.scenarioID == "code" && f.topic == "Parser" && f.policy == .flexible && f.seed == 9)
        #expect(f.status == .planned)
    }

    @Test func policyArgumentOverridesThePreference() throws {
        var s = state()
        s.setDuration(minutes: 40)
        #expect(try #require(s.makeFlight(policy: .strict)).policy == .strict)
    }

    @Test func freeFlightHasNoDurationOrDestination() throws {
        var s = state()
        s.setFreeFlight()
        let f = try #require(s.makeFlight())
        #expect(f.isFreeFlight && f.destinationIata == nil && f.routeDistanceKm == 0)
    }

    @Test func togglesAndCoachMarkPersistInPreferences() throws {
        var s = state()
        s.setScenario(id: "read"); s.setTopic("Chapter 3"); s.setMode(.together); s.setStyle(.quick)
        let data = try JSONEncoder().encode(s.preferences)
        let restored = try JSONDecoder().decode(PlanPreferences.self, from: data)
        #expect(restored == s.preferences)
        #expect(restored.scenarioID == "read" && restored.mode == .together && restored.style == .quick)
        #expect(s.showsRulerCoachMark)
        s.dismissRulerCoachMark()
        #expect(!s.showsRulerCoachMark)
    }

    @Test func ritualIsSkippedByQuickStyleOrTheForeverSetting() {
        var s = state()
        #expect(!s.skipsRitual)
        s.setStyle(.quick)
        #expect(s.skipsRitual)
        s.setStyle(.ritual)
        s.preferences.skipRitualAlways = true
        #expect(s.skipsRitual)
    }
}

@Suite struct QuickStartTests {
    @Test func noHistoryMeansNoQuickStart() {
        #expect(state().quickStart() == nil)
    }

    @Test func repeatsLastRouteDurationAndScenario() throws {
        var s = state()
        s.setDuration(minutes: 40)
        s.setScenario(id: "work")
        let first = try #require(s.makeFlight(seed: 1))
        s.recordStarted(first)
        s.setDuration(minutes: 120) // the screen has moved on; Quick Start does not care
        s.setScenario(id: "read")
        let q = try #require(s.quickStart(seed: 2))
        #expect(q.originIata == "AAA" && q.destinationIata == "MID")
        #expect(q.durationSec == 2400 && q.scenarioID == "work" && q.seed == 2)
    }

    @Test func freeFlightCanBeRepeated() throws {
        var s = state()
        s.setFreeFlight()
        s.recordStarted(try #require(s.makeFlight()))
        let q = try #require(s.quickStart())
        #expect(q.isFreeFlight && q.destinationIata == nil)
    }

    @Test func staleAirportsMeanNoQuickStart() {
        let s = state(.init(homeIata: "AAA", lastRoute: .init(originIata: "AAA", destinationIata: "GONE", durationMinutes: 40, scenarioID: "study")))
        #expect(s.quickStart() == nil)
    }

    @Test func landingUpdatesFlyAgainOrigin() throws {
        var s = state()
        s.setDuration(minutes: 40)
        let f = try #require(s.makeFlight())
        s.recordLanded(f)
        #expect(s.preferences.lastLandingIata == "MID")
        let result = s.continueFromLastLanding()
        #expect(result)
        #expect(s.origin.iata == "MID")
    }
}

@Suite struct RangeRingTests {
    @Test func radiusUsesTheFlightTimeFormula() {
        let ring = RangeRing(center: origin.coordinate, minutes: 42)
        #expect(abs(ring.radiusKm - FlightTiming.km(forMinutes: 42)) < 1e-9)
        #expect(ring.innerRadiusKm < ring.radiusKm && ring.radiusKm < ring.outerRadiusKm)
        #expect(RangeRing(center: origin.coordinate, minutes: 10).innerRadiusKm == FlightTiming.km(forMinutes: 7))
    }
}

@Suite struct BundledDataTests {
    let index: AirportIndex
    init() throws { index = try AirportIndex.bundled() }

    @Test func changingOriginRecomputesDestinationsUnder300ms() throws {
        var s = PlanState(index: index, preferences: .init(homeIata: "IST"))
        s.setDuration(minutes: 90)
        let istanbul = Set(s.destinations.map(\.iata))
        #expect(!istanbul.isEmpty)
        let clock = ContinuousClock()
        let elapsed = clock.measure { s.setOrigin(iata: "LHR") }
        #expect(s.origin.iata == "LHR")
        #expect(Set(s.destinations.map(\.iata)) != istanbul)
        #expect(elapsed < .milliseconds(300)) // PRD PLAN-1
    }

    @Test func everyBundledDestinationLiesInsideTheRing() throws {
        var s = PlanState(index: index, preferences: .init(homeIata: "JFK"))
        s.setDuration(minutes: 120)
        let ring = try #require(s.rangeRing)
        #expect(!s.destinations.isEmpty)
        #expect(s.destinations.allSatisfy(ring.contains))
    }

    @Test func londonToParisFlightIsAboutFortyTwoMinutes() throws {
        var s = PlanState(index: index, preferences: .init(homeIata: "LHR"))
        s.setDuration(minutes: 40)
        s.select(iata: "CDG")
        let f = try #require(s.makeFlight())
        #expect(f.destinationIata == "CDG")
        #expect((330...360).contains(f.routeDistanceKm))
    }
}
