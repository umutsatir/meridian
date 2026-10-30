import Foundation

public extension AirportIndex {
    /// Airports with an IATA code and scheduled service, from OurAirports
    /// (public domain). Rebuild with `Scripts/build-airports.py`.
    static func bundled() throws -> AirportIndex {
        guard let url = Bundle.module.url(forResource: "airports", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return AirportIndex(airports: try JSONDecoder().decode([Airport].self, from: Data(contentsOf: url)))
    }
}
