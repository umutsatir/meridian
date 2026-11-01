import Foundation
import MeridianCore
import MeridianMaps
import MeridianUI
import SwiftUI

// MARK: - Scenario table (meridian-kit.js `K.scenarios`)

struct ExScenario {
    let id: String, name: String, hex: String, icon: MRIconName
    var color: Color { MRColorToken(hex).color }
}

enum ExScn {
    static let table: [String: ExScenario] = [
        "study": .init(id: "study", name: "Study", hex: "#7AA2FF", icon: .cap),
        "work": .init(id: "work", name: "Work", hex: "#FFB86B", icon: .briefcase),
        "read": .init(id: "read", name: "Read", hex: "#7ADDB2", icon: .book),
        "create": .init(id: "create", name: "Create", hex: "#FF8FB1", icon: .spark),
        "code": .init(id: "code", name: "Coding", hex: "#B49CFF", icon: .code),
        "meditate": .init(id: "meditate", name: "Meditate", hex: "#8EE3E8", icon: .lotus),
        "fitness": .init(id: "fitness", name: "Fitness", hex: "#FF9B7A", icon: .dumbbell),
        "other": .init(id: "other", name: "Other", hex: "#C7CCDA", icon: .dot),
    ]
    static func get(_ id: String) -> ExScenario { table[id] ?? table["other"]! }
    /// Legend order of the world map (`Object.keys(K.scenarios)` without `other`).
    static let legend = ["study", "work", "read", "create", "code", "meditate", "fitness"]
}

// MARK: - Seeded generator (`K.rng`, mulberry32)

struct ExRNG {
    private var a: UInt32
    init(_ seed: Int) { a = UInt32(truncatingIfNeeded: seed) }
    mutating func next() -> Double {
        a = a &+ 0x6D2B_79F5
        var t = (a ^ (a >> 15)) &* (1 | a)
        t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
        return Double(t ^ (t >> 14)) / 4_294_967_296
    }
}

// MARK: - Formatting

enum ExFmt {
    /// Stats.dc.html `fmtH`: "42 min", "1 h 07 min", "2 h ".
    static func hours(_ h: Double) -> String {
        let m = Int((h * 60).rounded())
        if m >= 60 { return "\(m / 60) h " + (m % 60 != 0 ? String(format: "%02d", m % 60) + " min" : "") }
        return "\(m) min"
    }
    /// `K.fmtKm`: grouped with commas.
    static func km(_ v: Double) -> String {
        let n = Int(v.rounded())
        let s = String(abs(n))
        var out = ""
        for (i, ch) in s.reversed().enumerated() { if i > 0 && i % 3 == 0 { out.append(",") }; out.append(ch) }
        return (n < 0 ? "-" : "") + String(out.reversed())
    }
    static func oneDecimal(_ v: Double) -> String { String(format: "%.1f", v) }
}

// MARK: - Model

enum ExPeriod: String, CaseIterable, Hashable { case day, week, month, year
    var title: String { rawValue.capitalized }
}

struct ExBar {
    var xLabel: String
    var title: String
    var hours: Double
    var segs: [(scn: String, hours: Double)]
}

struct ExBarSeries {
    var bars: [ExBar]
    var goal: Double
    var step: Double
    var selected: Int
    var yUnitIsMinutes: Bool
    var barWidthCap: Double
}

struct ExReplayRoute {
    var a: String, b: String
    var count: Int
    /// Position on the replay timeline, 0...1.
    var t: Double
    var scenario: String
}

struct ExHeatCell { var week: Int, day: Int, level: Int, tip: String }

struct ExLongest { var from: String, to: String, km: Double, durationMin: Int, dateLabel: String, fromCity: String, toCity: String, weekdayDate: String }

/// Everything the Map, Stats and Year-in-flight screens show. `ExploreData.design` is the canvas' sample persona
/// (debug / preview fixture only); `ExploreData.real(...)` is derived from the user's landed flights.
struct ExploreData {
    var isFixture = false
    var name = ""
    var year = 2026
    var flights = 0
    var hours = 0.0
    var km = 0.0
    var countries = 0
    var airports = 0
    var streak = 0
    var bestStreak = 0
    var thisWeekFlights = 0
    var hoursDeltaLabel = ""
    var dailyDoneHours = 0.0
    var dailyGoalHours = 3.0
    /// 7 entries Mon...Sun: 0 future, 1 done, 2 today.
    var weekDots: [Int] = Array(repeating: 0, count: 7)
    var series: [ExPeriod: ExBarSeries] = [:]
    var heat: [ExHeatCell] = []
    var heatWeeks = 26
    var heatMonths: [String] = []
    var topScenarios: [(id: String, hours: Double)] = []
    var longest: ExLongest?
    var topAirports: [(code: String, visits: Int)] = []
    var routes: [ExReplayRoute] = []
    var replayStart = (year: 2025, month: 2)
    var replayMonths = 20
    var replayStartLabel = "Mar 2025"
    var replayEndLabel = "Oct 2026"
    var avgMinutes = 0
    var favourite: (id: String, flights: Int, pct: Int)?
    var mix: [(id: String, count: Int)] = []
    var busiest: (title: String, line: String)?
    var tierName = "Departure"
    var nextTierName: String?
    var nextTierKm: Double = 0
    var nextTierRemaining: Double = 0
    var heatBusyDays: [Double] = []

    var isEmpty: Bool { flights == 0 }
    var aroundEarth: Double { km / 40_075 }
    var topAirportMax: Int { topAirports.first?.visits ?? 1 }

    func flightsAt(_ t: Double) -> Int {
        if isFixture { return Int((Double(flights) * t).rounded()) }
        return routes.filter { $0.t <= t + 1e-6 }.reduce(0) { $0 + $1.count }
    }
    func monthLabel(_ t: Double) -> String {
        let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let m = min(replayMonths - 1, Int(t * (Double(replayMonths) - 0.001)))
        let mi = (replayStart.month + m) % 12, yr = replayStart.year + (replayStart.month + m) / 12
        return "\(names[mi]) \(yr)"
    }
}

// MARK: - Design fixture (canvas sample persona; debug routes and previews only)

extension ExploreData {
    private static func split(_ total: Double, seed: Int) -> [(scn: String, hours: Double)] {
        var r = ExRNG(seed)
        let keys = ["code", "work", "study", "read", "create"]
        let w = keys.map { _ in 0.2 + r.next() }
        let sw = w.reduce(0, +)
        return keys.enumerated().map { ($1, total * w[$0] / sw) }
    }

    static let design: ExploreData = {
        var d = ExploreData()
        d.isFixture = true
        d.name = "Elif Kaya"
        d.flights = 87; d.hours = 94.5; d.km = 12_022; d.countries = 19; d.airports = 41
        d.streak = 12; d.bestStreak = 31; d.thisWeekFlights = 5
        d.hoursDeltaLabel = "+6.2 h vs last month"
        d.dailyDoneHours = 1 + 52.0 / 60
        d.weekDots = [1, 1, 1, 1, 2, 0, 0]
        let full = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

        for per in ExPeriod.allCases {
            var rr = ExRNG(per == .week ? 5 : per == .month ? 11 : per == .year ? 23 : 31)
            var tot: [Double] = [], lab: [String] = []
            var sel = -1
            var goal = per == .day ? 0.5 : per == .week ? 3 : per == .month ? 3 : 90.0 / 12
            switch per {
            case .week:
                tot = [2.4, 3.1, 1.8, 4.2, 2.9, 1.1, 0.6]; lab = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]; sel = 3
            case .month:
                for i in 1...29 {
                    let wd = (i + 3) % 7
                    tot.append(wd >= 5 ? 0.4 + rr.next() * 1.4 : 1.4 + rr.next() * 3.4)
                    lab.append(i % 7 == 1 ? String(i) : "")
                }
                sel = 28
            case .year:
                tot = [14, 18, 22, 26, 31, 29, 24, 27, 33, 38, 8, 0]; lab = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]; sel = 9; goal = 30
            case .day:
                for i in 0..<24 {
                    let v: Double
                    if i >= 9 && i <= 11 { v = 0.5 + rr.next() * 0.5 }
                    else if i >= 14 && i <= 16 { v = 0.3 + rr.next() * 0.6 }
                    else if i >= 20 && i <= 21 { v = 0.15 + rr.next() * 0.3 }
                    else if rr.next() < 0.15 { v = rr.next() * 0.2 }
                    else { v = 0 }
                    tot.append(v); lab.append(i % 6 == 0 ? String(format: "%02d", i) : "")
                }
                sel = 10
            }
            let seedAdd = per.rawValue.count * 7
            let bars: [ExBar] = tot.enumerated().map { i, v in
                let title: String
                switch per {
                case .week: title = lab[i] + " 26 Oct"
                case .year: title = full[i]
                case .month: title = "Oct \(i + 1)"
                case .day: title = String(format: "%02d:00", i)
                }
                return ExBar(xLabel: lab[i], title: title, hours: v, segs: split(v, seed: i * 13 + seedAdd))
            }
            d.series[per] = ExBarSeries(bars: bars, goal: goal, step: per == .year ? 10 : per == .day ? 0.5 : 1, selected: sel,
                                        yUnitIsMinutes: per == .day, barWidthCap: per == .year ? 34 : per == .month ? 12 : per == .week ? 40 : 14)
        }

        // heat map (rng 77)
        var r = ExRNG(77)
        let weeks = 26
        for w in 0..<weeks {
            for dd in 0..<7 {
                let wk = dd >= 5, base = wk ? 0.25 : 0.72
                let v: Double = r.next() < (wk ? 0.5 : 0.12) ? 0 : base * r.next() * (1 + Double(w) / Double(weeks) * 0.6)
                let lvl = v == 0 ? 0 : v < 0.22 ? 1 : v < 0.42 ? 2 : v < 0.62 ? 3 : 4
                if w == weeks - 1 && dd > 3 { continue }
                let day = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][dd]
                let tip = day + " · " + (lvl == 0 ? "No flights" : ExFmt.hours(Double(lvl) * 0.75 + r.next() * 0.4))
                d.heat.append(ExHeatCell(week: w, day: dd, level: lvl, tip: tip))
            }
        }
        let MN = ["May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec", "Jan", "Feb", "Mar", "Apr"]
        d.heatMonths = stride(from: 0, to: weeks, by: 4).map { MN[Int((Double($0) / 4.33).rounded()) % 12] }

        d.topScenarios = [("code", 31.2), ("work", 24.5), ("study", 17.8), ("read", 12.6), ("create", 8.4)]
        d.longest = ExLongest(from: "FRA", to: "IST", km: 1838, durationMin: 157, dateLabel: "18 Sep", fromCity: "Frankfurt", toCity: "Istanbul", weekdayDate: "Fri 18 Sep")
        d.topAirports = [("LHR", 38), ("CDG", 17), ("AMS", 12), ("IST", 10), ("JFK", 8), ("FRA", 7), ("DUB", 7), ("MAD", 5)]
        let R: [(String, String, Int, Double, String)] = [("LHR", "CDG", 14, 0.04, "code"), ("LHR", "AMS", 9, 0.10, "work"), ("LHR", "DUB", 6, 0.22, "read"), ("LHR", "FRA", 5, 0.30, "work"), ("LHR", "IST", 4, 0.38, "study"), ("LHR", "MAD", 3, 0.46, "code"), ("LHR", "CAI", 2, 0.55, "read"), ("LHR", "JFK", 3, 0.60, "work"), ("LHR", "DXB", 2, 0.66, "create"), ("IST", "ESB", 3, 0.40, "create"), ("ESB", "ADB", 2, 0.44, "meditate"), ("FRA", "IST", 2, 0.48, "work"), ("JFK", "BOS", 4, 0.64, "work"), ("BOS", "YYZ", 2, 0.70, "study"), ("YYZ", "SFO", 2, 0.76, "create"), ("SIN", "SYD", 1, 0.82, "study"), ("DXB", "DOH", 2, 0.88, "fitness"), ("AMS", "BCN", 2, 0.93, "code")]
        d.routes = R.map { ExReplayRoute(a: $0.0, b: $0.1, count: $0.2, t: $0.3, scenario: $0.4) }
        d.avgMinutes = 65
        d.favourite = ("code", 31, 34)
        d.mix = [("code", 31), ("work", 22), ("study", 15), ("read", 11), ("create", 5), ("meditate", 3)]
        d.busiest = ("Tuesday, 14 April.", "4 flights and 3 h 10 min without a break longer than a coffee.")
        d.tierName = "Jetstream"; d.nextTierName = "Meridian Gold"; d.nextTierKm = 20_000; d.nextTierRemaining = 7_978
        return d
    }()
}

// MARK: - Real data

extension ExploreData {
    /// Derives the screens' data from landed flights (newest first, as `AppModel.walletFlights`).
    static func real(flights all: [Flight], totalKm: Double, streak: Int, stamps: [String], index: AirportIndex?, name: String, now: Date = .now) -> ExploreData {
        var d = ExploreData()
        let fl = all.filter { $0.isFinished && $0.startedAt != nil }
        let cal = Calendar.current
        d.name = name
        d.year = cal.component(.year, from: now)
        d.flights = fl.count
        d.km = totalKm
        d.streak = streak
        d.bestStreak = max(streak, bestStreak(fl, cal))
        func hrs(_ f: Flight) -> Double { (f.finalFocusedSec ?? 0) / 3600 }
        d.hours = fl.reduce(0) { $0 + hrs($1) }
        var codes = Set<String>()
        for f in fl { codes.insert(f.originIata); if let x = f.destinationIata { codes.insert(x) } }
        d.airports = codes.count
        let cc = Set(codes.compactMap { index?.airport(iata: $0)?.countryCode })
        d.countries = max(stamps.count, cc.count)
        d.avgMinutes = fl.isEmpty ? 0 : Int((d.hours * 60 / Double(fl.count)).rounded())
        do {
            d.tierName = tierLabel(MeridianCore.MembershipTier.tier(forKm: totalKm))
            if let next = MeridianCore.MembershipTier.allCases.first(where: { $0.thresholdKm > totalKm }) {
                d.nextTierName = tierLabel(next); d.nextTierKm = next.thresholdKm; d.nextTierRemaining = next.thresholdKm - totalKm
            }
        }
        if let wk = cal.dateInterval(of: .weekOfYear, for: now) { d.thisWeekFlights = fl.filter { wk.contains($0.startedAt!) }.count }
        // month delta
        if let mi = cal.dateInterval(of: .month, for: now), let prev = cal.date(byAdding: .month, value: -1, to: now), let pi = cal.dateInterval(of: .month, for: prev) {
            let a = fl.filter { mi.contains($0.startedAt!) }.reduce(0) { $0 + hrs($1) }
            let b = fl.filter { pi.contains($0.startedAt!) }.reduce(0) { $0 + hrs($1) }
            let diff = a - b
            d.hoursDeltaLabel = String(format: "%@%.1f h vs last month", diff >= 0 ? "+" : "-", abs(diff))
        }
        // today
        let today = fl.filter { cal.isDate($0.startedAt!, inSameDayAs: now) }.reduce(0) { $0 + hrs($1) }
        d.dailyDoneHours = today
        // week dots
        let wd = (cal.component(.weekday, from: now) + 5) % 7   // Mon = 0
        for i in 0..<7 {
            if i > wd { d.weekDots[i] = 0 } else if i == wd { d.weekDots[i] = 2 } else {
                let day = cal.date(byAdding: .day, value: i - wd, to: now)!
                d.weekDots[i] = fl.contains { cal.isDate($0.startedAt!, inSameDayAs: day) } ? 1 : 0
            }
        }
        // bars
        func segs(_ list: [Flight]) -> [(scn: String, hours: Double)] {
            var m: [String: Double] = [:]
            for f in list { m[f.scenarioID, default: 0] += hrs(f) }
            return m.keys.sorted().map { (scn: $0, hours: m[$0]!) }.filter { $0.hours > 0 }
        }
        func bar(_ x: String, _ title: String, _ list: [Flight]) -> ExBar {
            ExBar(xLabel: x, title: title, hours: list.reduce(0) { $0 + hrs($1) }, segs: segs(list))
        }
        let df = DateFormatter(); df.dateFormat = "EEE d MMM"
        let dMonth = DateFormatter(); dMonth.dateFormat = "MMM d"
        let wdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        if let wk = cal.dateInterval(of: .weekOfYear, for: now) {
            let start = cal.date(byAdding: .day, value: -wd, to: cal.startOfDay(for: now)) ?? wk.start
            var bars: [ExBar] = []
            for i in 0..<7 {
                let day = cal.date(byAdding: .day, value: i, to: start)!
                bars.append(bar(wdays[i], df.string(from: day), fl.filter { cal.isDate($0.startedAt!, inSameDayAs: day) }))
            }
            d.series[.week] = ExBarSeries(bars: bars, goal: d.dailyGoalHours, step: 1, selected: wd, yUnitIsMinutes: false, barWidthCap: 40)
        }
        let days = cal.range(of: .day, in: .month, for: now)?.count ?? 30
        let ms = cal.dateInterval(of: .month, for: now)!.start
        var mbars: [ExBar] = []
        for i in 0..<days {
            let day = cal.date(byAdding: .day, value: i, to: ms)!
            mbars.append(bar((i + 1) % 7 == 1 ? String(i + 1) : "", dMonth.string(from: day), fl.filter { cal.isDate($0.startedAt!, inSameDayAs: day) }))
        }
        d.series[.month] = ExBarSeries(bars: mbars, goal: d.dailyGoalHours, step: 1, selected: cal.component(.day, from: now) - 1, yUnitIsMinutes: false, barWidthCap: 12)
        let months = cal.monthSymbols
        var ybars: [ExBar] = []
        for m in 0..<12 {
            let list = fl.filter { cal.component(.year, from: $0.startedAt!) == d.year && cal.component(.month, from: $0.startedAt!) == m + 1 }
            ybars.append(bar(String(months[m].prefix(1)), months[m], list))
        }
        d.series[.year] = ExBarSeries(bars: ybars, goal: 30, step: 10, selected: cal.component(.month, from: now) - 1, yUnitIsMinutes: false, barWidthCap: 34)
        var dbars: [ExBar] = []
        for h in 0..<24 {
            let list = fl.filter { cal.isDate($0.startedAt!, inSameDayAs: now) && cal.component(.hour, from: $0.startedAt!) == h }
            dbars.append(bar(h % 6 == 0 ? String(format: "%02d", h) : "", String(format: "%02d:00", h), list))
        }
        d.series[.day] = ExBarSeries(bars: dbars, goal: 0.5, step: 0.5, selected: cal.component(.hour, from: now), yUnitIsMinutes: true, barWidthCap: 14)

        // heat: last 26 weeks, weeks start Monday, last column ends today
        let weeks = 26
        let thisMonday = cal.date(byAdding: .day, value: -wd, to: cal.startOfDay(for: now))!
        let first = cal.date(byAdding: .weekOfYear, value: -(weeks - 1), to: thisMonday)!
        var perDay: [Date: Double] = [:]
        for f in fl { perDay[cal.startOfDay(for: f.startedAt!), default: 0] += hrs(f) }
        for w in 0..<weeks {
            for dd in 0..<7 {
                if w == weeks - 1 && dd > wd { continue }
                let day = cal.date(byAdding: .day, value: w * 7 + dd, to: first)!
                let v = perDay[day] ?? 0
                let lvl = v == 0 ? 0 : v < 0.75 ? 1 : v < 1.5 ? 2 : v < 2.5 ? 3 : 4
                d.heat.append(ExHeatCell(week: w, day: dd, level: lvl, tip: wdays[dd] + " · " + (lvl == 0 ? "No flights" : ExFmt.hours(v))))
            }
        }
        let ms3 = DateFormatter(); ms3.dateFormat = "MMM"
        d.heatMonths = stride(from: 0, to: weeks, by: 4).map { ms3.string(from: cal.date(byAdding: .weekOfYear, value: $0, to: first)!) }

        // scenarios, longest, airports
        var perScn: [String: (h: Double, n: Int)] = [:]
        for f in fl { var e = perScn[f.scenarioID] ?? (0, 0); e.h += hrs(f); e.n += 1; perScn[f.scenarioID] = e }
        d.topScenarios = perScn.sorted { $0.value.h > $1.value.h }.prefix(5).map { ($0.key, $0.value.h) }
        d.mix = perScn.sorted { $0.value.n > $1.value.n }.prefix(6).map { ($0.key, $0.value.n) }
        if let top = perScn.max(by: { $0.value.n < $1.value.n }) { d.favourite = (top.key, top.value.n, Int((Double(top.value.n) / Double(max(1, fl.count)) * 100).rounded())) }
        if let l = fl.filter({ $0.destinationIata != nil }).max(by: { $0.routeDistanceKm < $1.routeDistanceKm }) {
            let df2 = DateFormatter(); df2.dateFormat = "d MMM"; let df3 = DateFormatter(); df3.dateFormat = "EEE d MMM"
            let dest = l.destinationIata!
            d.longest = ExLongest(from: l.originIata, to: dest, km: l.routeDistanceKm, durationMin: Int(((l.finalFocusedSec ?? 0) / 60).rounded()), dateLabel: df2.string(from: l.startedAt!),
                                  fromCity: index?.airport(iata: l.originIata)?.city ?? l.originIata, toCity: index?.airport(iata: dest)?.city ?? dest, weekdayDate: df3.string(from: l.startedAt!))
        }
        var visits: [String: Int] = [:]
        for f in fl { visits[f.originIata, default: 0] += 1; if let x = f.destinationIata { visits[x, default: 0] += 1 } }
        d.topAirports = visits.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.prefix(8).map { ($0.key, $0.value) }
        // busiest day
        var byDay: [Date: [Flight]] = [:]
        for f in fl { byDay[cal.startOfDay(for: f.startedAt!), default: []].append(f) }
        if let b = byDay.max(by: { $0.value.count < $1.value.count }) {
            let f1 = DateFormatter(); f1.dateFormat = "EEEE, d MMMM"
            let secs = b.value.reduce(0) { $0 + ($1.finalFocusedSec ?? 0) }
            d.busiest = (f1.string(from: b.key) + ".", "\(b.value.count) flights and \(ExFmt.hours(secs / 3600)) in the air.")
        }
        // routes for the replay
        if let firstDate = fl.compactMap(\.startedAt).min(), let lastDate = fl.compactMap(\.startedAt).max() {
            let sm = cal.dateInterval(of: .month, for: firstDate)!.start
            let nm = max(2, (cal.dateComponents([.month], from: sm, to: lastDate).month ?? 0) + 1)
            d.replayStart = (cal.component(.year, from: sm), cal.component(.month, from: sm) - 1)
            d.replayMonths = nm
            let lf = DateFormatter(); lf.dateFormat = "MMM yyyy"
            d.replayStartLabel = lf.string(from: sm)
            d.replayEndLabel = lf.string(from: lastDate)
            let span = Double(nm)
            var agg: [String: ExReplayRoute] = [:]
            for f in fl.sorted(by: { $0.startedAt! < $1.startedAt! }) {
                guard let dest = f.destinationIata else { continue }
                let key = f.originIata + dest
                let mo = Double(cal.dateComponents([.month], from: sm, to: f.startedAt!).month ?? 0)
                if var e = agg[key] { e.count += 1; agg[key] = e } else {
                    agg[key] = ExReplayRoute(a: f.originIata, b: dest, count: 1, t: min(1, mo / span), scenario: f.scenarioID)
                }
            }
            d.routes = agg.values.sorted { $0.t < $1.t }
        }
        return d
    }

    private static func tierLabel(_ t: MeridianCore.MembershipTier) -> String {
        switch t {
        case .departure: "Departure"
        case .cruise: "Cruise"
        case .jetstream: "Jetstream"
        case .meridianGold: "Meridian Gold"
        case .equator: "Equator"
        case .obsidian: "Obsidian"
        }
    }

    private static func bestStreak(_ fl: [Flight], _ cal: Calendar) -> Int {
        let days = Set(fl.map { cal.startOfDay(for: $0.startedAt!) }).sorted()
        var best = 0, run = 0
        var prev: Date?
        for day in days {
            if let p = prev, cal.date(byAdding: .day, value: 1, to: p) == day { run += 1 } else { run = 1 }
            best = max(best, run); prev = day
        }
        return best
    }
}
