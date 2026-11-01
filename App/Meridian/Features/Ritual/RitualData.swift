import Foundation
import MeridianCore
import MeridianFocus
import MeridianPlan
import MeridianUI
import SwiftUI

/// The four cabin zones of the seat map: rows 1-3 Study, 4-6 Work, 7-9 Read, 10-12 Create (`K.scenarios`).
enum RitualZone: Int, CaseIterable, Identifiable {
    case study, work, read, create
    var id: Int { rawValue }

    var scenario: PaperScenario {
        switch self {
        case .study: .study
        case .work: .work
        case .read: .read
        case .create: .create
        }
    }
    var label: String { scenario.label }
    var hex: String { scenario.hex }
    var icon: MRIconName { scenario.icon }
    var scenarioID: String { scenario.rawValue }

    static func of(row: Int) -> RitualZone { RitualZone(rawValue: max(0, min(3, (row - 1) / 3))) ?? .study }
    static func of(seat: String) -> RitualZone { of(row: Int(seat.dropLast()) ?? 1) }
    var firstRow: Int { rawValue * 3 + 1 }
}

/// What the ritual draws on the pass: route, time, scenario, topic (canvas `Ticket` props).
struct RitualFlightInfo: Equatable {
    var originCode: String
    var originCity: String
    var originName: String
    var destinationCode: String
    var destinationCity: String
    var originCoordinate: PaperCoordinate?
    var destinationCoordinate: PaperCoordinate?
    /// `nil` = free flight.
    var minutes: Int?
    var km: Int
    var scenario: PaperScenario
    var topic: String
    var flightNumber = "MR 0142"
    var gate = "A12"
    var dateText = "THU 29 OCT"
    var boardingTime = "10:00"
    /// Departures board clock ("09:57").
    var clock = "09:57"
    var passenger = "Elif Kaya"

    /// The canvas defaults: LHR to CDG, 42 min, Coding.
    static let canvas = RitualFlightInfo(
        originCode: "LHR", originCity: "London", originName: "Heathrow T5", destinationCode: "CDG", destinationCity: "Paris",
        originCoordinate: BoardingPassModel.lhrCoordinate, destinationCoordinate: BoardingPassModel.cdgCoordinate,
        minutes: 42, km: 348, scenario: .code, topic: "Auth module refactor")

    func passModel(seat: String, topic: String? = nil, scenario: PaperScenario? = nil) -> BoardingPassModel {
        BoardingPassModel(originCode: originCode, originCity: originCity, destinationCode: destinationCode, destinationCity: destinationCity,
                          originCoordinate: originCoordinate, destinationCoordinate: destinationCoordinate,
                          flightNumber: flightNumber, gate: gate, seat: seat,
                          durationMinutes: minutes, distanceKm: km, scenario: scenario ?? self.scenario, topic: topic ?? self.topic,
                          dateText: dateText, boardingTime: boardingTime, passengerName: passenger.uppercased())
    }

    var routeText: String { "\(originCode) → \(destinationCode)" }
    var durationText: String { minutes.map { "\($0) min" } ?? "Free" }
    /// "42 min · 348 km"
    var flightTimeText: String { "\(durationText) · \(km) km" }

    private static func coordinate(_ a: Airport) -> PaperCoordinate { PaperCoordinate(lat: a.coordinate.latitude, lon: a.coordinate.longitude) }

    /// The flight the user is about to take, from the plan (or the last route for Quick Start), with the real date and time.
    @MainActor static func make(plan: PlanState, quick: Bool, now: Date = .now) -> RitualFlightInfo {
        let origin: Airport
        var destination: Airport?
        var minutes: Int?
        var scenarioID = plan.scenarioID
        if quick, let last = plan.preferences.lastRoute, let from = plan.index.airport(iata: last.originIata) {
            origin = from
            destination = last.destinationIata.flatMap { plan.index.airport(iata: $0) }
            minutes = last.durationMinutes
            scenarioID = last.scenarioID
        } else {
            origin = plan.origin
            destination = plan.selectedDestination
            minutes = plan.durationMinutes
        }
        let km = destination.map { Int(PlanKit.km(origin, $0).rounded()) } ?? 0
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX"); day.dateFormat = "EEE d MMM"
        let hm = DateFormatter()
        hm.locale = Locale(identifier: "en_US_POSIX"); hm.dateFormat = "HH:mm"
        let name = NSFullUserName().trimmingCharacters(in: .whitespaces)
        var info = RitualFlightInfo(
            originCode: origin.iata, originCity: origin.city, originName: terminal(origin),
            destinationCode: destination?.iata ?? "FRE", destinationCity: destination?.city ?? "Free flight",
            originCoordinate: coordinate(origin), destinationCoordinate: destination.map(coordinate),
            minutes: minutes, km: km, scenario: PaperScenario(rawValue: scenarioID) ?? .code, topic: plan.topic)
        info.dateText = day.string(from: now).uppercased()
        info.boardingTime = hm.string(from: now)
        info.clock = hm.string(from: now.addingTimeInterval(-180))
        info.passenger = name.isEmpty ? "Traveller" : name
        return info
    }

    /// "Heathrow T5" for LHR (canvas), otherwise the airport name without the city.
    private static func terminal(_ a: Airport) -> String {
        if a.iata == "LHR" { return "Heathrow T5" }
        var n = a.name
        if n.hasPrefix(a.city + " ") { n.removeFirst(a.city.count + 1) }
        return n.isEmpty ? a.city : n
    }
}

/// Where the ritual is bypassed (RIT-6) and how it is configured, from the plan and the Settings keys.
enum RitualPolicy {
    /// Printer speed from Settings > Flight > Ticket printing: 0 Full, 1 Quick, 2 Off.
    enum Printing { case full, quick, off }
    static var printing: Printing {
        switch SettingsKeys.ticketPrinting.current { case 1: .quick; case 2: .off; default: .full }
    }

    /// Quick Start with "Quick start checks in automatically", the plan's Quick style, "skip always" and printing Off.
    @MainActor static func skips(plan: PlanState, quick: Bool) -> Bool {
        if printing == .off || plan.skipsRitual { return true }
        return quick && SettingsKeys.quickStartChecksIn.current
    }

    /// Seat step default from Settings > Flight > Seat preference (window or aisle).
    static var defaultSeat: String { SettingsKeys.seatPreference.current == 1 ? "1C" : "1A" }

    /// Label of the gate's blocking chip, nil when blocking is off.
    @MainActor static var blockingChip: String? {
        switch FocusStore.shared.prefs.mode {
        case .off: nil
        case .nudge: "Soft blocking is on"
        case .strictOverlay: "Strict blocking is on"
        }
    }
}
