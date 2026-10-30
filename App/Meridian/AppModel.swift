import Foundation
import MeridianCore
import MeridianCruise
import MeridianData
import MeridianPlan
import Observation
import SwiftData

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
    /// First-run onboarding done (or skipped). Written by `completeOnboarding` (Features/Onboarding).
    var hasOnboarded: Bool = UserDefaults.standard.bool(forKey: "onboarding.completed")
    var plan: PlanState {
        didSet { savePreferences() }
    }
    private(set) var activeFlight: Flight?
    private(set) var lastLanded: Flight?
    let index: AirportIndex

    // MARK: Persisted state for the views (read-only; refreshed from `FlightStore`)

    /// The most recent landing summary (km credited, unlocked cards, new stamp). Set when a
    /// flight lands, including while the app was away.
    private(set) var latestLanding: LandingSummary?
    /// "Flight resumed" / "Landed in Paris while you were away" banner; auto-dismisses.
    private(set) var resumeBanner: ResumeBanner?
    /// Finished flights, newest first.
    private(set) var walletFlights: [Flight] = []
    private(set) var totalKm: Double = 0
    private(set) var streak: Int = 0
    private(set) var unlockedTiers: [MembershipTier] = []
    /// ISO country codes with a stamp, sorted.
    private(set) var stamps: [String] = []

    @ObservationIgnored private let store: FlightStore
    /// Persistence calls run strictly in order.
    @ObservationIgnored private var storeQueue: Task<Void, Never>?
    @ObservationIgnored private var lastActiveAt: Date
    @ObservationIgnored private var bannerDismissTask: Task<Void, Never>?

    private static let preferencesKey = "plan.preferences"
    private static let heartbeatKey = "app.lastActiveAt"

    /// `container == nil` opens the on-disk store (CloudKit off for now); pass an in-memory
    /// container from `MeridianSchema.container()` for previews and tests.
    init(container: ModelContainer? = nil, resumeOnLaunch: Bool = true) {
        let index: AirportIndex
        do { index = try AirportIndex.bundled() } catch { fatalError("Bundled airport data is missing: \(error)") }
        self.index = index
        let stored = UserDefaults.standard.data(forKey: Self.preferencesKey)
            .flatMap { try? JSONDecoder().decode(PlanPreferences.self, from: $0) }
        plan = PlanState(index: index, preferences: stored ?? PlanPreferences())
        store = FlightStore(modelContainer: container ?? Self.makeContainer())
        lastActiveAt = (UserDefaults.standard.object(forKey: Self.heartbeatKey) as? Date) ?? .now
        enqueue { store in await store.configure(airports: index) }
        if resumeOnLaunch { resume(cause: .launch) }
        refreshCollections()
    }

    /// File-based store in Application Support, CloudKit off. Falls back to memory so the app
    /// still runs (without saving) if the file cannot be opened.
    private static func makeContainer() -> ModelContainer {
        let fm = FileManager.default
        if let support = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            let dir = support.appendingPathComponent("Meridian", isDirectory: true)
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            if let container = try? MeridianSchema.container(storeURL: dir.appendingPathComponent("Meridian.store"), cloudKit: false) {
                return container
            }
        }
        do { return try MeridianSchema.container() } catch { fatalError("Cannot create a data store: \(error)") }
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
        resumeBanner = nil
        touchHeartbeat(.now)
        let started = flight
        enqueue { store in try? await store.begin(started) }
    }

    func landEarly() {
        guard var flight = activeFlight else { return }
        do { try flight.landEarly(at: .now) } catch { return }
        finish(flight)
    }

    /// Called every second and on wake; lands the flight when its time is up. A gap since the
    /// last tick (sleep, App Nap) produces the "resumed" / "landed while away" banner.
    func tick(at now: Date = .now) {
        defer { touchHeartbeat(now) }
        guard var flight = activeFlight else { return }
        let before = lastActiveAt
        let landed = flight.settle(at: now)
        let banner = ResumeBanner.select(flight: flight, cause: .wake, lastActiveAt: before, now: now,
                                         destinationCity: airport(flight.destinationIata)?.city)
        if landed {
            finish(flight, banner: banner)
        } else {
            activeFlight = flight
            if let banner { show(banner) }
        }
    }

    private func finish(_ flight: Flight, banner: ResumeBanner? = nil) {
        plan.recordLanded(flight)
        lastLanded = flight
        activeFlight = nil
        if let banner { show(banner) }
        enqueue { [weak self] store in
            guard let summary = try? await store.complete(flight) else { return }
            self?.didLand(summary)
        }
    }

    private func didLand(_ summary: LandingSummary) {
        // An idempotent repeat returns an empty summary; keep the richer one.
        if latestLanding?.flight.id != summary.flight.id || !summary.unlockedTiers.isEmpty || summary.newStampCountry != nil {
            latestLanding = summary
        }
        refreshCollections()
    }

    // MARK: Resume (launch and wake)

    /// Settles the stored active flight against the clock and restores it, or reports that it
    /// landed while the app was away.
    func resume(cause: ResumeCause, at now: Date = .now) {
        let lastActive = lastActiveAt
        enqueue { [weak self] store in
            guard let outcome = try? await store.resume(at: now) else { return }
            self?.apply(outcome, cause: cause, lastActiveAt: lastActive, now: now)
        }
    }

    private func apply(_ outcome: ResumeOutcome, cause: ResumeCause, lastActiveAt: Date, now: Date) {
        switch outcome {
        case .unchanged:
            break
        case .resumedInFlight(let flight):
            guard activeFlight == nil || activeFlight?.id == flight.id else { return }
            activeFlight = flight
            plan.recordStarted(flight)
            if let banner = ResumeBanner.select(flight: flight, cause: cause, lastActiveAt: lastActiveAt, now: now,
                                                destinationCity: airport(flight.destinationIata)?.city) {
                show(banner)
            }
        case .landedWhileAway(let summary):
            plan.recordLanded(summary.flight)
            lastLanded = summary.flight
            if activeFlight?.id == summary.flight.id { activeFlight = nil }
            latestLanding = summary
            if let banner = ResumeBanner.select(flight: summary.flight, cause: cause, lastActiveAt: lastActiveAt, now: now,
                                                destinationCity: airport(summary.flight.destinationIata)?.city) {
                show(banner)
            }
            refreshCollections()
        }
    }

    // MARK: Banner

    private func show(_ banner: ResumeBanner) {
        resumeBanner = banner
        bannerDismissTask?.cancel()
        bannerDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(ResumeBanner.autoDismissAfterSec))
            guard !Task.isCancelled else { return }
            self?.resumeBanner = nil
        }
    }

    func dismissResumeBanner() {
        bannerDismissTask?.cancel()
        resumeBanner = nil
    }

    // MARK: Collections

    /// Reloads wallet, distance, streak, cards and stamps from the store.
    func refreshCollections() {
        enqueue { [weak self] store in
            let flights = (try? await store.finishedFlights()) ?? []
            let km = (try? await store.totalKm()) ?? 0
            let dates = (try? await store.landingDates()) ?? []
            let tiers = (try? await store.unlockedTiers()) ?? []
            let stamps = (try? await store.stampedCountries()) ?? []
            guard let self else { return }
            self.walletFlights = flights
            self.totalKm = km
            self.streak = Streak.current(landingDates: dates, now: .now)
            self.unlockedTiers = tiers
            self.stamps = stamps
        }
    }

    // MARK: Helpers

    func airport(_ iata: String?) -> Airport? { iata.flatMap { index.airport(iata: $0) } }

    private func enqueue(_ work: @escaping @MainActor (FlightStore) async -> Void) {
        let previous = storeQueue
        let store = store
        storeQueue = Task { @MainActor in
            await previous?.value
            await work(store)
        }
    }

    private func touchHeartbeat(_ now: Date) {
        lastActiveAt = now
        UserDefaults.standard.set(now, forKey: Self.heartbeatKey)
    }

    private func savePreferences() {
        guard let data = try? JSONEncoder().encode(plan.preferences) else { return }
        UserDefaults.standard.set(data, forKey: Self.preferencesKey)
    }
}
