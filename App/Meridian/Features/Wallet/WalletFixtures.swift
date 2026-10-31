import Foundation
import MeridianCore
import MeridianUI

/// The canvas' sample flights (`Wallet.dc.html` DATA, `meridian-kit.js` helpers). DEBUG routes only: the real wallet
/// always shows `AppModel.walletFlights`.
enum WalletFixtures {
    /// `[from, to, scenario, month, date, flight, topic]`
    private static let rows: [(String, String, PaperScenario, Int, String, String, String)] = [
        ("LHR", "CDG", .code, 9, "THU 29 OCT", "MR 0142", "Auth module refactor"), ("CDG", "LHR", .work, 9, "WED 28 OCT", "MR 0141", "Q4 planning deck"),
        ("LHR", "AMS", .study, 9, "TUE 27 OCT", "MR 0139", "Organic chemistry"), ("AMS", "FRA", .read, 8, "MON 21 SEP", "MR 0131", "The Overstory"),
        ("FRA", "IST", .work, 8, "FRI 18 SEP", "MR 0128", "Vendor review"), ("IST", "ESB", .create, 8, "THU 10 SEP", "MR 0124", "Brand sketches"),
        ("ESB", "ADB", .meditate, 7, "SUN 30 AUG", "MR 0119", "Morning sit"), ("LHR", "DUB", .read, 7, "SAT 22 AUG", "MR 0114", "Essays"),
        ("JFK", "BOS", .work, 6, "FRI 17 JUL", "MR 0108", "Inbox zero"), ("BOS", "YYZ", .study, 6, "WED 08 JUL", "MR 0102", "Statistics"),
        ("YYZ", "SFO", .create, 5, "TUE 23 JUN", "MR 0097", "Album notes"), ("LHR", "CAI", .read, 5, "SAT 13 JUN", "MR 0093", "Field guide"),
        ("DXB", "DOH", .fitness, 4, "MON 18 MAY", "MR 0088", "Mobility"), ("SIN", "SYD", .study, 3, "SUN 12 APR", "MR 0079", "Thesis chapter 2"),
        ("LHR", "MAD", .code, 2, "THU 05 MAR", "MR 0071", "API cleanup"),
    ]

    /// Canvas summary line and total of the persona ("87 flights · 94.5 hours · 12,022 km").
    static let summary = "87 flights · 94.5 hours · 12,022 km"
    static let total = 87

    @MainActor static func tickets(airport: (String) -> Airport?) -> [WalletTicket] {
        rows.compactMap { r in
            guard let a = airport(r.0), let b = airport(r.1) else { return nil }
            let km = Int(PlanKit.km(a, b).rounded())
            let minutes = Int((15 + Double(km) / 12.9).rounded())
            let model = BoardingPassModel(
                originCode: r.0, originCity: a.city, destinationCode: r.1, destinationCity: b.city,
                originCoordinate: PaperCoordinate(lat: a.coordinate.latitude, lon: a.coordinate.longitude),
                destinationCoordinate: PaperCoordinate(lat: b.coordinate.latitude, lon: b.coordinate.longitude),
                flightNumber: r.5, durationMinutes: minutes, distanceKm: km, scenario: r.2, topic: r.6, dateText: r.4,
                continent: WalletBuilder.continent(of: b), month: r.3)
            return WalletTicket(id: "fixture-\(r.5)", flightID: nil, from: r.0, to: r.1, scenario: r.2, month: r.3, year: 2026,
                                km: km, minutes: minutes, continent: model.continent, state: .landed, model: model)
        }
    }
}
