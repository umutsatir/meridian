import Foundation
import MeridianCore
import MeridianPlan
import Observation

enum AppSection: String, CaseIterable, Identifiable {
    case fly, wallet, map, stats, together

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fly: "Fly"
        case .wallet: "Wallet"
        case .map: "Map"
        case .stats: "Stats"
        case .together: "Together"
        }
    }

    var symbol: String {
        switch self {
        case .fly: "airplane.departure"
        case .wallet: "ticket"
        case .map: "globe.europe.africa"
        case .stats: "chart.bar"
        case .together: "person.2"
        }
    }
}

@Observable
final class AppModel {
    var section: AppSection = .fly
    var plan: PlanState {
        didSet { savePreferences() }
    }
    private(set) var activeFlight: Flight?
    private(set) var lastLanded: Flight?
    let index: AirportIndex

    private static let preferencesKey = "plan.preferences"

    init() {
        let index: AirportIndex
        do { index = try AirportIndex.bundled() } catch { fatalError("Bundled airport data is missing: \(error)") }
        self.index = index
        let stored = UserDefaults.standard.data(forKey: Self.preferencesKey)
            .flatMap { try? JSONDecoder().decode(PlanPreferences.self, from: $0) }
        plan = PlanState(index: index, preferences: stored ?? PlanPreferences())
    }

    // MARK: Flight lifecycle

    /// Starts the planned flight (the ritual comes later; this is the quick path).
    func startFlight() {
        guard activeFlight == nil, let flight = plan.makeFlight() else { return }
        begin(flight)
    }

    /// PLAN-7: repeat the last route, duration and scenario.
    func quickStart() {
        guard activeFlight == nil, let flight = plan.quickStart() else { return }
        begin(flight)
    }

    private func begin(_ flight: Flight) {
        var flight = flight
        do {
            try flight.board()
            try flight.takeOff(at: .now)
        } catch { return }
        plan.recordStarted(flight)
        activeFlight = flight
        section = .fly
    }

    func landEarly() {
        guard var flight = activeFlight else { return }
        do { try flight.landEarly(at: .now) } catch { return }
        finish(flight)
    }

    /// Called every second and on wake; lands the flight when its time is up.
    func tick(at now: Date = .now) {
        guard var flight = activeFlight else { return }
        if flight.settle(at: now) { finish(flight) } else { activeFlight = flight }
    }

    private func finish(_ flight: Flight) {
        plan.recordLanded(flight)
        lastLanded = flight
        activeFlight = nil
    }

    func airport(_ iata: String?) -> Airport? { iata.flatMap { index.airport(iata: $0) } }

    private func savePreferences() {
        guard let data = try? JSONEncoder().encode(plan.preferences) else { return }
        UserDefaults.standard.set(data, forKey: Self.preferencesKey)
    }
}
