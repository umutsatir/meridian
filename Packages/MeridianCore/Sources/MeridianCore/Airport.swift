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

    /// Country name in `locale`'s language ("Türkiye", "Turkey"), or `nil` for an unknown region code.
    public func countryName(locale: Locale = .current) -> String? {
        locale.localizedString(forRegionCode: countryCode)
    }
}

public enum Continent: String, Sendable, Codable, CaseIterable {
    case africa, antarctica, asia, europe, northAmerica, oceania, southAmerica
}

public struct AirportIndex: Sendable {
    public let airports: [Airport]
    private let byCode: [String: Airport]
    private let keys: [SearchKey]

    /// Folded strings one airport can be found by, computed once.
    private struct SearchKey: Sendable {
        var code: String
        var city: String
        var name: String
        var country: String
        var aliases: [String]
    }

    /// - Parameter aliases: extra names per IATA code (district vs. city, local
    ///   spellings, exonyms) that search should match like the city.
    public init(airports: [Airport], aliases: [String: [String]] = [:]) {
        self.airports = airports
        self.byCode = Dictionary(airports.map { ($0.iata, $0) }, uniquingKeysWith: { first, _ in first })
        self.keys = airports.map { a in
            SearchKey(code: a.iata.lowercased(), city: Self.fold(a.city), name: Self.fold(a.name),
                      country: a.countryCode.lowercased(), aliases: (aliases[a.iata] ?? []).map(Self.fold))
        }
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

    /// Search by IATA code, city, alias, name or country code (PRD PLAN-6). Case
    /// and diacritic insensitive; exact code matches first, then prefix, then contains.
    public func search(_ query: String, limit: Int = 20) -> [Airport] {
        let q = Self.fold(query).trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        func rank(_ k: SearchKey) -> Int? {
            if k.code == q { return 0 }
            if k.city.hasPrefix(q) || k.code.hasPrefix(q) || k.aliases.contains(where: { $0.hasPrefix(q) }) { return 1 }
            if k.name.hasPrefix(q) { return 2 }
            if k.city.contains(q) || k.name.contains(q) || k.country == q || k.aliases.contains(where: { $0.contains(q) }) { return 3 }
            return nil
        }
        return zip(airports, keys)
            .compactMap { a, k in rank(k).map { (a, $0) } }
            .sorted { ($0.1, $0.0.iata) < ($1.1, $1.0.iata) }
            .prefix(limit)
            .map(\.0)
    }

    private static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
