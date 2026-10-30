import Foundation
@testable import MeridianCore

enum Fixtures {
    static let lhr = Airport(iata: "LHR", name: "Heathrow", city: "London", countryCode: "GB", continent: .europe, coordinate: .init(latitude: 51.4700, longitude: -0.4543))
    static let cdg = Airport(iata: "CDG", name: "Charles de Gaulle", city: "Paris", countryCode: "FR", continent: .europe, coordinate: .init(latitude: 49.0097, longitude: 2.5479))
    static let ist = Airport(iata: "IST", name: "Istanbul Airport", city: "İstanbul", countryCode: "TR", continent: .europe, coordinate: .init(latitude: 41.2753, longitude: 28.7519))
    static let jfk = Airport(iata: "JFK", name: "John F. Kennedy", city: "New York", countryCode: "US", continent: .northAmerica, coordinate: .init(latitude: 40.6413, longitude: -73.7781))
    static let index = AirportIndex(airports: [lhr, cdg, ist, jfk])

    static let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    /// A boarded-and-departed 42 minute LHR→CDG flight starting at `t0`.
    static func flight(policy: PausePolicy = .normal, minutes: Double? = 42) -> Flight {
        var f = Flight(originIata: "LHR", destinationIata: "CDG", scenarioID: "study", policy: policy,
                       durationSec: minutes.map { $0 * 60 }, routeDistanceKm: 348, seed: 7)
        try! f.board()
        try! f.takeOff(at: t0)
        return f
    }
}
