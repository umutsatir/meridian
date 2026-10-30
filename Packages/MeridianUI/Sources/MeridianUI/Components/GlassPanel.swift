import SwiftUI

/// Liquid Glass on macOS/iOS 26, material before that, solid bg-2 under Reduce Transparency.
public struct GlassPanel<Content: View>: View {
    private let cornerRadius: CGFloat
    private let padding: CGFloat
    private let content: Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var scheme

    public init(cornerRadius: CGFloat = MRRadius.panel, padding: CGFloat = MRSpacing.l, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let palette = MRPalette.resolve(scheme)
        if reduceTransparency {
            content.padding(padding)
                .background(palette.bg2.color, in: shape)
                .overlay(shape.strokeBorder(palette.text3.color.opacity(0.35), lineWidth: 1))
        } else if #available(macOS 26.0, iOS 26.0, *) {
            content.padding(padding).glassEffect(.regular, in: shape)
        } else {
            content.padding(padding)
                .background(.regularMaterial, in: shape)
                .overlay(shape.strokeBorder(palette.text3.color.opacity(0.2), lineWidth: 1))
        }
    }
}

#Preview("GlassPanel") {
    ZStack {
        LinearGradient(colors: [MRPalette.dark.bg1.color, MRPalette.dark.accent1.color.opacity(0.4)], startPoint: .top, endPoint: .bottom)
        GlassPanel {
            Text("In flight to Paris").mrText(.title2).foregroundStyle(MRPalette.dark.text1.color)
        }
    }
    .frame(width: 360, height: 220)
    .preferredColorScheme(.dark)
}
