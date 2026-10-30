import SwiftUI

/// The canvas split-flap row (`SplitFlap.dc.html`): cells with a two-tone card, hinge and a flipping top and bottom half.
/// Static by default; with `live` the text flips to the new value cell by cell (staggered 40 ms, up to 5 flips per cell,
/// 62 ms per half). Reduce Motion shows the final text immediately.
public struct MRSplitFlapBoard: View {
    public enum Size: Sendable {
        case xs, s, m, l
        /// (cell width, cell height, font size) of the canvas.
        var dims: (w: CGFloat, h: CGFloat, font: CGFloat) {
            switch self { case .xs: (20, 30, 19); case .s: (22, 32, 20); case .m: (30, 44, 30); case .l: (42, 62, 44) }
        }
    }
    public enum Tone: Sendable { case amber, white }

    static let charset: [Character] = Array(" ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789→·:-+/")

    private let text: String
    private let length: Int
    private let size: Size
    private let tone: Tone
    private let live: Bool
    @State private var shown: [Character]
    @State private var next: [Character]
    @State private var flipping: [Bool]
    @State private var tasks: [Task<Void, Never>] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(_ text: String, length: Int = 0, size: Size = .m, tone: Tone = .amber, live: Bool = false) {
        self.text = text; self.size = size; self.tone = tone; self.live = live
        let len = length > 0 ? length : text.count
        self.length = len
        let initial = Self.normalize(live ? "" : text, len)
        _shown = State(initialValue: initial)
        _next = State(initialValue: initial)
        _flipping = State(initialValue: Array(repeating: false, count: len))
    }

    static func normalize(_ text: String, _ len: Int) -> [Character] {
        Array((text.uppercased() + String(repeating: " ", count: len)).prefix(len))
    }

    public var body: some View {
        let d = size.dims
        HStack(spacing: 3) {
            ForEach(0..<length, id: \.self) { i in
                FlapCell(cur: shown[safe: i] ?? " ", nxt: next[safe: i] ?? " ", flipping: flipping[safe: i] ?? false,
                         width: d.w, height: d.h, font: d.font, tone: tone)
            }
        }
        .task(id: "\(text)|\(live)") { await retarget() }
        .onDisappear { tasks.forEach { $0.cancel() } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    @MainActor private func retarget() async {
        let target = Self.normalize(text, length)
        guard live, !reduceMotion else { shown = target; next = target; flipping = Array(repeating: false, count: length); return }
        tasks.forEach { $0.cancel() }
        tasks = (0..<length).map { i in
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(40 * i))
                let from = shown[i], to = target[i]
                let fi = Self.charset.firstIndex(of: from) ?? 0, ti = Self.charset.firstIndex(of: to) ?? 0
                let steps = min(5, max(0, abs(ti - fi) != 0 ? abs(ti - fi) : (from == to ? 0 : 3)))
                for s in 0..<steps {
                    let ch = s == steps - 1 ? to : Self.charset[(fi + 1 + Int.random(in: 0..<30)) % Self.charset.count]
                    next[i] = ch
                    flipping[i] = true
                    try? await Task.sleep(for: .milliseconds(128))
                    if Task.isCancelled { return }
                    shown[i] = ch
                    flipping[i] = false
                    try? await Task.sleep(for: .milliseconds(8))
                }
                shown[i] = to; next[i] = to
            }
        }
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

private struct FlapCell: View {
    let cur: Character
    let nxt: Character
    let flipping: Bool
    let width: CGFloat
    let height: CGFloat
    let font: CGFloat
    let tone: MRSplitFlapBoard.Tone
    @State private var topAngle = 0.0
    @State private var bottomAngle = 90.0

    private var ink: Color { tone == .white ? MRColorToken("#F3F5FA").color : MRColorToken("#FFB547").color }

    private func glyph(_ c: Character) -> some View {
        Text(String(c))
            .font(.mr(.condensed, size: font, weight: 600))
            .tracking(font * 0.02)
            .foregroundStyle(ink)
            .shadow(color: .black.opacity(0.6), radius: 0, y: 1)
            .frame(width: width, height: height)
    }

    private func top(_ c: Character, _ colors: [Color]) -> some View {
        glyph(c).frame(width: width, height: height / 2, alignment: .top).clipped()
            .background(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 5))
    }

    var body: some View {
        let topColors = [MRColorToken("#252932").color, MRColorToken("#171A20").color]
        let botColors = [MRColorToken("#14171C").color, MRColorToken("#0F1115").color]
        let card = RoundedRectangle(cornerRadius: 5, style: .continuous)
        ZStack {
            VStack(spacing: 0) {
                top(nxt, topColors)
                lowerHalf(cur, botColors)
            }
            if flipping {
                VStack(spacing: 0) {
                    top(cur, topColors)
                        .rotation3DEffect(.degrees(topAngle), axis: (1, 0, 0), anchor: .bottom, perspective: 0.35)
                    Color.clear.frame(height: height / 2)
                }
                VStack(spacing: 0) {
                    Color.clear.frame(height: height / 2)
                    lowerHalf(nxt, botColors)
                        .rotation3DEffect(.degrees(bottomAngle), axis: (1, 0, 0), anchor: .top, perspective: 0.35)
                }
            }
            Rectangle().fill(Color(red: 5 / 255, green: 6 / 255, blue: 8 / 255)).frame(height: 2)
                .shadow(color: .white.opacity(0.06), radius: 0, y: 1)
        }
        .frame(width: width, height: height)
        .background(card.fill(MRColorToken("#0D0F13").color))
        .overlay(MRInsetShadow(card, color: .white.opacity(0.04), spread: 1))
        .shadow(color: .white.opacity(0.07), radius: 0, y: 1)
        .shadow(color: .black.opacity(0.45), radius: 4, y: 3)
        .onChange(of: flipping) { _, on in
            guard on else { return }
            topAngle = 0; bottomAngle = 90
            withAnimation(.timingCurve(0.5, 0, 1, 0.6, duration: 0.062)) { topAngle = -90 }
            withAnimation(.timingCurve(0, 0.4, 0.5, 1, duration: 0.062).delay(0.062)) { bottomAngle = 0 }
        }
    }

    /// Bottom half of the card showing the lower half of the glyph.
    private func lowerHalf(_ c: Character, _ colors: [Color]) -> some View {
        glyph(c).frame(width: width, height: height)
            .frame(width: width, height: height / 2, alignment: .bottom)
            .clipped()
            .background(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 5, bottomTrailingRadius: 5, topTrailingRadius: 0))
    }
}

#Preview("MRSplitFlapBoard") {
    VStack(alignment: .leading, spacing: 12) {
        MRSplitFlapBoard("BRUSSELS", length: 12, size: .m)
        MRSplitFlapBoard("BRU · 42M · BE", length: 22, size: .xs, tone: .white)
    }
    .padding(18).background(Color(red: 11 / 255, green: 16 / 255, blue: 32 / 255))
}
