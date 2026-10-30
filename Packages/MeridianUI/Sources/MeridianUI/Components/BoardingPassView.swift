import SwiftUI

/// The hero artifact (PRD RIT-2/3). `tearProgress` (0...1, from `TearState.progress`) drives the
/// jagged tear and the stub's pivot; the drag gesture itself lives in the caller.
public struct BoardingPassView: View {
    private let model: BoardingPassModel
    private let tearProgress: Double
    private let onTear: (() -> Void)?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let mainWidth: CGFloat = 430
    static let stubWidth: CGFloat = 128
    static let height: CGFloat = 208

    public init(_ model: BoardingPassModel, tearProgress: Double = 0, onTear: (() -> Void)? = nil) {
        self.model = model
        self.tearProgress = min(1, max(0, tearProgress))
        self.onTear = onTear
    }

    public var body: some View {
        let p = MRPalette.resolve(scheme)
        let angle = reduceMotion ? 0 : -TearState.maxStubAngleDegrees * tearProgress
        HStack(spacing: 0) {
            panel(.main, palette: p) { mainContent(p) }
                .frame(width: Self.mainWidth)
            panel(.stub, palette: p) { stubContent(p) }
                .frame(width: Self.stubWidth)
                .rotationEffect(.degrees(angle), anchor: .bottomLeading)
                .offset(x: reduceMotion ? 0 : 6 * tearProgress, y: 0)
        }
        .frame(height: Self.height)
        .shadow(color: .black.opacity(0.28), radius: 18, y: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.accessibilityDescription(canTear: onTear != nil && tearProgress < 1))
        .accessibilityAddTraits(onTear == nil ? [] : .isButton)
        .accessibilityAction(named: "Tear off the stub") { onTear?() }
    }

    private func panel<C: View>(_ side: TicketPanelShape.Side, palette p: MRPalette, @ViewBuilder content: () -> C) -> some View {
        let shape = TicketPanelShape(side: side, seed: model.seed, tearProgress: tearProgress)
        return ZStack(alignment: .top) {
            shape.fill(p.paper.color)
            content()
            foil.frame(height: 5).frame(maxHeight: .infinity, alignment: .top)
        }
        .clipShape(shape)
        .foregroundStyle(p.ink.color)
    }

    private var foil: some View {
        LinearGradient(colors: model.cabin.foilHexes.map { Color(hex: $0) }, startPoint: .leading, endPoint: .trailing)
    }

    private func field(_ label: String, _ value: String, _ p: MRPalette) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).mrText(.caption).foregroundStyle(p.ink.color.opacity(0.65))
            Text(value).mrText(.headline, .mono)
        }
    }

    private func mainContent(_ p: MRPalette) -> some View {
        VStack(alignment: .leading, spacing: MRSpacing.s) {
            Text("\(MRBrand.name.uppercased()) · BOARDING PASS · \(model.cabin.title.uppercased())")
                .mrText(.caption, .mono)
                .foregroundStyle(p.ink.color.opacity(0.65))
            HStack(alignment: .center, spacing: MRSpacing.m) {
                place(model.originCode, model.originCity)
                Image(systemName: "airplane").font(.title2).foregroundStyle(p.ink.color.opacity(0.7))
                place(model.destinationCode, model.destinationCity)
            }
            Spacer(minLength: 0)
            HStack(spacing: MRSpacing.l) {
                field("FLIGHT", model.flightNumber, p)
                field("GATE", model.gate, p)
                field("SEAT", model.seat, p)
                field("DURATION", model.durationText, p)
            }
            Text(model.scenarioName).mrText(.callout).foregroundStyle(p.ink.color.opacity(0.65))
        }
        .padding(.horizontal, MRSpacing.l)
        .padding(.top, MRSpacing.m + 5)
        .padding(.bottom, MRSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func place(_ code: String, _ city: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(code).font(.system(size: 44, weight: .bold).width(.condensed))
            Text(city).mrText(.callout).lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    private func stubContent(_ p: MRPalette) -> some View {
        VStack(alignment: .leading, spacing: MRSpacing.xs) {
            Text("\(model.originCode) → \(model.destinationCode)").mrText(.headline, .condensed)
            field("FLIGHT", model.flightNumber, p)
            HStack(spacing: MRSpacing.m) {
                field("GATE", model.gate, p)
                field("SEAT", model.seat, p)
            }
            Spacer(minLength: 0)
            BarcodeView(seed: model.seed).frame(height: 34)
        }
        .padding(.leading, MRSpacing.m + MRRadius.ticketNotch / 2)
        .padding(.trailing, MRSpacing.m)
        .padding(.top, MRSpacing.m + 5)
        .padding(.bottom, MRSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Decorative barcode, deterministic per seed. Not machine-readable.
struct BarcodeView: View {
    let seed: UInt64

    var body: some View {
        Canvas { context, size in
            let widths = TornEdge.barWidths(seed: seed, count: 30)
            let unit = size.width / CGFloat(widths.reduce(0) { $0 + $1 + 1 })
            var x: CGFloat = 0
            for w in widths {
                context.fill(Path(CGRect(x: x, y: 0, width: CGFloat(w) * unit, height: size.height)), with: .foreground)
                x += CGFloat(w + 1) * unit
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("BoardingPassView") {
    struct Demo: View {
        @State private var tear = TearState()
        @State private var raw = 0.0
        var body: some View {
            VStack(spacing: 24) {
                BoardingPassView(.sample, tearProgress: tear.progress) { tear.complete() }
                Slider(value: $raw).frame(width: 300)
                    .onChange(of: raw) { _, v in tear.drag(to: v) }
                    .onSubmit { tear.release() }
            }
            .padding(40)
            .background(MRPalette.dark.bg0.color)
        }
    }
    return Demo().preferredColorScheme(.dark)
}

#Preview("Cabin foil edges") {
    VStack(spacing: 20) {
        ForEach(BoardingPassCabin.allCases, id: \.self) { cabin in
            var m = BoardingPassModel.sample
            let _ = m.cabin = cabin
            BoardingPassView(m)
        }
    }
    .padding(40)
    .background(MRPalette.light.bg0.color)
    .preferredColorScheme(.light)
}
