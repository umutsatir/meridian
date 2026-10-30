import Foundation

public struct Airport: Sendable, Hashable, Codable, Identifiable {
    public var iata: String
    public var name: String
    public var city: String
    /// ISO 3166-1 alpha-2.
    public var countryCode: String
    public var continent: Continent
    public var coordinate: Coordinate

    public var id: String { iata }

    public init(iata: String, name: String, city: String, countryCode: String, continent: Continent, coordinate: Coordinate) {
        self.iata = iata
        self.name = name
        self.city = city
        self.countryCode = countryCode
        self.continent = continent
        self.coordinate = coordinate
    }
}

public enum Continent: String, Sendable, Codable, CaseIterable {
    case africa, antarctica, asia, europe, northAmerica, oceania, southAmerica
}

public struct AirportIndex: Sendable {
    public let airports: [Airport]
    private let byCode: [String: Airport]

    public init(airports: [Airport]) {
        self.airports = airports
        self.byCode = Dictionary(airports.map { ($0.iata, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public func airport(iata: String) -> Airport? { byCode[iata.uppercased()] }

    /// Airports whose flight time from `origin` is within `toleranceMinutes` of
    /// `minutes` (PRD PLAN-3), nearest match first.
    public func destinations(from origin: Airport, minutes: Int, toleranceMinutes: Int = 3) -> [Airport] {
        airports
            .compactMap { dest -> (Airport, Int)? in
                guard dest.iata != origin.iata else { return nil }
                let t = FlightTiming.minutes(forKm: Geo.distanceKm(from: origin.coordinate, to: dest.coordinate))
                let delta = abs(t - minutes)
                return delta <= toleranceMinutes ? (dest, delta) : nil
            }
            .sorted { ($0.1, $0.0.iata) < ($1.1, $1.0.iata) }
            .map(\.0)
    }

    /// Search by IATA code, city, name or country code (PRD PLAN-6). Case and
    /// diacritic insensitive; exact code matches first, then prefix, then contains.
    public func search(_ query: String, limit: Int = 20) -> [Airport] {
        let q = Self.fold(query)
        guard !q.isEmpty else { return [] }
        func rank(_ a: Airport) -> Int? {
            let code = a.iata.lowercased()
            if code == q { return 0 }
            let city = Self.fold(a.city), name = Self.fold(a.name)
            if city.hasPrefix(q) || code.hasPrefix(q) { return 1 }
            if name.hasPrefix(q) { return 2 }
            if city.contains(q) || name.contains(q) || a.countryCode.lowercased() == q { return 3 }
            return nil
        }
        return airports
            .compactMap { a in rank(a).map { (a, $0) } }
            .sorted { ($0.1, $0.0.iata) < ($1.1, $1.0.iata) }
            .prefix(limit)
            .map(\.0)
    }

    private static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
