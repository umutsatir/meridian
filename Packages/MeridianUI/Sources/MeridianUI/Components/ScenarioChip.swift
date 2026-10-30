import SwiftUI

/// Focus-type chip. Color is never the only signal: icon and label always show (PRD COL-2).
public struct ScenarioChip: View {
    private let name: String
    private let symbol: String
    private let colorHex: String
    private let isSelected: Bool
    private let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    public init(name: String, symbol: String, colorHex: String, isSelected: Bool = false, action: @escaping () -> Void = {}) {
        self.name = name
        self.symbol = symbol
        self.colorHex = colorHex
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        let p = MRPalette.resolve(scheme)
        let tint = Color(hex: colorHex)
        let shape = Capsule()
        Button(action: action) {
            Label(name, systemImage: symbol)
                .mrText(.callout)
                .foregroundStyle(p.text1.color)
                .padding(.horizontal, MRSpacing.s)
                .padding(.vertical, MRSpacing.xs)
                .background(tint.opacity(isSelected ? 0.28 : 0.12), in: shape)
                .overlay(shape.strokeBorder(tint.opacity(isSelected ? 1 : 0.45), lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .mrAnimation(MRMotion.snappy, value: isSelected)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview("ScenarioChip") {
    HStack {
        ScenarioChip(name: "Study", symbol: "book", colorHex: MRScenarioColor.study.hex, isSelected: true)
        ScenarioChip(name: "Code", symbol: "chevron.left.forwardslash.chevron.right", colorHex: MRScenarioColor.code.hex)
        ScenarioChip(name: "Meditate", symbol: "leaf", colorHex: MRScenarioColor.meditate.hex)
    }
    .padding(24)
    .background(MRPalette.dark.bg0.color)
    .preferredColorScheme(.dark)
}
