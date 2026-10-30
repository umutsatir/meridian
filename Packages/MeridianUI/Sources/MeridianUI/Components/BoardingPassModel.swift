import Foundation

/// Cabin class as printed on the ticket's foil edge. Mirrors MeridianCore's `CabinClass`
/// (this package does not depend on it).
public enum BoardingPassCabin: String, Sendable, CaseIterable {
    case economy, premium, business, first, longHaul

    public var title: String {
        switch self {
        case .economy: "Economy"
        case .premium: "Premium"
        case .business: "Business"
        case .first: "First"
        case .longHaul: "Long-haul"
        }
    }

    /// Foil gradient stops (hex). Economy is a flat, muted edge.
    var foilHexes: [String] {
        switch self {
        case .economy: ["#B9B2A3", "#CFC9BB"]
        case .premium: ["#6AB7FF", "#8BF3D8"]
        case .business: ["#8BF3D8", "#6AB7FF", "#B49CFF"]
        case .first: ["#FFB547", "#FFE3A3", "#FFB547"]
        case .longHaul: ["#FF8FB1", "#FFB547", "#8BF3D8", "#6AB7FF", "#B49CFF"]
        }
    }
}

public struct BoardingPassModel: Sendable, Hashable {
    public var originCode: String
    public var originCity: String
    public var destinationCode: String
    public var destinationCity: String
    public var flightNumber: String
    public var gate: String
    public var seat: String
    /// `nil` for a free flight.
    public var durationMinutes: Int?
    public var cabin: BoardingPassCabin
    public var scenarioName: String
    /// Drives the torn edge and barcode, so the same flight always prints the same ticket.
    public var seed: UInt64

    public init(originCode: String, originCity: String, destinationCode: String, destinationCity: String,
                flightNumber: String, gate: String, seat: String, durationMinutes: Int?,
                cabin: BoardingPassCabin, scenarioName: String, seed: UInt64) {
        self.originCode = originCode
        self.originCity = originCity
        self.destinationCode = destinationCode
        self.destinationCity = destinationCity
        self.flightNumber = flightNumber
        self.gate = gate
        self.seat = seat
        self.durationMinutes = durationMinutes
        self.cabin = cabin
        self.scenarioName = scenarioName
        self.seed = seed
    }

    public var durationText: String {
        guard let m = durationMinutes else { return "FREE" }
        guard m >= 60 else { return "\(m) MIN" }
        return m % 60 == 0 ? "\(m / 60) H" : "\(m / 60) H \(m % 60) MIN"
    }

    /// PRD §10.3: "Boarding pass, London Heathrow to Paris Charles de Gaulle…"
    public func accessibilityDescription(canTear: Bool) -> String {
        var parts = ["Boarding pass, \(originCity) to \(destinationCity)",
                     "flight \(flightNumber)", "gate \(gate)", "seat \(seat)",
                     durationMinutes == nil ? "free flight" : "\(durationText.lowercased())",
                     "\(cabin.title) cabin", scenarioName]
        parts.removeAll { $0.isEmpty }
        return parts.joined(separator: ", ") + (canTear ? ". Activate to tear off the stub." : ".")
    }

    public static let sample = BoardingPassModel(
        originCode: "LHR", originCity: "London Heathrow", destinationCode: "CDG", destinationCity: "Paris Charles de Gaulle",
        flightNumber: "MR4821", gate: "B7", seat: "12A", durationMinutes: 42, cabin: .economy, scenarioName: "Study", seed: 42)
}
