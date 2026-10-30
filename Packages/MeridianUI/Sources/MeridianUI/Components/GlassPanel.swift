import SwiftUI

/// The canvas `.glass` material (ADR 0008: material + overlay layers, not the system glassEffect).
/// Reduce Transparency / Increase Contrast fall back to a solid bg-2 with the hairline kept.
public struct GlassPanel<Content: View>: View {
    private let cornerRadius: CGFloat
    private let padding: CGFloat
    private let elevation: MRElevation
    private let content: Content

    public init(cornerRadius: CGFloat = MRRadius.panel, padding: CGFloat = MRSpacing.l, elevation: MRElevation = .e3, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.elevation = elevation
        self.content = content()
    }

    public var body: some View {
        content.padding(padding).mrGlass(cornerRadius: cornerRadius, elevation: elevation)
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
