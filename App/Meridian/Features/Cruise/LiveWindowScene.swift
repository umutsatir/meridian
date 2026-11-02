import AppKit
import MeridianCore
import MeridianCruise
import MeridianMaps
import Observation
import SwiftUI

// MARK: - Weather (Open-Meteo), one shared instance

/// Real weather along the current route (Open-Meteo, 10 minute cache). No network: sun and no clouds.
@MainActor @Observable
final class LiveWeather {
    static let shared = LiveWeather()

    private(set) var profile: WeatherProfile = .clear
    @ObservationIgnored private var key: String?
    @ObservationIgnored private var loadedAt = Date.distantPast
    @ObservationIgnored private var loading = false
    @ObservationIgnored private let service = WeatherService()

    /// Idempotent: fetches when the route changed or the data is older than the cache time.
    func ensure(from a: Coordinate, to b: Coordinate) {
        let k = String(format: "%.2f,%.2f>%.2f,%.2f", a.latitude, a.longitude, b.latitude, b.longitude)
        let fresh = Date().timeIntervalSince(loadedAt) < WeatherService.ttl
        guard !loading, k != key || !fresh else { return }
        loading = true
        key = k
        Task {
            let p = await service.profile(from: a, to: b)
            profile = p
            loadedAt = p.isFallback ? Date().addingTimeInterval(-WeatherService.ttl + 60) : Date()   // retry a failed fetch after a minute
            loading = false
        }
    }
}

// MARK: - Fixed conditions for screenshots

/// A frozen aircraft position and time (`--at lat,lon,ISO8601`, `--heading`, `--alt`, `--weather cover,precip,code`).
struct WindowFixture {
    var position: Coordinate
    var heading: Double
    var date: Date
    var altitudeFt: Double
    var weather: WeatherCondition?

    @MainActor static var active: WindowFixture?

    static func iso(_ s: String) -> Date { ISO8601DateFormatter().date(from: s) ?? Date() }

    /// Defaults of a route, overridden by the launch arguments.
    static func make(lat: Double, lon: Double, at: String, heading: Double = 90, altitudeFt: Double = 30_000, weather: WeatherCondition? = nil) -> WindowFixture {
        let a = CommandLine.arguments
        func value(_ f: String) -> String? { a.firstIndex(of: f).flatMap { $0 + 1 < a.count ? a[$0 + 1] : nil } }
        var fx = WindowFixture(position: .init(latitude: lat, longitude: lon), heading: heading, date: iso(at), altitudeFt: altitudeFt, weather: weather)
        if let s = value("--at") {
            let p = s.split(separator: ",", maxSplits: 2).map(String.init)
            if p.count == 3, let la = Double(p[0]), let lo = Double(p[1]) { fx.position = .init(latitude: la, longitude: lo); fx.date = iso(p[2]) }
        }
        if let h = value("--heading").flatMap(Double.init) { fx.heading = h }
        if let h = value("--alt").flatMap(Double.init) { fx.altitudeFt = h }
        if let w = value("--weather")?.split(separator: ",").compactMap({ Double($0) }), w.count == 3 {
            fx.weather = WeatherCondition(cloudCover: w[0], precipitationMM: w[1], weatherCode: Int(w[2]), windKmh: 12)
        }
        return fx
    }
}

// MARK: - What the window shows

/// Everything the scene needs: sun, atmosphere and altitude. Resolved from the real sun and weather (auto) or from a chosen scene.
struct WindowLook: Equatable {
    var sunElevation: Double
    var sunAzimuth: Double
    var atmosphere: WindowAtmosphere
    var altitudeFt: Double
    var runway = false
    var position: Coordinate
    var heading: Double
    var side: WindowSide = .left

    var grade: DayNightGrade { .weights(elevation: sunElevation) }
    var camera: WindowCameraSpec {
        let a = CommandLine.arguments
        let dbg = a.firstIndex(of: "--pitch").flatMap { $0 + 1 < a.count ? Double(a[$0 + 1]) : nil }
        return WindowCamera.spec(position: position, heading: heading, side: side, altitudeFt: altitudeFt, pitch: dbg ?? (altitudeFt > 20_000 ? 66 : 72))
    }

    /// The real sun and weather at `position` and `date`.
    static func real(position: Coordinate, heading: Double, date: Date, progress: Double, routeKm: Double, weather: WeatherCondition,
                     altitudeFt: Double? = nil, side: WindowSide = .left) -> WindowLook {
        let sun = SunElevation.position(at: date, coordinate: position)
        let alt = altitudeFt ?? WindowCamera.altitudeFt(progress: progress, cruiseFt: WindowCamera.cruiseAltitudeFt(routeKm: routeKm))
        return WindowLook(sunElevation: sun.elevation, sunAzimuth: sun.azimuth, atmosphere: WindowAtmosphere(weather), altitudeFt: alt,
                          runway: progress > 0.96, position: position, heading: heading, side: side)
    }

    /// A chosen scene of the menu: fixed sun and weather, the real position and phase altitude.
    static func manual(_ key: String, position: Coordinate, heading: Double, progress: Double, routeKm: Double, side: WindowSide = .left) -> WindowLook {
        let alt = WindowCamera.altitudeFt(progress: progress, cruiseFt: WindowCamera.cruiseAltitudeFt(routeKm: routeKm))
        var l = WindowLook(sunElevation: 45, sunAzimuth: heading + side.headingOffset + 25, atmosphere: WindowAtmosphere(cloud: 0.3), altitudeFt: alt,
                           position: position, heading: heading, side: side)
        let rel = heading + side.headingOffset
        switch key {
        case "sunset": l.sunElevation = 1.5; l.sunAzimuth = rel - 22; l.atmosphere = .init(cloud: 0.35)
        case "blue": l.sunElevation = -5; l.sunAzimuth = rel - 30; l.atmosphere = .init(cloud: 0.25)
        case "night": l.sunElevation = -30; l.atmosphere = .clear
        case "rain": l.sunElevation = 30; l.atmosphere = .init(cloud: 0.92, rain: 0.6)
        case "storm": l.sunElevation = 14; l.atmosphere = .init(cloud: 1, rain: 1, storm: true)
        case "takeoff": l.altitudeFt = 1_200
        case "landing": l.altitudeFt = 1_000; l.sunElevation = 8; l.sunAzimuth = rel - 26; l.runway = true
        default: break
        }
        return l
    }
}

extension CruiseFrame {
    /// Aircraft position and heading along the route (great circle).
    var windowPosition: (Coordinate, Double) {
        let o = origin.coordinate, d = (destination ?? origin).coordinate
        let pos = Geo.interpolate(from: o, to: d, fraction: progress)
        let ahead = Geo.distanceKm(from: pos, to: d) > 0.5
        return (pos, ahead ? Geo.bearing(from: pos, to: d) : Geo.bearing(from: o, to: d))
    }

    func windowLook(ui: CruiseUI) -> WindowLook {
        let (pos, hdg) = windowPosition
        if ui.sceneAuto {
            let fx = WindowFixture.active
            let p = fx?.position ?? pos
            let w = fx?.weather ?? LiveWeather.shared.profile.condition(at: progress)
            return .real(position: p, heading: fx?.heading ?? hdg, date: fx?.date ?? date ?? .now, progress: progress, routeKm: routeKm,
                         weather: w, altitudeFt: fx?.altitudeFt, side: ui.windowSide)
        }
        return .manual(ui.scene, position: pos, heading: hdg, progress: progress, routeKm: routeKm, side: ui.windowSide)
    }
}

// MARK: - Scene

/// The window content without the cabin: satellite ground, real clouds, grade, lights, haze, sun, procedural clouds, fog, rain.
struct LiveWindowScene: View {
    let look: WindowLook
    let size: CGSize
    var animated = true
    @State private var mapFailed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let cloudDay: Date = Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: .now) ?? .now

    var body: some View {
        let g = look.grade
        let a = look.atmosphere
        let sky = g.skyColor
        ZStack(alignment: .topLeading) {
            Color.black
            if CommandLine.arguments.contains("--swiftmap") {
                SwiftMapProbe(camera: look.camera).frame(width: size.width, height: size.height)
            } else {
                LiveWindowMap(camera: look.camera, tint: g.groundTint, lights: g.lights, cloudAlpha: 0.18 + 0.75 * a.cloud,
                              cloudDay: Self.cloudDay, animated: animated, onHealth: { mapFailed = $0 })
                    .frame(width: size.width * 1.6, height: size.height * 1.6)
                    .rotation3DEffect(.degrees(45), axis: (1, 0, 0), anchor: .bottom, perspective: 0.45)
                    .frame(width: size.width, height: size.height, alignment: .bottom)
            }

            // distant haze at the top only
            LinearGradient(stops: [.init(color: cruiseRGBA(sky.r, sky.g, sky.b, 0.62 + 0.2 * a.cloud), location: 0),
                                   .init(color: cruiseRGBA(sky.r, sky.g, sky.b, 0.26), location: 0.16),
                                   .init(color: cruiseRGBA(sky.r, sky.g, sky.b, 0), location: 0.40)], startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)

            // low sun: warm glow towards the sun's azimuth
            sunGlow(g)

            // procedural clouds from the weather's cloud cover (parallax, slow drift)
            if a.cloud > 0.08 { ProceduralClouds(cover: a.cloud, grade: g, drift: !reduceMotion).frame(width: size.width, height: size.height) }

            if a.fog > 0.02 {
                Rectangle().fill(LinearGradient(colors: [fogColor(g, 0.9 * a.fog), fogColor(g, 0.55 * a.fog)], startPoint: .top, endPoint: .bottom)).allowsHitTesting(false)
            }
            if a.rain > 0.02 { WindowRain(storm: a.storm, intensity: a.rain).frame(width: size.width, height: size.height) }
            if look.runway { RunwayLights().frame(width: size.width, height: size.height) }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .overlay { if mapFailed || MapHealth.shared.failed { PhotoFallback(look: look).frame(width: size.width, height: size.height) } }
    }

    private func fogColor(_ g: DayNightGrade, _ o: Double) -> Color {
        let day = (206.0, 212.0, 218.0), night = (18.0, 22.0, 34.0), warm = (232.0, 196.0, 170.0), blue = (96.0, 106.0, 150.0)
        let r = g.day * day.0 + g.night * night.0 + g.golden * warm.0 + g.blue * blue.0
        let gg = g.day * day.1 + g.night * night.1 + g.golden * warm.1 + g.blue * blue.1
        let b = g.day * day.2 + g.night * night.2 + g.golden * warm.2 + g.blue * blue.2
        return cruiseRGBA(r, gg, b, o)
    }

    @ViewBuilder private func sunGlow(_ g: DayNightGrade) -> some View {
        let rel = SunGlare.relativeAzimuth(sun: look.sunAzimuth, viewHeading: look.camera.heading)
        let strength = (g.glow * 0.8 + g.day * 0.16) * (1 - look.atmosphere.cloud * 0.7) * (look.sunElevation > -4 ? 1 : 0)
        if abs(rel) < 75, strength > 0.01 {
            let x = 0.5 + rel / 80
            let y = max(0.05, 0.30 - look.sunElevation / 90 * 0.25)
            CSSEllipse(cx: x, cy: y, rx: 0.55, ry: 0.5, stops: [
                .init(color: cruiseRGBA(255, 238, 200, 0.75 * strength), location: 0),
                .init(color: cruiseRGBA(255, 170, 100, 0.34 * strength), location: 0.22),
                .init(color: cruiseRGBA(255, 130, 80, 0), location: 0.75)])
                .blendMode(.screen)
        }
    }
}

/// Soft cloud layers on the glass side of the scene (`wv-cloud-a/b`), tinted by the light, drifting slowly with different speeds.
private struct ProceduralClouds: View {
    let cover: Double
    let grade: DayNightGrade
    let drift: Bool

    private static func image(_ n: String) -> NSImage? { Bundle.main.url(forResource: n, withExtension: "png").flatMap { NSImage(contentsOf: $0) } }

    var body: some View {
        // cloud colour: white by day, warm at golden hour, bluish at blue hour, dark at night
        let tint = cruiseRGBA(255 * grade.day + 255 * grade.golden + 150 * grade.blue + 38 * grade.night,
                              255 * grade.day + 205 * grade.golden + 160 * grade.blue + 44 * grade.night,
                              255 * grade.day + 170 * grade.golden + 215 * grade.blue + 70 * grade.night)
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 15, paused: !drift)) { tl in
                let t = drift ? tl.date.timeIntervalSinceReferenceDate : 0
                ZStack {
                    layer("wv-cloud-a", geo.size, scale: 1.9, speed: 3.0, t: t, opacity: min(0.85, pow(cover, 1.3) * 0.7), y: 0.1)
                    layer("wv-cloud-b", geo.size, scale: 1.2, speed: 6.5, t: t, opacity: min(0.6, pow(cover, 1.6) * 0.5), y: 0.45)
                }
                .colorMultiply(tint)
                .mask(LinearGradient(stops: [.init(color: .black.opacity(0.35), location: 0), .init(color: .black, location: 0.35), .init(color: .black, location: 1)], startPoint: .top, endPoint: .bottom))
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder private func layer(_ name: String, _ size: CGSize, scale: Double, speed: Double, t: Double, opacity: Double, y: Double) -> some View {
        if let img = Self.image(name) {
            let w = size.width * scale
            let h = w
            let dx = (t * speed).truncatingRemainder(dividingBy: w)
            Canvas { ctx, sz in
                let res = ctx.resolve(Image(nsImage: img))
                var x = -dx - w
                while x < sz.width {
                    var yy = sz.height * y - h * 0.5
                    while yy < sz.height { ctx.draw(res, in: CGRect(x: x, y: yy, width: w, height: h)); yy += h }
                    x += w
                }
            }
            .opacity(opacity)
            .blur(radius: 1.2)
        }
    }
}

/// Bundled photos: only used when the map or the network is not available.
private struct PhotoFallback: View {
    let look: WindowLook
    var body: some View {
        let g = look.grade
        let key = g.night > 0.5 ? "night" : g.blue > 0.5 ? "blue" : g.golden > 0.5 ? "sunset" : look.atmosphere.raining ? "rain" : "day"
        let s = WindowSceneSpec.spec(key)
        GeometryReader { geo in
            if let img = WindowPhoto.image(s.image) {
                let scale = max(geo.size.width / img.size.width, geo.size.height / img.size.height)
                Image(nsImage: img).resizable().interpolation(.high)
                    .frame(width: img.size.width * scale, height: img.size.height * scale)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            } else {
                Color(nsColor: .black)
            }
        }
    }
}
