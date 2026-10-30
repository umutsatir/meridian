import MeridianUI
import Foundation
import MeridianCore
import MeridianMaps
import SwiftUI

/// The canvas kit (`meridian-kit.js`) data the Plan screens use: the curated airport list in canvas order, country
/// names, flag stripes and scenario icons. Exported by `Scripts/export-plan-kit.js` into `plan-kit.json`.
enum PlanKit {
    private struct Raw: Decodable {
        struct A: Decodable { var iata, city, name, cc: String; var lat, lon: Double }
        var airports: [A]
        var countries: [String: String]
        var flags: [String: [String]]
        var scenarios: [String: [String]]
    }

    private static let raw: Raw = {
        guard let url = Bundle.main.url(forResource: "plan-kit", withExtension: "json"),
              let data = try? Data(contentsOf: url), let raw = try? JSONDecoder().decode(Raw.self, from: data)
        else { return Raw(airports: [], countries: [:], flags: [:], scenarios: [:]) }
        return raw
    }()

    private static func continent(_ cc: String) -> Continent {
        switch cc {
        case "US", "CA": .northAmerica
        case "BR": .southAmerica
        case "AU": .oceania
        case "JP", "SG", "AE", "QA": .asia
        case "EG", "MA": .africa
        default: .europe
        }
    }

    /// Airports with the canvas' clean city names, in canvas order (ties in the candidate rule depend on it).
    static let airports: [Airport] = raw.airports.map {
        Airport(iata: $0.iata, name: $0.name, city: $0.city, countryCode: $0.cc, continent: continent($0.cc),
                coordinate: Coordinate(latitude: $0.lat, longitude: $0.lon))
    }

    static let index = AirportIndex(airports: airports)

    static func countryName(_ cc: String) -> String { raw.countries[cc] ?? cc }

    /// `K.fmtDur`
    static func fmtDur(_ minutes: Double) -> String {
        let m = Int(minutes.rounded())
        if m < 60 { return "\(m) min" }
        let h = m / 60, r = m % 60
        return r > 0 ? "\(h)h \(r)m" : "\(h)h"
    }

    /// `K.fmtShort`
    static func fmtShort(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let h = minutes / 60, r = minutes % 60
        return r > 0 ? "\(h)h \(r)m" : "\(h)h"
    }

    static func fmtKm(_ km: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal; f.groupingSeparator = ","; f.usesGroupingSeparator = true
        return f.string(from: NSNumber(value: Int(km.rounded()))) ?? "\(Int(km))"
    }

    /// Scenario `(label, hex, icon)` by id, from the kit's `SC` table.
    static func scenario(_ id: String) -> (label: String, hex: String, icon: String) {
        let s = raw.scenarios[id] ?? raw.scenarios["code"] ?? ["Coding", "#B49CFF", "code"]
        return (s[0], s[1], s[2])
    }

    static let scenarioOrder = ["study", "work", "read", "create", "code", "meditate", "fitness", "other"]

    /// Canvas distance: the fixed demo value for LHR-CDG, great circle otherwise.
    static func km(_ a: Airport, _ b: Airport) -> Double {
        if (a.iata == "LHR" && b.iata == "CDG") || (a.iata == "CDG" && b.iata == "LHR") { return 348 }
        return Geo.distanceKm(from: a.coordinate, to: b.coordinate)
    }

    /// `flagBg(cc)` as stripes (colors top to bottom, or left to right when `vertical`), or a plain color.
    static func flagStripes(_ cc: String) -> (colors: [Color], vertical: Bool) {
        guard let f = raw.flags[cc], f.count >= 2 else { return ([Color(RGB(hex: "#6B7592"))], false) }
        if f[0] == "s" { return ([Color(RGB(hex: f[1]))], false) }
        return ([Color(RGB(hex: f[1])), Color(RGB(hex: f[2])), Color(RGB(hex: f[3]))], f[0] == "v")
    }

    /// Great-circle points `K.arc` (lat, lon).
    static func arc(_ p: Coordinate, _ q: Coordinate, n: Int = 56) -> [Coordinate] {
        let r = Double.pi / 180
        let p1 = p.latitude * r, l1 = p.longitude * r, p2 = q.latitude * r, l2 = q.longitude * r
        let d = 2 * asin(sqrt(pow(sin((p2 - p1) / 2), 2) + cos(p1) * cos(p2) * pow(sin((l2 - l1) / 2), 2)))
        if d < 1e-6 { return [p] }
        return (0...n).map { i in
            let f = Double(i) / Double(n)
            let a = sin((1 - f) * d) / sin(d), b = sin(f * d) / sin(d)
            let x = a * cos(p1) * cos(l1) + b * cos(p2) * cos(l2)
            let y = a * cos(p1) * sin(l1) + b * cos(p2) * sin(l2)
            let z = a * sin(p1) + b * sin(p2)
            return Coordinate(latitude: atan2(z, sqrt(x * x + y * y)) / r, longitude: atan2(y, x) / r)
        }
    }

    /// mulberry32 as in `K.rng`.
    static func rng(_ seed: UInt32) -> () -> Double {
        var a = seed
        return {
            a = a &+ 0x6D2B79F5
            var t = (a ^ (a >> 15)) &* (1 | a)
            t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
            return Double(t ^ (t >> 14)) / 4294967296
        }
    }

    static let visited: [String: String] = ["CDG": "code", "AMS": "work", "DUB": "read", "BRU": "study", "MAN": "create", "EDI": "meditate", "BCN": "code", "LIS": "read"]
}
