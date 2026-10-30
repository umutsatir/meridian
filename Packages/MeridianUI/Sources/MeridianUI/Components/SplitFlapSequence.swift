import Foundation

/// Frames for a split-flap reveal. Each cell steps forward through the character set
/// and lands on its target; later cells start a little later.
public enum SplitFlapSequence {
    public static let charset: [Character] = Array(" ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-:")
    /// A cell flips through at most this many characters before landing.
    public static let maxFlipsPerCell = 12
    public static let staggerFrames = 2

    /// Uppercases, maps unknown characters to space, then pads or truncates to `count`.
    public static func normalize(_ text: String, count: Int) -> String {
        let mapped = text.uppercased().map { charset.contains($0) ? $0 : " " }
        return String((mapped + Array(repeating: " ", count: max(0, count))).prefix(count))
    }

    /// All intermediate frames, ending with the target. Empty when nothing changes.
    public static func frames(from: String, to: String) -> [String] {
        let count = max(from.count, to.count)
        let start = Array(normalize(from, count: count)), end = Array(normalize(to, count: count))
        let n = charset.count
        let steps: [Int] = (0..<count).map { i in
            guard start[i] != end[i], let c = charset.firstIndex(of: start[i]), let t = charset.firstIndex(of: end[i]) else { return 0 }
            return min(maxFlipsPerCell, (t - c + n) % n)
        }
        let totalFrames = (0..<count).map { steps[$0] == 0 ? 0 : $0 * staggerFrames + steps[$0] }.max() ?? 0
        guard totalFrames > 0 else { return [] }
        return (1...totalFrames).map { frame in
            String((0..<count).map { i -> Character in
                guard steps[i] > 0, let t = charset.firstIndex(of: end[i]) else { return end[i] }
                let done = min(steps[i], max(0, frame - i * staggerFrames))
                if done == 0 { return start[i] }
                return charset[(t - steps[i] + done + n) % n]
            })
        }
    }
}
