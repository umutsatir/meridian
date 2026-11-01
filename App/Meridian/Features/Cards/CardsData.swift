import AppKit
import MeridianCore
import MeridianUI
import SwiftUI

typealias UITier = MeridianUI.MembershipTier
typealias CoreTier = MeridianCore.MembershipTier

extension UITier {
    /// The design-system tier for a domain tier (same order).
    init(core: CoreTier) { self = UITier.allCases[CoreTier.allCases.firstIndex(of: core) ?? 0] }

    /// Highlight color of the progress bar and the screen glow (`TINT` in CardsScreen.dc.html).
    var tintHex: String {
        switch self {
        case .departure, .cruise: "#6AB7FF"
        case .jetstream: "#8BF3D8"
        case .gold: "#FFE9A8"
        case .equator: "#FFFFFF"
        case .obsidian: "#B49CFF"
        }
    }
    var index: Int { UITier.allCases.firstIndex(of: self) ?? 0 }
}

/// What the Cards screen shows about the member. Real values come from `AppModel`; the debug routes pass the
/// canvas persona (`K.me`) as a fixture.
struct CardsContent: Equatable {
    var km: Double
    var name: String
    var joined: String        // "Mar 2025"
    var daysFlown: Int
    var memberNumber: String
    var flights: Int
    var hours: String         // "94.5"
    /// Canvas `index` prop (fixtures); nil selects the highest unlocked tier.
    var startIndex: Int? = nil

    var info: MembershipCardInfo {
        MembershipCardInfo(memberName: name, memberNumber: memberNumber, since: joined.uppercased(),
                           distanceKm: Int(km.rounded()), flights: flights, hours: hours)
    }

    /// The canvas persona (DEBUG routes only).
    static let fixture = CardsContent(km: 12022, name: "Elif Kaya", joined: "Mar 2025", daysFlown: 365,
                                      memberNumber: "0048 1317 2204", flights: 87, hours: "94.5", startIndex: 3)

    @MainActor static func live(_ model: AppModel) -> CardsContent {
        let name = NSFullUserName().isEmpty ? "You" : NSFullUserName()
        let flights = model.walletFlights
        let cal = Calendar.current
        let days = Set(flights.compactMap { $0.endedAt }.map { cal.startOfDay(for: $0) }).count
        let first = flights.compactMap { $0.startedAt }.min() ?? .now
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US"); f.dateFormat = "MMM yyyy"
        let focused = flights.reduce(0.0) { $0 + ($1.finalFocusedSec ?? 0) } / 3600
        return CardsContent(km: model.totalKm, name: name, joined: f.string(from: first), daysFlown: days,
                            memberNumber: memberNumber(for: name), flights: flights.count,
                            hours: String(format: "%.1f", focused))
    }

    /// A stable 12-digit number per member name, printed `0000 0000 0000`.
    static func memberNumber(for name: String) -> String {
        var h = UInt64(PaperHash.fnv1a(name)) &* 2_654_435_761 &+ 4_813_172_204
        var groups: [String] = []
        for _ in 0..<3 { groups.append(String(format: "%04d", Int(h % 10_000))); h /= 10_000; h = h &* 7 &+ 13 }
        return groups.joined(separator: " ")
    }
}

private struct CardsFixtureKey: EnvironmentKey { static let defaultValue: CardsContent? = nil }
extension EnvironmentValues {
    /// DEBUG routes: draws the canvas persona instead of the saved data.
    var cardsFixture: CardsContent? {
        get { self[CardsFixtureKey.self] }
        set { self[CardsFixtureKey.self] = newValue }
    }
}

/// `#RRGGBB` token color.
func mrHex(_ s: String) -> Color { MRColorToken(s).color }
