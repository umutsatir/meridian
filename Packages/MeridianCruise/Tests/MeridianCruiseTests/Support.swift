import Foundation
import MeridianCore

enum Fx {
    static let lhr = Airport(iata: "LHR", name: "Heathrow", city: "London", countryCode: "GB", continent: .europe, coordinate: .init(latitude: 51.47, longitude: -0.4543))
    static let cdg = Airport(iata: "CDG", name: "Charles de Gaulle", city: "Paris", countryCode: "FR", continent: .europe, coordinate: .init(latitude: 49.0097, longitude: 2.5479))
    static let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    static func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }

    static func utc(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

    /// 42 minute LHR→CDG flight that took off at `t0`.
    static func flight(policy: PausePolicy = .normal, minutes: Double? = 42) -> Flight {
        var f = Flight(originIata: "LHR", destinationIata: "CDG", scenarioID: "study", policy: policy,
                       durationSec: minutes.map { $0 * 60 }, routeDistanceKm: 348, seed: 7)
        try! f.board()
        try! f.takeOff(at: t0)
        return f
    }
}
