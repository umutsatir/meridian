import Foundation
import MeridianCore
import MeridianUI
import SwiftUI

// MARK: - Ticket value

/// One wallet entry: everything the grid tile, the stack and the detail need, derived from a finished `Flight`.
/// The same flight always prints the same ticket (seed = `hash(from + to + flight number)`, as in the canvas).
struct WalletTicket: Identifiable, Hashable {
    let id: String
    /// `nil` for fixtures (debug routes only).
    let flightID: UUID?
    let from: String
    let to: String
    let scenario: PaperScenario
    let month: Int
    let year: Int
    let km: Int
    let minutes: Int
    let continent: PaperContinent
    let state: BoardingPassState
    var model: BoardingPassModel

    var cabin: BoardingPassCabin { model.cabin }
    var dateText: String { model.dateText }
    var flightNumber: String { model.flightNumber }
    var topic: String { model.topic }
    var notes: String { model.notes }

    func model(colorBy: PaperColorBy) -> BoardingPassModel {
        var m = model
        m.colorBy = colorBy
        return m
    }

    /// VoiceOver / aria label of a tile (canvas: "Ticket LHR to CDG, THU 29 OCT, Coding").
    var accessibilityLabel: String {
        "Ticket \(from) to \(to), \(dateText), \(scenario.label)"
    }

    /// Text the search field matches against.
    var searchText: String {
        [from, to, model.originCity, model.destinationCity, topic, flightNumber, scenario.label, dateText, model.cabin.title].joined(separator: " ")
    }
}

// MARK: - Color-by presentation (legend, captions)

enum WalletColor {
    /// `hsl(month * 30, 62%, 74%)` of the canvas.
    static func month(_ m: Int) -> Color {
        let l = 0.74, s = 0.62
        let v = l + s * min(l, 1 - l)
        return Color(hue: Double(m * 30) / 360, saturation: v == 0 ? 0 : 2 * (1 - l / v), brightness: v)
    }

    static func foil(_ cabin: BoardingPassCabin) -> LinearGradient {
        LinearGradient(stops: cabin.foilStops.map { .init(color: MRColorToken($0.1).color, location: $0.0) }, startPoint: .leading, endPoint: .trailing)
    }

    static let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    static func continentName(_ c: PaperContinent) -> String {
        switch c {
        case .eu: "Europe"
        case .na: "N. America"
        case .sa: "S. America"
        case .asia: "Asia"
        case .af: "Africa"
        case .oc: "Oceania"
        }
    }

    /// Caption under a tile: dot fill and label for the active "Color by" (never color alone).
    @ViewBuilder static func dot(_ t: WalletTicket, by: PaperColorBy, size: CGFloat) -> some View {
        switch by {
        case .scenario: Circle().fill(MRColorToken(t.scenario.hex).color).frame(width: size, height: size)
        case .class: Circle().fill(foil(t.cabin)).frame(width: size, height: size)
        case .continent: Circle().fill(MRColorToken(t.continent.hex).color).frame(width: size, height: size)
        case .month: Circle().fill(month(t.month)).frame(width: size, height: size)
        }
    }

    static func label(_ t: WalletTicket, by: PaperColorBy) -> String {
        switch by {
        case .scenario: t.scenario.label
        case .class: t.cabin.title
        case .continent: continentName(t.continent)
        case .month: monthNames[min(11, max(0, t.month))]
        }
    }
}

// MARK: - Filters

struct WalletFilters: Equatable {
    static let allYears = "All years"
    static let allScenarios = "All scenarios"
    static let allClasses = "All classes"

    var year = allYears
    var scenario = allScenarios
    var cabin = allClasses
    var query = ""

    var isActive: Bool { year != Self.allYears || scenario != Self.allScenarios || cabin != Self.allClasses || !query.isEmpty }

    func apply(_ list: [WalletTicket]) -> [WalletTicket] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return list.filter { t in
            (year == Self.allYears || String(t.year) == year)
                && (scenario == Self.allScenarios || t.scenario.label == scenario)
                && (cabin == Self.allClasses || t.cabin.title == cabin)
                && (q.isEmpty || t.searchText.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil)
        }
    }
}

// MARK: - Building tickets from flights

enum WalletBuilder {
    /// The canvas' continent rule (`CONT` in meridian-kit.js: Turkey counts as Europe), falling back to the airport's continent.
    private static let kitContinent: [String: PaperContinent] = {
        var m: [String: PaperContinent] = [:]
        for c in "GB JE GG IE FR NL BE LU DE CH AT CZ PL HU DK NO SE FI IS ES PT IT GR TR".split(separator: " ") { m[String(c)] = .eu }
        for c in "AE QA JP SG".split(separator: " ") { m[String(c)] = .asia }
        for c in "EG MA".split(separator: " ") { m[String(c)] = .af }
        for c in "US CA".split(separator: " ") { m[String(c)] = .na }
        m["BR"] = .sa; m["AU"] = .oc
        return m
    }()

    static func continent(of a: Airport?) -> PaperContinent {
        guard let a else { return .eu }
        if let c = kitContinent[a.countryCode] { return c }
        switch a.continent {
        case .europe: return .eu
        case .northAmerica: return .na
        case .southAmerica: return .sa
        case .asia: return .asia
        case .africa: return .af
        case .oceania, .antarctica: return .oc
        }
    }

    private static func coordinate(_ a: Airport?) -> PaperCoordinate? {
        a.map { PaperCoordinate(lat: $0.coordinate.latitude, lon: $0.coordinate.longitude) }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "EEE dd MMM"; return f
    }()
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "HH:mm"; return f
    }()

    /// Finished flights with a destination become tickets; free flights (no destination) have no route to print.
    @MainActor static func tickets(from flights: [Flight], airport: (String) -> Airport?, passenger: String) -> [WalletTicket] {
        flights.compactMap { f -> WalletTicket? in
            guard f.isFinished, let to = f.destinationIata else { return nil }
            let a = airport(f.originIata), b = airport(to)
            let identity = TicketIdentity(seed: f.seed)
            let number = identity.flightNumber.replacingOccurrences(of: "MR", with: "MR ")
            let when = f.endedAt ?? f.startedAt ?? .now
            let cal = Calendar.current
            let planned = Int(((f.durationSec ?? 0) / 60).rounded())
            let diverted = f.status == .diverted
            let flown = f.finalFocusedSec.map { Int(($0 / 60).rounded()) }
            let scenario = PaperScenario(rawValue: f.scenarioID) ?? .other
            let model = BoardingPassModel(
                originCode: f.originIata, originCity: a?.city ?? f.originIata,
                destinationCode: to, destinationCity: b?.city ?? to,
                originCoordinate: coordinate(a), destinationCoordinate: coordinate(b),
                flightNumber: number, gate: identity.gate, seat: "1A",
                durationMinutes: planned, distanceKm: Int(f.routeDistanceKm.rounded()),
                scenario: scenario, topic: f.topic,
                dateText: dateFormatter.string(from: when).uppercased(),
                boardingTime: timeFormatter.string(from: f.startedAt ?? when), passengerName: passenger.uppercased(),
                notes: f.notes, landTime: timeFormatter.string(from: when), flownMinutes: diverted ? flown : nil,
                continent: continent(of: b), month: cal.component(.month, from: when) - 1)
            return WalletTicket(id: f.id.uuidString, flightID: f.id, from: f.originIata, to: to, scenario: scenario,
                                month: cal.component(.month, from: when) - 1, year: cal.component(.year, from: when),
                                km: model.distanceKm, minutes: planned, continent: model.continent,
                                state: diverted ? .diverted : .landed, model: model)
        }
    }
}

// MARK: - Summary

enum WalletSummary {
    static func text(count: Int, flights: [Flight]) -> String {
        let noun = count == 1 ? "flight" : "flights"
        let sec = flights.reduce(0.0) { $0 + ($1.finalFocusedSec ?? 0) }
        let km = flights.reduce(0.0) { $0 + $1.creditedKm }
        let hours = (sec / 3600 * 10).rounded() / 10
        return "\(count) \(noun) · \(hours.formatted(.number.precision(.fractionLength(1)))) hours · \(PlanKit.fmtKm(km)) km"
    }
}
