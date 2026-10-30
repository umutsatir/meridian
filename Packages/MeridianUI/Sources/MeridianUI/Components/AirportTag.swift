import SwiftUI

/// Amber destination tag on the range ring (PRD PLAN-3). The selected tag grows.
public struct AirportTag: View {
    private let code: String
    private let city: String?
    private let minutes: Int?
    private let isSelected: Bool
    @Environment(\.colorScheme) private var scheme

    public init(code: String, city: String? = nil, minutes: Int? = nil, isSelected: Bool = false) {
        self.code = code
        self.city = city
        self.minutes = minutes
        self.isSelected = isSelected
    }

    /// Spoken label, e.g. "Paris, CDG, 42 minutes". Pure, so it can be used off the main actor.
    public nonisolated static func spokenLabel(code: String, city: String?, minutes: Int?) -> String {
        [city, code, minutes.map { "\($0) minutes" }].compactMap { $0 }.joined(separator: ", ")
    }

    public var body: some View {
        let p = MRPalette.resolve(scheme)
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        Text(code)
            .mrText(.callout, .condensed)
            .fontWeight(.bold)
            .foregroundStyle(p.ink.color)
            .padding(.horizontal, MRSpacing.xs)
            .padding(.vertical, 3)
            .background(p.amber.color, in: shape)
            .overlay(shape.strokeBorder(p.ink.color.opacity(isSelected ? 0.9 : 0), lineWidth: 1.5))
            .scaleEffect(isSelected ? 1.18 : 1)
            .mrAnimation(MRMotion.bouncy, value: isSelected)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Self.spokenLabel(code: code, city: city, minutes: minutes))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("AirportTag") {
    HStack(spacing: 16) {
        AirportTag(code: "CDG", city: "Paris", minutes: 42, isSelected: true)
        AirportTag(code: "AMS", city: "Amsterdam", minutes: 45)
        AirportTag(code: "BRU")
    }
    .padding(32)
    .background(MRPalette.dark.bg0.color)
    .preferredColorScheme(.dark)
}
