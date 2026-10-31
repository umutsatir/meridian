import Foundation

/// Cabin class as printed on the ticket's foil edge (`K.cabin(minutes)` in meridian-kit.js).
/// Mirrors MeridianCore's `CabinClass` (this package does not depend on it).
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

    /// `K.cabin(min)`: < 45 economy, < 90 premium, < 180 business, < 300 first, else long-haul.
    public static func cabin(forMinutes m: Int) -> BoardingPassCabin {
        m < 45 ? .economy : m < 90 ? .premium : m < 180 ? .business : m < 300 ? .first : .longHaul
    }

    /// `--foil-*` gradient stops (horizontal), `meridian.css`.
    public var foilStops: [(Double, String)] {
        switch self {
        case .economy: [(0, "#868FA0"), (0.28, "#D6DCE6"), (0.52, "#9AA3B3"), (0.78, "#CBD1DC"), (1, "#868FA0")]
        case .premium: [(0, "#79BDFB"), (0.38, "#DCF0FF"), (0.68, "#6FAEEA"), (1, "#BFE2FF")]
        case .business: [(0, "#C29A52"), (0.34, "#F3DFAA"), (0.62, "#B98E3F"), (1, "#ECD59C")]
        case .first: [(0, "#E4D7B8"), (0.38, "#FFFCF2"), (0.70, "#D5C49A"), (1, "#F8F1DE")]
        case .longHaul: [(0, "#8BF3D8"), (0.25, "#6AB7FF"), (0.50, "#B49CFF"), (0.75, "#FF8FB1"), (1, "#FFB86B")]
        }
    }

    /// Ink tone for the "Class" color-by view.
    var classTone: String {
        switch self {
        case .first: "#D5C49A"
        case .economy: "#9AA3B3"
        case .premium: "#6FAEEA"
        case .business: "#B98E3F"
        case .longHaul: "#6AB7FF"
        }
    }
}

/// Focus type (`K.scenarios`). Always pair color with the icon and label (PRD COL-2).
public enum PaperScenario: String, Sendable, CaseIterable {
    case study, work, read, create, code, meditate, fitness, other

    public var label: String {
        switch self {
        case .study: "Study"
        case .work: "Work"
        case .read: "Read"
        case .create: "Create"
        case .code: "Coding"
        case .meditate: "Meditate"
        case .fitness: "Fitness"
        case .other: "Other"
        }
    }

    public var hex: String {
        switch self {
        case .study: "#7AA2FF"
        case .work: "#FFB86B"
        case .read: "#7ADDB2"
        case .create: "#FF8FB1"
        case .code: "#B49CFF"
        case .meditate: "#8EE3E8"
        case .fitness: "#FF9B7A"
        case .other: "#C7CCDA"
        }
    }

    public var icon: MRIconName {
        switch self {
        case .study: .cap
        case .work: .briefcase
        case .read: .book
        case .create: .spark
        case .code: .code
        case .meditate: .lotus
        case .fitness: .dumbbell
        case .other: .dot
        }
    }
}

/// What colors the band / underline (C01 "Color by").
public enum PaperColorBy: String, Sendable, CaseIterable { case scenario, `class`, continent, month }

public enum PaperContinent: String, Sendable, CaseIterable {
    case eu, na, sa, asia, af, oc
    public var hex: String {
        switch self {
        case .eu: "#7AA2FF"   // --ct-eu = --sc-study
        case .na: "#B49CFF"   // --sc-code
        case .sa: "#7ADDB2"   // --sc-read
        case .asia: "#FF8FB1"   // --sc-create
        case .af: "#FFB86B"   // --sc-work
        case .oc: "#8EE3E8"   // --sc-meditate
        }
    }
}

/// Visual state of a pass (the `state` prop of Ticket.dc.html).
public enum BoardingPassState: Sendable, Hashable {
    case printed
    /// Revealed top-down, 0...1 (C01 "Printing").
    case printing(Double)
    /// Stub gone; seeded jagged edge, 452 pt tall.
    case torn
    /// Pulsing amber BOARDING pill replaces the date.
    case boarding
    /// Torn, with a progress line along the edge (0...1).
    case inflight(Double)
    case landed
    case diverted
    /// Passenger avatars replace the name.
    case group
    /// Wallet placeholder (dashed outline, no ink).
    case locked

    var isTornShape: Bool {
        switch self {
        case .torn, .inflight, .landed, .diverted: true
        default: false
        }
    }
}

public enum BoardingPassSide: Sendable { case front, back }

public struct BoardingPassModel: Sendable, Hashable {
    public var originCode: String
    public var originCity: String
    public var destinationCode: String
    public var destinationCity: String
    public var originCoordinate: PaperCoordinate?
    public var destinationCoordinate: PaperCoordinate?
    public var flightNumber: String
    public var gate: String
    public var seat: String
    /// `nil` for a free flight.
    public var durationMinutes: Int?
    public var distanceKm: Int
    public var cabin: BoardingPassCabin
    public var scenario: PaperScenario
    public var topic: String
    public var dateText: String
    public var boardingTime: String
    public var passengerName: String
    /// Back of the pass.
    public var notes: String
    /// "Landed" stamp time and the diverted flown fraction.
    public var landTime: String
    public var flownMinutes: Int?
    public var groupInitials: [String]
    public var colorBy: PaperColorBy
    public var continent: PaperContinent
    /// 0...11, for the Month view.
    public var month: Int
    /// Drives the torn edge and barcode, so the same flight always prints the same ticket
    /// (`hash(from + to + flight)`).
    public var seed: UInt64

    public init(originCode: String, originCity: String, destinationCode: String, destinationCity: String,
                originCoordinate: PaperCoordinate? = nil, destinationCoordinate: PaperCoordinate? = nil,
                flightNumber: String = "MR 0142", gate: String = "A12", seat: String = "1A",
                durationMinutes: Int? = 42, distanceKm: Int = 348, cabin: BoardingPassCabin? = nil,
                scenario: PaperScenario = .code, topic: String = "Auth module refactor",
                dateText: String = "THU 29 OCT", boardingTime: String = "10:00", passengerName: String = "ELIF KAYA",
                notes: String = "Finished the token refresh path and wrote the migration. Review tomorrow.",
                landTime: String = "10:42", flownMinutes: Int? = nil,
                groupInitials: [String] = ["E", "A", "M", "S", "D", "K"],
                colorBy: PaperColorBy = .scenario, continent: PaperContinent = .eu, month: Int? = nil, seed: UInt64? = nil) {
        self.originCode = originCode; self.originCity = originCity
        self.destinationCode = destinationCode; self.destinationCity = destinationCity
        self.originCoordinate = originCoordinate; self.destinationCoordinate = destinationCoordinate
        self.flightNumber = flightNumber; self.gate = gate; self.seat = seat
        self.durationMinutes = durationMinutes; self.distanceKm = distanceKm
        self.cabin = cabin ?? BoardingPassCabin.cabin(forMinutes: durationMinutes ?? 0)
        self.scenario = scenario; self.topic = topic
        self.dateText = dateText; self.boardingTime = boardingTime; self.passengerName = passengerName
        self.notes = notes; self.landTime = landTime; self.flownMinutes = flownMinutes
        self.groupInitials = Array(groupInitials.prefix(6))
        self.colorBy = colorBy; self.continent = continent
        let s = seed ?? UInt64(Self.designSeed(from: originCode, to: destinationCode, flight: flightNumber))
        self.seed = s
        self.month = month ?? Int(s % 12)
    }

    /// `hash(from + to + flight)`, the canvas' ticket seed.
    public static func designSeed(from: String, to: String, flight: String) -> UInt32 {
        PaperHash.fnv1a(from + to + flight)
    }

    /// Scenario label as printed on the chip.
    public var scenarioName: String { scenario.label }

    /// "42 min" (JetBrains Mono 13 under the plane glyph); "Free" for a free flight.
    public var durationText: String { durationMinutes.map { "\($0) min" } ?? "Free" }

    public var distanceText: String { "\(distanceKm) km" }

    /// PRD §10.3: "Boarding pass, London Heathrow to Paris Charles de Gaulle…"
    public func accessibilityDescription(canTear: Bool) -> String {
        var parts = ["Boarding pass, \(originCity) to \(destinationCity)",
                     "flight \(flightNumber)", "gate \(gate)", "seat \(seat)",
                     durationMinutes == nil ? "free flight" : durationText,
                     "\(cabin.title) cabin", scenarioName]
        parts.removeAll { $0.isEmpty }
        return parts.joined(separator: ", ") + (canTear ? ". Activate to tear off the stub." : ".")
    }

    /// Decorative serial under the barcode (`MR0142·LHRCDG·1A·29OCT26·00xxxx`).
    var serial: String {
        let flight = flightNumber.replacingOccurrences(of: " ", with: "")
        return "\(flight)·\(originCode)\(destinationCode)·\(seat)·29OCT26·00\(1000 + Int(seed % 9000))"
    }

    public static let lhrCoordinate = PaperCoordinate(lat: 51.4700, lon: -0.4543)
    public static let cdgCoordinate = PaperCoordinate(lat: 49.0097, lon: 2.5479)

    /// The canvas' default pass: LHR to CDG, MR 0142, 348 km / 42 min.
    public static let sample = BoardingPassModel(
        originCode: "LHR", originCity: "London", destinationCode: "CDG", destinationCity: "Paris",
        originCoordinate: lhrCoordinate, destinationCoordinate: cdgCoordinate)
}
