import Foundation

/// A runway as the two surveyed ends of its centre line.
public struct Runway: Sendable, Equatable {
    public var a: Coordinate
    public var b: Coordinate
    public init(a: Coordinate, b: Coordinate) { self.a = a; self.b = b }
    public var lengthKm: Double { Geo.distanceKm(from: a, to: b) }
}

/// The runway a departure uses: where the roll starts, which way it points and how long it is.
public struct DepartureRunway: Sendable, Equatable {
    public var start: Coordinate
    public var end: Coordinate
    /// Degrees clockwise from north.
    public var bearing: Double
    public var lengthM: Double
    /// `false` when the airport has no surveyed runway and this is a stand-in through the airport's reference point.
    public var surveyed: Bool
}

/// Runways of the bundled airports, from OurAirports (public domain). Rebuild with `Scripts/build-runways.py`.
public enum BundledRunways {
    private static let table: [String: [[Double]]] = {
        guard let url = Bundle.module.url(forResource: "runways", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let t = try? JSONDecoder().decode([String: [[Double]]].self, from: data) else { return [:] }
        return t
    }()

    /// Up to four of the airport's longest runways, longest first.
    public static func runways(iata: String) -> [Runway] {
        (table[iata.uppercased()] ?? []).compactMap { v in
            v.count == 4 ? Runway(a: Coordinate(latitude: v[0], longitude: v[1]), b: Coordinate(latitude: v[2], longitude: v[3])) : nil
        }
    }

    /// Shortest angle between two compass directions, 0...180.
    static func angle(_ a: Double, _ b: Double) -> Double {
        let d = abs((a - b).truncatingRemainder(dividingBy: 360))
        return d > 180 ? 360 - d : d
    }

    /// The runway and direction that point closest to `bearing` (the way the flight leaves). Airports without surveyed
    /// runways get a 2.4 km stand-in through their reference point along `bearing`.
    public static func departure(from airport: Airport, toward bearing: Double) -> DepartureRunway {
        var best: DepartureRunway?
        var bestAngle = Double.infinity
        for r in runways(iata: airport.iata) {
            for (s, e) in [(r.a, r.b), (r.b, r.a)] {
                let b = Geo.bearing(from: s, to: e), d = angle(b, bearing)
                if d < bestAngle - 0.5 {     // near ties keep the longer runway (the table is longest first)
                    bestAngle = d
                    best = DepartureRunway(start: s, end: e, bearing: b, lengthM: Geo.distanceKm(from: s, to: e) * 1000, surveyed: true)
                }
            }
        }
        if let best { return best }
        let c = airport.coordinate
        func step(_ km: Double, _ brg: Double) -> Coordinate {
            let rad = brg * .pi / 180
            return Coordinate(latitude: c.latitude + km / 111.32 * cos(rad),
                              longitude: c.longitude + km / (111.32 * max(0.05, cos(c.latitude * .pi / 180))) * sin(rad))
        }
        return DepartureRunway(start: step(1.2, bearing + 180), end: step(1.2, bearing), bearing: bearing, lengthM: 2400, surveyed: false)
    }
}
