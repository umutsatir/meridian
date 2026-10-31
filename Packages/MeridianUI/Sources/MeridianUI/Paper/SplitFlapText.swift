import SwiftUI

public enum SplitFlapSize: Sendable, CaseIterable {
    case xs, s, m, l
    /// Cell width, height, font size (SplitFlap.dc.html).
    var dims: (w: CGFloat, h: CGFloat, font: CGFloat) {
        switch self {
        case .xs: (20, 30, 19)
        case .s: (22, 32, 20)
        case .m: (30, 44, 30)
        case .l: (42, 62, 44)
        }
    }
}

public enum SplitFlapTone: Sendable { case amber, white }

/// Pure logic of the flap cascade (SplitFlap.dc.html `target()`).
public enum SplitFlapLogic {
    public static let charset: [Character] = Array(" ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789→·:-+/")
    /// 62 ms top flap + 62 ms bottom flap, plus 4 ms idle and an 8 ms gap before the next flip.
    public static let flipDuration = 0.062
    public static let cellStagger = 0.040
    public static let maxFlips = 5

    public static func normalize(_ text: String, count: Int) -> [Character] {
        let up = Array(text.uppercased())
        return (0..<count).map { $0 < up.count ? up[$0] : " " }
    }

    /// Characters a cell flips through to get from `cur` to `target` (last element is the target). Empty if unchanged.
    public static func chain(from cur: Character, to target: Character, random: () -> Double) -> [Character] {
        let ci = charset.firstIndex(of: cur) ?? -1, ti = charset.firstIndex(of: target) ?? -1
        let diff = abs(ti - ci)
        let steps = min(maxFlips, max(0, diff != 0 ? diff : (target == cur ? 0 : 3)))
        return (0..<steps).map { s in
            s == steps - 1 ? target : charset[(max(0, ci) + 1 + Int(random() * 30)) % charset.count]
        }
    }

    /// Cubic bezier easing (CSS `cubic-bezier(x1,y1,x2,y2)`).
    public static func bezier(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, _ t: Double) -> Double {
        if t <= 0 { return 0 }; if t >= 1 { return 1 }
        func f(_ u: Double, _ a: Double, _ b: Double) -> Double { 3 * a * u * (1 - u) * (1 - u) + 3 * b * u * u * (1 - u) + u * u * u }
        var lo = 0.0, hi = 1.0
        for _ in 0..<24 { let m = (lo + hi) / 2; if f(m, x1, x2) < t { lo = m } else { hi = m } }
        return f((lo + hi) / 2, y1, y2)
    }

    /// Fold angles at time `t` (s) into one flip: (top flap rotateX degrees 0 -> -90, bottom flap 90 -> 0).
    public static func angles(at t: Double) -> (top: Double, bottom: Double) {
        let a = bezier(0.5, 0, 1, 0.6, min(1, t / flipDuration))
        let b = bezier(0, 0.4, 0.5, 1, min(1, max(0, (t - flipDuration) / flipDuration)))
        return (-90 * a, 90 * (1 - b))
    }
}

/// Departures-board text, 1:1 with SplitFlap.dc.html. Changing `text` cascades the cells left to right
/// (40 ms apart, 62 + 62 ms per flip, up to 5 flips per cell). With Reduce Motion the text just changes.
public struct SplitFlapText: View {
    private let text: String
    private let length: Int
    private let size: SplitFlapSize
    private let tone: SplitFlapTone
    private let dim: Bool
    private let onFlap: (@Sendable (Int) -> Void)?

    private struct Cell: Equatable { var cur: Character; var nxt: Character; var flipStart: Date? }
    @State private var cells: [Cell]
    @State private var tasks: [Task<Void, Never>] = []
    @State private var lastFlapSound = Date.distantPast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - length: cell count (default: text length).
    ///   - onFlap: called when a cell starts a flip (even cells only, rate-limited to 25 per second) for the clack sound.
    public init(_ text: String, length: Int? = nil, size: SplitFlapSize = .m, tone: SplitFlapTone = .amber, dim: Bool = false,
                onFlap: (@Sendable (Int) -> Void)? = nil) {
        let n = max(length ?? text.count, 0)
        self.text = text; self.length = n; self.size = size; self.tone = tone; self.dim = dim; self.onFlap = onFlap
        let chars = SplitFlapLogic.normalize(text, count: n)
        _cells = State(initialValue: chars.map { Cell(cur: $0, nxt: $0, flipStart: nil) })
    }

    /// Source-compatible with the first stand-in (`cellCount`, text style).
    public init(_ text: String, cellCount: Int?, style: MRTextStyle) {
        self.init(text, length: cellCount, size: style.size >= 34 ? .l : style.size >= 20 ? .m : .s)
    }

    public var body: some View {
        let d = size.dims
        let ink = tone == .white ? Color(hex: "#F3F5FA") : Color(hex: "#FFB547")
        TimelineView(.animation(paused: !cells.contains { $0.flipStart != nil })) { tl in
            HStack(spacing: 3) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, c in
                    FlapCell(cell: (c.cur, c.nxt, c.flipStart), now: tl.date, dims: d, ink: ink)
                }
            }
            .opacity(dim ? 0.55 : 1)
        }
        .fixedSize()
        .onChange(of: text) { _, new in retarget(new) }
        .onDisappear { tasks.forEach { $0.cancel() }; tasks = [] }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text.trimmingCharacters(in: .whitespaces))
    }

    private func retarget(_ new: String) {
        tasks.forEach { $0.cancel() }; tasks = []
        let target = SplitFlapLogic.normalize(new, count: length)
        if reduceMotion {
            cells = target.map { Cell(cur: $0, nxt: $0, flipStart: nil) }
            return
        }
        // settle half-finished flips on their current value
        cells = cells.map { Cell(cur: $0.nxt, nxt: $0.nxt, flipStart: nil) }
        var rng = PaperRandom(seed: PaperHash.fnv1a(new))
        for (i, ch) in target.enumerated() {
            let chain = SplitFlapLogic.chain(from: cells[i].cur, to: ch, random: { rng.next() })
            guard !chain.isEmpty else { continue }
            tasks.append(Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(40 * i))
                for next in chain {
                    if Task.isCancelled { return }
                    cells[i].nxt = next
                    cells[i].flipStart = Date()
                    if i % 2 == 0, let onFlap, Date().timeIntervalSince(lastFlapSound) >= 0.04 {
                        lastFlapSound = Date(); onFlap(i)
                    }
                    try? await Task.sleep(for: .milliseconds(128))
                    cells[i].cur = next
                    cells[i].flipStart = nil
                    try? await Task.sleep(for: .milliseconds(8))
                }
            })
        }
    }
}

private struct FlapCell: View {
    let cell: (cur: Character, nxt: Character, start: Date?)
    let now: Date
    let dims: (w: CGFloat, h: CGFloat, font: CGFloat)
    let ink: Color

    var body: some View {
        let (w, h) = (dims.w, dims.h)
        let t = cell.start.map { now.timeIntervalSince($0) }
        let ang = t.map { SplitFlapLogic.angles(at: max(0, $0)) }
        ZStack(alignment: .topLeading) {
            half(cell.nxt, top: true)
            half(cell.cur, top: false)
            if let ang {
                half(cell.cur, top: true)
                    .modifier(PaperTilt(rx: ang.top, ry: 0, size: CGSize(width: w, height: h), perspective: 600,
                                        origin: CGPoint(x: w / 2, y: h / 2)))
                half(cell.nxt, top: false)
                    .modifier(PaperTilt(rx: ang.bottom, ry: 0, size: CGSize(width: w, height: h), perspective: 600,
                                        origin: CGPoint(x: w / 2, y: h / 2)))
            }
            // hinge
            Rectangle().fill(Color(hex: "#050608")).frame(width: w, height: 2).offset(y: h / 2 - 1)
            Rectangle().fill(.white.opacity(0.06)).frame(width: w, height: 1).offset(y: h / 2 + 1)
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 5).fill(Color(hex: "#0D0F13"))
            .shadow(color: .black.opacity(0.45), radius: 4, y: 3)
            .shadow(color: .white.opacity(0.07), radius: 0, y: 1))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.white.opacity(0.04), lineWidth: 1))
    }

    private func half(_ ch: Character, top: Bool) -> some View {
        let (w, h) = (dims.w, dims.h)
        let g = top ? [Color(hex: "#252932"), Color(hex: "#171A20")] : [Color(hex: "#14171C"), Color(hex: "#0F1115")]
        return ZStack(alignment: .topLeading) {
            LinearGradient(colors: g, startPoint: .top, endPoint: .bottom)
            Text(String(ch))
                .font(MRFonts.font(.condensed, size: dims.font, weight: 600)).tracking(dims.font * 0.02)
                .foregroundStyle(ink)
                .shadow(color: .black.opacity(0.6), radius: 0, y: 1)
                .frame(width: w, height: h)
                .offset(y: top ? 0 : -h / 2)
        }
        .frame(width: w, height: h / 2, alignment: .topLeading)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: top ? 5 : 0, bottomLeadingRadius: top ? 0 : 5,
                                          bottomTrailingRadius: top ? 0 : 5, topTrailingRadius: top ? 5 : 0))
        .frame(width: w, height: h, alignment: top ? .top : .bottom)
    }
}

#Preview("SplitFlapText") {
    struct Demo: View {
        @State private var t = "MR 0142 · A12"
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                SplitFlapText(t, length: 13, size: .m)
                SplitFlapText("LHR → CDG", size: .l, tone: .white)
                Button("Change") { t = ["LHR → CDG", "GATE B7", "MR 4821 · B7"].randomElement()! }
            }.padding(32).background(MRPalette.dark.bg0.color)
        }
    }
    return Demo().preferredColorScheme(.dark)
}
