import SwiftUI

/// Departures-board text. Changing `text` flips the cells; with Reduce Motion it just updates.
public struct SplitFlapText: View {
    private let text: String
    private let cellCount: Int
    private let style: MRTextStyle
    @State private var shown: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    /// Longest reveal, in seconds (PRD PLAN-5: ≤ 1.5 s).
    private static let maxDuration = 1.2

    public init(_ text: String, cellCount: Int? = nil, style: MRTextStyle = .title2) {
        self.text = text
        self.cellCount = cellCount ?? text.count
        self.style = style
        _shown = State(initialValue: SplitFlapSequence.normalize(text, count: cellCount ?? text.count))
    }

    public var body: some View {
        let palette = MRPalette.resolve(scheme)
        HStack(spacing: 3) {
            ForEach(Array(shown.enumerated()), id: \.offset) { _, ch in
                Text(String(ch))
                    .mrText(style, .mono)
                    .foregroundStyle(palette.text1.color)
                    .frame(width: style.size * 0.7, height: style.lineHeight + 8)
                    .background(palette.bg2.color, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay {
                        Rectangle().fill(palette.bg0.color.opacity(0.7)).frame(height: 1)
                    }
            }
        }
        .task(id: text) { await reveal() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    @MainActor private func reveal() async {
        let target = SplitFlapSequence.normalize(text, count: cellCount)
        guard !reduceMotion else { shown = target; return }
        let frames = SplitFlapSequence.frames(from: SplitFlapSequence.normalize(shown, count: cellCount), to: target)
        guard !frames.isEmpty else { shown = target; return }
        let interval = min(0.04, Self.maxDuration / Double(frames.count))
        for frame in frames {
            try? await Task.sleep(for: .seconds(interval))
            if Task.isCancelled { return }
            shown = frame
        }
    }
}

#Preview("SplitFlapText") {
    struct Demo: View {
        @State private var city = "PARIS"
        var body: some View {
            VStack(spacing: 16) {
                SplitFlapText(city, cellCount: 8)
                Button("Surprise me") { city = ["TOKYO", "LISBON", "CDG 08:30", "ISTANBUL"].randomElement()! }
                    .buttonStyle(MRButtonStyle(.secondary))
            }
            .padding(32)
            .background(MRPalette.dark.bg0.color)
        }
    }
    return Demo().preferredColorScheme(.dark)
}
