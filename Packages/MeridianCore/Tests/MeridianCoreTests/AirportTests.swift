import Testing
@testable import MeridianCore

@Suite struct AirportTests {
    @Test func destinationsAreWithinTolerance() {
        let result = Fixtures.index.destinations(from: Fixtures.lhr, minutes: 42)
        #expect(result.map(\.iata) == ["CDG"])
    }

    @Test func destinationsExcludeOriginAndFarAirports() {
        let result = Fixtures.index.destinations(from: Fixtures.lhr, minutes: 42, toleranceMinutes: 1000)
        #expect(!result.contains { $0.iata == "LHR" })
        #expect(result.count == 3)
    }

    @Test func shortFlightFindsNearbyAirportOnly() {
        #expect(Fixtures.index.destinations(from: Fixtures.lhr, minutes: 10).isEmpty)
    }

    @Test func searchByCodeCityAndDiacritics() {
        #expect(Fixtures.index.search("cdg").first?.iata == "CDG")
        #expect(Fixtures.index.search("istanbul").first?.iata == "IST")
        #expect(Fixtures.index.search("par").first?.iata == "CDG")
        #expect(Fixtures.index.search("tr").first?.iata == "IST")
        #expect(Fixtures.index.search("  ").isEmpty)
    }

    @Test func lookupIsCaseInsensitive() {
        #expect(Fixtures.index.airport(iata: "lhr")?.city == "London")
        #expect(Fixtures.index.airport(iata: "XXX") == nil)
    }
}
