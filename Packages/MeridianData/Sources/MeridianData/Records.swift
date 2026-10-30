import Foundation
import MeridianCore
import SwiftData

// CloudKit rules (PRD §11.4): every attribute is optional or has a default,
// no unique constraints, relationships (none yet) would be optional.

@Model
public final class FlightRecord {
    public var id: UUID = UUID()
    public var originIata: String = ""
    public var destinationIata: String?
    public var scenarioID: String = ""
    public var statusRaw: String = FlightStatus.planned.rawValue
    public var startedAt: Date?
    public var endedAt: Date?
    public var durationSec: Double?
    public var routeDistanceKm: Double = 0
    /// Kilometres credited at landing (`Flight.creditedKm`); 0 while flying.
    public var creditedKm: Double = 0
    /// True for the one flight currently in progress.
    public var isActive: Bool = false
    /// Full `Flight` as JSON. `Flight`'s progress fields are `private(set)`, so
    /// a column-by-column rebuild is impossible without changing MeridianCore;
    /// the Codable blob is lossless. The columns above only serve queries.
    public var flightData: Data?

    public init() {}

    public var status: FlightStatus { FlightStatus(rawValue: statusRaw) ?? .planned }

    public var flight: Flight? {
        flightData.flatMap { try? JSONDecoder().decode(Flight.self, from: $0) }
    }

    func apply(_ flight: Flight, isActive: Bool) throws {
        id = flight.id
        originIata = flight.originIata
        destinationIata = flight.destinationIata
        scenarioID = flight.scenarioID
        statusRaw = flight.status.rawValue
        startedAt = flight.startedAt
        endedAt = flight.endedAt
        durationSec = flight.durationSec
        routeDistanceKm = flight.routeDistanceKm
        creditedKm = flight.isFinished ? flight.creditedKm : 0
        self.isActive = isActive
        flightData = try JSONEncoder().encode(flight)
    }
}

@Model
public final class CardUnlockRecord {
    public var tierRaw: String = MembershipTier.departure.rawValue
    public var unlockedAt: Date?
    public init() {}
    public var tier: MembershipTier? { MembershipTier(rawValue: tierRaw) }
}

@Model
public final class StampRecord {
    public var countryCode: String = ""
    public var airportIata: String?
    public var flightID: UUID?
    public var scenarioID: String?
    public var stampedAt: Date?
    public init() {}
}

@Model
public final class ProfileRecord {
    public var createdAt: Date?
    public var homeAirportIata: String?
    public var dailyGoalMinutes: Int = 60
    public init() {}
}

@Model
public final class CustomScenarioRecord {
    public var scenarioID: String = ""
    public var name: String = ""
    public var symbol: String = "ellipsis"
    public var colorHex: String = "#C7CCDA"
    public init() {}

    public var scenario: Scenario {
        Scenario(id: scenarioID, name: name, symbol: symbol, colorHex: colorHex, isCustom: true)
    }
}
