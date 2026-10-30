import SwiftUI

/// `.nav`: sidebar row. 34 pt (30 `.sub`), radius 12, 14 medium, icon 18, optional keycap and badge.
/// Active state is the blue-to-mint gradient with a 1 pt ring and glow; hover is `fill-1`.
/// `isRail` is the 48 pt icon-only variant (`.rail-nav`).
public struct MRNavItem: View {
    private let title: String
    private let icon: MRIconName
    private let shortcut: String?
    private let badge: String?
    private let isActive: Bool
    private let isSub: Bool
    private let isRail: Bool
    private let pinnedHover: Bool
    private let action: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isFocused) private var isFocused
    @State private var hovered = false

    public init(_ title: String, icon: MRIconName, shortcut: String? = nil, badge: String? = nil, isActive: Bool = false,
                isSub: Bool = false, isRail: Bool = false, pinnedHover: Bool = false, action: @escaping () -> Void = {}) {
        self.title = title; self.icon = icon; self.shortcut = shortcut; self.badge = badge; self.isActive = isActive
        self.isSub = isSub; self.isRail = isRail && true; self.pinnedHover = pinnedHover; self.action = action
    }

    public var body: some View {
        let p = MRPalette.resolve(scheme)
        let dark = scheme == .dark
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        let hover = (hovered || pinnedHover) && !isActive
        let tint = dark ? (MRColorToken(106, 183, 255, 0.24), MRColorToken(139, 243, 216, 0.10), MRColorToken(106, 183, 255, 0.34), MRColorToken(106, 183, 255, 0.20), 26.0)
                        : (MRColorToken(30, 107, 255, 0.14), MRColorToken(24, 199, 160, 0.08), MRColorToken(30, 107, 255, 0.30), MRColorToken(30, 107, 255, 0.12), 22.0)
        Button(action: action) {
            HStack(spacing: 10) {
                MRIcon(icon, size: 18)
                if !isRail {
                    Text(title).font(.mr(.ui, size: isSub ? 13 : 14, weight: 500)).lineLimit(1).fixedSize()
                    if shortcut != nil || badge != nil { Spacer(minLength: 0) }
                    if let shortcut { MRKbd(shortcut) }
                    if let badge { MRBadge(badge).padding(.leading, 6) }
                }
            }
            .foregroundStyle(isActive || hover ? p.text1.color : p.text2.color)
            .padding(.horizontal, isRail ? 0 : 10)
            .frame(maxWidth: isRail ? 48 : .infinity, alignment: isRail ? .center : .leading)
            .frame(width: isRail ? 48 : nil, height: isSub ? 30 : 34)
            .background {
                if isActive {
                    ZStack {
                        shape.fill(LinearGradient(colors: [tint.0.color, tint.1.color], startPoint: .topLeading, endPoint: .bottomTrailing))
                        shape.stroke(tint.2.color, lineWidth: 1).padding(-0.5)
                    }
                    .shadow(color: tint.3.color, radius: tint.4 / 2)
                } else if hover {
                    shape.fill(p.fill1.color)
                }
            }
            .mrFocusRing(isFocused, cornerRadius: 12, color: p.accent1.color)
            .contentShape(shape)
            .animation(MRMotion.ease(MRMotion.d2), value: isActive)
            .animation(MRMotion.ease(MRMotion.d2), value: hover)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}

/// The sidebar's "In flight" capsule (`.sbx .live`): pulsing dot, eyebrow, mono time and a chevron; in `isRail` only the dot.
public struct MRLiveCapsule: View {
    private let time: String
    private let isRail: Bool
    private let action: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    public init(time: String, isRail: Bool = false, action: @escaping () -> Void = {}) {
        self.time = time; self.isRail = isRail; self.action = action
    }

    public var body: some View {
        let p = MRPalette.resolve(scheme)
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        Button(action: action) {
            HStack(spacing: 10) {
                Circle().fill(p.accent1.color).frame(width: 8, height: 8)
                    .opacity(dim ? 0.4 : 1).scaleEffect(dim ? 0.8 : 1)
                if !isRail {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("In flight").font(.mr(.ui, size: 10, weight: 500)).tracking(0.8).textCase(.uppercase)
                            .foregroundStyle(p.text2.color).frame(height: 12)
                        Text(time).font(.mr(.mono, size: 15, weight: 600)).foregroundStyle(p.text1.color).frame(height: 18)
                    }
                    Spacer(minLength: 0)
                    MRIcon(.chevR, size: 14).foregroundStyle(p.text2.color)
                }
            }
            .padding(.horizontal, isRail ? 0 : 12)
            .frame(width: isRail ? 48 : nil, height: 44)
            .frame(maxWidth: isRail ? 48 : .infinity, alignment: isRail ? .center : .leading)
            .background {
                shape.fill(LinearGradient(colors: [MRColorToken(106, 183, 255, 0.22).color, MRColorToken(139, 243, 216, 0.10).color],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(shape.stroke(MRColorToken(106, 183, 255, 0.34).color, lineWidth: 1).padding(-0.5))
                    .shadow(color: MRColorToken(106, 183, 255, 0.16).color, radius: 12)
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { dim = true }
        }
        .accessibilityLabel("In flight, \(time) remaining")
    }
}

#Preview("MRNavItem") {
    VStack(alignment: .leading, spacing: 2) {
        MRNavItem("Plan", icon: .plane, shortcut: "⌘1", isActive: true)
        MRNavItem("Tickets", icon: .ticket, shortcut: "⌘2")
        MRNavItem("Cards", icon: .card, isSub: true)
        MRLiveCapsule(time: "24:10")
    }
    .padding(12).frame(width: 220).background(MRPalette.dark.bg1.color).preferredColorScheme(.dark)
}
