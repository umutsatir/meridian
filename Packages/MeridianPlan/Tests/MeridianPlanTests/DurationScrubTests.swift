import Testing
import MeridianCore
@testable import MeridianPlan

@Suite struct DurationScrubTests {
    @Test func dragMapsPixelsToMinutesAtCanvasScale() {
        var s = DurationScrub(duration: .minutes(60))
        s.beginDrag(atX: 500)
        s.drag(toX: 500 - 36) // 36 px left = +10 min at 3.6 px/min
        #expect(abs(s.rawMinutes - 70) < 1e-9)
        s.drag(toX: 500 + 36) // absolute from the origin, not incremental
        #expect(abs(s.rawMinutes - 50) < 1e-9)
    }

    @Test func clampsAtThirtyAndFreeStop() {
        var s = DurationScrub(duration: .minutes(40))
        s.beginDrag(atX: 0)
        s.drag(toX: 10_000)
        #expect(s.rawMinutes == 30)
        #expect(s.detentDuration == .minutes(30))
        s.drag(toX: -100_000)
        #expect(s.rawMinutes == 372)
        #expect(s.isFree && s.detentDuration == .free)
    }

    @Test func detentCrossingTicksOncePerFiveMinutes() {
        var s = DurationScrub(duration: .minutes(60))
        s.beginDrag(atX: 0)
        let a = s.drag(toX: -1)
        #expect(!a.crossedDetent)    // +0.28 min, still the 60 detent
        let b = s.drag(toX: -9)
        #expect(b.crossedDetent)     // +2.5 min -> rounds to 65
        let c = s.drag(toX: -10)
        #expect(!c.crossedDetent)
        #expect(s.detentMinutes == 65)
    }

    @Test func releaseSnapsToDetentOrFreeStop() {
        var s = DurationScrub(rawMinutes: 42)
        let moved = s.endGesture()
        #expect(moved)
        #expect(s.rawMinutes == 40)
        s = DurationScrub(rawMinutes: 368)
        s.endGesture()
        #expect(s.rawMinutes == 372)
        let again = s.endGesture()
        #expect(!again)
    }

    @Test func freeStartsAbove366() {
        #expect(!DurationScrub(rawMinutes: 366).isFree)
        #expect(DurationScrub(rawMinutes: 366.5).isFree)
        #expect(DurationScrub(rawMinutes: 360).detentDuration == .minutes(360))
    }

    @Test func scrollDirectionAndAcceleration() {
        var s = DurationScrub(rawMinutes: 100)
        s.scroll(deltaPx: -3.6)  // content moves left, slow: +1 min
        #expect(abs(s.rawMinutes - 101) < 1e-9)
        s.scroll(deltaPx: 3.6)
        #expect(abs(s.rawMinutes - 100) < 1e-9)
        #expect(DurationScrub.acceleration(forDeltaPx: 4) == 1)
        #expect(DurationScrub.acceleration(forDeltaPx: 40) == 3)
        #expect(DurationScrub.acceleration(forDeltaPx: -400) == 3)
        let mid = DurationScrub.acceleration(forDeltaPx: 22)
        #expect(mid > 1 && mid < 3)
        var fast = DurationScrub(rawMinutes: 100)
        fast.scroll(deltaPx: -40) // full 3x
        #expect(abs(fast.rawMinutes - (100 + 40 * 3 / 3.6)) < 1e-9)
    }

    @Test func dominantAxis() {
        #expect(DurationScrub.dominantScrollDelta(dx: 5, dy: 1) == 5)
        #expect(DurationScrub.dominantScrollDelta(dx: 1, dy: -8) == 8)
    }

    @Test func keySteps() {
        var s = DurationScrub(rawMinutes: 42)
        s.step(1)
        #expect(s.rawMinutes == 45)
        s.step(-1, shift: true)
        #expect(s.rawMinutes == 30)
        var t = DurationScrub(rawMinutes: 360)
        t.step(1)
        #expect(t.isFree)
        let noop = t.step(1)
        #expect(!noop.changed)
        t.step(-1)
        #expect(t.rawMinutes == 360)
        var lo = DurationScrub(rawMinutes: 30)
        let stuck = lo.step(-1)
        #expect(!stuck.changed)
    }

    @Test func trackGeometryKeepsCanvasOrigin() {
        #expect(abs(DurationScrub.trackX(forMinutes: 30) - 72) < 1e-9) // 20 min * 3.6
        #expect(abs(DurationScrub.trackOffset(forMinutes: 42) + 115.2) < 1e-9)
    }

    @Test func planStateAppliesDetentValues() {
        let a = Airport(iata: "AAA", name: "A", city: "A", countryCode: "XX", continent: .europe, coordinate: .init(latitude: 0, longitude: 0))
        var plan = PlanState(index: AirportIndex(airports: [a]), preferences: PlanPreferences(homeIata: "AAA"), fallbackOriginIata: "AAA")
        #expect(plan.makeScrub().detentDuration == .minutes(40))
        plan.apply(DurationScrub(rawMinutes: 369))
        #expect(plan.isFreeFlight)
        plan.apply(DurationScrub(rawMinutes: 83))
        #expect(plan.durationMinutes == 85)
    }
}
