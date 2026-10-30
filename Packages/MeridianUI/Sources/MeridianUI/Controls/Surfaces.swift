import SwiftUI

// MARK: - Inset shadow / highlight (CSS `box-shadow: inset x y blur spread color`)

/// Draws a CSS inset box-shadow inside `shape`. Use as an `overlay`.
public struct MRInsetShadow<S: InsettableShape>: View {
    let shape: S
    let color: Color
    var x: CGFloat = 0
    var y: CGFloat = 0
    var blur: CGFloat = 0
    var spread: CGFloat = 0

    public init(_ shape: S, color: Color, x: CGFloat = 0, y: CGFloat = 0, blur: CGFloat = 0, spread: CGFloat = 0) {
        self.shape = shape; self.color = color; self.x = x; self.y = y; self.blur = blur; self.spread = spread
    }

    public var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size)
            Path { p in
                p.addRect(rect.insetBy(dx: -400, dy: -400))
                p.addPath(shape.inset(by: spread).path(in: rect))
            }
            .fill(color, style: FillStyle(eoFill: true))
            .offset(x: x, y: y)
            .blur(radius: blur / 2)
        }
        .clipShape(shape)
        .allowsHitTesting(false)
    }
}

// MARK: - Outer shadow that does not show through a translucent surface (CSS clips box-shadow to outside the box)

private struct MROuterShadow<S: Shape>: ViewModifier {
    let shape: S
    let shadows: [MRShadow]

    func body(content: Content) -> some View {
        content.background {
            ZStack {
                ForEach(Array(shadows.enumerated()), id: \.offset) { _, s in
                    shape.fill(Color.black).shadow(color: s.color.color, radius: s.radius, x: s.x, y: s.y)
                }
            }
            .compositingGroup()
            .mask {
                Rectangle().padding(-160)
                    .overlay { shape.fill(Color.black).blendMode(.destinationOut) }
                    .compositingGroup()
            }
            .allowsHitTesting(false)
        }
    }
}

public extension View {
    /// CSS outer `box-shadow` layers drawn only outside `shape`.
    func mrOuterShadow<S: Shape>(_ shape: S, _ shadows: [MRShadow]) -> some View {
        modifier(MROuterShadow(shape: shape, shadows: shadows))
    }

    /// `outline: 2px solid var(--accent-1); outline-offset: 2px` following the corner radius.
    func mrFocusRing(_ active: Bool, cornerRadius: CGFloat, offset: CGFloat = MRFocus.offset, color: Color) -> some View {
        overlay {
            if active {
                RoundedRectangle(cornerRadius: cornerRadius + offset, style: .continuous)
                    .strokeBorder(color, lineWidth: MRFocus.width)
                    .padding(-(offset + MRFocus.width))
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Glass

public enum MRElevation: Sendable {
    case e1, e2, e3

    public func shadow(_ p: MRPalette) -> MRShadow {
        switch self {
        case .e1: p.e1
        case .e2: p.e2
        case .e3: p.e3
        }
    }
}

private struct MRGlassSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    let elevation: MRElevation
    let shadowOn: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let p = MRPalette.resolve(scheme)
        let solid = reduceTransparency || contrast == .increased
        content
            .background {
                ZStack {
                    if solid {
                        // [data-a11y~=reduce-transparency] .glass: background bg-2, no blur.
                        shape.fill(p.bg2.color)
                    } else {
                        // backdrop-filter: blur(40px) saturate(1.6) — SwiftUI materials stand in for the configurable blur.
                        shape.fill(.ultraThinMaterial)
                        shape.fill(p.glassTint.color)
                        shape.fill(LinearGradient(
                            stops: [.init(color: p.glassSpec.color, location: 0), .init(color: MRGlass.specMid.color, location: MRGlass.specMidAt), .init(color: MRGlass.specEnd.color, location: 1)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                }
            }
            .overlay {
                // inset 0 1px 0 var(--stroke-glow), inside the 1px border.
                MRInsetShadow(shape.inset(by: 1), color: p.strokeGlow.color, y: 1)
            }
            .overlay {
                shape.strokeBorder(contrast == .increased ? Color.white.opacity(0.6) : p.strokeHair.color, lineWidth: 1)
            }
            .mrOuterShadow(shape, shadowOn ? [elevation.shadow(p)] : [])
    }
}

public extension View {
    /// The canvas `.glass` material (`.e1/.e2/.e3` elevation) on a rounded rectangle.
    func mrGlass(cornerRadius: CGFloat, elevation: MRElevation = .e3, shadow: Bool = true) -> some View {
        modifier(MRGlassSurface(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), elevation: elevation, shadowOn: shadow))
    }

    /// The canvas `.glass` material on any inset shape (e.g. `Capsule()`).
    func mrGlass<S: InsettableShape>(in shape: S, elevation: MRElevation = .e3, shadow: Bool = true) -> some View {
        modifier(MRGlassSurface(shape: shape, elevation: elevation, shadowOn: shadow))
    }

    /// `.glass-ctl`: white wash on hover (.06 dark / .5 light) and press (.03).
    func mrGlassControlWash<S: Shape>(_ shape: S, hovering: Bool, pressed: Bool, dark: Bool) -> some View {
        overlay {
            shape.fill(Color.white)
                .opacity(pressed ? MRGlass.pressedWash : hovering ? MRGlass.hoverWash(dark: dark) : 0)
                .animation(MRMotion.ease(MRMotion.d1), value: hovering)
                .allowsHitTesting(false)
        }
    }
}
