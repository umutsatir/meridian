import SwiftUI

// MARK: - .seg

/// `.seg`: segmented control. Track pad 3 / gap 2 / radius 12; items 28 pt, radius 9, 13 medium.
public struct MRSegmented<Value: Hashable>: View {
    public struct Option: Identifiable {
        public let value: Value
        public let title: String
        public let icon: MRIconName?
        public let iconSize: CGFloat
        public var id: Value { value }
        public init(_ value: Value, _ title: String, icon: MRIconName? = nil, iconSize: CGFloat = 16) { self.value = value; self.title = title; self.icon = icon; self.iconSize = iconSize }
    }

    private let options: [Option]
    @Binding private var selection: Value
    private let pinnedHover: Value?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovered: Value?
    @FocusState private var focused: Value?

    private let fill: Bool

    /// `fill`: items share the track width (`flex:1` on each, as in the C12 popover).
    public init(selection: Binding<Value>, options: [Option], pinnedHover: Value? = nil, fill: Bool = false) {
        self._selection = selection; self.options = options; self.pinnedHover = pinnedHover; self.fill = fill
    }

    public var body: some View {
        let p = MRPalette.resolve(scheme)
        let dark = scheme == .dark
        let track = RoundedRectangle(cornerRadius: 12, style: .continuous)
        HStack(spacing: 2) {
            ForEach(options) { opt in
                let on = opt.value == selection
                let hover = (hovered == opt.value || pinnedHover == opt.value)
                let item = RoundedRectangle(cornerRadius: 9, style: .continuous)
                Button { selection = opt.value } label: {
                    HStack(spacing: 6) {
                        if let icon = opt.icon { MRIcon(icon, size: opt.iconSize) }
                        Text(opt.title).font(.mr(.ui, size: 13, weight: 500)).lineLimit(1)
                    }
                    .foregroundStyle(on || hover ? p.text1.color : p.text2.color)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: fill ? .infinity : nil)
                    .frame(height: 28)
                    .background {
                        if on {
                            item.fill(p.segOn.color)
                                .shadow(color: dark ? .black.opacity(0.25) : MRColorToken(40, 34, 20, 0.18).color, radius: 1.5, y: 1)
                                .overlay(MRInsetShadow(item, color: p.strokeGlow.color, y: 1))
                        }
                    }
                    .mrFocusRing(focused == opt.value, cornerRadius: 9, offset: 1, color: p.accent1.color)
                    .contentShape(item)
                }
                .buttonStyle(.plain)
                .focused($focused, equals: opt.value)
                .onHover { hv in withAnimation(MRMotion.hover) { hovered = hv ? opt.value : (hovered == opt.value ? nil : hovered) } }
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(p.fill1.color, in: track)
        .overlay(track.strokeBorder(p.strokeHair.color, lineWidth: 1))
        .animation(MRMotion.snappy, value: selection)
        .opacity(isEnabled ? 1 : 0.38)
    }
}

// MARK: - .toggle

/// `.toggle`: 44 x 26 switch, 20 pt knob that travels 18 pt on `MRMotion.snappy`.
public struct MRToggleStyle: ToggleStyle {
    private let pinnedHover: Bool
    public init(pinnedHover: Bool = false) { self.pinnedHover = pinnedHover }

    public func makeBody(configuration: Configuration) -> some View {
        Row(configuration: configuration, pinnedHover: pinnedHover)
    }

    private struct Row: View {
        let configuration: ToggleStyleConfiguration
        let pinnedHover: Bool
        @Environment(\.colorScheme) private var scheme
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.isFocused) private var isFocusedEnv
        @Environment(\.mrForcedState) private var forced
        @State private var hovered = false

        var body: some View {
            let p = MRPalette.resolve(scheme)
            let on = configuration.isOn
            let isFocused = isFocusedEnv || forced == .focus
            HStack {
                configuration.label
                Button { configuration.isOn.toggle() } label: {
                    ZStack(alignment: .leading) {
                        Capsule().fill(on ? AnyShapeStyle(p.accentGradient) : AnyShapeStyle(p.fill3.color))
                        Circle().fill(.white).frame(width: 20, height: 20)
                            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                            .padding(3)
                            .offset(x: on ? 18 : 0)
                    }
                    .frame(width: 44, height: 26)
                    .brightness(hovered || pinnedHover || forced == .hover ? 0.05 : 0) // filter: brightness(1.12)
                    .mrFocusRing(isFocused, cornerRadius: 13, color: p.accent1.color)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .onHover { hv in withAnimation(MRMotion.hover) { hovered = hv } }
                .animation(MRMotion.snappy, value: on)
                .animation(MRMotion.ease(MRMotion.d2), value: hovered)
                .opacity(isEnabled ? 1 : 0.38)
                .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label } }
            }
        }
    }
}

// MARK: - .slider

/// `.slider`: 4 pt gradient track, 16 pt white thumb (hover scale 1.15). Drag, click, arrow keys (shift = 10x).
public struct MRSlider: View {
    @Binding private var value: Double
    private let range: ClosedRange<Double>
    private let step: Double
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var focusedState: Bool
    @Environment(\.mrForcedState) private var forced
    @State private var hoveredState = false
    private var focused: Bool { focusedState || forced == .focus }
    private var hovered: Bool { hoveredState || forced == .hover }

    public init(value: Binding<Double>, in range: ClosedRange<Double> = 0...1, step: Double = 0.01) {
        self._value = value; self.range = range; self.step = step
    }

    private var fraction: Double { (value - range.lowerBound) / (range.upperBound - range.lowerBound) }

    public var body: some View {
        let p = MRPalette.resolve(scheme)
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(p.fill3.color).frame(height: 4)
                Capsule().fill(p.accentGradient).frame(width: w * fraction, height: 4)
                Circle().fill(.white).frame(width: 16, height: 16)
                    .shadow(color: .black.opacity(0.45), radius: 2.5, y: 1)
                    .scaleEffect(hovered ? 1.15 : 1)
                    .mrFocusRing(focused, cornerRadius: 8, color: p.accent1.color)
                    .offset(x: w * fraction - 8)
            }
            .frame(height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                let f = min(1, max(0, g.location.x / max(1, w)))
                set(range.lowerBound + f * (range.upperBound - range.lowerBound))
                focusedState = true
            })
        }
        .frame(height: 16)
        .focusable(isEnabled)
        .focused($focusedState)
        .focusEffectDisabled()
        .onHover { hv in withAnimation(MRMotion.hover) { hoveredState = hv } }
        .animation(MRMotion.ease(MRMotion.d1), value: hovered)
        .onMoveCommand { dir in
            let k = step * 1
            switch dir {
            case .left, .down: set(value - k)
            case .right, .up: set(value + k)
            default: break
            }
        }
        .opacity(isEnabled ? 1 : 0.38)
        .accessibilityElement()
        .accessibilityValue("\(Int((fraction * 100).rounded())) percent")
        .accessibilityAdjustableAction { dir in
            switch dir {
            case .increment: set(value + step * 10)
            case .decrement: set(value - step * 10)
            @unknown default: break
            }
        }
    }

    private func set(_ v: Double) {
        let snapped = step > 0 ? (v / step).rounded() * step : v
        value = min(range.upperBound, max(range.lowerBound, snapped))
    }
}

// MARK: - .field

/// `.field`: 36 pt text field, radius 12, 14 regular, optional leading icon.
public struct MRField: View {
    private let placeholder: String
    @Binding private var text: String
    private let icon: MRIconName?
    private let pinnedHover: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var focusedState: Bool
    @Environment(\.mrForcedState) private var forced
    @State private var hoveredState = false
    private var focused: Bool { focusedState || forced == .focus }
    private var hovered: Bool { hoveredState || forced == .hover }

    private let isError: Bool

    private let iconSize: CGFloat

    public init(_ placeholder: String, text: Binding<String>, icon: MRIconName? = nil, iconSize: CGFloat = 16, pinnedHover: Bool = false, isError: Bool = false) {
        self.placeholder = placeholder; self._text = text; self.icon = icon; self.pinnedHover = pinnedHover; self.isError = isError; self.iconSize = iconSize
    }

    public var body: some View {
        let p = MRPalette.resolve(scheme)
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        HStack(spacing: 8) {
            if let icon { MRIcon(icon, size: iconSize).foregroundStyle(p.text3.color) }
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(p.text3.color))
                .textFieldStyle(.plain)
                .font(.mr(.ui, size: 14, weight: 400))
                .foregroundStyle(p.text1.color)
                .focused($focusedState)
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(isError ? Color(red: 1, green: 107 / 255, blue: 107 / 255, opacity: 0.08) : (focused || hovered || pinnedHover) ? p.fill2.color : p.fill1.color, in: shape)
        .overlay(shape.strokeBorder(isError ? Color(red: 1, green: 107 / 255, blue: 107 / 255, opacity: 0.7) : p.strokeHair.color, lineWidth: 1))
        .mrFocusRing(focused, cornerRadius: 12, color: p.accent1.color)
        .onHover { hv in withAnimation(MRMotion.hover) { hoveredState = hv } }
        .opacity(isEnabled ? 1 : 0.4)
        .animation(MRMotion.ease(MRMotion.d2), value: focused)
    }
}
