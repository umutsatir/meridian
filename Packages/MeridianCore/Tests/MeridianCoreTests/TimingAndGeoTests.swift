import Testing
@testable import MeridianCore

@Suite struct TimingAndGeoTests {
    @Test func londonToParisIsAbout42Minutes() {
        let km = Geo.distanceKm(from: Fixtures.lhr.coordinate, to: Fixtures.cdg.coordinate)
        #expect(abs(km - 348) < 5)
        #expect(FlightTiming.minutes(forKm: 348) == 42)
    }

    @Test func shortFlightsHaveDestinations() {
        #expect(abs(FlightTiming.km(forMinutes: 10) - 64.5) < 0.1)
        #expect(abs(FlightTiming.km(forMinutes: 20) - 129) < 0.1)
        #expect(abs(FlightTiming.km(forMinutes: 30) - 193.5) < 0.1)
    }

    @Test func regimesAreContinuousAtThirtyMinutes() {
        #expect(abs(FlightTiming.km(forMinutes: 30.001) - FlightTiming.km(forMinutes: 29.999)) < 0.1)
        #expect(FlightTiming.minutes(forKm: 193.5) == 30)
        #expect(FlightTiming.minutes(forKm: 194) == 30)
    }

    @Test(arguments: [10, 15, 25, 30, 42, 90, 240, 360])
    func kmAndMinutesRoundTrip(minutes: Int) {
        #expect(FlightTiming.minutes(forKm: FlightTiming.km(forMinutes: Double(minutes))) == minutes)
    }

    @Test func zeroAndNegativeDistanceAreSafe() {
        #expect(FlightTiming.minutes(forKm: 0) == 0)
        #expect(FlightTiming.minutes(forKm: -50) == 0)
        #expect(FlightTiming.km(forMinutes: -5) == 0)
    }

    @Test func cabinClassBoundaries() {
        #expect(CabinClass(durationMinutes: 44) == .economy)
        #expect(CabinClass(durationMinutes: 45) == .premium)
        #expect(CabinClass(durationMinutes: 90) == .business)
        #expect(CabinClass(durationMinutes: 180) == .first)
        #expect(CabinClass(durationMinutes: 300) == .longHaul)
        #expect(CabinClass.economy < CabinClass.longHaul)
    }

    @Test func interpolationHitsEndpointsAndMidpoint() {
        let a = Fixtures.lhr.coordinate, b = Fixtures.jfk.coordinate
        let start = Geo.interpolate(from: a, to: b, fraction: 0)
        let end = Geo.interpolate(from: a, to: b, fraction: 1)
        #expect(Geo.distanceKm(from: start, to: a) < 0.01)
        #expect(Geo.distanceKm(from: end, to: b) < 0.01)
        let mid = Geo.interpolate(from: a, to: b, fraction: 0.5)
        let total = Geo.distanceKm(from: a, to: b)
        #expect(abs(Geo.distanceKm(from: a, to: mid) - total / 2) < 1)
    }

    @Test func interpolationAcrossAntimeridianStaysFinite() {
        let a = Coordinate(latitude: 35, longitude: 170), b = Coordinate(latitude: 35, longitude: -170)
        let mid = Geo.interpolate(from: a, to: b, fraction: 0.5)
        #expect(abs(abs(mid.longitude) - 180) < 1)
    }

    @Test func samePointInterpolationDoesNotDivideByZero() {
        let p = Fixtures.lhr.coordinate
        #expect(Geo.interpolate(from: p, to: p, fraction: 0.5) == p)
    }

    @Test func bearingEastIsNinety() {
        let b = Geo.bearing(from: .init(latitude: 0, longitude: 0), to: .init(latitude: 0, longitude: 10))
        #expect(abs(b - 90) < 0.001)
    }
}
