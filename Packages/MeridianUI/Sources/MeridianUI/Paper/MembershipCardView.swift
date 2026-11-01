import SwiftUI

public enum MembershipTier: String, CaseIterable, Sendable {
    case departure, cruise, jetstream, gold, equator, obsidian

    public var title: String {
        switch self {
        case .departure: "Departure"
        case .cruise: "Cruise"
        case .jetstream: "Jetstream"
        case .gold: "Meridian Gold"
        case .equator: "Equator"
        case .obsidian: "Obsidian"
        }
    }
    public var tagline: String {
        switch self {
        case .departure: "Every route begins somewhere."
        case .cruise: "Altitude is a kind of calm."
        case .jetstream: "Carried by the current."
        case .gold: "The line everything is measured from."
        case .equator: "Once around the world."
        case .obsidian: "Beyond the horizon line."
        }
    }
    /// Distance threshold in km (K.tiers).
    public var thresholdKm: Int {
        switch self {
        case .departure: 0
        case .cruise: 1000
        case .jetstream: 5000
        case .gold: 20000
        case .equator: 40075
        case .obsidian: 100000
        }
    }
    public var next: MembershipTier? {
        let all = MembershipTier.allCases
        return all.firstIndex(of: self).flatMap { $0 + 1 < all.count ? all[$0 + 1] : nil }
    }
    public static func highest(forKm km: Int) -> MembershipTier { allCases.last { km >= $0.thresholdKm } ?? .departure }
}

public enum MembershipCardSize: Sendable {
    case list, hero
    var width: CGFloat { self == .hero ? 480 : 340 }
    var scale: CGFloat { width / 340 }
}

/// Member data printed on the card (K.me).
public struct MembershipCardInfo: Sendable, Hashable {
    public var memberName = "Elif Kaya"
    public var memberNumber = "0048 1317 2204"
    public var since = "MAR 2025"
    public var distanceKm = 12022
    public var flights = 87
    public var hours = "94.5"
    public init() {}
    public init(memberName: String, memberNumber: String, since: String, distanceKm: Int, flights: Int, hours: String) {
        self.memberName = memberName; self.memberNumber = memberNumber; self.since = since
        self.distanceKm = distanceKm; self.flights = flights; self.hours = hours
    }
}

/// Membership card (Card.dc.html, R02). One card; the coverflow lives elsewhere.
/// Pointer-driven tilt (rotateY = x * 28, rotateX = -y * 28, so +-14 degrees at the edge, perspective 900, lift 10),
/// specular glare, hue-shifting foil, brushed-metal sunburst, 6 s idle shimmer, 700 ms bouncy flip, locked state.
/// Reduce Motion: no tilt, no shimmer; a static glare keeps the metal bright.
public struct MembershipCardView: View {
    let tier: MembershipTier
    let size: MembershipCardSize
    let locked: Bool
    let info: MembershipCardInfo
    let live: Bool
    let pose: CGPoint?
    let idlePhase: Double?
    @Binding var flipped: Bool
    @State private var pointer: CGPoint? = nil      // -0.5...0.5
    @State private var entering = false             // first contact eases in; afterwards the tilt follows the pointer closely
    @State private var localFlip = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - pose: fixed pointer position in -0.5...0.5 (for static renders); `live` cards track the real pointer.
    ///   - flipped: back face.
    ///   - idlePhase: freezes the idle shimmer at a point of its 6 s loop (0...1) for static renders; nil runs it.
    public init(tier: MembershipTier, size: MembershipCardSize = .list, locked: Bool = false, info: MembershipCardInfo = .init(),
                live: Bool = false, pose: CGPoint? = nil, flipped: Binding<Bool>? = nil, idlePhase: Double? = nil) {
        self.tier = tier; self.size = size; self.locked = locked; self.info = info; self.live = live; self.pose = pose
        self.idlePhase = idlePhase
        self._flipped = flipped ?? .constant(false)
        self.usesExternalFlip = flipped != nil
    }
    private let usesExternalFlip: Bool

    private var isFlipped: Bool { usesExternalFlip ? flipped : localFlip }

    public var body: some View {
        let p = reduceMotion ? nil : (live ? pointer : pose)
        let px = Double(p?.x ?? 0), py = Double(p?.y ?? 0)
        let over = p != nil && abs(px) + abs(py) > 0.001
        let lift: CGFloat = over ? 10 : 0
        let scale = size.scale
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.01))
                .frame(width: 340, height: 214)
                .shadow(color: .black.opacity(over ? 0.4 : 0.45), radius: (40 + lift * 2) / 2, x: CGFloat(-px * 60), y: 30 + lift * 1.6 - CGFloat(py * 30))
            CardFlip(angle: isFlipped ? 180 : 0, px: px, py: py, lift: lift,
                     front: { x, y in CardFront(tier: tier, locked: locked, info: info, px: x, py: y, over: over, reduceMotion: reduceMotion, idlePhase: idlePhase) },
                     back: { x, y in CardBack(tier: tier, locked: locked, info: info, px: x, py: y, over: over) })
        }
        .frame(width: 340, height: 214, alignment: .topLeading)
        .animation(live && over && !entering ? .easeOut(duration: 0.16) : (reduceMotion ? nil : MRMotion.hoverTilt), value: pointer)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : MRMotion.bouncy, value: isFlipped)
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: 340 * scale, height: 214 * scale, alignment: .topLeading)
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            guard live else { return }
            switch phase {
            case .active(let l):
                if pointer == nil, !reduceMotion {
                    // first contact: ease towards the pointer pose, then follow it closely
                    entering = true
                    Task { @MainActor in try? await Task.sleep(for: .milliseconds(480)); entering = false }
                }
                pointer = CGPoint(x: min(0.5, max(-0.5, l.x / (340 * scale) - 0.5)), y: min(0.5, max(-0.5, l.y / (214 * scale) - 0.5)))
            case .ended: pointer = nil
            }
        }
        .onTapGesture { if live { toggle() } }
        .focusable(live)
        .onKeyPress(.return) { if live { toggle(); return .handled }; return .ignored }
        .onKeyPress(.space) { if live { toggle(); return .handled }; return .ignored }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(tier.title) membership card" + (locked ? ", locked, \(Self.fmt(max(0, tier.thresholdKm - info.distanceKm))) kilometres to unlock" : ", unlocked") + ". Press Return to flip.")
        .accessibilityAddTraits(live ? .isButton : [])
        .accessibilityAction(named: "Flip card") { toggle() }
    }

    private func toggle() { if usesExternalFlip { flipped.toggle() } else { localFlip.toggle() } }

    static func fmt(_ n: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.groupingSeparator = ","; f.locale = Locale(identifier: "en_US")
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

/// Animates the flip angle and the pointer position, and swaps faces at 90 degrees (both faces are backface-hidden in the canvas).
/// The pointer (px, py) is animatable so the glare, foil, parallax and bend shading ease with the tilt instead of stepping
/// with every pointer event (the canvas moves those gradients instantly; the owner found that harsh).
private struct CardFlip<Front: View, Back: View>: View, @preconcurrency Animatable {
    var angle: Double
    var px: Double, py: Double
    var lift: CGFloat
    let front: (Double, Double) -> Front, back: (Double, Double) -> Back
    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { .init(angle, .init(px, py)) }
        set { angle = newValue.first; px = newValue.second.first; py = newValue.second.second }
    }
    var body: some View {
        let rx = -py * 28, ry = px * 28
        let total = (ry + angle).truncatingRemainder(dividingBy: 360)
        let showFront = cos(total * .pi / 180) > 0
        Group {
            if showFront { front(px, py) } else { back(px, py).scaleEffect(x: -1, y: 1) }
        }
        .frame(width: 340, height: 214)
        .modifier(PaperTilt(rx: rx, ry: ry + angle, lift: lift, size: CGSize(width: 340, height: 214)))
    }
}

// MARK: - Tier recipes

private struct TierRecipe {
    var ink: String, soft: Double, softBase: String
    var back: Color
    var base: [(Double, String)]
    var edge: String, edgeAlpha: Double
    var foil: Double
    var chipA: String, chipB: String
    var emboss: [(Color, CGFloat)]  // y offsets +1 / -1
    var glare: Double
    var tint: String

    static func of(_ t: MembershipTier) -> TierRecipe {
        let white = Color.white
        switch t {
        case .departure:
            return .init(ink: "#14161C", soft: 0.85, softBase: "#14161C", back: white.opacity(0.42),
                         base: [(0, "#8A94A6"), (0.38, "#CCD3DE"), (0.62, "#9AA4B5"), (1, "#C3CAD6")], edge: "#BFE2FF", edgeAlpha: 0.9, foil: 0.25,
                         chipA: "#C8CFD9", chipB: "#F2F5F9", emboss: [(white.opacity(0.55), 1), (Color(hex: "#14161C").opacity(0.2), -1)], glare: 0.34, tint: "#6AB7FF")
        case .cruise:
            return .init(ink: "#F3F5FA", soft: 0.9, softBase: "#F3F5FA", back: Color(hex: "#06080D").opacity(0.42),
                         base: [(0, "#0A1D4A"), (0.46, "#1B55CC"), (1, "#0B2A6B")], edge: "#A0C8FF", edgeAlpha: 0.7, foil: 0.3,
                         chipA: "#8FB4F5", chipB: "#DCE9FF", emboss: [(white.opacity(0.25), 1), (Color(red: 0, green: 0, blue: 30 / 255).opacity(0.4), -1)], glare: 0.38, tint: "#6AB7FF")
        case .jetstream:
            return .init(ink: "#F3F5FA", soft: 0.78, softBase: "#F3F5FA", back: Color(hex: "#06080D").opacity(0.42),
                         base: [(0, "#0B1020"), (0.5, "#16224A"), (1, "#0B1020")], edge: "#8BF3D8", edgeAlpha: 0.7, foil: 1,
                         chipA: "#8BF3D8", chipB: "#E6FFF8", emboss: [(Color(hex: "#8BF3D8").opacity(0.45), 0)], glare: 0.3, tint: "#8BF3D8")
        case .gold:
            return .init(ink: "#2B1C04", soft: 0.9, softBase: "#2B1C04", back: white.opacity(0.42),
                         base: [(0, "#A07A28"), (0.36, "#E8C46A"), (0.62, "#B58B35"), (1, "#F0D58C")], edge: "#FFECAA", edgeAlpha: 0.95, foil: 0.35,
                         chipA: "#C29A52", chipB: "#F7E6B5", emboss: [(Color(red: 1, green: 244 / 255, blue: 205 / 255).opacity(0.75), 1), (Color(red: 60 / 255, green: 40 / 255, blue: 5 / 255).opacity(0.4), -1)], glare: 0.4, tint: "#FFE9A8")
        case .equator:
            return .init(ink: "#3A2E15", soft: 0.85, softBase: "#3A2E15", back: white.opacity(0.42),
                         base: [(0, "#E9DEC0"), (0.4, "#FFFFFF"), (0.7, "#E7D9B1"), (1, "#FBF4E0")], edge: "#FFFFFF", edgeAlpha: 1, foil: 0.4,
                         chipA: "#D5C49A", chipB: "#FFFCF2", emboss: [(white.opacity(0.9), 1), (Color(hex: "#3A2E15").opacity(0.18), -1)], glare: 0.45, tint: "#FFFFFF")
        case .obsidian:
            return .init(ink: "#F3F5FA", soft: 0.78, softBase: "#F3F5FA", back: Color(hex: "#06080D").opacity(0.42),
                         base: [(0, "#050608"), (0.48, "#14161C"), (1, "#08090C")], edge: "#FFFFFF", edgeAlpha: 0.75, foil: 0.9,
                         chipA: "#555B68", chipB: "#B8BECC", emboss: [(white.opacity(0.12), 1), (Color.black.opacity(0.6), -1)], glare: 0.3, tint: "#B49CFF")
        }
    }
    var inkColor: Color { Color(hex: ink) }
    var softColor: Color { Color(hex: softBase).opacity(soft) }
    var edgeColor: Color { Color(hex: edge).opacity(edgeAlpha) }
}

// MARK: - CSS gradient helpers

enum CSSGradient {
    /// `linear-gradient(<angle>deg, ...)` on a w x h box: start/end of the CSS gradient line as unit points.
    static func linear(_ stops: [Gradient.Stop], angle: Double, size: CGSize) -> LinearGradient {
        let a = angle * .pi / 180
        let dx = sin(a), dy = -cos(a)
        let len = abs(size.width * dx) + abs(size.height * dy)
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let s = CGPoint(x: c.x - dx * len / 2, y: c.y - dy * len / 2), e = CGPoint(x: c.x + dx * len / 2, y: c.y + dy * len / 2)
        return LinearGradient(stops: stops, startPoint: UnitPoint(x: s.x / size.width, y: s.y / size.height),
                              endPoint: UnitPoint(x: e.x / size.width, y: e.y / size.height))
    }

    static func hsl(_ h: Double, _ s: Double, _ l: Double, _ a: Double = 1) -> Color {
        let hh = ((h.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360) / 360
        let c = (1 - abs(2 * l - 1)) * s
        let x = c * (1 - abs((hh * 6).truncatingRemainder(dividingBy: 2) - 1))
        let m = l - c / 2
        let (r, g, b): (Double, Double, Double)
        switch Int(hh * 6) % 6 {
        case 0: (r, g, b) = (c, x, 0)
        case 1: (r, g, b) = (x, c, 0)
        case 2: (r, g, b) = (0, c, x)
        case 3: (r, g, b) = (0, x, c)
        case 4: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        return Color(.sRGB, red: r + m, green: g + m, blue: b + m, opacity: a)
    }

    /// `radial-gradient(rx ry at cx cy, stops)` with explicit radii (points) drawn into `ctx`.
    static func ellipse(_ ctx: inout GraphicsContext, size: CGSize, at c: CGPoint, rx: CGFloat, ry: CGFloat, stops: [Gradient.Stop]) {
        var g = ctx
        g.translateBy(x: c.x, y: c.y)
        g.scaleBy(x: rx, y: ry)
        let big = max(size.width, size.height) * 4 / max(1, min(rx, ry))
        g.fill(Path(CGRect(x: -big, y: -big, width: 2 * big, height: 2 * big)),
               with: .radialGradient(Gradient(stops: stops), center: .zero, startRadius: 0, endRadius: 1))
    }
}

// MARK: - Front

private struct CardFront: View {
    let tier: MembershipTier, locked: Bool, info: MembershipCardInfo
    let px: Double, py: Double, over: Bool, reduceMotion: Bool
    var idlePhase: Double? = nil
    private var R: TierRecipe { .of(tier) }
    private let size = CGSize(width: 340, height: 214)

    private func par(_ f: Double) -> CGSize { CGSize(width: -px * 12 * f, height: -py * 12 * f) }
    private var hue: Double { px * 120 + py * 60 }

    var body: some View {
        let r = R, sh = hypot(px, py)
        ZStack(alignment: .topLeading) {
            CSSGradient.linear(r.base.map { .init(color: Color(hex: $0.1), location: $0.0) }, angle: 135, size: size)
            patterns.offset(par(0))
            engraving.offset(par(0.33))
            holo(r).opacity(locked ? 0 : (r.foil >= 0.9 ? 0.16 + sh * 0.7 : r.foil * (0.1 + sh * 0.5)))
            HStack(spacing: 8) {
                MRIcon(.mark, size: 26)
                Text("MERIDIAN").font(MRFonts.font(.ui, size: 9, weight: 600)).tracking(2.7)
            }
            .foregroundStyle(r.inkColor).at(22, 18).offset(par(0.33))
            Text("NO. \(info.memberNumber)").font(MRFonts.font(.mono, size: 9.5, weight: 500)).tracking(1.14)
                .foregroundStyle(r.softColor).frame(width: 340 - 22, alignment: .trailing).at(0, 24).offset(par(0.67))
            chip(r).at(22, 66).offset(par(1))
            VStack(alignment: .leading, spacing: 2) {
                emboss(Text(tier.title).font(MRFonts.font(.serif, size: 32, weight: 600)).tracking(-0.16), r)
                    .frame(height: 36)
                Text(tier.tagline).font(MRFonts.font(.serif, size: 12.5, weight: 500, italic: true)).foregroundStyle(r.softColor).frame(height: 16)
            }
            .fixedSize().at(22, 214 - 42 - 54).offset(par(0.67))
            HStack {
                Text("MEMBER SINCE \(info.since)"); Spacer(minLength: 0); Text("\(MembershipCardView.fmt(tier.thresholdKm)) KM")
            }
            .font(MRFonts.font(.mono, size: 9.5, weight: 500)).tracking(0.95).foregroundStyle(r.softColor)
            .frame(width: 296).at(22, 214 - 16 - 9.5).offset(par(0.67))
            // bend shading, glare, glint
            Rectangle().fill(CSSGradient.linear([.init(color: .black.opacity(0), location: 0.4), .init(color: .black.opacity(min(0.26, sh * 0.55)), location: 1)],
                                                angle: atan2(py, px) * 180 / .pi + 90, size: size))
            glare(r)
            glint
            if !locked && !reduceMotion { idle.opacity(over ? 0 : 1).animation(.easeOut(duration: 0.3), value: over) }
            // rim
            RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.12), lineWidth: 1)
            RoundedRectangle(cornerRadius: 20).fill(.clear)
                .overlay(alignment: .top) { Rectangle().fill(r.edgeColor).frame(height: 1) }
            RoundedRectangle(cornerRadius: 20).strokeBorder(Color(hex: r.edge).opacity(0.55), lineWidth: 1)
        }
        .frame(width: 340, height: 214, alignment: .topLeading)
        .compositingGroup()
        // the canvas frost is `backdrop-filter: blur(3px)` over the whole face including its edge light, with clamped edges
        .blur(radius: locked ? 3 : 0)
        .background { if locked { CSSGradient.linear(r.base.map { .init(color: Color(hex: $0.1), location: $0.0) }, angle: 135, size: size) } }
        .overlay { if locked { lockOverlay(r) } }
        .modifier(LockFilter(locked: locked))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func emboss(_ t: Text, _ r: TierRecipe) -> some View {
        var v: AnyView = AnyView(t.foregroundStyle(r.inkColor))
        for (c, y) in r.emboss { v = AnyView(v.shadow(color: c, radius: 0, x: 0, y: y)) }
        return v
    }

    // MARK: patterns
    @ViewBuilder private var patterns: some View {
        Canvas { ctx, sz in
            switch tier {
            case .departure:
                var x: CGFloat = 0
                while x < sz.width {   // repeating-linear-gradient(90deg, white .07 0-1px, ink .05 1-2px)
                    ctx.fill(Path(CGRect(x: x, y: 0, width: 1, height: sz.height)), with: .color(.white.opacity(0.07)))
                    ctx.fill(Path(CGRect(x: x + 1, y: 0, width: 1, height: sz.height)), with: .color(Color(hex: "#14161C").opacity(0.05)))
                    x += 2
                }
                CSSGradient.ellipse(&ctx, size: sz, at: CGPoint(x: 0.2 * sz.width, y: 0), rx: 1.2 * sz.width, ry: 0.9 * sz.height,
                                    stops: [.init(color: .white.opacity(0.35), location: 0), .init(color: .white.opacity(0), location: 0.6)])
            case .cruise:
                CSSGradient.ellipse(&ctx, size: sz, at: CGPoint(x: 0.8 * sz.width, y: 0), rx: 0.9 * sz.width, ry: 0.8 * sz.height,
                                    stops: [.init(color: Color(red: 150 / 255, green: 200 / 255, blue: 1).opacity(0.35), location: 0), .init(color: .clear, location: 0.6)])
                ctx.fill(Path(CGRect(origin: .zero, size: sz)), with: .linearGradient(Gradient(stops: [.init(color: .white.opacity(0.12), location: 0), .init(color: .clear, location: 0.4)]),
                                                                                     startPoint: .zero, endPoint: CGPoint(x: 0, y: sz.height)))
            case .jetstream:
                CSSGradient.ellipse(&ctx, size: sz, at: CGPoint(x: 0.78 * sz.width, y: 0.2 * sz.height), rx: 0.6 * sz.width, ry: 0.7 * sz.height,
                                    stops: [.init(color: Color(hex: "#8BF3D8").opacity(0.22), location: 0), .init(color: .clear, location: 0.7)])
                CSSGradient.ellipse(&ctx, size: sz, at: CGPoint(x: 0.18 * sz.width, y: 0.9 * sz.height), rx: 0.5 * sz.width, ry: 0.6 * sz.height,
                                    stops: [.init(color: Color(hex: "#B49CFF").opacity(0.22), location: 0), .init(color: .clear, location: 0.7)])
            case .gold:
                let c = CGPoint(x: 0.76 * sz.width, y: 0.46 * sz.height)
                var a = 0.0   // repeating-conic: white .12 for .7deg, dark .12 for .8deg (from 12 o'clock, clockwise)
                while a < 360 {
                    for (len, col) in [(0.7, Color.white.opacity(0.12)), (0.8, Color(red: 60 / 255, green: 35 / 255, blue: 0).opacity(0.12))] {
                        var w = Path(); w.move(to: c)
                        w.addArc(center: c, radius: 700, startAngle: .degrees(a - 90), endAngle: .degrees(a - 90 + len), clockwise: false)
                        w.closeSubpath()
                        ctx.fill(w, with: .color(col)); a += len
                    }
                }
                let a0 = atan2(py, px) * 180 / .pi
                let hi = Color(red: 1, green: 250 / 255, blue: 220 / 255)
                let g = Gradient(stops: [.init(color: hi.opacity(0), location: 0), .init(color: hi.opacity(0.22 + min(0.3, hypot(px, py))), location: 0.12),
                                         .init(color: hi.opacity(0), location: 0.26), .init(color: hi.opacity(0), location: 0.5),
                                         .init(color: hi.opacity(0.2), location: 0.62), .init(color: hi.opacity(0), location: 0.76), .init(color: hi.opacity(0), location: 1)])
                ctx.fill(Path(CGRect(origin: .zero, size: sz)), with: .conicGradient(g, center: c, angle: .degrees(a0 + 90 - 90)))
            case .equator:
                CSSGradient.ellipse(&ctx, size: sz, at: CGPoint(x: 0.8 * sz.width, y: 0.2 * sz.height), rx: 0.7 * sz.width, ry: 0.9 * sz.height,
                                    stops: [.init(color: .white.opacity(0.7), location: 0), .init(color: .clear, location: 0.7)])
            case .obsidian:
                CSSGradient.ellipse(&ctx, size: sz, at: CGPoint(x: 0.3 * sz.width, y: 0), rx: 0.8 * sz.width, ry: 0.6 * sz.height,
                                    stops: [.init(color: .white.opacity(0.07), location: 0), .init(color: .clear, location: 0.7)])
            }
        }
        .frame(width: 340, height: 214)
    }

    // MARK: engraving (cruise meridians, equator guilloche). Jetstream / obsidian engravings reference an undefined gradient
    // in the canvas and render nothing there, so they are not drawn here either.
    @ViewBuilder private var engraving: some View {
        Canvas { ctx, _ in
            switch tier {
            case .cruise:
                let cx = 238.0, cy = 107.0, Rg = 118.0
                let col = GraphicsContext.Shading.color(Color(hex: "#CFE0FF").opacity(0.22))
                for i in -4...4 {
                    let rx = max(abs(Double(i)) / 4 * Rg, 0.01)
                    var p = Path(); p.move(to: CGPoint(x: cx, y: cy - Rg))
                    p.addEllipse(in: CGRect(x: cx - rx, y: cy - Rg, width: 2 * rx, height: 2 * Rg))
                    ctx.stroke(p, with: col, lineWidth: 0.8)
                }
                for j in -3...3 {
                    let y = cy + Double(j) * Rg / 3.4, hw = sqrt(max(0, Rg * Rg - pow(Double(j) * Rg / 3.4, 2)))
                    var p = Path(); p.move(to: CGPoint(x: cx - hw, y: y))
                    p.addQuadCurve(to: CGPoint(x: cx + hw, y: y), control: CGPoint(x: cx, y: y + Double(j) * 6))
                    ctx.stroke(p, with: col, style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
                }
            case .equator:
                func ros(_ cx: Double, _ cy: Double, _ Rr: Double, _ r: Double, _ d: Double, _ n: Int, _ op: Double) {
                    var p = Path()
                    for i in 0...n {
                        let t = Double(i) / Double(n) * .pi * 2 * r
                        let x = (Rr - r) * cos(t) + d * cos((Rr - r) / r * t), y = (Rr - r) * sin(t) - d * sin((Rr - r) / r * t)
                        let pt = CGPoint(x: cx + x, y: cy + y)
                        i == 0 ? p.move(to: pt) : p.addLine(to: pt)
                    }
                    ctx.stroke(p, with: .color(Color(hex: "#B8995A").opacity(op)), style: StrokeStyle(lineWidth: 0.55, lineCap: .round))
                }
                ros(236, 107, 100, 13, 62, 560, 0.55); ros(236, 107, 84, 11, 50, 460, 0.4); ros(236, 107, 66, 7, 40, 300, 0.45)
                ctx.stroke(Path(ellipseIn: CGRect(x: 136, y: 7, width: 200, height: 200)), with: .color(Color(hex: "#B8995A").opacity(0.7)), lineWidth: 1)
            default: break
            }
        }
        .frame(width: 340, height: 214)
    }

    // MARK: holo foil
    private func holo(_ r: TierRecipe) -> some View {
        let ang = 135 + px * 120
        let gx = (px + 0.5) * 100, gy = (py + 0.5) * 100
        let hues = [160.0, 220, 290, 345, 35, 160]
        let colors = hues.enumerated().map { i, h in CSSGradient.hsl(h + hue, 0.62, i == 2 ? 0.74 : i == 3 || i == 4 ? 0.72 : 0.70) }
        return Rectangle()
            .fill(AngularGradient(gradient: Gradient(colors: colors), center: UnitPoint(x: (30 + gx * 0.4) / 100, y: (30 + gy * 0.4) / 100), angle: .degrees(ang - 90 - 90)))
            .mask {
                Canvas { ctx, sz in
                    // repeating-linear-gradient(115deg, #000 0 1px, rgba(0,0,0,.18) 1px 4px)
                    ctx.fill(Path(CGRect(origin: .zero, size: sz)), with: .color(.black.opacity(0.18)))
                    let a = 115.0 * .pi / 180, dx = sin(a), dy = -cos(a)
                    let len = abs(sz.width * dx) + abs(sz.height * dy)
                    var t = -len / 2
                    while t < len / 2 {
                        var line = Path()
                        let c = CGPoint(x: sz.width / 2 + dx * (t + 0.5), y: sz.height / 2 + dy * (t + 0.5))
                        line.move(to: CGPoint(x: c.x - dy * 600, y: c.y + dx * 600)); line.addLine(to: CGPoint(x: c.x + dy * 600, y: c.y - dx * 600))
                        ctx.stroke(line, with: .color(.black), lineWidth: 1)
                        t += 4
                    }
                }
            }
            .blendMode(r.foil >= 0.9 ? .screen : .overlay)
    }

    private func chip(_ r: TierRecipe) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(LinearGradient(colors: [Color(hex: r.chipA), Color(hex: r.chipB), Color(hex: r.chipA)], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 6).strokeBorder(.black.opacity(0.35), lineWidth: 1)
            Path { p in
                p.move(to: CGPoint(x: 13, y: 0.5)); p.addLine(to: CGPoint(x: 13, y: 29.5))
                p.move(to: CGPoint(x: 27, y: 0.5)); p.addLine(to: CGPoint(x: 27, y: 29.5))
                p.move(to: CGPoint(x: 0.5, y: 10)); p.addLine(to: CGPoint(x: 39.5, y: 10))
                p.move(to: CGPoint(x: 0.5, y: 20)); p.addLine(to: CGPoint(x: 39.5, y: 20))
                p.addRoundedRect(in: CGRect(x: 13, y: 10, width: 14, height: 10), cornerSize: CGSize(width: 2, height: 2))
            }.stroke(.black.opacity(0.32), lineWidth: 1)
        }
        .frame(width: 40, height: 30)
    }

    private func glare(_ r: TierRecipe) -> some View {
        let gx = (px + 0.5), gy = (py + 0.5)
        let opacity: Double = locked ? 0.12 : (over ? 1 : (reduceMotion ? 0.55 : 0))
        let cx = reduceMotion && !over ? 0.3 : gx, cy = reduceMotion && !over ? 0.25 : gy
        return Canvas { ctx, sz in
            // radial-gradient(circle at x% y%, white a, transparent 60%): circle, farthest-corner radius
            let c = CGPoint(x: cx * sz.width, y: cy * sz.height)
            let far = max(hypot(c.x, c.y), hypot(sz.width - c.x, c.y), hypot(c.x, sz.height - c.y), hypot(sz.width - c.x, sz.height - c.y))
            ctx.fill(Path(CGRect(origin: .zero, size: sz)),
                     with: .radialGradient(Gradient(stops: [.init(color: .white.opacity(r.glare), location: 0), .init(color: .white.opacity(0), location: 0.6)]),
                                           center: c, startRadius: 0, endRadius: far))
        }
        .blendMode(.softLight)
        .opacity(opacity)
        .animation(.timingCurve(0.2, 0, 0, 1, duration: 0.42), value: over)
        .allowsHitTesting(false)
    }

    @ViewBuilder private var glint: some View {
        if over && !locked {
            let horiz = abs(px) >= abs(py)
            let g: LinearGradient = horiz
                ? CSSGradient.linear([.init(color: .white.opacity(0.55), location: 0), .init(color: .white.opacity(0), location: 0.03)], angle: px > 0 ? 270 : 90, size: size)
                : CSSGradient.linear([.init(color: .white.opacity(0.55), location: 0), .init(color: .white.opacity(0), location: 0.04)], angle: py > 0 ? 0 : 180, size: size)
            Rectangle().fill(g).opacity(0.9).allowsHitTesting(false)
        }
    }

    /// The canvas band (clear 35 %, white .3 at 48 %, .06 at 52 %, clear 62 %) with eased ramps: the same peak and width,
    /// but smoothstep intermediate stops so the sweep has no visible edge or banding.
    private static let shimmerStops: [Gradient.Stop] = {
        func ramp(_ l0: Double, _ a0: Double, _ l1: Double, _ a1: Double, n: Int = 6) -> [Gradient.Stop] {
            (0...n).map { i in
                let t = Double(i) / Double(n), e = t * t * (3 - 2 * t)
                return .init(color: .white.opacity(a0 + (a1 - a0) * e), location: l0 + (l1 - l0) * t)
            }
        }
        return ramp(0.35, 0, 0.48, 0.3) + ramp(0.48, 0.3, 0.52, 0.06, n: 3).dropFirst() + ramp(0.52, 0.06, 0.62, 0).dropFirst()
    }()

    /// `cd-idle`: 6 s loop, 115 degree sweep during the last 38 %.
    private var idle: some View {
        TimelineView(.animation(paused: idlePhase != nil)) { tl in
            let f = idlePhase ?? tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6) / 6
            let u = f < 0.62 ? 0 : (f - 0.62) / 0.38
            let e = SplitFlapLogic.bezier(0.42, 0, 0.58, 1, u)
            let pos = 1.4 + (-0.4 - 1.4) * e
            let w: CGFloat = 340 * 2.6
            Rectangle()
                .fill(CSSGradient.linear(Self.shimmerStops, angle: 115, size: CGSize(width: w, height: 214)))
                .frame(width: w, height: 214)
                .offset(x: (340 - w) * pos)
                .frame(width: 340, height: 214, alignment: .topLeading)
        }
        .allowsHitTesting(false)
    }

    private func lockOverlay(_ r: TierRecipe) -> some View {
        let toGo = max(0, tier.thresholdKm - info.distanceKm)
        let frac = min(1, Double(info.distanceKm) / Double(max(1, tier.thresholdKm)))
        return ZStack {
            Rectangle().fill(Color(red: 18 / 255, green: 26 / 255, blue: 46 / 255).opacity(0.42))
            VStack(spacing: 8) {
                ZStack {
                    Circle().stroke(.white.opacity(0.2), lineWidth: 3).frame(width: 50, height: 50)
                    Circle().trim(from: 0, to: frac).stroke(Color(hex: r.tint), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90)).frame(width: 50, height: 50)
                    MRIcon(.lock, size: 20).foregroundStyle(Color(hex: "#F3F5FA"))
                }
                .frame(width: 58, height: 58)
                Text("\(MembershipCardView.fmt(toGo)) km to unlock")
                    .font(MRFonts.font(.mono, size: 13, weight: 600)).tracking(0.26).foregroundStyle(Color(hex: "#F3F5FA"))
            }
        }
    }
}

private struct LockFilter: ViewModifier {
    let locked: Bool
    func body(content: Content) -> some View {
        if locked { content.grayscale(0.75).colorMultiply(Color(white: 0.78)).saturation(0.6) } else { content }
    }
}

// MARK: - Back

private struct CardBack: View {
    let tier: MembershipTier, locked: Bool, info: MembershipCardInfo
    let px: Double, py: Double, over: Bool
    private var R: TierRecipe { .of(tier) }
    private let size = CGSize(width: 340, height: 214)

    var body: some View {
        let r = R
        let next = tier.next
        let nextGo = next.map { max(0, $0.thresholdKm - info.distanceKm) } ?? 0
        // the canvas ignores a negative width (CSS) and shows a full bar
        let frac = next.map { n -> Double in let f = Double(info.distanceKm - tier.thresholdKm) / Double(n.thresholdKm - tier.thresholdKm); return f < 0 ? 1 : min(1, f) } ?? 1
        ZStack(alignment: .topLeading) {
            CSSGradient.linear(r.base.map { .init(color: Color(hex: $0.1), location: $0.0) }, angle: 135, size: size)
            Rectangle().fill(r.back)
            Rectangle().fill(LinearGradient(colors: [Color(hex: "#07080B"), Color(hex: "#171A20"), Color(hex: "#0A0B0E")],
                                            startPoint: .top, endPoint: .bottom)).frame(width: 340, height: 34)
                .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.14)).frame(height: 1).offset(y: 1) }
                .at(0, 22)
            HStack(spacing: 10) {
                stat("Distance", "\(MembershipCardView.fmt(info.distanceKm)) km", r)
                stat("Flights", "\(info.flights)", r)
                stat("Hours", "\(info.hours) h", r)
            }
            .frame(width: 296).at(22, 70)
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Next card: \(next?.title ?? "Top tier")").font(MRFonts.font(.serif, size: 13, weight: 500)).foregroundStyle(r.inkColor)
                    Spacer(minLength: 0)
                    Text("\(next != nil ? MembershipCardView.fmt(nextGo) : "0") km").font(MRFonts.font(.mono, size: 10.5, weight: 500)).foregroundStyle(r.softColor)
                }
                ZStack(alignment: .leading) {
                    Capsule().fill(.black.opacity(0.28))
                    Capsule().fill(Color(hex: r.tint)).frame(width: 296 * frac).shadow(color: Color(hex: r.tint), radius: 4)
                }
                .frame(height: 5).clipShape(Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
            }
            .frame(width: 296).at(22, 128)
            HStack {
                ZStack(alignment: .leading) {
                    Canvas { ctx, sz in
                        var x = -sz.height
                        while x < sz.width + sz.height {
                            var p = Path()
                            p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x + 3, y: 0)); p.addLine(to: CGPoint(x: x + 3 + sz.height, y: sz.height)); p.addLine(to: CGPoint(x: x + sz.height, y: sz.height)); p.closeSubpath()
                            ctx.fill(p, with: .color(.white.opacity(0.55))); x += 6 * 1.414 * 0.707 * 2 / 2
                        }
                    }
                    Text(info.memberName).font(MRFonts.font(.serif, size: 11, weight: 500, italic: true)).foregroundStyle(Color(hex: "#14110F")).padding(.leading, 8)
                }
                .frame(width: 150, height: 24).background(Color.white.opacity(0.25)).clipShape(RoundedRectangle(cornerRadius: 5))
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    MRIcon(.share, size: 12)
                    Text("Share").font(MRFonts.font(.mono, size: 11, weight: 500))
                }
                .foregroundStyle(r.inkColor).padding(.horizontal, 12).frame(height: 26)
                .overlay(Capsule().strokeBorder(r.softColor, lineWidth: 1))
            }
            .frame(width: 296, height: 26).at(22, 214 - 16 - 26)
            RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.12), lineWidth: 1)
            RoundedRectangle(cornerRadius: 20).fill(.clear).overlay(alignment: .top) { Rectangle().fill(r.edgeColor).frame(height: 1) }
        }
        .frame(width: 340, height: 214, alignment: .topLeading)
        .compositingGroup()
        .modifier(LockFilter(locked: locked))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func stat(_ cap: String, _ v: String, _ r: TierRecipe) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(cap.uppercased()).font(MRFonts.font(.ui, size: 9, weight: 500)).tracking(1.08).foregroundStyle(r.softColor)
            Text(v).font(MRFonts.font(.mono, size: 15, weight: 600)).foregroundStyle(r.inkColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("MembershipCardView") {
    VStack(spacing: 20) {
        ForEach(MembershipTier.allCases, id: \.self) { MembershipCardView(tier: $0, live: true) }
    }
    .padding(40).background(MRPalette.dark.bg0.color)
}
