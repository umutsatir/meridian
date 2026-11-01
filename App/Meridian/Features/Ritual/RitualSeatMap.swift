import MeridianUI
import SwiftUI

/// A friend's seat on the map (C06). Static data until the Together service exists.
struct RitualFriend: Hashable {
    var seat: String
    var initial: String
    var name: String
    var colorHex: String
    var presence: MRAvatar.Presence = .online
}

/// `SeatMap.dc.html`: a top-down airliner in dark glass, 2-2 seating (A C | D F) either side of the aisle, rows 01-12, four zone
/// tabs. 800 x 392 design points; `scale` multiplies the frame. A single `Canvas` draws the fuselage, seats are buttons.
struct RitualSeatMap: View {
    var seat: String
    var zone: RitualZone
    var live = true
    var scale: CGFloat = 1
    var friends: [RitualFriend] = []
    var taken: [String] = RitualSeatMap.defaultTaken
    /// Pins the hover state (design reference); live hover comes from the pointer.
    var pinnedHover = ""
    var focusSeat = ""
    var onSeat: (String, RitualZone) -> Void = { _, _ in }
    var onZone: (RitualZone) -> Void = { _ in }

    static let defaultTaken = ["2C", "3D", "5D", "5F", "8A", "8C", "9F", "11C", "4A", "6F", "12D", "10C"]

    // geometry (canvas `renderVals`)
    static let W: CGFloat = 800, H: CGFloat = 392
    static let x0: CGFloat = 8, hw: CGFloat = 88, L: CGFloat = 172, P: CGFloat = 43, SZ: CGFloat = 30, cy: CGFloat = 196
    static var xr0: CGFloat { x0 + L + 12 }
    static let lanes: [CGFloat] = [-64, -30, 30, 64]
    static let letters = ["A", "C", "D", "F"]
    static func xc(_ row: Int) -> CGFloat { xr0 + CGFloat(row - 1) * P + P / 2 }
    /// Centre of a seat in the map's own 800 x 392 space.
    static func center(of code: String) -> CGPoint {
        let row = Int(code.dropLast()) ?? 1
        let li = letters.firstIndex(of: String(code.suffix(1))) ?? 0
        return CGPoint(x: xc(row), y: cy + lanes[li])
    }
    static func type(of letter: String) -> String { (letter == "A" || letter == "F") ? "Window" : "Aisle" }

    @Environment(\.colorScheme) private var scheme
    @State private var hover = ""
    @State private var cursor = ""
    @FocusState private var focused: Bool

    var body: some View {
        let p = MRPalette.resolve(scheme)
        let hov = pinnedHover.isEmpty ? hover : pinnedHover
        let cur = focusSeat.isEmpty ? (focused ? cursor : "") : focusSeat
        ZStack(alignment: .topLeading) {
            Fuselage(palette: p)
            ForEach(RitualZone.allCases) { z in
                let on = zone == z, c = RGB(hex: z.hex)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(c).opacity(on ? 0.20 : 0.07))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color(c).opacity(on ? 0.60 : 0.20), lineWidth: 1))
                    .frame(width: 3 * Self.P - 4, height: 166)
                    .offset(x: Self.xr0 + CGFloat(z.rawValue) * 3 * Self.P + 2, y: Self.cy - 83)
                    .animation(MRMotion.ease(MRMotion.d3), value: on)
                    .allowsHitTesting(false)
            }
            ForEach(0..<4, id: \.self) { i in
                Text(Self.letters[i]).font(.mr(.mono, size: 10, weight: 500)).foregroundStyle(p.text2.color)
                    .frame(width: 16, height: 14).offset(x: Self.xr0 - 28, y: Self.cy + Self.lanes[i] - 7)
            }
            ForEach(1...12, id: \.self) { r in
                Text(r < 10 ? "0\(r)" : "\(r)").font(.mr(.mono, size: 10, weight: 500)).tracking(0.2).foregroundStyle(p.text2.color)
                    .frame(width: 26, height: 14).offset(x: Self.xc(r) - 13, y: Self.cy - 7)
            }
            // window-seat rim light on the hull
            let selRow = Int(seat.dropLast()) ?? 0, selLetter = String(seat.suffix(1))
            if selRow > 0 && (selLetter == "A" || selLetter == "F") {
                Capsule().fill(p.accent1.color).frame(width: 26, height: 3)
                    .shadow(color: p.accent1.color.opacity(0.8), radius: 5)
                    .offset(x: Self.xc(selRow) - 13, y: selLetter == "A" ? Self.cy - Self.hw - 2 : Self.cy + Self.hw - 1)
                    .animation(MRMotion.smooth, value: seat)
                    .allowsHitTesting(false)
            }
            ForEach(1...12, id: \.self) { r in
                ForEach(0..<4, id: \.self) { li in seatView(row: r, li: li, hov: hov, cur: cur, palette: p) }
            }
            ForEach(RitualZone.allCases) { z in zoneTab(z, palette: p) }
            if !hov.isEmpty, let _ = seatCenter(hov) { tip(hov, palette: p) }
        }
        .frame(width: Self.W, height: Self.H, alignment: .topLeading)
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: Self.W * scale, height: Self.H * scale, alignment: .topLeading)
        .focusable(live)
        .focused($focused)
        .focusEffectDisabled()
        .onKeyPress(phases: [.down, .repeat]) { press in handleKey(press) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Seat map")
    }

    private func seatCenter(_ code: String) -> CGPoint? {
        guard let r = Int(code.dropLast()), (1...12).contains(r), Self.letters.contains(String(code.suffix(1))) else { return nil }
        return Self.center(of: code)
    }

    // MARK: seats

    @ViewBuilder private func seatView(row r: Int, li: Int, hov: String, cur: String, palette p: MRPalette) -> some View {
        let letter = Self.letters[li], code = "\(r)\(letter)"
        let friend = friends.first { $0.seat == code }
        let off = taken.contains(code) && friend == nil
        let sel = code == seat
        let z = RitualZone.of(row: r)
        let type = Self.type(of: letter)
        SeatCell(code: code, selected: sel, friend: friend, off: off, hovered: hov == code, focusRing: cur == code, palette: p) {
            guard !off else { return }
            cursor = code
            onSeat(code, z); onZone(z)
        }
        .onHover { inside in withAnimation(MRMotion.hover) { if live { hover = inside ? code : (hover == code ? "" : hover) } } }
        .offset(x: Self.xc(r) - Self.SZ / 2, y: Self.cy + Self.lanes[li] - Self.SZ / 2)
        .zIndex(sel ? 5 : 0)
        .accessibilityLabel("Seat \(code), \(type), \(z.label) zone" + (friend.map { ", taken by \($0.name)" } ?? (off ? ", unavailable" : "")) + (sel ? ", selected" : ""))
        .accessibilityAddTraits(sel ? [.isButton, .isSelected] : .isButton)
        .accessibilityHidden(off && friend == nil ? false : false)
    }

    // MARK: zone tabs

    private func zoneTab(_ z: RitualZone, palette p: MRPalette) -> some View {
        ZoneTab(zone: z, selected: zone == z, palette: p) {
            let cs = Int(seat.dropLast()) ?? 1
            var ns = seat
            if RitualZone.of(row: cs) != z { ns = "\(z.firstRow)A" }
            cursor = ns
            onZone(z); onSeat(ns, z)
        }
        .frame(width: 3 * Self.P - 8, height: 32)
        .offset(x: Self.xr0 + CGFloat(z.rawValue) * 3 * Self.P + 4, y: 0)
    }

    // MARK: tooltip

    private func tip(_ code: String, palette p: MRPalette) -> some View {
        let c = Self.center(of: code)
        let letter = String(code.suffix(1)), row = Int(code.dropLast()) ?? 1
        let dark = scheme == .dark
        return HStack(spacing: 8) {
            Text(code).font(.mr(.ui, size: 12, weight: 700))
            Text(" · \(Self.type(of: letter)) · \(RitualZone.of(row: row).label)").font(.mr(.ui, size: 12, weight: 500)).foregroundStyle(dark ? p.text2.color : Color(white: 0.8))
        }
        .foregroundStyle(dark ? p.text1.color : Color(hex: "#F3F5FA"))
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(dark ? Color(red: 18 / 255, green: 26 / 255, blue: 46 / 255).opacity(0.92) : Color(red: 20 / 255, green: 22 / 255, blue: 28 / 255).opacity(0.92)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(p.strokeHair.color, lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        .fixedSize()
        .alignmentGuide(.leading) { $0[HorizontalAlignment.center] }
        .offset(x: c.x, y: c.y - Self.SZ / 2 - 36 + 3)
        .allowsHitTesting(false)
        .zIndex(9)
        .accessibilityHidden(true)
    }

    // MARK: keyboard

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        guard live else { return .ignored }
        let cs = cursor.isEmpty ? seat : cursor
        var r = Int(cs.dropLast()) ?? 1
        var li = Self.letters.firstIndex(of: String(cs.suffix(1))) ?? 0
        switch press.key {
        case .rightArrow: r = min(12, r + 1)
        case .leftArrow: r = max(1, r - 1)
        case .downArrow: li = min(3, li + 1)
        case .upArrow: li = max(0, li - 1)
        case .return, .space:
            let code = cs
            if !taken.contains(code) || friends.contains(where: { $0.seat == code }) {
                let z = RitualZone.of(seat: code)
                onSeat(code, z); onZone(z)
            }
            return .handled
        default: return .ignored
        }
        cursor = "\(r)\(Self.letters[li])"; hover = ""
        return .handled
    }
}

// MARK: - one seat

private struct SeatCell: View {
    let code: String
    let selected: Bool
    let friend: RitualFriend?
    let off: Bool
    let hovered: Bool
    let focusRing: Bool
    let palette: MRPalette
    private var p: MRPalette { palette }
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        let dark = scheme == .dark
        Button(action: action) {
            ZStack {
                shape.fill(selected
                           ? AnyShapeStyle(LinearGradient(colors: dark
                                ? [Color(red: 106 / 255, green: 183 / 255, blue: 1).opacity(0.55), Color(red: 139 / 255, green: 243 / 255, blue: 216 / 255).opacity(0.35)]
                                : [Color(red: 30 / 255, green: 107 / 255, blue: 1).opacity(0.4), Color(red: 24 / 255, green: 199 / 255, blue: 160 / 255).opacity(0.3)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                           : AnyShapeStyle(hovered && !off ? p.fill3.color : p.fill2.color))
                if off { Hatch().clipShape(shape) }
                shape.strokeBorder(p.strokeHair.color, lineWidth: 1).opacity(selected ? 0 : 1)
                if !selected { MRInsetShadow(shape, color: p.strokeGlow.color, y: 1) }
                if selected {
                    MRInsetShadow(shape, color: .white.opacity(dark ? 0.5 : 0.7), y: 1)
                    shape.inset(by: -2).strokeBorder(p.accent1.color, lineWidth: 2)
                }
                if let friend {
                    shape.inset(by: -1.5).strokeBorder(Color(hex: friend.colorHex), lineWidth: 1.5)
                    MRAvatar(friend.initial, tint: Color(hex: friend.colorHex), size: .sm, presence: friend.presence)
                }
                if selected { Text(code).font(.mr(.mono, size: 11, weight: 700)).tracking(-0.22).foregroundStyle(p.text1.color) }
                if off { MRIcon(.x, size: 12).foregroundStyle(p.text3.color) }
            }
            .frame(width: 30, height: 30)
            .shadow(color: selected ? .black.opacity(dark ? 0.4 : 0.25) : .clear, radius: 9, y: 8)
            .shadow(color: selected && dark ? Color(red: 106 / 255, green: 183 / 255, blue: 1).opacity(0.38) : .clear, radius: 12)
            .scaleEffect(selected ? 1.12 : 1)
            .offset(y: selected ? -2 : (hovered && !off ? -1.5 : 0))
            .opacity(off ? 0.34 : 1)
            .overlay {
                if focusRing {
                    RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(p.accent1.color, lineWidth: 2).padding(-4)
                }
            }
            .animation(MRMotion.snappy, value: selected)
            .animation(MRMotion.snappy, value: hovered)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!off)
    }

    /// `repeating-linear-gradient(135deg, fill-1 0 3px, transparent 3px 6px)`
    private struct Hatch: View {
        @Environment(\.colorScheme) private var scheme
        var body: some View {
            let color = MRPalette.resolve(scheme).fill1.color
            Canvas { ctx, size in
                let period = 6 * 2.0.squareRoot(), band = 3 * 2.0.squareRoot()
                var s = 0.0
                while s < size.width + size.height {
                    var path = Path()
                    path.move(to: CGPoint(x: s, y: 0)); path.addLine(to: CGPoint(x: s + band, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: s + band)); path.addLine(to: CGPoint(x: 0, y: s)); path.closeSubpath()
                    ctx.fill(path, with: .color(color))
                    s += period
                }
            }
        }
    }
}

// MARK: - zone tab

private struct ZoneTab: View {
    let zone: RitualZone
    let selected: Bool
    let palette: MRPalette
    private var p: MRPalette { palette }
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var hovered = false

    var body: some View {
        let zc = RGB(hex: zone.hex)
        let dark = scheme == .dark
        let ink = dark ? zc : zc.mixed(with: RGB(hex: "#14161C"), amount: 0.54)
        let shape = Capsule()
        Button(action: action) {
            HStack(spacing: 7) {
                MRIcon(zone.icon, size: 14)
                Text(zone.label).font(.mr(.ui, size: 13, weight: 500))
            }
            .foregroundStyle(Color(ink))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                shape.fill(selected ? Color(zc).opacity(0.22) : (hovered ? Color(zc.mixedPremultiplied(with: p.fill1.rgb, share: 0.14)) : p.fill1.color))
            }
            .overlay { shape.strokeBorder(selected ? Color(zc) : p.strokeHair.color, lineWidth: 1) }
            .shadow(color: selected ? Color(zc).opacity(0.28) : .clear, radius: 11)
            .contentShape(shape)
            .animation(MRMotion.ease(MRMotion.d2), value: selected)
            .animation(MRMotion.ease(MRMotion.d2), value: hovered)
        }
        .buttonStyle(.plain)
        .onHover { hv in withAnimation(MRMotion.hover) { hovered = hv } }
        .accessibilityLabel("\(zone.label) zone, rows \(zone.firstRow) to \(zone.firstRow + 2)")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - fuselage

/// Hull, wings, tail planes and windshield. Local space: u across (0 = centre line), v along from the nose tip, turned so the nose points left.
private struct Fuselage: View {
    let palette: MRPalette

    var body: some View {
        let p = palette
        Canvas { ctx, _ in
            let h = RitualSeatMap.hw, L = RitualSeatMap.L, P = RitualSeatMap.P
            let V1 = RitualSeatMap.xr0 + 12 * P - RitualSeatMap.x0 + 4
            var c = ctx
            c.concatenate(CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: RitualSeatMap.x0, ty: RitualSeatMap.cy))

            // hull: parabolic nose, straight sides, round tail cap
            let na: CGFloat = 36.6, nb: CGFloat = 91.1, ry: CGFloat = 66, k: CGFloat = 0.5522847
            var hull = Path()
            hull.move(to: CGPoint(x: 0, y: 0))
            hull.addCurve(to: CGPoint(x: h, y: L), control1: CGPoint(x: na, y: 0), control2: CGPoint(x: h, y: nb))
            hull.addLine(to: CGPoint(x: h, y: V1))
            hull.addCurve(to: CGPoint(x: 0, y: V1 + ry), control1: CGPoint(x: h, y: V1 + ry * k), control2: CGPoint(x: h * k, y: V1 + ry))
            hull.addCurve(to: CGPoint(x: -h, y: V1), control1: CGPoint(x: -h * k, y: V1 + ry), control2: CGPoint(x: -h, y: V1 + ry * k))
            hull.addLine(to: CGPoint(x: -h, y: L))
            hull.addCurve(to: CGPoint(x: 0, y: 0), control1: CGPoint(x: -h, y: nb), control2: CGPoint(x: -na, y: 0))
            hull.closeSubpath()

            func fade(_ a: CGFloat, _ b: CGFloat, _ o1: Double, _ o2: Double, mid: Double? = nil) -> GraphicsContext.Shading {
                var stops: [Gradient.Stop] = [.init(color: p.text1.color.opacity(o1), location: 0)]
                if let mid { stops.append(.init(color: p.text1.color.opacity(mid), location: 0.5)) }
                stops.append(.init(color: p.text1.color.opacity(o2), location: 1))
                return .linearGradient(Gradient(stops: stops), startPoint: CGPoint(x: a, y: 0), endPoint: CGPoint(x: b, y: 0))
            }
            // wings: a flat swept trapezoid, root rows 4-9, faint and fading toward the tip
            let rv = RitualSeatMap.xr0 - RitualSeatMap.x0, uT: CGFloat = 190, rootLE = rv + 3.9 * P, rootTE = rv + 8.5 * P
            let sLE: CGFloat = 0.52, sTE: CGFloat = 0.2, u0 = h - 12
            func wing(_ s: CGFloat) -> Path {
                var w = Path()
                w.move(to: CGPoint(x: s * u0, y: rootLE - 12 * sLE))
                w.addLine(to: CGPoint(x: s * uT, y: rootLE + (uT - h) * sLE))
                w.addLine(to: CGPoint(x: s * uT, y: rootTE + (uT - h) * sTE))
                w.addLine(to: CGPoint(x: s * u0, y: rootTE))
                w.closeSubpath(); return w
            }
            let sT = h + 44, sRootLE = V1 - 62, sRootTE = V1 - 10
            func stab(_ s: CGFloat) -> Path {
                var w = Path()
                w.move(to: CGPoint(x: s * (h - 8), y: sRootLE))
                w.addLine(to: CGPoint(x: s * sT, y: sRootLE + 44 * 0.62))
                w.addLine(to: CGPoint(x: s * sT, y: sRootTE + 44 * 0.12))
                w.addLine(to: CGPoint(x: s * (h - 8), y: sRootTE))
                w.closeSubpath(); return w
            }
            c.fill(wing(1), with: fade(h, uT, 0.085, 0, mid: 0.05))
            c.fill(wing(-1), with: fade(-h, -uT, 0.085, 0, mid: 0.05))
            c.fill(stab(1), with: fade(h, sT, 0.07, 0))
            c.fill(stab(-1), with: fade(-h, -sT, 0.07, 0))

            c.fill(hull, with: .color(p.bg1.color.opacity(0.94)))
            c.fill(hull, with: .color(p.fill1.color))
            c.fill(hull, with: .linearGradient(Gradient(stops: [
                .init(color: .white.opacity(0.05), location: 0), .init(color: .white.opacity(0), location: 0.18),
                .init(color: .white.opacity(0), location: 0.82), .init(color: .white.opacity(0.05), location: 1)]),
                startPoint: CGPoint(x: -h, y: 0), endPoint: CGPoint(x: h, y: 0)))
            c.stroke(hull, with: .color(p.strokeHair.color), lineWidth: 1.2)
            // soft inner shading along the hull edge
            var inner = c
            inner.clip(to: hull)
            inner.stroke(hull, with: .color(p.text1.color.opacity(0.035)), lineWidth: 30)
            inner.stroke(hull, with: .color(p.text1.color.opacity(0.04)), lineWidth: 16)
            inner.stroke(hull, with: .color(p.text1.color.opacity(0.05)), lineWidth: 6)
            // windshield: two panes with a centre post
            func pane(_ s: CGFloat) -> Path {
                var q = Path()
                q.move(to: CGPoint(x: s * 5, y: 35)); q.addLine(to: CGPoint(x: s * 5, y: 56.3))
                q.addQuadCurve(to: CGPoint(x: s * 52.4, y: 72), control: CGPoint(x: s * 24, y: 55.9))
                q.addLine(to: CGPoint(x: s * 42, y: 48.4))
                q.addQuadCurve(to: CGPoint(x: s * 5, y: 35), control: CGPoint(x: s * 26, y: 36))
                q.closeSubpath(); return q
            }
            c.fill(pane(-1), with: .color(p.fill3.color))
            c.fill(pane(1), with: .color(p.fill3.color))
        }
        .frame(width: RitualSeatMap.W, height: RitualSeatMap.H)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
