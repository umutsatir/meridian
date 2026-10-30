import Foundation
import MeridianCore
import SwiftData
import Testing
@testable import MeridianData

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
private func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }

private let cdg = Airport(iata: "CDG", name: "Charles de Gaulle", city: "Paris", countryCode: "FR", continent: .europe, coordinate: .init(latitude: 49.0097, longitude: 2.5479))
private let ory = Airport(iata: "ORY", name: "Orly", city: "Paris", countryCode: "FR", continent: .europe, coordinate: .init(latitude: 48.7233, longitude: 2.3794))
private let jfk = Airport(iata: "JFK", name: "JFK", city: "New York", countryCode: "US", continent: .northAmerica, coordinate: .init(latitude: 40.6413, longitude: -73.7781))
private let airports = AirportIndex(airports: [cdg, ory, jfk])

private func departed(to dest: String = "CDG", minutes: Double = 42, km: Double = 348, policy: PausePolicy = .normal, start: Date = t0) -> Flight {
    var f = Flight(originIata: "LHR", destinationIata: dest, scenarioID: "study", policy: policy,
                   durationSec: minutes * 60, routeDistanceKm: km, seed: UInt64.max - 3)
    try! f.board()
    try! f.takeOff(at: start)
    return f
}

private func makeStore(url: URL? = nil) throws -> FlightStore {
    let store = FlightStore(modelContainer: try MeridianSchema.container(storeURL: url))
    return store
}

private func tempStoreURL() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("meridian-\(UUID().uuidString).store")
}

@Suite struct FlightStoreTests {
    @Test func roundTripPreservesEveryField() async throws {
        let store = try makeStore()
        var f = departed(policy: .flexible)
        try f.startPause(at: at(10))
        try f.resume(at: at(14))
        try f.startBreak(at: at(20))
        f.notes = "deep work"
        f.topic = "thesis"
        try await store.begin(f)
        let loaded = try #require(try await store.activeFlight())
        #expect(loaded == f)
        #expect(loaded.seed == UInt64.max - 3)
        #expect(loaded.elapsedSec(at: at(30)) == f.elapsedSec(at: at(30)))
    }

    @Test func secondActiveFlightIsRejected() async throws {
        let store = try makeStore()
        try await store.begin(departed())
        await #expect(throws: FlightStoreError.activeFlightExists) { try await store.begin(departed()) }
    }

    @Test func relaunchReadsTheSameFlightFromDisk() async throws {
        let url = tempStoreURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let f = departed()
        do {
            let first = try makeStore(url: url)
            try await first.begin(f)
        }
        let second = try makeStore(url: url) // new container, same file = relaunch
        let outcome = try await second.resume(at: at(10))
        #expect(outcome == .resumedInFlight(f))
        #expect(try await second.activeFlight() == f)
    }

    @Test func sleepingPastTheEndLandsWhileAway() async throws {
        let store = try makeStore()
        await store.configure(airports: airports)
        try await store.begin(departed())
        let outcome = try await store.resume(at: at(600))
        guard case .landedWhileAway(let summary) = outcome else { Issue.record("expected landedWhileAway, got \(outcome)"); return }
        #expect(summary.flight.status == .landed)
        #expect(summary.flight.endedAt == at(42))
        #expect(summary.creditedKm == 348)
        #expect(summary.newStampCountry == "FR")
        #expect(try await store.activeFlight() == nil)
        #expect(try await store.totalKm() == 348)
        #expect(try await store.landingDates() == [at(42)])
        // A second launch finds nothing left to do.
        #expect(try await store.resume(at: at(700)) == .unchanged)
    }

    @Test func noActiveFlightAndBoardingAreUnchanged() async throws {
        let store = try makeStore()
        #expect(try await store.resume(at: t0) == .unchanged)
        var f = Flight(originIata: "LHR", destinationIata: "CDG", scenarioID: "study", durationSec: 2520, routeDistanceKm: 348)
        try f.board()
        try await store.begin(f)
        #expect(try await store.resume(at: at(5)) == .unchanged)
    }

    @Test func updateChangesPersistedState() async throws {
        let store = try makeStore()
        var f = departed(policy: .flexible)
        try await store.begin(f)
        try f.startPause(at: at(5))
        try await store.update(f)
        let loaded = try #require(try await store.activeFlight())
        #expect(loaded.isHeld)
        await #expect(throws: FlightStoreError.noActiveFlight) { try await store.update(departed()) }
    }

    @Test func cardsUnlockOnceAndNeverRelock() async throws {
        let store = try makeStore()
        await store.configure(airports: airports)
        var first = departed(km: 900)
        first.settle(at: at(100))
        let s1 = try await store.complete(first)
        #expect(s1.unlockedTiers == [.departure])
        var second = departed(km: 300, start: at(200))
        second.settle(at: at(400))
        let s2 = try await store.complete(second)
        #expect(s2.unlockedTiers == [.cruise]) // 900 -> 1200 km
        var third = departed(km: 100, start: at(500))
        third.settle(at: at(700))
        #expect(try await store.complete(third).unlockedTiers.isEmpty)
        #expect(try await store.unlockedTiers() == [.departure, .cruise])
        // Deleting a flight lowers the total but keeps the card.
        try await store.delete(flightID: second.id)
        #expect(try await store.totalKm() == 1000)
        #expect(try await store.unlockedTiers() == [.departure, .cruise])
    }

    @Test func completeIsIdempotent() async throws {
        let store = try makeStore()
        await store.configure(airports: airports)
        var f = departed()
        f.settle(at: at(100))
        _ = try await store.complete(f)
        let again = try await store.complete(f)
        #expect(again.unlockedTiers.isEmpty && again.newStampCountry == nil)
        #expect(try await store.totalKm() == 348)
        #expect(try await store.finishedFlights().count == 1)
    }

    @Test func divertedFlightCreditsPartialKmWithoutAStamp() async throws {
        let store = try makeStore()
        await store.configure(airports: airports)
        let f0 = departed()
        try await store.begin(f0)
        var f = f0
        try f.landEarly(at: at(21))
        let summary = try await store.complete(f)
        #expect(summary.creditedKm == 174)
        #expect(summary.newStampCountry == nil)
        #expect(try await store.activeFlight() == nil)
        #expect(try await store.stampedCountries().isEmpty)
    }

    @Test func oneStampPerCountry() async throws {
        let store = try makeStore()
        await store.configure(airports: airports)
        var a = departed(to: "CDG"); a.settle(at: at(100))
        var b = departed(to: "ORY", start: at(200)); b.settle(at: at(400))
        var c = departed(to: "JFK", start: at(500)); c.settle(at: at(900))
        #expect(try await store.complete(a).newStampCountry == "FR")
        #expect(try await store.complete(b).newStampCountry == nil)
        #expect(try await store.complete(c).newStampCountry == "US")
        #expect(try await store.stampedCountries() == ["FR", "US"])
    }

    @Test func unfinishedFlightCannotBeCompleted() async throws {
        let store = try makeStore()
        await #expect(throws: FlightStoreError.flightNotFinished) { try await store.complete(departed()) }
    }

    @Test func deleteAllDataWipesEverything() async throws {
        let store = try makeStore()
        await store.configure(airports: airports)
        var done = departed(); done.settle(at: at(100))
        try await store.complete(done)
        try await store.begin(departed(start: at(200)))
        try await store.updateProfile(homeAirportIata: "IST", dailyGoalMinutes: 90)
        try await store.deleteAllData()
        #expect(try await store.activeFlight() == nil)
        #expect(try await store.finishedFlights().isEmpty)
        #expect(try await store.unlockedTiers().isEmpty)
        #expect(try await store.stampedCountries().isEmpty)
        #expect(try await store.totalKm() == 0)
        #expect(try await store.profile().homeAirportIata == nil)
        try await store.begin(departed()) // slot is free again
    }

    @Test func streakCanBeBuiltFromStoredLandings() async throws {
        let store = try makeStore()
        await store.configure(airports: airports)
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        for day in 0..<3 {
            var f = departed(start: t0.addingTimeInterval(Double(day) * 86_400))
            f.settle(at: f.startedAt!.addingTimeInterval(7200))
            try await store.complete(f)
        }
        let dates = try await store.landingDates()
        #expect(Streak.current(landingDates: dates, now: t0.addingTimeInterval(2 * 86_400 + 3600), calendar: cal) == 3)
    }
}
