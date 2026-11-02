import Foundation
import Testing
import MeridianCore
@testable import MeridianCruise

@Suite struct LiveWindowTests {
    // MARK: weather code -> kind -> atmosphere

    @Test(arguments: [(0, WeatherKind.clear), (1, .clear), (2, .partlyCloudy), (3, .overcast), (45, .fog), (48, .fog), (53, .drizzle),
                      (61, .rain), (65, .rain), (81, .rain), (73, .snow), (86, .snow), (95, .thunderstorm), (99, .thunderstorm), (123, .clear)])
    func codeMapping(code: Int, kind: WeatherKind) {
        #expect(WeatherKind(code: code) == kind)
    }

    @Test func atmosphereFromWeather() {
        let clear = WindowAtmosphere(.clear)
        #expect(clear == .clear)
        let rain = WindowAtmosphere(.init(cloudCover: 40, precipitationMM: 1.2, weatherCode: 63, windKmh: 10))
        #expect(rain.raining && rain.cloud >= 0.85 && rain.fog == 0)
        let fog = WindowAtmosphere(.init(cloudCover: 100, precipitationMM: 0, weatherCode: 45, windKmh: 3))
        #expect(fog.fog > 0.5 && !fog.raining)
        let storm = WindowAtmosphere(.init(cloudCover: 90, precipitationMM: 4, weatherCode: 95, windKmh: 40))
        #expect(storm.storm && storm.rain == 1)
        let partly = WindowAtmosphere(.init(cloudCover: 35, precipitationMM: 0, weatherCode: 2, windKmh: 5))
        #expect(abs(partly.cloud - 0.35) < 1e-9 && !partly.raining)
    }

    @Test func rainChoosesTheRainScene() {
        #expect(WindowScene.scene(elevation: 40, weather: .init(cloudCover: 90, precipitationMM: 2, weatherCode: 61, windKmh: 5)) == .rain)
        #expect(WindowScene.scene(elevation: -30, weather: .init(cloudCover: 90, precipitationMM: 2, weatherCode: 61, windKmh: 5)) == .night)
        #expect(WindowScene.scene(elevation: 40, weather: .clear) == .day)
    }

    // MARK: sampling along the route

    @Test func sampleFractionsScaleWithDistance() {
        #expect(WeatherRoute.sampleFractions(routeKm: 50) == [0, 1])
        #expect(WeatherRoute.sampleFractions(routeKm: 800).count == 3)
        #expect(WeatherRoute.sampleFractions(routeKm: 12_000).count == 6)
    }

    @Test func routePointsLieOnTheGreatCircle() {
        let a = Fx.lhr.coordinate, b = Coordinate(latitude: 40.64, longitude: -73.78)
        let pts = WeatherRoute.samplePoints(from: a, to: b)
        #expect(pts.first?.coordinate == a || Geo.distanceKm(from: pts[0].coordinate, to: a) < 1)
        #expect(Geo.distanceKm(from: pts.last!.coordinate, to: b) < 1)
        let total = Geo.distanceKm(from: a, to: b)
        for p in pts { #expect(abs(Geo.distanceKm(from: a, to: p.coordinate) - p.fraction * total) < 5) }
    }

    @Test func profileInterpolates() {
        let p = WeatherProfile(samples: [(0, .init(cloudCover: 0, precipitationMM: 0, weatherCode: 0, windKmh: 0)),
                                         (1, .init(cloudCover: 100, precipitationMM: 2, weatherCode: 61, windKmh: 20))])
        let mid = p.condition(at: 0.25)
        #expect(abs(mid.cloudCover - 25) < 1e-9 && abs(mid.precipitationMM - 0.5) < 1e-9 && mid.weatherCode == 0)
        #expect(p.condition(at: 0.75).weatherCode == 61)
        #expect(p.condition(at: -1).cloudCover == 0 && p.condition(at: 3).cloudCover == 100)
        #expect(WeatherProfile.clear.condition(at: 0.5) == .clear)
    }

    // MARK: Open-Meteo parsing and the cache

    static let json = #"{"latitude":51.5,"current":{"time":"2026-11-02T11:45","cloud_cover":84,"precipitation":0.0,"weather_code":3,"wind_speed_10m":19.4}}"#

    @Test func parsesOpenMeteo() throws {
        let w = try OpenMeteo.parse(Data(Self.json.utf8))
        #expect(w == .init(cloudCover: 84, precipitationMM: 0, weatherCode: 3, windKmh: 19.4))
        #expect(throws: (any Error).self) { try OpenMeteo.parse(Data("{}".utf8)) }
        let url = OpenMeteo.url(for: .init(latitude: 51.5, longitude: -0.45)).absoluteString
        #expect(url.contains("current=cloud_cover,precipitation,weather_code,wind_speed_10m") && url.contains("latitude=51.500"))
    }

    final class Clock: @unchecked Sendable { var now = Date(timeIntervalSince1970: 1_800_000_000) }

    @Test func cacheHoldsTenMinutesAndRefetches() async {
        let clock = Clock()
        let service = WeatherService(fetcher: { _ in Data(Self.json.utf8) }, clock: { clock.now })
        let c = Coordinate(latitude: 51.4, longitude: -0.3)
        _ = await service.condition(at: c)
        _ = await service.condition(at: .init(latitude: 51.45, longitude: -0.35))   // same 0.5 degree cell
        #expect(await service.requestCount == 1)
        clock.now.addTimeInterval(599)
        _ = await service.condition(at: c)
        #expect(await service.requestCount == 1)
        clock.now.addTimeInterval(2)
        _ = await service.condition(at: c)
        #expect(await service.requestCount == 2)
        _ = await service.condition(at: .init(latitude: 49.0, longitude: 2.5))
        #expect(await service.requestCount == 3)
    }

    @Test func failuresFallBackToClear() async {
        let service = WeatherService(fetcher: { _ in throw URLError(.notConnectedToInternet) })
        let p = await service.profile(from: Fx.lhr.coordinate, to: Fx.cdg.coordinate)
        #expect(p.isFallback && p.condition(at: 0.5) == .clear)
        let bad = WeatherService(fetcher: { _ in Data("nope".utf8) })
        #expect(await bad.condition(at: Fx.lhr.coordinate) == nil)
    }

    @Test func profileSkipsFailedSamples() async {
        // fail for the second sample point only
        let service = WeatherService(fetcher: { url in
            if url.absoluteString.contains("latitude=49") { throw URLError(.timedOut) }
            return Data(Self.json.utf8)
        })
        let p = await service.profile(from: Fx.lhr.coordinate, to: Fx.cdg.coordinate)
        #expect(!p.isFallback && p.samples.count == 1)
    }

    // MARK: day / night weights

    @Test func weightsAlwaysSumToOne() {
        for e in stride(from: -40.0, through: 80, by: 0.5) {
            let w = DayNightGrade.weights(elevation: e)
            #expect(abs(w.total - 1) < 1e-9)
            #expect(w.day >= 0 && w.golden >= 0 && w.blue >= 0 && w.night >= 0)
        }
    }

    @Test func bandsAtKnownElevations() {
        #expect(DayNightGrade.weights(elevation: 45).day == 1)
        #expect(DayNightGrade.weights(elevation: -30).night == 1)
        let sunset = DayNightGrade.weights(elevation: 1)
        #expect(sunset.golden > 0.99)
        let blue = DayNightGrade.weights(elevation: -5)
        #expect(blue.blue > 0.99)
    }

    @Test func nightFadesInContinuously() {
        var last = DayNightGrade.weights(elevation: 30).groundTint.a
        var maxStep = 0.0
        for e in stride(from: 29.5, through: -20, by: -0.5) {
            let a = DayNightGrade.weights(elevation: e).groundTint.a
            #expect(a >= last - 1e-9)   // only darkens as the sun sinks
            maxStep = max(maxStep, a - last)
            last = a
        }
        #expect(maxStep < 0.12)          // no visible jump
        #expect(last > 0.8)
        #expect(DayNightGrade.weights(elevation: 30).groundTint.a == 0)
    }

    @Test func lightsOnlyWhenDark() {
        #expect(DayNightGrade.weights(elevation: 40).lights == 0)
        #expect(DayNightGrade.weights(elevation: -30).lights == 1)
        #expect(DayNightGrade.weights(elevation: -5).lights > 0.5)
    }

    // MARK: sun azimuth, camera

    @Test func sunAzimuthIsEastInTheMorningAndWestInTheEvening() {
        let c = Coordinate(latitude: 48, longitude: 2)
        let am = SunElevation.position(at: Fx.utc("2026-09-22T05:30:00Z"), coordinate: c)
        let pm = SunElevation.position(at: Fx.utc("2026-09-22T17:30:00Z"), coordinate: c)
        #expect(am.azimuth > 60 && am.azimuth < 120)
        #expect(pm.azimuth > 240 && pm.azimuth < 300)
        let noon = SunElevation.position(at: Fx.utc("2026-09-22T11:45:00Z"), coordinate: c)
        #expect(abs(noon.azimuth - 180) < 8)
    }

    @Test func relativeAzimuthWraps() {
        #expect(SunGlare.relativeAzimuth(sun: 10, viewHeading: 350) == 20)
        #expect(SunGlare.relativeAzimuth(sun: 350, viewHeading: 10) == -20)
    }

    @Test func windowLooksPerpendicularToTheRoute() {
        let pos = Coordinate(latitude: 48, longitude: 2)
        let left = WindowCamera.spec(position: pos, heading: 90, side: .left, altitudeFt: 30_000)
        let right = WindowCamera.spec(position: pos, heading: 90, side: .right, altitudeFt: 30_000)
        #expect(left.heading == 0 && right.heading == 180)
        #expect(left.center.latitude > pos.latitude && right.center.latitude < pos.latitude)
        #expect(abs(left.eyeAltitudeM - 9144) < 1)
        #expect(WindowSide(seat: "12A") == .left && WindowSide(seat: "31F") == .right)
    }

    @Test func altitudeFollowsThePhases() {
        let cruise = 34_000.0
        #expect(WindowCamera.altitudeFt(progress: 0, cruiseFt: cruise) == 0)
        #expect(WindowCamera.altitudeFt(progress: 0.5, cruiseFt: cruise) == cruise)
        #expect(WindowCamera.altitudeFt(progress: 1, cruiseFt: cruise) == 0)
        #expect(WindowCamera.altitudeFt(progress: 0.1, cruiseFt: cruise) < cruise)
        #expect(WindowCamera.altitudeFt(progress: 0.9, cruiseFt: cruise) > 2_000)
        #expect(WindowCamera.cruiseAltitudeFt(routeKm: 348) == 28_000)
    }

    @Test func cloudMask() {
        #expect(CloudMask.alpha(r: 0.95, g: 0.95, b: 0.97) > 0.9)       // cloud
        #expect(CloudMask.alpha(r: 0.15, g: 0.30, b: 0.15) < 0.01)      // forest
        #expect(CloudMask.alpha(r: 0.05, g: 0.12, b: 0.25) < 0.01)      // sea
        #expect(CloudMask.alpha(r: 0.7, g: 0.55, b: 0.35) < 0.2)        // desert
    }
}
