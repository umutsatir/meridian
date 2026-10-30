import Foundation

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Seeded jagged edge for tickets: the same seed always yields the same tear (PRD COL-1).
public enum TornEdge {
    /// `count` offsets in -1...1.
    public static func offsets(seed: UInt64, count: Int) -> [Double] {
        guard count > 0 else { return [] }
        var rng = SeededGenerator(seed: seed ^ 0xA5A5_5A5A_1234_4321)
        return (0..<count).map { _ in Double.random(in: -1...1, using: &rng) }
    }

    /// Deterministic 0/1 bar widths for the decorative barcode, 1...4 units each.
    public static func barWidths(seed: UInt64, count: Int) -> [Int] {
        var rng = SeededGenerator(seed: seed ^ 0x0BAD_C0DE_F00D_1234)
        return (0..<max(0, count)).map { _ in Int.random(in: 1...4, using: &rng) }
    }
}
