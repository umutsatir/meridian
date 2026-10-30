import Foundation

public extension AirportIndex {
    /// Airports with an IATA code and scheduled service, from OurAirports
    /// (public domain), plus hand-curated search aliases. Rebuild the airports
    /// with `Scripts/build-airports.py`; edit `Resources/aliases.json` by hand.
    static func bundled() throws -> AirportIndex {
        func load<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
            guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
        }
        return AirportIndex(airports: try load("airports", as: [Airport].self),
                            aliases: try load("aliases", as: [String: [String]].self))
    }
}
