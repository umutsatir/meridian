import MeridianCore
import MeridianUI
import SwiftUI

/// One stamp in the passport: the first landing in a country.
struct PassportEntry: Hashable, Identifiable {
    var id: Int { idx }
    var idx: Int
    var code: String          // IATA
    var cc: String            // ISO country code
    var country: String
    var date: String          // "14 Apr 2025"
    var scenario: String      // scenario id
    var shape: StampShape
}

/// A placeholder for a place not visited yet ("Not yet visited").
struct PassportLock: Hashable {
    var code: String, cc: String, country: String, shape: StampShape
}

/// What the Passport screen shows. The real app builds it from `AppModel`; DEBUG routes pass the canvas persona.
struct PassportContent {
    var entries: [PassportEntry]
    var locks: [PassportLock]
    var countries: Int
    var airports: Int
    var stamps: Int
    var memberNumber: String
    /// Index of the newest stamp (plays the passport stamp animation).
    var newest: Int?

    var years: [String] {
        Array(Set(entries.map { String($0.date.suffix(4)) })).sorted(by: >)
    }

    // MARK: Canvas persona (DEBUG routes only)

    static let countryNames: [String: String] = [
        "GB": "United Kingdom", "FR": "France", "NL": "Netherlands", "BE": "Belgium", "DE": "Germany", "IE": "Ireland", "ES": "Spain",
        "PT": "Portugal", "IT": "Italy", "CH": "Switzerland", "AT": "Austria", "DK": "Denmark", "NO": "Norway", "SE": "Sweden",
        "FI": "Finland", "IS": "Iceland", "PL": "Poland", "CZ": "Czechia", "HU": "Hungary", "GR": "Greece", "TR": "Türkiye",
        "LU": "Luxembourg", "JE": "Jersey", "GG": "Guernsey", "AE": "UAE", "QA": "Qatar", "EG": "Egypt", "MA": "Morocco",
        "US": "United States", "CA": "Canada", "JP": "Japan", "SG": "Singapore", "AU": "Australia", "BR": "Brazil",
    ]

    static let fixture: PassportContent = {
        let rec: [(String, String, String, String, String, StampShape)] = [
            ("CDG", "FR", "14 Apr 2025", "code", "", .round), ("AMS", "NL", "02 May 2025", "work", "", .octagon),
            ("DUB", "IE", "19 May 2025", "read", "", .oval), ("BRU", "BE", "08 Jun 2025", "study", "", .rosette),
            ("BCN", "ES", "21 Jun 2025", "create", "", .round), ("LIS", "PT", "12 Jul 2025", "read", "", .octagon),
            ("FCO", "IT", "30 Jul 2025", "meditate", "", .oval), ("ZRH", "CH", "17 Aug 2025", "work", "", .rosette),
            ("CPH", "DK", "03 Sep 2025", "code", "", .round), ("ARN", "SE", "24 Sep 2025", "study", "", .octagon),
            ("VIE", "AT", "11 Oct 2025", "create", "", .oval), ("ATH", "GR", "02 Nov 2025", "read", "", .rosette),
            ("IST", "TR", "20 Nov 2025", "code", "", .round), ("JFK", "US", "09 Dec 2025", "work", "", .octagon),
            ("DXB", "AE", "15 Jan 2026", "study", "", .oval), ("NRT", "JP", "11 Feb 2026", "create", "", .rosette),
            ("OSL", "NO", "04 Mar 2026", "fitness", "", .round), ("HEL", "FI", "28 Apr 2026", "meditate", "", .octagon),
            ("WAW", "PL", "17 Jun 2026", "read", "", .oval),
        ]
        let locks: [(String, String, StampShape)] = [
            ("GRU", "BR", .round), ("SIN", "SG", .octagon), ("SYD", "AU", .oval), ("YYZ", "CA", .rosette),
            ("CMN", "MA", .round), ("CAI", "EG", .octagon), ("DOH", "QA", .oval), ("KEF", "IS", .rosette),
        ]
        return PassportContent(
            entries: rec.enumerated().map { i, r in
                PassportEntry(idx: i, code: r.0, cc: r.1, country: countryNames[r.1] ?? r.1, date: r.2, scenario: r.3, shape: r.5)
            },
            locks: locks.map { PassportLock(code: $0.0, cc: $0.1, country: countryNames[$0.1] ?? $0.1, shape: $0.2) },
            countries: 19, airports: 41, stamps: 87, memberNumber: "0048 1317 2204", newest: nil)
    }()

    // MARK: Real data

    private static let shapes: [StampShape] = [.round, .octagon, .oval, .rosette]
    private static let candidateLocks: [(String, StampShape)] = [
        ("GRU", .round), ("SIN", .octagon), ("SYD", .oval), ("YYZ", .rosette), ("CMN", .round), ("CAI", .octagon),
        ("DOH", .oval), ("KEF", .rosette), ("JFK", .round), ("NRT", .octagon), ("DXB", .oval), ("HEL", .rosette),
    ]

    /// First landing per stamped country (oldest first), from the saved flights and `AppModel.stamps`.
    @MainActor static func live(_ model: AppModel) -> PassportContent {
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US"); df.dateFormat = "dd MMM yyyy"
        let stamped = Set(model.stamps)
        var seen = Set<String>(), entries: [PassportEntry] = []
        let landed = model.walletFlights.filter { $0.endedAt != nil && $0.destinationIata != nil }
            .sorted { ($0.endedAt ?? .distantPast) < ($1.endedAt ?? .distantPast) }
        for f in landed {
            guard let iata = f.destinationIata, let ap = model.airport(iata), stamped.contains(ap.countryCode), !seen.contains(ap.countryCode) else { continue }
            seen.insert(ap.countryCode)
            let i = entries.count
            entries.append(PassportEntry(idx: i, code: ap.iata, cc: ap.countryCode, country: name(ap, model), date: df.string(from: f.endedAt ?? .now),
                                         scenario: f.scenarioID, shape: shapes[i % shapes.count]))
        }
        let airports = Set(landed.compactMap(\.destinationIata)).count
        let locks: [PassportLock] = candidateLocks.compactMap { code, shape in
            guard let ap = model.airport(code), !seen.contains(ap.countryCode) else { return nil }
            return PassportLock(code: code, cc: ap.countryCode, country: name(ap, model), shape: shape)
        }
        return PassportContent(entries: entries, locks: locks, countries: seen.count, airports: airports, stamps: entries.count,
                               memberNumber: CardsContent.memberNumber(for: NSFullUserName().isEmpty ? "You" : NSFullUserName()),
                               newest: nil)
    }

    private static func name(_ ap: Airport, _ model: AppModel) -> String {
        countryNames[ap.countryCode] ?? ap.countryName(locale: Locale(identifier: "en_US")) ?? ap.countryCode
    }
}

private struct PassportFixtureKey: EnvironmentKey { static let defaultValue: PassportContent? = nil }
private struct PassportStartKey: EnvironmentKey { static let defaultValue = PassportStart() }

/// Initial filter/spread/animation of a passport (the canvas screen props).
struct PassportStart: Equatable {
    var year = "all"
    var scenario = "all"
    var spread = 0
    var animIndex = -1
}

extension EnvironmentValues {
    var passportFixture: PassportContent? {
        get { self[PassportFixtureKey.self] }
        set { self[PassportFixtureKey.self] = newValue }
    }
    var passportStart: PassportStart {
        get { self[PassportStartKey.self] }
        set { self[PassportStartKey.self] = newValue }
    }
}

/// Stamp ink per scenario (`INK` in Passport.dc.html).
enum PassportInk {
    static func color(_ scenario: String) -> Color {
        switch scenario {
        case "study": mrHex("#243F8F")
        case "work": mrHex("#8C4B08")
        case "read": mrHex("#08613F")
        case "create": mrHex("#A82A24")
        case "code": mrHex("#4B2FA0")
        case "meditate": mrHex("#0C6A74")
        case "fitness": mrHex("#B0401F")
        default: mrHex("#4A5163")
        }
    }
}

/// One stamp placed on a page.
struct PlacedStamp: Identifiable {
    var id: Int
    var shape: StampShape, country: String, cc: String, code: String, date: String
    var ink: Color, rot: Double, seed: UInt32, size: CGFloat
    var locked: Bool, anim: Bool, tip: String
    var x: CGFloat, y: CGFloat, h: CGFloat
}

struct PageModel {
    var stamps: [PlacedStamp]
    var tl: String, tr: String, bl: String, br: String
    var hasHeading: Bool
    var number: Int
    var side: PassportBook.Side
}

/// Filtering and paging (`Passport.dc.html data()` / `page()`).
struct PassportLayout {
    let content: PassportContent
    let year: String
    let scenario: String
    static let perSpread = 12

    var filtered: [PassportEntry] {
        content.entries.filter { (year == "all" || $0.date.hasSuffix(year)) && (scenario == "all" || $0.scenario == scenario) }
    }
    var isUnfiltered: Bool { year == "all" && scenario == "all" }
    var spreadCount: Int { filtered.count > Self.perSpread ? Int((Double(filtered.count) / Double(Self.perSpread)).rounded(.up)) : 1 }

    private static let slots: [(CGFloat, CGFloat)] = [(76, 138), (256, 143), (64, 302), (258, 307), (74, 462), (254, 470)]

    func page(spread: Int, side: PassportBook.Side, animIndex: Int) -> PageModel {
        enum Item { case entry(PassportEntry), lock(PassportLock) }
        let all = filtered
        let lo = min(all.count, spread * Self.perSpread), hi = min(all.count, lo + Self.perSpread)
        var items: [Item] = all[lo..<hi].map { .entry($0) }
        var li = 0
        while items.count < Self.perSpread, isUnfiltered, li < content.locks.count { items.append(.lock(content.locks[li])); li += 1 }
        let pick = side == .left ? Array(items.prefix(6)) : Array(items.dropFirst(6).prefix(6))
        let stamps: [PlacedStamp] = pick.enumerated().map { n, it in
            let code: String, cc: String, country: String, date: String, shape: StampShape, scenarioID: String, locked: Bool, idx: Int
            switch it {
            case .entry(let e): (code, cc, country, date, shape, scenarioID, locked, idx) = (e.code, e.cc, e.country, e.date, e.shape, e.scenario, false, e.idx)
            case .lock(let l): (code, cc, country, date, shape, scenarioID, locked, idx) = (l.code, l.cc, l.country, "", l.shape, "other", true, -1)
            }
            let h = PaperHash.fnv1a(code + (date.isEmpty ? "x" : date))
            let rot = Double(Int(h % 25) - 12)
            let hh = (150 * (shape == .oval ? 0.725 : shape == .octagon ? 0.775 : 1)).rounded()
            let jx = CGFloat(Int((h >> 3) % 15) - 7), jy = CGFloat(Int((h >> 6) % 13) - 6)
            let sl = Self.slots[n]
            let scName = PlanKit.scenario(scenarioID).label
            return PlacedStamp(id: n, shape: shape, country: country, cc: cc, code: code, date: date, ink: PassportInk.color(scenarioID),
                               rot: rot, seed: (h % 13) + 2, size: 150, locked: locked, anim: idx == animIndex && animIndex >= 0,
                               tip: locked ? "Not yet visited" : "\(country) · \(code) · \(date) · \(scName)",
                               x: sl.0 + jx - 10, y: sl.1 + jy - CGFloat(hh) / 2 + 14, h: CGFloat(hh))
        }
        let no = spread * 2 + (side == .left ? 14 : 15)
        let scLabel = scenario == "all" ? "All scenarios" : PlanKit.scenario(scenario).label
        if side == .left {
            return PageModel(stamps: stamps, tl: "Meridian · Passport", tr: "No. \(content.memberNumber)", bl: "Page \(no)",
                             br: isUnfiltered ? "\(content.countries) countries" : "\(all.count) shown", hasHeading: true, number: no, side: side)
        }
        return PageModel(stamps: stamps, tl: "\(year == "all" ? "All years" : year) · \(scLabel)", tr: "Visas", bl: "Page \(no)",
                         br: isUnfiltered ? "\(content.airports) airports" : (year == "all" ? "" : year), hasHeading: false, number: no, side: side)
    }
}
