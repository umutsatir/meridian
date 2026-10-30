import SwiftUI

public struct MRButtonStyle: ButtonStyle {
    public enum Kind: Sendable { case primary, secondary, ghost }

    private let kind: Kind

    public init(_ kind: Kind = .primary) { self.kind = kind }

    public func makeBody(configuration: Configuration) -> some View {
        StyledLabel(kind: kind, configuration: configuration)
    }

    private struct StyledLabel: View {
        let kind: Kind
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.isFocused) private var isFocused
        @Environment(\.colorScheme) private var scheme
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            let p = MRPalette.resolve(scheme)
            let shape = RoundedRectangle(cornerRadius: MRRadius.control, style: .continuous)
            let pressed = configuration.isPressed
            configuration.label
                .mrText(.headline)
                .foregroundStyle(foreground(p))
                .padding(.horizontal, MRSpacing.m)
                .frame(minHeight: 36)
                .background(background(p, pressed: pressed), in: shape)
                .overlay {
                    if kind == .secondary { shape.strokeBorder(p.text3.color.opacity(0.4), lineWidth: 1) }
                }
                // Visible focus ring for keyboard operation (PRD §10.3).
                .overlay {
                    if isFocused { shape.inset(by: -3).stroke(p.accent1.color, lineWidth: 2) }
                }
                .scaleEffect(pressed && !reduceMotion ? 0.97 : 1)
                .opacity(isEnabled ? 1 : 0.45)
                .animation(reduceMotion ? nil : MRMotion.snappy, value: pressed)
                .contentShape(shape)
        }

        private func foreground(_ p: MRPalette) -> Color {
            switch kind {
            case .primary: p.onAccent.color
            case .secondary, .ghost: p.text1.color
            }
        }

        private func background(_ p: MRPalette, pressed: Bool) -> Color {
            switch kind {
            case .primary: p.accent1.color.opacity(pressed ? 0.85 : 1)
            case .secondary: p.bg2.color.opacity(pressed ? 0.7 : 1)
            case .ghost: pressed ? p.text3.color.opacity(0.2) : .clear
            }
        }
    }
}

#Preview("MRButtonStyle") {
    VStack(spacing: 12) {
        Button("Check in") {}.buttonStyle(MRButtonStyle(.primary))
        Button("Take a break") {}.buttonStyle(MRButtonStyle(.secondary))
        Button("Skip") {}.buttonStyle(MRButtonStyle(.ghost))
        Button("Disabled") {}.buttonStyle(MRButtonStyle(.primary)).disabled(true)
    }
    .padding(32)
    .background(MRPalette.dark.bg0.color)
    .preferredColorScheme(.dark)
}
