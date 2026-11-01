import AppKit
import MeridianUI
import SwiftUI

/// S34 spread (Passport.dc.html): two 486 x 600 paper pages with guilloche, captions and stamps, page turning by
/// dragging the page edge (peel corner), Enter or arrows. 3D with `perspective: 2400px` about the spread center.
struct PassportBook: View {
    enum Side { case left, right }

    let layout: PassportLayout
    let animIndex: Int
    @Binding var spread: Int

    private struct Flip: Equatable { var dir: Int; var u: Double }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0
    @State private var flip: Flip?
    @State private var busy = false
    @State private var dragging = false
    @State private var grabX0: CGFloat = 0
    @State private var grabDir = 0
    @State private var lastU = 0.0

    private var n: Int { layout.spreadCount }
    private var current: Int { max(0, min(n - 1, shown)) }

    var body: some View {
        let canL = current > 0, canR = current < n - 1
        ZStack(alignment: .topLeading) {
            faces
            // spine shadow
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: Color(red: 30 / 255, green: 20 / 255, blue: 8 / 255).opacity(0.34), location: 0.46),
                .init(color: Color(red: 30 / 255, green: 20 / 255, blue: 8 / 255).opacity(0.44), location: 0.5),
                .init(color: Color(red: 30 / 255, green: 20 / 255, blue: 8 / 255).opacity(0.34), location: 0.54),
                .init(color: .clear, location: 1),
            ], startPoint: .leading, endPoint: .trailing)
                .frame(width: 26, height: 600).offset(x: 480).zIndex(20).allowsHitTesting(false)
            EdgeZone(dir: -1, enabled: canL && !reduceMotion, dragging: dragging && grabDir == -1,
                     onGrab: { grab($0, -1) }, onMove: move, onRelease: release, onTurn: { turn(-1) })
                .offset(x: 0).zIndex(30)
                .accessibilityLabel("Turn back to the previous spread")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { turn(-1) }
            EdgeZone(dir: 1, enabled: canR && !reduceMotion, dragging: dragging && grabDir == 1,
                     onGrab: { grab($0, 1) }, onMove: move, onRelease: release, onTurn: { turn(1) })
                .offset(x: 928).zIndex(30)
                .accessibilityLabel("Turn to the next spread")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { turn(1) }
        }
        .frame(width: 982, height: 600, alignment: .topLeading)
        .coordinateSpace(name: "book")
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Passport, spread \(current + 1) of \(n)")
        .onAppear { shown = spread }
        .onChange(of: spread) { old, new in
            guard new != shown else { return }
            if abs(new - shown) == 1, !busy { turn(new - shown) } else { flip = nil; shown = new }
        }
        .onChange(of: layout.year) { _, _ in flip = nil; shown = spread }
        .onChange(of: layout.scenario) { _, _ in flip = nil; shown = spread }
    }

    // MARK: Faces

    @ViewBuilder private var faces: some View {
        let s = current
        if let f = flip, s + f.dir >= 0, s + f.dir < n {
            let a = f.u * 180, sn = sin(f.u * .pi)
            let cast = LinearGradient(colors: [Color(red: 20 / 255, green: 12 / 255, blue: 4 / 255).opacity(0.36 * sn), .clear],
                                      startPoint: f.dir == 1 ? .trailing : .leading, endPoint: f.dir == 1 ? UnitPoint(x: 0.38, y: 0.5) : UnitPoint(x: 0.62, y: 0.5))
            let leaf = LinearGradient(colors: [Color(red: 20 / 255, green: 12 / 255, blue: 4 / 255).opacity(0.42 * sn),
                                               Color(red: 255 / 255, green: 248 / 255, blue: 230 / 255).opacity(0.14 * sn)],
                                      startPoint: f.dir == 1 ? .trailing : .leading, endPoint: f.dir == 1 ? .leading : .trailing)
            if f.dir == 1 {
                face(s, .left, left: 0, angle: 0, ox: 0, z: 1, shade: nil)
                face(s + 1, .right, left: 496, angle: 0, ox: 0, z: 1, shade: cast)
                face(s, .right, left: 496, angle: -a, ox: -5, z: 6, shade: leaf)
                face(s + 1, .left, left: 0, angle: 180 - a, ox: 491, z: 6, shade: leaf)
            } else {
                face(s - 1, .left, left: 0, angle: 0, ox: 0, z: 1, shade: cast)
                face(s, .right, left: 496, angle: 0, ox: 0, z: 1, shade: nil)
                face(s, .left, left: 0, angle: a, ox: 491, z: 6, shade: leaf)
                face(s - 1, .right, left: 496, angle: a - 180, ox: -5, z: 6, shade: leaf)
            }
        } else {
            face(s, .left, left: 0, angle: 0, ox: 0, z: 1, shade: nil)
            face(s, .right, left: 496, angle: 0, ox: 0, z: 1, shade: nil)
        }
    }

    private func face(_ sp: Int, _ side: Side, left: CGFloat, angle: Double, ox: CGFloat, z: Double, shade: LinearGradient?) -> some View {
        PassportPage(model: layout.page(spread: sp, side: side, animIndex: animIndex), shade: shade)
            .opacity(cos(angle * .pi / 180) > 0.0001 ? 1 : 0)   // backface-visibility: hidden
            .modifier(PageLeafEffect(angle: angle, left: Double(left), originX: Double(ox)))
            .zIndex(z)
    }

    // MARK: Turning

    private func commit(_ dir: Int) {
        shown += dir
        flip = nil
        dragging = false
        busy = false
        spread = shown
    }

    private func turn(_ dir: Int, from: Double = 0) {
        let t = shown + dir
        guard t >= 0, t < n, !busy else { return }
        if reduceMotion { commit(dir); return }
        busy = true
        MRSound.shared.play(.paperSlide)
        flip = Flip(dir: dir, u: from)
        let dur = 0.52 * (1 - from * 0.6)
        withAnimation(.timingCurve(0.65, 0, 0.35, 1, duration: dur)) { flip?.u = 1 } completion: { commit(dir) }
    }

    private func grab(_ x: CGFloat, _ dir: Int) {
        let t = shown + dir
        guard t >= 0, t < n, !busy, !reduceMotion else { return }
        grabX0 = x; grabDir = dir; lastU = 0
        dragging = true
        var tr = Transaction(); tr.disablesAnimations = true
        withTransaction(tr) { flip = Flip(dir: dir, u: 0.001) }
    }

    private func move(_ x: CGFloat) {
        guard dragging, grabDir != 0 else { return }
        let ax = grabDir == 1 ? x : 982 - x, a0 = grabDir == 1 ? grabX0 : 982 - grabX0
        let ex = max(5, min(977, ax - (a0 - 977)))
        let u = acos(max(-1, min(1, (ex - 491) / 486))) / .pi
        lastU = u
        var tr = Transaction(); tr.disablesAnimations = true
        withTransaction(tr) { flip = Flip(dir: grabDir, u: max(0.001, u)) }
    }

    private func release(velocity vx: CGFloat) {
        guard dragging else { return }
        let u = lastU, dir = grabDir
        let v = Double(vx) / 1000 * Double(dir)
        let done = u > 0.5 || (v < -0.5 && u > 0.08)
        busy = true
        dragging = false
        if done {
            withAnimation(.timingCurve(0.65, 0, 0.35, 1, duration: 0.38 * (1 - u * 0.6))) { flip?.u = 1 } completion: { commit(dir) }
        } else {
            withAnimation(.timingCurve(0.65, 0, 0.35, 1, duration: 0.26 * (u + 0.3))) { flip?.u = 0 } completion: { flip = nil; busy = false }
        }
    }
}

/// The page-edge zone: grab cursor, hover peel corner (18 -> 46 pt), drag to turn, Enter / Space / arrows.
private struct EdgeZone: View {
    let dir: Int
    let enabled: Bool
    let dragging: Bool
    var onGrab: (CGFloat) -> Void
    var onMove: (CGFloat) -> Void
    var onRelease: (CGFloat) -> Void
    var onTurn: () -> Void
    @State private var hover = false
    @FocusState private var focused: Bool

    var body: some View {
        let big = enabled && (hover || focused || dragging)
        let side: CGFloat = big ? 46 : 18
        let peel = LinearGradient(stops: [
            .init(color: mrHex("#F4ECDA"), location: 0), .init(color: mrHex("#F4ECDA"), location: 0.46),
            .init(color: Color(red: 40 / 255, green: 28 / 255, blue: 10 / 255).opacity(0.34), location: 0.54),
            .init(color: .clear, location: 0.74),
        ], startPoint: dir == 1 ? .bottomTrailing : .bottomLeading, endPoint: dir == 1 ? .topLeading : .topTrailing)
        ZStack(alignment: dir == 1 ? .bottomTrailing : .bottomLeading) {
            Color.clear
            UnevenRoundedRectangle(bottomLeadingRadius: dir == -1 ? 18 : 0, bottomTrailingRadius: dir == 1 ? 18 : 0)
                .fill(peel)
                .frame(width: side, height: side)
                .opacity(big ? 1 : 0)
                .animation(MRMotion.ease(MRMotion.d2), value: big)
        }
        .frame(width: 54, height: 600)
        .contentShape(Rectangle())
        .onHover { h in
            hover = h
            if enabled { if h { NSCursor.openHand.push() } else { NSCursor.pop() } }
        }
        .gesture(DragGesture(minimumDistance: 2, coordinateSpace: .named("book"))
            .onChanged { v in
                if !dragging { onGrab(v.startLocation.x) }
                onMove(v.location.x)
            }
            .onEnded { v in onRelease(v.velocity.width) })
        .focusable(enabled)
        .focused($focused)
        .focusEffectDisabled()
        .overlay { if focused && enabled { RoundedRectangle(cornerRadius: 6).strokeBorder(MRPalette.dark.accent1.color, lineWidth: 2) } }
        .onKeyPress(.return) { onTurn(); return .handled }
        .onKeyPress(.space) { onTurn(); return .handled }
        .onKeyPress(.rightArrow) { dir == 1 ? { onTurn(); return .handled }() : .ignored }
        .onKeyPress(.leftArrow) { dir == -1 ? { onTurn(); return .handled }() : .ignored }
    }
}

/// `rotateY(angle)` about `(originX, 50 %)` of a page placed at `left`, with `perspective: 2400px` at the spread center.
struct PageLeafEffect: GeometryEffect {
    var angle: Double
    var left: Double
    var originX: Double

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    nonisolated func effectValue(size: CGSize) -> ProjectionTransform {
        let m = CSSMat4.translate(491, 300, 0) * CSSMat4.perspective(2400) * CSSMat4.translate(-491, -300, 0)
            * CSSMat4.translate(left, 0, 0) * CSSMat4.translate(originX, 300, 0) * CSSMat4.rotateY(angle) * CSSMat4.translate(-originX, -300, 0)
        return m.projection()
    }
}

// MARK: - Page

struct PassportPage: View {
    let model: PageModel
    var shade: LinearGradient?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = MRPalette.resolve(scheme)
        let left = model.side == .left
        let shape = UnevenRoundedRectangle(topLeadingRadius: left ? 18 : 4, bottomLeadingRadius: left ? 18 : 4,
                                           bottomTrailingRadius: left ? 4 : 18, topTrailingRadius: left ? 4 : 18, style: .continuous)
        let ink = p.ink.color
        let cap = Color(red: 20 / 255, green: 17 / 255, blue: 15 / 255).opacity(0.64)
        ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                p.paper.color
                LinearGradient(stops: [.init(color: .white.opacity(0.06), location: 0), .init(color: .white.opacity(0), location: 0.4)], startPoint: .top, endPoint: .bottom)
                MRPaperGrain()
                Rectangle().fill(.white.opacity(0.9)).frame(height: 1)
                Guilloche().opacity(0.07)
                LinearGradient(stops: [.init(color: .clear, location: 0.78),
                                       .init(color: Color(red: 70 / 255, green: 50 / 255, blue: 20 / 255).opacity(0.16), location: 0.98),
                                       .init(color: Color(red: 70 / 255, green: 50 / 255, blue: 20 / 255).opacity(0.28), location: 1)],
                               startPoint: left ? .leading : .trailing, endPoint: left ? .trailing : .leading)
                HStack { caption(model.tl, cap); Spacer(); caption(model.tr, cap) }
                    .padding(.horizontal, 34).padding(.top, 28)
                if model.hasHeading {
                    Text("Entries").font(.mr(.serif, size: 30, weight: 500, italic: true)).foregroundStyle(ink.opacity(0.88))
                        .frame(height: 34, alignment: .leading).offset(x: 34, y: 52)
                }
                VStack { Spacer(); HStack { caption(model.bl, cap); Spacer(); caption(model.br, cap) } }
                    .padding(.horizontal, 34).padding(.bottom, 24)
                ForEach(model.stamps) { s in StampSlot(s: s) }
                if let shade { Rectangle().fill(shade).allowsHitTesting(false) }
            }
            .frame(width: 486, height: 600)
            .clipShape(shape)
        }
        .frame(width: 486, height: 600)
        .background(shape.fill(p.paper.color).shadow(color: .black.opacity(0.45), radius: 30, x: 0, y: 30))
        .overlay { MRInsetShadow(shape, color: .white.opacity(0.4), y: 2) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Page \(model.number), \(left ? "Entries" : "Visas"), \(model.stamps.filter { !$0.locked }.count) stamps")
    }

    private func caption(_ t: String, _ c: Color) -> some View {
        Text(t).font(.mr(.ui, size: 10, weight: 600)).tracking(10 * 0.2).textCase(.uppercase).foregroundStyle(c).frame(height: 12)
    }
}

private struct StampSlot: View {
    let s: PlacedStamp
    @State private var hover = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        StampView(shape: s.shape, country: s.country, code: s.code, date: s.date, kind: "ARRIVAL", cc: s.cc, ink: s.ink,
                  rotation: s.rot, size: s.size, locked: s.locked, seed: s.seed,
                  animation: s.anim ? .passport : nil,
                  onThump: s.anim ? { @Sendable in Task { @MainActor in MRSound.shared.play(.stamp) } } : nil)
            .frame(width: s.size, height: s.h)
            .scaleEffect(hover && !reduceMotion ? 1.04 : 1)
            .animation(MRMotion.snappy, value: hover)
            .onHover { hover = $0 }
            .help(s.tip)
            .offset(x: s.x, y: s.y)
    }
}

/// `pp-g` pattern: 44 pt tile of three concentric circles plus two corner arcs, stroke #243F8F .7.
private struct Guilloche: View {
    var body: some View {
        Canvas { ctx, size in
            let stroke = mrHex("#243F8F")
            var path = Path()
            for ty in 0..<Int(ceil(size.height / 44)) {
                for tx in 0..<Int(ceil(size.width / 44)) {
                    let ox = CGFloat(tx) * 44, oy = CGFloat(ty) * 44
                    for r in [20.0, 14.0, 8.0] { path.addEllipse(in: CGRect(x: ox + 22 - r, y: oy + 22 - r, width: 2 * r, height: 2 * r)) }
                    path.addEllipse(in: CGRect(x: ox - 20, y: oy - 20, width: 40, height: 40))
                    path.addEllipse(in: CGRect(x: ox + 44 - 20, y: oy + 44 - 20, width: 40, height: 40))
                }
            }
            ctx.stroke(path, with: .color(stroke), lineWidth: 0.7)
        }
        .allowsHitTesting(false)
    }
}
