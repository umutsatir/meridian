import Foundation
import MeridianCore
import SwiftData

public enum MeridianSchema {
    public static let models: [any PersistentModel.Type] = [
        FlightRecord.self, CardUnlockRecord.self, StampRecord.self, ProfileRecord.self, CustomScenarioRecord.self,
    ]

    /// `storeURL == nil` keeps the store in memory (tests, previews). CloudKit
    /// sync is opt-in so tests and unsigned builds never touch iCloud.
    public static func container(storeURL: URL? = nil, cloudKit: Bool = false) throws -> ModelContainer {
        let schema = Schema(models)
        let configuration: ModelConfiguration
        if let storeURL {
            configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: cloudKit ? .automatic : .none)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

public enum FlightStoreError: Error, Sendable, Equatable {
    case activeFlightExists
    case noActiveFlight
    case flightNotFinished
    case corruptRecord
}

/// What the app should show after launch or wake (PRD S54 banners).
public enum ResumeOutcome: Sendable, Equatable {
    /// No flight in progress, or it has not left the gate yet.
    case unchanged
    /// A flight is still in the air; show "Flight resumed".
    case resumedInFlight(Flight)
    /// The flight finished while the app was away and has been saved.
    case landedWhileAway(LandingSummary)
}

public struct LandingSummary: Sendable, Equatable {
    public var flight: Flight
    public var creditedKm: Double
    public var totalKmBefore: Double
    public var totalKmAfter: Double
    public var unlockedTiers: [MembershipTier]
    /// Set when this landing earned the first stamp for the country.
    public var newStampCountry: String?
}

public struct Profile: Sendable, Equatable {
    public var createdAt: Date?
    public var homeAirportIata: String?
    public var dailyGoalMinutes: Int

    init(_ record: ProfileRecord) {
        createdAt = record.createdAt
        homeAirportIata = record.homeAirportIata
        dailyGoalMinutes = record.dailyGoalMinutes
    }
}

@ModelActor
public actor FlightStore {
    /// Used to resolve the destination country for stamps.
    private var airports = AirportIndex(airports: [])

    public func configure(airports: AirportIndex) { self.airports = airports }

    // MARK: Active flight (ADR 0002: one flight, always recoverable)

    public func begin(_ flight: Flight) throws {
        if try activeRecord() != nil { throw FlightStoreError.activeFlightExists }
        let record = FlightRecord()
        try record.apply(flight, isActive: true)
        modelContext.insert(record)
        try modelContext.save()
    }

    /// Persists a new state of the active flight (pause, break, take-off...).
    public func update(_ flight: Flight) throws {
        guard let record = try activeRecord(), record.id == flight.id else { throw FlightStoreError.noActiveFlight }
        try record.apply(flight, isActive: true)
        try modelContext.save()
    }

    public func activeFlight() throws -> Flight? {
        guard let record = try activeRecord() else { return nil }
        guard let flight = record.flight else { throw FlightStoreError.corruptRecord }
        return flight
    }

    /// Call on launch and on wake. Settles the active flight against `now`.
    public func resume(at now: Date) throws -> ResumeOutcome {
        guard let record = try activeRecord() else { return .unchanged }
        guard var flight = record.flight else { throw FlightStoreError.corruptRecord }
        guard flight.status == .inFlight || flight.status == .onBreak else { return .unchanged }
        if flight.settle(at: now) {
            return .landedWhileAway(try complete(flight, at: now))
        }
        try record.apply(flight, isActive: true)
        try modelContext.save()
        return .resumedInFlight(flight)
    }

    /// Saves a finished flight (landed or diverted), releases the active slot,
    /// credits distance, unlocks cards and stamps the country. Idempotent.
    @discardableResult
    public func complete(_ flight: Flight, at now: Date = Date()) throws -> LandingSummary {
        guard flight.isFinished else { throw FlightStoreError.flightNotFinished }
        let existing = try record(id: flight.id)
        if let existing, !existing.isActive, existing.status == flight.status, existing.flightData != nil {
            let total = try totalKm()
            return LandingSummary(flight: flight, creditedKm: existing.creditedKm,
                                  totalKmBefore: total - existing.creditedKm, totalKmAfter: total,
                                  unlockedTiers: [], newStampCountry: nil)
        }
        let before = try totalKm(excluding: flight.id)
        let record = existing ?? FlightRecord()
        try record.apply(flight, isActive: false)
        if existing == nil { modelContext.insert(record) }
        let after = before + flight.creditedKm
        let landedAt = flight.endedAt ?? now

        // Cards unlock once and never relock; the first landing also hands out Departure.
        let owned = Set(try modelContext.fetch(FetchDescriptor<CardUnlockRecord>()).compactMap(\.tier))
        var tiers = MembershipTier.unlocked(from: before, to: after)
        if owned.isEmpty && !tiers.contains(.departure) { tiers.insert(.departure, at: 0) }
        tiers.removeAll { owned.contains($0) }
        for tier in tiers {
            let card = CardUnlockRecord()
            card.tierRaw = tier.rawValue
            card.unlockedAt = landedAt
            modelContext.insert(card)
        }

        // One stamp per country, on a completed landing at a known destination.
        var stampCountry: String?
        if flight.status == .landed, let iata = flight.destinationIata, let airport = airports.airport(iata: iata) {
            let code = airport.countryCode
            let stamped = try modelContext.fetchCount(FetchDescriptor<StampRecord>(predicate: #Predicate { $0.countryCode == code }))
            if stamped == 0 {
                let stamp = StampRecord()
                stamp.countryCode = code
                stamp.airportIata = iata
                stamp.flightID = flight.id
                stamp.scenarioID = flight.scenarioID
                stamp.stampedAt = landedAt
                modelContext.insert(stamp)
                stampCountry = code
            }
        }
        try modelContext.save()
        return LandingSummary(flight: flight, creditedKm: flight.creditedKm, totalKmBefore: before,
                              totalKmAfter: after, unlockedTiers: tiers, newStampCountry: stampCountry)
    }

    // MARK: Queries

    public func totalKm() throws -> Double { try totalKm(excluding: nil) }

    public func landingDates() throws -> [Date] {
        try modelContext.fetch(FetchDescriptor<FlightRecord>(predicate: #Predicate { !$0.isActive && $0.endedAt != nil }))
            .compactMap(\.endedAt)
    }

    public func finishedFlights() throws -> [Flight] {
        try modelContext.fetch(FetchDescriptor<FlightRecord>(predicate: #Predicate { !$0.isActive },
                                                             sortBy: [SortDescriptor(\.endedAt, order: .reverse)]))
            .compactMap(\.flight)
    }

    public func unlockedTiers() throws -> [MembershipTier] {
        try modelContext.fetch(FetchDescriptor<CardUnlockRecord>()).compactMap(\.tier).sorted()
    }

    public func stampedCountries() throws -> [String] {
        try modelContext.fetch(FetchDescriptor<StampRecord>()).map(\.countryCode).sorted()
    }

    public func profile() throws -> Profile { Profile(try profileRecord()) }

    public func updateProfile(homeAirportIata: String?, dailyGoalMinutes: Int) throws {
        let record = try profileRecord()
        record.homeAirportIata = homeAirportIata
        record.dailyGoalMinutes = dailyGoalMinutes
        try modelContext.save()
    }

    private func profileRecord() throws -> ProfileRecord {
        if let existing = try modelContext.fetch(FetchDescriptor<ProfileRecord>()).first { return existing }
        let record = ProfileRecord()
        record.createdAt = Date()
        modelContext.insert(record)
        try modelContext.save()
        return record
    }

    // MARK: Deletion

    /// Removes one flight. Cards stay unlocked and stamps stay in the passport.
    public func delete(flightID: UUID) throws {
        guard let record = try record(id: flightID) else { return }
        modelContext.delete(record)
        try modelContext.save()
    }

    /// Edits the notes of a finished flight (ticket back, COL-4).
    public func updateNotes(flightID: UUID, notes: String) throws {
        guard let record = try record(id: flightID), var flight = record.flight else { return }
        flight.notes = notes
        try record.apply(flight, isActive: record.isActive)
        try modelContext.save()
    }

    /// "Delete all data" in Settings (PRD §10.5).
    public func deleteAllData() throws {
        try modelContext.delete(model: FlightRecord.self)
        try modelContext.delete(model: CardUnlockRecord.self)
        try modelContext.delete(model: StampRecord.self)
        try modelContext.delete(model: ProfileRecord.self)
        try modelContext.delete(model: CustomScenarioRecord.self)
        try modelContext.save()
    }

    // MARK: Helpers

    private func activeRecord() throws -> FlightRecord? {
        try modelContext.fetch(FetchDescriptor<FlightRecord>(predicate: #Predicate { $0.isActive })).first
    }

    private func record(id: UUID) throws -> FlightRecord? {
        try modelContext.fetch(FetchDescriptor<FlightRecord>(predicate: #Predicate { $0.id == id })).first
    }

    private func totalKm(excluding id: UUID?) throws -> Double {
        try modelContext.fetch(FetchDescriptor<FlightRecord>(predicate: #Predicate { !$0.isActive }))
            .filter { $0.id != id }
            .reduce(0) { $0 + $1.creditedKm }
    }
}
