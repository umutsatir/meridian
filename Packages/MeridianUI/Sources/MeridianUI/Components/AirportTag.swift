import SwiftUI

/// `.tag`: amber airport label on the range ring (PRD PLAN-3). Selected grows 1.15 with a white ring and amber glow.
public struct AirportTag: View {
    private let code: String
    private let city: String?
    private let minutes: Int?
    private let isSelected: Bool
    private let isDisabled: Bool
    private let isDim: Bool
    private let showsIcon: Bool
    private let visitedColor: Color?
    private let forcedHover: Bool
    private var minWidth: CGFloat?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isFocused) private var isFocused
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var hovered = false

    public init(code: String, city: String? = nil, minutes: Int? = nil, isSelected: Bool = false, isDisabled: Bool = false,
                isDim: Bool = false, showsIcon: Bool = false, visitedColor: Color? = nil) {
        self.init(code: code, city: city, minutes: minutes, isSelected: isSelected, isDisabled: isDisabled, isDim: isDim,
                  showsIcon: showsIcon, visitedColor: visitedColor, forcedHover: false)
    }

    private init(code: String, city: String?, minutes: Int?, isSelected: Bool, isDisabled: Bool, isDim: Bool, showsIcon: Bool, visitedColor: Color?, forcedHover: Bool) {
        self.code = code; self.city = city; self.minutes = minutes; self.isSelected = isSelected; self.isDisabled = isDisabled
        self.isDim = isDim; self.showsIcon = showsIcon; self.visitedColor = visitedColor; self.forcedHover = forcedHover
    }

    /// `min-width` with centred content (the search rows use 48).
    public func minWidth(_ w: CGFloat) -> AirportTag { var t = self; t.minWidth = w; return t }

    /// Pins the hover state for galleries (`.is-hover`).
    public func hoverPinned() -> AirportTag {
        AirportTag(code: code, city: city, minutes: minutes, isSelected: isSelected, isDisabled: isDisabled, isDim: isDim,
                   showsIcon: showsIcon, visitedColor: visitedColor, forcedHover: true)
    }

    /// Spoken label, e.g. "Paris, CDG, 42 minutes". Pure, so it can be used off the main actor.
    public nonisolated static func spokenLabel(code: String, city: String?, minutes: Int?) -> String {
        [city, code, minutes.map { "\($0) minutes" }].compactMap { $0 }.joined(separator: ", ")
    }

    public var body: some View {
        let p = MRPalette.resolve(scheme)
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        let hover = (hovered || forcedHover) && !isDisabled
        let orange = Color(red: 1, green: 140 / 255, blue: 0)
        HStack(spacing: 5) {
            if showsIcon { MRIcon(.plane, size: 12) }
            Text(code)
                .font(.mr(.condensed, size: 13, weight: 700))
                .tracking(13 * 0.05)
        }
        .foregroundStyle(isDisabled ? p.text3.color : p.ink.color)
        .padding(.leading, 6).padding(.trailing, 8)
        .frame(minWidth: minWidth, minHeight: 24, maxHeight: 24)
        .background {
            if isDisabled {
                shape.fill(p.fill2.color)
            } else {
                shape.fill(p.amber.color)
                    .shadow(color: .black.opacity(isSelected ? 0.45 : hover ? 0.4 : 0.35), radius: (isSelected ? 16 : hover ? 16 : 8) / 2, y: isSelected ? 6 : hover ? 8 : 2)
            }
        }
        .overlay {
            if isDisabled {
                shape.strokeBorder(p.strokeHair.color, lineWidth: 1)
            } else {
                ZStack {
                    // inset 0 0 0 1px rgba(255,255,255,.4/.55/.7)
                    shape.strokeBorder(.white.opacity(isSelected ? 0.7 : hover ? 0.55 : 0.4), lineWidth: 1)
                    // inset 0 -7px 10px rgba(255,140,0,.32) (absent in the selected state)
                    if !isSelected { MRInsetShadow(shape, color: orange.opacity(0.32), y: -7, blur: 10) }
                }
            }
        }
        .overlay {
            if isSelected && !isDisabled {
                // 0 0 0 2px #fff, 0 0 22px rgba(255,181,71,.65)
                shape.stroke(.white, lineWidth: 2).padding(-1)
                    .background { shape.fill(.clear).shadow(color: p.amber.color.opacity(0.65), radius: 11) }
            }
        }
        .overlay(alignment: .topTrailing) {
            if let visitedColor {
                Circle().fill(visitedColor).frame(width: 9, height: 9)
                    .overlay(Circle().stroke(p.bg1.color, lineWidth: 2).padding(-2))
                    .offset(x: 3, y: -3)
            }
        }
        .mrFocusRing(isFocused, cornerRadius: 8, offset: 3, color: p.accent1.color)
        .overlay {
            if contrast == .increased && !isDisabled {
                shape.stroke(.black, lineWidth: 2).padding(-2).overlay(shape.stroke(.white, lineWidth: 1).padding(-3))
            }
        }
        .opacity(isDim ? 0.62 : 1)
        .saturation(isDim ? 0.8 : 1)
        .offset(y: hover && !isSelected ? -2 : 0)
        .scaleEffect(isSelected ? 1.15 : 1)
        .animation(MRMotion.snappy, value: isSelected)
        .animation(MRMotion.snappy, value: hover)
        .onHover { hovered = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.spokenLabel(code: code, city: city, minutes: minutes))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("AirportTag") {
    HStack(spacing: 16) {
        AirportTag(code: "CDG", city: "Paris", minutes: 42, isSelected: true)
        AirportTag(code: "AMS", city: "Amsterdam", minutes: 45)
        AirportTag(code: "BRU", showsIcon: true)
        AirportTag(code: "FRA", isDisabled: true)
    }
    .padding(32)
    .background(MRPalette.dark.bg0.color)
    .preferredColorScheme(.dark)
}
