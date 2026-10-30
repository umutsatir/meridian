import Foundation
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

@Suite struct AirportAliasTests {
    @Test func aliasMatchesLikeTheCity() {
        let gaziemir = Airport(iata: "ADB", name: "Adnan Menderes", city: "Gaziemir", countryCode: "TR", continent: .asia, coordinate: .init(latitude: 38.29, longitude: 27.16))
        let index = AirportIndex(airports: [gaziemir, Fixtures.cdg], aliases: ["ADB": ["İzmir"]])
        #expect(index.search("izmir").map(\.iata) == ["ADB"])
        #expect(index.search("İZMİR").map(\.iata) == ["ADB"])
        #expect(index.search("gazi").map(\.iata) == ["ADB"])
        #expect(AirportIndex(airports: [gaziemir]).search("izmir").isEmpty)
    }

    @Test func countryNameFollowsTheLocale() {
        #expect(Fixtures.ist.countryName(locale: Locale(identifier: "en")) == "Türkiye" || Fixtures.ist.countryName(locale: Locale(identifier: "en")) == "Turkey")
        #expect(Fixtures.cdg.countryName(locale: Locale(identifier: "en")) == "France")
        #expect(Fixtures.cdg.countryName(locale: Locale(identifier: "tr")) == "Fransa")
        let bogus = Airport(iata: "ZZZ", name: "x", city: "x", countryCode: "ZZ", continent: .europe, coordinate: .init(latitude: 0, longitude: 0))
        #expect(bogus.countryName(locale: Locale(identifier: "en")) == nil || bogus.countryName(locale: Locale(identifier: "en")) == "Unknown Region")
    }
}
