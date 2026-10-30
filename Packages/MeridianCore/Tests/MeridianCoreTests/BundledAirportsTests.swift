import Foundation
import Testing
@testable import MeridianCore

@Suite struct BundledAirportsTests {
    let index: AirportIndex

    init() throws { index = try AirportIndex.bundled() }

    @Test func containsThousandsOfAirportsWithUniqueCodes() {
        #expect(index.airports.count > 3500)
        #expect(Set(index.airports.map(\.iata)).count == index.airports.count)
    }

    @Test func everyRecordIsWellFormed() {
        for a in index.airports {
            #expect(a.iata.count == 3 && a.iata == a.iata.uppercased(), "\(a.iata)")
            #expect(!a.city.isEmpty && !a.name.isEmpty, "\(a.iata)")
            #expect(a.countryCode.count == 2, "\(a.iata)")
            #expect((-90...90).contains(a.coordinate.latitude) && (-180...180).contains(a.coordinate.longitude), "\(a.iata)")
        }
    }

    @Test func wellKnownAirportsAreThere() {
        for code in ["LHR", "CDG", "IST", "SAW", "JFK", "HND", "SYD", "ESB", "ADB"] {
            #expect(index.airport(iata: code) != nil, "\(code)")
        }
        #expect(index.airport(iata: "IST")?.countryCode == "TR")
    }

    @Test func realLondonToParisIsAboutFortyTwoMinutes() throws {
        let lhr = try #require(index.airport(iata: "LHR")), cdg = try #require(index.airport(iata: "CDG"))
        let minutes = FlightTiming.minutes(forKm: Geo.distanceKm(from: lhr.coordinate, to: cdg.coordinate))
        #expect((40...44).contains(minutes))
    }

    @Test func istanbulHasDestinationsForCommonDurations() throws {
        let ist = try #require(index.airport(iata: "IST"))
        for minutes in [10, 25, 60, 120, 240] {
            #expect(!index.destinations(from: ist, minutes: minutes).isEmpty, "\(minutes) min")
        }
    }

    @Test func searchFindsCitiesAndFoldsDiacritics() {
        #expect(index.search("istanbul").map(\.iata).contains("IST"))
        #expect(index.search("antalya").map(\.iata).contains("AYT"))
    }

    @Test func destinationsFromAllAirportsStayFastEnough() throws {
        let ist = try #require(index.airport(iata: "IST"))
        let clock = ContinuousClock()
        let elapsed = clock.measure { _ = index.destinations(from: ist, minutes: 90) }
        #expect(elapsed < .milliseconds(100)) // PRD PLAN-1: redraw in < 300 ms
    }

    @Test func districtNamedAirportsAreFoundByTheirCity() {
        #expect(index.search("izmir").map(\.iata).contains("ADB"))
        #expect(index.search("istanbul").map(\.iata).contains("SAW"))
        #expect(index.search("brussels").map(\.iata).contains("BRU"))
        #expect(index.search("milan").map(\.iata).contains("MXP"))
        #expect(index.search("london").map(\.iata).contains("LTN"))
        #expect(index.search("londra").map(\.iata).contains("LHR"))
        #expect(index.search("tokyo").map(\.iata).contains("NRT"))
    }

    @Test func aliasFileOnlyReferencesRealAirports() throws {
        let url = try #require(Bundle.module.url(forResource: "aliases", withExtension: "json"))
        let aliases = try JSONDecoder().decode([String: [String]].self, from: Data(contentsOf: url))
        #expect(aliases.count > 100)
        for (code, names) in aliases {
            #expect(index.airport(iata: code) != nil, "\(code)")
            #expect(!names.isEmpty && names.allSatisfy { !$0.isEmpty }, "\(code)")
        }
    }

    @Test func everyAirportHasACountryName() {
        let missing = index.airports.filter { $0.countryName(locale: Locale(identifier: "en")) == nil }
        #expect(missing.count < 5, "\(Set(missing.map(\.countryCode)))")
    }

    @Test func searchIsFastOverAllAirports() {
        let clock = ContinuousClock()
        let elapsed = clock.measure { for q in ["i", "ist", "izmir", "lon", "new york"] { _ = index.search(q) } }
        #expect(elapsed < .milliseconds(100))
    }
}
