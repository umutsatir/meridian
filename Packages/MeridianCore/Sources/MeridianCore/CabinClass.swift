import Foundation

/// Foil edge on the ticket, derived from the planned duration (PRD §7.1).
public enum CabinClass: String, Sendable, Codable, CaseIterable, Comparable {
    case economy, premium, business, first, longHaul

    public init(durationMinutes: Int) {
        switch durationMinutes {
        case ..<45: self = .economy
        case 45..<90: self = .premium
        case 90..<180: self = .business
        case 180..<300: self = .first
        default: self = .longHaul
        }
    }

    private var order: Int { Self.allCases.firstIndex(of: self)! }
    public static func < (a: Self, b: Self) -> Bool { a.order < b.order }
}
