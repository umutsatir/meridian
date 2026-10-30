import Foundation

/// Membership tiers unlocked by cumulative distance (PRD §7.5). Fictional.
public enum MembershipTier: String, Sendable, Codable, CaseIterable, Comparable {
    case departure, cruise, jetstream, meridianGold, equator, obsidian

    public var thresholdKm: Double {
        switch self {
        case .departure: 0
        case .cruise: 1_000
        case .jetstream: 5_000
        case .meridianGold: 20_000
        case .equator: Geo.equatorKm
        case .obsidian: 100_000
        }
    }

    /// Highest tier reached at `totalKm`.
    public static func tier(forKm totalKm: Double) -> MembershipTier {
        allCases.last { totalKm >= $0.thresholdKm } ?? .departure
    }

    /// Tiers newly reached when a landing moves the total from `before` to `after`.
    public static func unlocked(from before: Double, to after: Double) -> [MembershipTier] {
        allCases.filter { before < $0.thresholdKm && after >= $0.thresholdKm }
    }

    public static func < (a: Self, b: Self) -> Bool { a.thresholdKm < b.thresholdKm }
}

/// Deterministic per-flight cosmetics: the same flight always prints the same ticket.
public struct TicketIdentity: Sendable, Hashable {
    public let flightNumber: String
    public let gate: String

    public init(seed: UInt64) {
        var rng = SplitMix64(seed: seed)
        flightNumber = "MR" + String(format: "%04d", Int(rng.next() % 10_000))
        let letters = Array("ABCDEFGHJK")
        gate = "\(letters[Int(rng.next() % UInt64(letters.count))])\(1 + Int(rng.next() % 24))"
    }
}

public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

public enum Streak {
    /// Consecutive days, ending today or yesterday, with at least one landing.
    /// Today with no flight yet does not break a streak.
    public static func current(landingDates: [Date], now: Date, calendar: Calendar = .current) -> Int {
        let days = Set(landingDates.map { calendar.startOfDay(for: $0) })
        var day = calendar.startOfDay(for: now)
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while days.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
}
