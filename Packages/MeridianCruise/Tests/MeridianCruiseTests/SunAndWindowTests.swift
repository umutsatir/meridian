import Foundation
import Testing
import MeridianCore
@testable import MeridianCruise

@Suite struct SunAndWindowTests {
    @Test func equinoxNoonOnTheEquatorIsOverhead() {
        let e = SunElevation.degrees(at: Fx.utc("2026-03-20T12:07:00Z"), coordinate: .init(latitude: 0, longitude: 0))
        #expect(abs(e - 90) < 1.5)
    }

    @Test func midnightOnTheEquatorIsDeepBelowTheHorizon() {
        let e = SunElevation.degrees(at: Fx.utc("2026-03-20T00:07:00Z"), coordinate: .init(latitude: 0, longitude: 0))
        #expect(e < -85)
    }

    @Test(arguments: [("2026-06-21T11:59:00Z", 61.9), ("2026-12-21T12:02:00Z", 15.1)])
    func londonSolsticeNoon(iso: String, expected: Double) {
        let e = SunElevation.degrees(at: Fx.utc(iso), coordinate: .init(latitude: 51.5, longitude: 0))
        #expect(abs(e - expected) < 1.0)
    }

    @Test func longitudeShiftsSolarNoon() {
        // 90°E is six hours ahead: UTC 06:00 is local noon there.
        let e = SunElevation.degrees(at: Fx.utc("2026-03-20T06:07:00Z"), coordinate: .init(latitude: 0, longitude: 90))
        #expect(e > 85)
    }

    @Test func sceneThresholds() {
        #expect(WindowScene.scene(elevation: 40) == .day)
        #expect(WindowScene.scene(elevation: 8) == .day)
        #expect(WindowScene.scene(elevation: 3) == .sunset)
        #expect(WindowScene.scene(elevation: -5) == .blueHour)
        #expect(WindowScene.scene(elevation: -20) == .night)
    }

    @Test func rainReplacesEverySceneButNight() {
        #expect(WindowScene.scene(elevation: 40, isRaining: true) == .rain)
        #expect(WindowScene.scene(elevation: -5, isRaining: true) == .rain)
        #expect(WindowScene.scene(elevation: -30, isRaining: true) == .night)
    }

    @Test func blendIsStableAwayFromThresholds() {
        let b = WindowBlend.blend(elevation: 40)
        #expect(b.from == .day && b.to == .day && !b.isTransitioning)
    }

    @Test func blendCrossfadesThroughAThresholdAndIsMonotonic() {
        let center = WindowBlend.blend(elevation: WindowScene.Threshold.day)
        #expect(center.from == .sunset && center.to == .day)
        #expect(abs(center.weight - 0.5) < 1e-9)
        var last = -1.0
        for step in stride(from: 6.0, through: 10.0, by: 0.25) {
            let w = WindowBlend.blend(elevation: step)
            let weight = w.from == w.to ? (w.to == .day ? 1.0 : 0.0) : w.weight
            #expect(weight >= last)
            last = weight
        }
    }

    @Test func samplerFollowsTheRouteInTimeOrder() {
        let s = WindowSampler.samples(from: Fx.lhr.coordinate, to: Fx.cdg.coordinate, departure: Fx.t0, durationSec: 2520, count: 5)
        #expect(s.count == 5)
        #expect(s.first?.routeFraction == 0 && s.last?.routeFraction == 1)
        #expect(zip(s, s.dropFirst()).allSatisfy { $0.date < $1.date })
        #expect(WindowSampler.samples(from: Fx.lhr.coordinate, to: Fx.cdg.coordinate, departure: Fx.t0, durationSec: 60, count: 1).count == 2)
    }

    @Test func aFlightIntoTheEveningSeesTheSunGoDown() {
        // Departing JFK-ish at 20:30 UTC in June heads into dusk over the Atlantic.
        let samples = WindowSampler.samples(
            from: .init(latitude: 40.6, longitude: -73.8), to: .init(latitude: 51.5, longitude: -0.45),
            departure: Fx.utc("2026-06-21T22:00:00Z"), durationSec: 7 * 3600, count: 15)
        let scenes = Set(samples.map(\.blend.dominant))
        #expect(scenes.count >= 2)
    }
}
