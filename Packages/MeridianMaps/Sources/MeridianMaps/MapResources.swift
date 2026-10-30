import SwiftUI
import ImageIO
import MeridianCore

/// Parsed-once, cached map geometry. Everything here is immutable and loaded lazily on first use;
/// `MapResources.preload()` can be called from a background task (e.g. at launch) so the first frame does not pay for it.
public enum MapResources {
    /// Size of the Europe plane (the SVG viewBox and `.eu` box of the design).
    public static let europePlane = CGSize(width: 3200, height: 2589)

    /// Land silhouette (even-odd fill) in plane coordinates.
    static let europeLand: Path = loadPath("map-europe-land")
    /// Borders (stroked 1.2 plane px, round joins) in plane coordinates.
    static let europeBorders: Path = loadPath("map-europe-borders")
    /// Bounding rect of the land in plane coordinates, used for culling decisions.
    static let europeLandBounds: CGRect = europeLand.boundingRect

    /// Terrain texture of the Satellite style (rasterized `terrain-fields.svg`, saturate .8 / brightness .9 baked in).
    static let terrain: SendableImage? = {
        guard let url = Bundle.module.url(forResource: "terrain-fields", withExtension: "jpg"),
              let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        else { return nil }
        return SendableImage(image: img)
    }()

    static let world: WorldGeometry = WorldGeometry.load()

    /// Design kit airports (`K.airports`): code -> coordinates, used by the fidelity tests and as fallback.
    static let designAirports: [String: DesignAirport] = {
        guard let url = Bundle.module.url(forResource: "design-airports", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: [DesignAirportField]].self, from: data) else { return [:] }
        var out: [String: DesignAirport] = [:]
        for (code, f) in raw where f.count == 5 {
            out[code] = DesignAirport(code: code, city: f[0].string, name: f[1].string, countryCode: f[2].string,
                                      coordinate: Coordinate(latitude: f[3].number, longitude: f[4].number))
        }
        return out
    }()

    /// Forces parsing of every bundled resource (safe from any thread).
    public static func preload() {
        _ = europeLand; _ = europeBorders; _ = terrain; _ = world
    }

    private static func loadPath(_ name: String) -> Path {
        guard let url = Bundle.module.url(forResource: name, withExtension: "svg"),
              let svg = try? String(contentsOf: url, encoding: .utf8) else { return Path() }
        return SVGPathParser.path(svg: svg)
    }
}

struct SendableImage: @unchecked Sendable {
    let image: CGImage
}

struct DesignAirport: Sendable {
    var code: String, city: String, name: String, countryCode: String
    var coordinate: Coordinate
}

/// `["Istanbul","Istanbul Airport","TR",41.2,28.7]` mixes strings and numbers.
struct DesignAirportField: Decodable {
    var string: String = ""
    var number: Double = 0
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { string = s } else { number = try c.decode(Double.self) }
    }
}

/// The world rings of `meridian-world.js` (`[lon*10, lat*10, ...]` per ring), prepared for fast projection:
/// per point we keep cos/sin of latitude and longitude so a frame needs no trigonometry per point.
struct WorldGeometry: Sendable {
    struct Rings: Sendable {
        /// Flat (cosφ, sinφ, cosλ, sinλ) per point.
        var pts: [Float]
        /// Point range per ring (start index in points, count).
        var ranges: [(start: Int, count: Int)]
    }

    var land = Rings(pts: [], ranges: [])
    var borders = Rings(pts: [], ranges: [])
    var hi = Rings(pts: [], ranges: [])
    var mid = Rings(pts: [], ranges: [])
    var lo = Rings(pts: [], ranges: [])

    static func load() -> WorldGeometry {
        guard let url = Bundle.module.url(forResource: "world", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: [[Int]]].self, from: data) else { return WorldGeometry() }
        func build(_ rings: [[Int]]?) -> Rings {
            var pts = [Float](), ranges = [(start: Int, count: Int)]()
            for r in rings ?? [] {
                let start = pts.count / 4
                var k = 0
                while k + 1 < r.count {
                    let lon = Double(r[k]) / 10 * .pi / 180, lat = Double(r[k + 1]) / 10 * .pi / 180
                    pts.append(Float(cos(lat))); pts.append(Float(sin(lat)))
                    pts.append(Float(cos(lon))); pts.append(Float(sin(lon)))
                    k += 2
                }
                ranges.append((start, pts.count / 4 - start))
            }
            return Rings(pts: pts, ranges: ranges)
        }
        return WorldGeometry(land: build(raw["land"]), borders: build(raw["borders"]), hi: build(raw["hi"]),
                             mid: build(raw["mid"]), lo: build(raw["lo"]))
    }
}

/// Airport lookup for routes and pins. `.bundled` uses MeridianCore's airport database (the app's real data);
/// `.design` uses the coordinates of the design kit (`K.airports`), for pixel-comparing the design artboards.
public struct MapAirports: Sendable {
    private let lookup: @Sendable (String) -> Coordinate?
    public init(_ lookup: @escaping @Sendable (String) -> Coordinate?) { self.lookup = lookup }

    public func coordinate(_ iata: String) -> Coordinate? { lookup(iata.uppercased()) }

    private static let index: AirportIndex? = try? AirportIndex.bundled()

    /// MeridianCore bundled airports, falling back to the design table for codes the database lacks.
    public static let bundled = MapAirports { code in
        index?.airport(iata: code)?.coordinate ?? MapResources.designAirports[code]?.coordinate
    }
    /// The design kit's airport table only.
    public static let design = MapAirports { MapResources.designAirports[$0]?.coordinate }
}
