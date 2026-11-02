import Foundation
import MeridianCore

/// Current weather at one point (Open-Meteo `current`). Model output, not a satellite measurement.
public struct WeatherCondition: Sendable, Equatable, Codable {
    /// 0...100
    public var cloudCover: Double
    /// mm in the last interval
    public var precipitationMM: Double
    /// WMO weather interpretation code
    public var weatherCode: Int
    public var windKmh: Double

    public init(cloudCover: Double, precipitationMM: Double, weatherCode: Int, windKmh: Double) {
        self.cloudCover = cloudCover; self.precipitationMM = precipitationMM; self.weatherCode = weatherCode; self.windKmh = windKmh
    }

    /// Sun and no clouds: what the window shows without data.
    public static let clear = WeatherCondition(cloudCover: 0, precipitationMM: 0, weatherCode: 0, windKmh: 0)

    public var kind: WeatherKind { WeatherKind(code: weatherCode) }
}

public enum WeatherKind: String, Sendable, Equatable {
    case clear, partlyCloudy, overcast, fog, drizzle, rain, snow, thunderstorm

    /// WMO code table 4677 as used by Open-Meteo.
    public init(code: Int) {
        switch code {
        case 0, 1: self = .clear
        case 2: self = .partlyCloudy
        case 3: self = .overcast
        case 45, 48: self = .fog
        case 51...57: self = .drizzle
        case 61...67, 80...82: self = .rain
        case 71...77, 85, 86: self = .snow
        case 95...99: self = .thunderstorm
        default: self = .clear
        }
    }
}

/// What the window draws for a weather condition: all values 0...1.
public struct WindowAtmosphere: Sendable, Equatable {
    public var cloud: Double
    public var rain: Double
    public var fog: Double
    public var snow: Double
    public var storm: Bool

    public init(cloud: Double = 0, rain: Double = 0, fog: Double = 0, snow: Double = 0, storm: Bool = false) {
        self.cloud = cloud; self.rain = rain; self.fog = fog; self.snow = snow; self.storm = storm
    }

    public static let clear = WindowAtmosphere()

    public init(_ w: WeatherCondition) {
        var cloud = min(1, max(0, w.cloudCover / 100))
        var rain = 0.0, fog = 0.0, snow = 0.0, storm = false
        let intensity = min(1, 0.45 + w.precipitationMM / 2)
        switch w.kind {
        case .clear, .partlyCloudy, .overcast: break
        case .fog: fog = 0.85; cloud = max(cloud, 0.5)
        case .drizzle: rain = 0.35; cloud = max(cloud, 0.75)
        case .rain: rain = intensity; cloud = max(cloud, 0.85)
        case .snow: snow = intensity; cloud = max(cloud, 0.8); fog = 0.25
        case .thunderstorm: rain = 1; cloud = 1; storm = true
        }
        self.init(cloud: cloud, rain: rain, fog: fog, snow: snow, storm: storm)
    }

    /// The canvas scene key for a manual / fixed look (`WindowSceneSpec`).
    public var raining: Bool { rain > 0.2 }
}

public extension WindowScene {
    /// Scene for a sun elevation and a real weather condition (rain replaces everything except night).
    static func scene(elevation: Double, weather: WeatherCondition) -> WindowScene {
        scene(elevation: elevation, isRaining: WindowAtmosphere(weather).raining)
    }
}

// MARK: - Route sampling

public enum WeatherRoute {
    /// Fractions along the route to query: both ends and one point about every 400 km, 2 to 6 in total.
    public static func sampleFractions(routeKm: Double) -> [Double] {
        let n = min(6, max(2, Int((routeKm / 400).rounded(.up)) + 1))
        return (0..<n).map { Double($0) / Double(n - 1) }
    }

    public static func samplePoints(from a: Coordinate, to b: Coordinate) -> [(fraction: Double, coordinate: Coordinate)] {
        let km = Geo.distanceKm(from: a, to: b)
        return sampleFractions(routeKm: km).map { ($0, Geo.interpolate(from: a, to: b, fraction: $0)) }
    }
}

/// Weather along the route: samples at fractions, interpolated for any progress.
public struct WeatherProfile: Sendable, Equatable {
    public var samples: [(fraction: Double, condition: WeatherCondition)]
    /// `true` when no sample could be fetched and the default (sun, no clouds) is used.
    public var isFallback: Bool

    public init(samples: [(fraction: Double, condition: WeatherCondition)], isFallback: Bool = false) {
        self.samples = samples.sorted { $0.fraction < $1.fraction }
        self.isFallback = isFallback
    }

    public static let clear = WeatherProfile(samples: [], isFallback: true)

    public static func == (l: WeatherProfile, r: WeatherProfile) -> Bool {
        l.isFallback == r.isFallback && l.samples.count == r.samples.count
            && zip(l.samples, r.samples).allSatisfy { $0.fraction == $1.fraction && $0.condition == $1.condition }
    }

    /// Cloud cover, precipitation and wind interpolate linearly; the weather code is the one of the nearer sample.
    public func condition(at fraction: Double) -> WeatherCondition {
        guard let first = samples.first, let last = samples.last else { return .clear }
        if fraction <= first.fraction { return first.condition }
        if fraction >= last.fraction { return last.condition }
        guard let i = samples.firstIndex(where: { $0.fraction >= fraction }), i > 0 else { return first.condition }
        let a = samples[i - 1], b = samples[i]
        let t = (fraction - a.fraction) / max(1e-9, b.fraction - a.fraction)
        func mix(_ x: Double, _ y: Double) -> Double { x + (y - x) * t }
        return WeatherCondition(
            cloudCover: mix(a.condition.cloudCover, b.condition.cloudCover),
            precipitationMM: mix(a.condition.precipitationMM, b.condition.precipitationMM),
            weatherCode: t < 0.5 ? a.condition.weatherCode : b.condition.weatherCode,
            windKmh: mix(a.condition.windKmh, b.condition.windKmh))
    }
}

// MARK: - Open-Meteo

public enum OpenMeteo {
    public static func url(for c: Coordinate) -> URL {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            .init(name: "latitude", value: String(format: "%.3f", c.latitude)),
            .init(name: "longitude", value: String(format: "%.3f", c.longitude)),
            .init(name: "current", value: "cloud_cover,precipitation,weather_code,wind_speed_10m"),
        ]
        return comps.url!
    }

    struct Response: Decodable {
        struct Current: Decodable {
            var cloud_cover: Double?
            var precipitation: Double?
            var weather_code: Int?
            var wind_speed_10m: Double?
        }
        var current: Current
    }

    public static func parse(_ data: Data) throws -> WeatherCondition {
        let r = try JSONDecoder().decode(Response.self, from: data)
        return WeatherCondition(cloudCover: r.current.cloud_cover ?? 0, precipitationMM: r.current.precipitation ?? 0,
                                weatherCode: r.current.weather_code ?? 0, windKmh: r.current.wind_speed_10m ?? 0)
    }
}

/// Fetches weather with a 10 minute cache keyed by a 0.5 degree grid cell. No network or a bad answer means
/// "no sample": the window then falls back to sun and no clouds.
public actor WeatherService {
    public typealias Fetcher = @Sendable (URL) async throws -> Data

    public static let ttl: TimeInterval = 600

    private let fetcher: Fetcher
    private let clock: @Sendable () -> Date
    private var cache: [String: (at: Date, value: WeatherCondition)] = [:]
    public private(set) var requestCount = 0

    public init(fetcher: @escaping Fetcher = WeatherService.liveFetcher, clock: @escaping @Sendable () -> Date = { Date() }) {
        self.fetcher = fetcher
        self.clock = clock
    }

    public static let liveFetcher: Fetcher = { url in
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }

    static func key(_ c: Coordinate) -> String {
        "\((c.latitude * 2).rounded() / 2),\((c.longitude * 2).rounded() / 2)"
    }

    public func condition(at c: Coordinate) async -> WeatherCondition? {
        let k = Self.key(c)
        if let hit = cache[k], clock().timeIntervalSince(hit.at) < Self.ttl { return hit.value }
        requestCount += 1
        do {
            let value = try OpenMeteo.parse(try await fetcher(OpenMeteo.url(for: c)))
            cache[k] = (clock(), value)
            return value
        } catch {
            return nil
        }
    }

    /// A profile along the route; samples that fail are left out, all failing gives the clear fallback.
    public func profile(from a: Coordinate, to b: Coordinate) async -> WeatherProfile {
        let points = WeatherRoute.samplePoints(from: a, to: b)
        var out: [(fraction: Double, condition: WeatherCondition)] = []
        for p in points {
            if let c = await condition(at: p.coordinate) { out.append((p.fraction, c)) }
        }
        return out.isEmpty ? .clear : WeatherProfile(samples: out)
    }
}

// MARK: - Satellite clouds (NASA GIBS)

public enum CloudMask {
    /// Opacity of a cloud pixel of a true-colour satellite tile. Clouds are bright and nearly colourless; land,
    /// vegetation and sea are darker or saturated. Snow cover also passes (a known limit).
    public static func alpha(r: Double, g: Double, b: Double) -> Double {
        let mx = max(r, g, b), mn = min(r, g, b)
        let value = (r + g + b) / 3
        let saturation = mx > 0 ? (mx - mn) / mx : 0
        let bright = DayNightGrade.smoothstep((value - 0.52) / 0.36)
        let neutral = 1 - DayNightGrade.smoothstep((saturation - 0.10) / 0.22)
        return min(1, bright * neutral)
    }

    /// `https://gibs.earthdata.nasa.gov` WMTS URL of a Web Mercator tile (z 0...9) for a UTC day.
    public static func gibsURL(layer: String = "VIIRS_SNPP_CorrectedReflectance_TrueColor", day: Date, z: Int, x: Int, y: Int) -> URL {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"; f.timeZone = .gmt; f.locale = Locale(identifier: "en_US_POSIX")
        return URL(string: "https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/\(layer)/default/\(f.string(from: day))/GoogleMapsCompatible_Level9/\(z)/\(y)/\(x).jpg")!
    }
}
