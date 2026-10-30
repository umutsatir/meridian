import Foundation
import MeridianCore

public enum PlanDuration: Sendable, Hashable, Codable {
    case minutes(Int)
    case free

    public var minutes: Int? {
        if case .minutes(let m) = self { return m }
        return nil
    }
}

/// What the user committed to with ⏎ (PLAN-4).
public struct PlanSelection: Sendable, Hashable {
    public var origin: Airport
    /// `nil` for a free flight.
    public var destination: Airport?
    public var duration: PlanDuration
}

public enum SurpriseResult: Sendable, Hashable {
    case picked(Airport)
    /// No airport sits inside the ring for this origin and duration.
    case emptyRing
    /// Free flights have no destination to draw.
    case freeFlight
}

/// Pure state of the Plan screen. Every user action is a mutating function, so
/// the SwiftUI layer only forwards events and reads values.
public struct PlanState: Sendable {
    public static let durationRange = FlightTiming.minDurationMinutes...FlightTiming.maxDurationMinutes
    public static let detentMinutes = 5
    /// Quick-set chips: the canvas has 15·25·50·90·2h; ADR 0008 raises the minimum to 30,
    /// so the first two are replaced by a single 30 chip.
    public static let quickChipMinutes = [30, 50, 90, 120]
    /// The canvas opens at 42 minutes (LHR→CDG). It snaps to a detent on the first drag.
    public static let defaultDurationMinutes = 42

    public private(set) var index: AirportIndex
    public private(set) var origin: Airport
    public private(set) var duration: PlanDuration
    /// Airports inside the ring, nearest match first. Empty for free flights.
    public private(set) var destinations: [Airport]
    public private(set) var selectedDestinationIata: String?

    public var preferences: PlanPreferences

    /// Falls back to the home airport, then to `fallbackOriginIata`, then to the
    /// first airport in the index. Returns `nil` only for an empty index.
    public init(index: AirportIndex, preferences: PlanPreferences = .init(), fallbackOriginIata: String = "LHR") {
        let candidates = [preferences.homeIata, preferences.lastLandingIata, fallbackOriginIata].compactMap { $0 }
        guard let origin = candidates.lazy.compactMap({ index.airport(iata: $0) }).first ?? index.airports.first else {
            preconditionFailure("PlanState needs a non-empty airport index")
        }
        self.index = index
        self.preferences = preferences
        self.origin = origin
        self.duration = .minutes(preferences.lastRoute?.durationMinutes.map(Self.snap) ?? Self.defaultDurationMinutes)
        self.destinations = []
        self.selectedDestinationIata = nil
        recomputeDestinations()
    }

    // MARK: Derived

    public var scenarioID: String { preferences.scenarioID }
    public var topic: String { preferences.topic }
    public var mode: CompanionMode { preferences.mode }
    public var style: StartStyle { preferences.style }
    public var isFreeFlight: Bool { duration == .free }
    public var durationMinutes: Int? { duration.minutes }

    public var selectedDestination: Airport? {
        selectedDestinationIata.flatMap { iata in destinations.first { $0.iata == iata } }
    }

    public var selectedIndex: Int? {
        selectedDestinationIata.flatMap { iata in destinations.firstIndex { $0.iata == iata } }
    }

    /// `nil` for free flights, which have no ring.
    public var rangeRing: RangeRing? {
        durationMinutes.map { RangeRing(center: origin.coordinate, minutes: $0) }
    }

    public var isFavoriteOrigin: Bool { preferences.favoriteIatas.contains(origin.iata) }

    /// Ready to confirm: a timed flight with a chosen destination, or a free flight.
    public var canConfirm: Bool { isFreeFlight || selectedDestination != nil }

    /// RIT-6 and "Quick start checks in automatically".
    public var skipsRitual: Bool {
        preferences.skipRitualAlways || preferences.style == .quick
    }

    // MARK: Origin (PLAN-1)

    /// Changes the origin and redraws the ring and destinations. Persists it as
    /// the default. Returns `false` for an unknown code.
    @discardableResult
    public mutating func setOrigin(iata: String) -> Bool {
        guard let airport = index.airport(iata: iata) else { return false }
        setOrigin(airport)
        return true
    }

    public mutating func setOrigin(_ airport: Airport) {
        origin = airport
        preferences.homeIata = airport.iata
        recomputeDestinations()
    }

    /// "Continue from last landing". Returns `false` when there is none.
    @discardableResult
    public mutating func continueFromLastLanding() -> Bool {
        guard let iata = preferences.lastLandingIata else { return false }
        return setOrigin(iata: iata)
    }

    public mutating func toggleFavoriteOrigin() {
        if let i = preferences.favoriteIatas.firstIndex(of: origin.iata) {
            preferences.favoriteIatas.remove(at: i)
        } else {
            preferences.favoriteIatas.append(origin.iata)
        }
    }

    public var favoriteAirports: [Airport] {
        preferences.favoriteIatas.compactMap { index.airport(iata: $0) }
    }

    /// ⌘K search (PLAN-6).
    public func searchAirports(_ query: String, limit: Int = 20) -> [Airport] {
        index.search(query, limit: limit)
    }

    // MARK: Duration (PLAN-2)

    /// Snaps to the 5-minute detent and clamps to 30 min...6 h.
    public static func snap(_ minutes: Int) -> Int {
        let snapped = Int((Double(minutes) / Double(detentMinutes)).rounded()) * detentMinutes
        return min(durationRange.upperBound, max(durationRange.lowerBound, snapped))
    }

    public mutating func setDuration(minutes: Int) {
        duration = .minutes(Self.snap(minutes))
        recomputeDestinations()
    }

    public mutating func setFreeFlight() {
        duration = .free
        recomputeDestinations()
    }

    /// ←/→ on the ruler: ±5 minutes. From a free flight, → returns to the last
    /// timed value and ← does nothing.
    public mutating func stepDuration(by detents: Int) {
        guard case .minutes(let m) = duration else {
            if detents > 0 { setDuration(minutes: Self.defaultDurationMinutes) }
            return
        }
        // Past the 6 h end, → goes to Free flight.
        if m == Self.durationRange.upperBound, detents > 0 { setFreeFlight(); return }
        setDuration(minutes: m + detents * Self.detentMinutes)
    }

    /// Starts a ruler gesture (drag, two-finger scroll or key) from the current duration.
    public func makeScrub() -> DurationScrub { DurationScrub(duration: duration) }

    /// Applies the detent value of a scrub in progress (called when a 5-minute detent is crossed
    /// and on release). Only recomputes when the value changed.
    public mutating func apply(_ scrub: DurationScrub) {
        let target = scrub.detentDuration
        guard target != duration else { return }
        switch target {
        case .free: setFreeFlight()
        case .minutes(let m): setDuration(minutes: m)
        }
    }

    public mutating func applyQuickChip(minutes: Int) {
        setDuration(minutes: minutes)
    }

    // MARK: Destinations (PLAN-3, PLAN-4)

    public mutating func select(iata: String) {
        if destinations.contains(where: { $0.iata == iata }) { selectedDestinationIata = iata }
    }

    /// → in the dock. Wraps around.
    public mutating func selectNextDestination() { moveSelection(by: 1) }

    /// ← in the dock. Wraps around.
    public mutating func selectPreviousDestination() { moveSelection(by: -1) }

    /// ⏎ in the dock. `nil` while a timed flight has no destination.
    public func confirm() -> PlanSelection? {
        guard canConfirm else { return nil }
        return PlanSelection(origin: origin, destination: selectedDestination, duration: duration)
    }

    /// "Surprise me" (PLAN-5): a random airport inside the ring, now selected.
    public mutating func surpriseMe<G: RandomNumberGenerator>(using generator: inout G) -> SurpriseResult {
        guard !isFreeFlight else { return .freeFlight }
        guard let pick = destinations.randomElement(using: &generator) else { return .emptyRing }
        selectedDestinationIata = pick.iata
        return .picked(pick)
    }

    public mutating func surpriseMe() -> SurpriseResult {
        var generator = SystemRandomNumberGenerator()
        return surpriseMe(using: &generator)
    }

    // MARK: Scenario, topic, toggles (PLAN-8)

    public mutating func setScenario(id: String) { preferences.scenarioID = id }
    public mutating func setTopic(_ topic: String) { preferences.topic = topic }
    public mutating func setMode(_ mode: CompanionMode) { preferences.mode = mode }
    public mutating func setStyle(_ style: StartStyle) { preferences.style = style }

    // MARK: Coach mark (PLAN-9)

    public var showsRulerCoachMark: Bool { !preferences.hasSeenRulerCoachMark }
    public mutating func dismissRulerCoachMark() { preferences.hasSeenRulerCoachMark = true }

    // MARK: Flights

    /// Builds the flight for the current selection, or `nil` if nothing can be confirmed.
    public func makeFlight(policy: PausePolicy? = nil, seed: UInt64 = UInt64.random(in: .min ... .max)) -> Flight? {
        guard let selection = confirm() else { return nil }
        let km = selection.destination.map { Geo.distanceKm(from: selection.origin.coordinate, to: $0.coordinate) } ?? 0
        return Flight(
            originIata: selection.origin.iata,
            destinationIata: selection.destination?.iata,
            scenarioID: preferences.scenarioID,
            topic: preferences.topic,
            policy: policy ?? preferences.pausePolicy,
            durationSec: selection.duration.minutes.map { TimeInterval($0) * 60 },
            routeDistanceKm: km,
            seed: seed
        )
    }

    /// Quick Start (PLAN-7, ⌘⏎): repeats the last route, duration and scenario.
    /// `nil` when there is no history or the airports are gone from the index.
    public func quickStart(policy: PausePolicy? = nil, seed: UInt64 = UInt64.random(in: .min ... .max)) -> Flight? {
        guard let last = preferences.lastRoute,
              let from = index.airport(iata: last.originIata) else { return nil }
        let to = last.destinationIata.flatMap { index.airport(iata: $0) }
        // A timed flight needs both its destination and duration; a free one needs neither.
        if last.durationMinutes != nil, to == nil { return nil }
        let km = to.map { Geo.distanceKm(from: from.coordinate, to: $0.coordinate) } ?? 0
        return Flight(
            originIata: from.iata,
            destinationIata: to?.iata,
            scenarioID: last.scenarioID,
            topic: preferences.topic,
            policy: policy ?? preferences.pausePolicy,
            durationSec: last.durationMinutes.map { TimeInterval($0) * 60 },
            routeDistanceKm: km,
            seed: seed
        )
    }

    /// Remembers a flight as the "last route" for Quick Start; call when it starts.
    public mutating func recordStarted(_ flight: Flight) {
        preferences.lastRoute = LastRoute(
            originIata: flight.originIata,
            destinationIata: flight.destinationIata,
            durationMinutes: flight.durationSec.map { Int(($0 / 60).rounded()) },
            scenarioID: flight.scenarioID
        )
    }

    /// Remembers where the plane landed so "Fly again from CDG" and
    /// "Continue from last landing" work (LND-3). Free flights have no landing airport.
    public mutating func recordLanded(_ flight: Flight) {
        if let destination = flight.destinationIata { preferences.lastLandingIata = destination }
    }

    // MARK: Internals

    private mutating func recomputeDestinations() {
        guard let minutes = duration.minutes else {
            destinations = []
            selectedDestinationIata = nil
            return
        }
        destinations = index.destinations(from: origin, minutes: minutes, toleranceMinutes: RangeRing.defaultToleranceMinutes)
        // Keep the user's pick if it is still in the ring; otherwise the nearest match.
        if let kept = selectedDestinationIata, destinations.contains(where: { $0.iata == kept }) { return }
        selectedDestinationIata = destinations.first?.iata
    }

    private mutating func moveSelection(by step: Int) {
        guard !destinations.isEmpty else { return }
        let current = selectedIndex ?? (step > 0 ? -1 : 0)
        let next = ((current + step) % destinations.count + destinations.count) % destinations.count
        selectedDestinationIata = destinations[next].iata
    }
}
