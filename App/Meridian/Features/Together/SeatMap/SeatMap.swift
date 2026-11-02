import MeridianUI
import SwiftUI

/// Shared seat map (`SeatMap.dc.html`). Fixed design space 800 x 392 pt; callers scale it (`.scaleEffect`) to fit.
/// Used by the Together lobby and, later, by the seat and scenario step of the ritual (S12 / S12B). API: docs/design/seatmap.md.
struct SeatMapFriend: Hashable, Sendable {
    var seat: String
    var initial: String
    var tintHex: String
    var name: String
    var presence: TGPresence = .atGate
}

struct SeatMap: View {
    static let size = CGSize(width: 800, height: 392)

    var selectedSeat: String?
    /// Zone key (`study`, `work`, `read`, `create`) highlighted; `nil` highlights none.
    var zone: String?
    var friends: [SeatMapFriend] = []
    var taken: Set<String> = ["2C", "3D", "5D", "5F", "8A", "8C", "9F", "11C", "4A", "6F", "12D", "10C"]
    var interactive = false
    var hoveredSeat: String?
    var onSeat: ((String, String) -> Void)?
    var onZone: ((String) -> Void)?

    @Environment(\.colorScheme) private var scheme
    @State private var hover: String?
    @State private var internalSeat: String?
    @State private var internalZone: String?

    // Geometry (px), as the canvas.
    private let x0: CGFloat = 8, h: CGFloat = 88, L: CGFloat = 172, P: CGFloat = 43, SZ: CGFloat = 30, cy: CGFloat = 196
    private var xr0: CGFloat { x0 + L + 12 }
    private let lanes: [CGFloat] = [-64, -30, 30, 64]
    private let letters = ["A", "C", "D", "F"]

    private struct Zone { let key: String, label: String, icon: MRIconName, hex: String }
    private static let zones = [Zone(key: "study", label: "Study", icon: .cap, hex: "#7AA2FF"),
                                Zone(key: "work", label: "Work", icon: .briefcase, hex: "#FFB86B"),
                                Zone(key: "read", label: "Read", icon: .book, hex: "#7ADDB2"),
                                Zone(key: "create", label: "Create", icon: .spark, hex: "#FF8FB1")]

    private func xc(_ r: Int) -> CGFloat { xr0 + CGFloat(r - 1) * P + P / 2 }
    private func zoneOf(_ r: Int) -> Zone { Self.zones[(r - 1) / 3] }
    private func type(_ l: String) -> String { l == "A" || l == "F" ? "Window" : "Aisle" }

    var body: some View {
        let p = MRPalette.resolve(scheme)
        let seat = internalSeat ?? selectedSeat
        let zoneSel = internalZone ?? zone
        let hov = hover ?? hoveredSeat
        ZStack(alignment: .topLeading) {
            aircraft(p)
            // zone tints
            ForEach(Array(Self.zones.enumerated()), id: \.offset) { i, z in
                let on = zoneSel == z.key, c = MRColorToken(z.hex)
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(c.opacity(on ? 0.20 : 0.07))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(c.opacity(on ? 0.60 : 0.20), lineWidth: 1))
                    .frame(width: 3 * P - 4, height: 166)
                    .offset(x: xr0 + CGFloat(i) * 3 * P + 2, y: cy - 83)
                    .animation(MRMotion.ease(MRMotion.d3), value: on)
            }
            // zone tabs
            ForEach(Array(Self.zones.enumerated()), id: \.offset) { i, z in tab(z, i, on: zoneSel == z.key, seat: seat, p: p) }
            // letters and row numbers
            ForEach(0..<4, id: \.self) { i in
                Text(letters[i]).font(.mr(.mono, size: 10, weight: 500)).foregroundStyle(p.text2.color)
                    .frame(width: 16, height: 14).offset(x: xr0 - 28, y: cy + lanes[i] - 7)
            }
            ForEach(1...12, id: \.self) { r in
                Text(r < 10 ? "0\(r)" : "\(r)").font(.mr(.mono, size: 10, weight: 500)).tracking(0.2).foregroundStyle(p.text2.color)
                    .frame(width: 26, height: 14).offset(x: xc(r) - 13, y: cy - 7)
            }
            // window rim of the selected window seat
            if let seat, let r = Int(seat.dropLast()), let l = seat.last.map(String.init), l == "A" || l == "F" {
                RoundedRectangle(cornerRadius: 2).fill(p.accent1.color).frame(width: 26, height: 3)
                    .shadow(color: MRColorToken(106, 183, 255, 0.8).color, radius: 5)
                    .offset(x: xc(r) - 13, y: l == "A" ? cy - h - 2 : cy + h - 1)
            }
            // seats
            ForEach(1...12, id: \.self) { r in
                ForEach(0..<4, id: \.self) { li in seatView(r, li, seat: seat, hov: hov, p: p) }
            }
            // tooltip
            if let hov, let r = Int(hov.dropLast()), let li = letters.firstIndex(of: String(hov.last ?? "A")) {
                HStack(spacing: 8) {
                    Text(hov).font(.mr(.ui, size: 12, weight: 700))
                    Text(" · \(type(letters[li])) · \(zoneOf(r).label)").font(.mr(.ui, size: 12, weight: 500)).foregroundStyle(p.text2.color)
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(MRColorToken(18, 26, 46, 0.92).color))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(p.strokeHair.color, lineWidth: 1))
                .foregroundStyle(p.text1.color)
                .fixedSize()
                .position(x: xc(r), y: cy + lanes[li] - 36 + 10)
                .allowsHitTesting(false)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Seat map")
    }

    // MARK: Seats

    @ViewBuilder private func seatView(_ r: Int, _ li: Int, seat: String?, hov: String?, p: MRPalette) -> some View {
        let code = "\(r)\(letters[li])"
        let fr = friends.first { $0.seat == code }
        let off = taken.contains(code) && fr == nil
        let sel = code == seat
        let isHover = hov == code && !off
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        ZStack {
            shape.fill(sel ? AnyShapeStyle(LinearGradient(colors: scheme == .dark
                                                           ? [MRColorToken(106, 183, 255, 0.55).color, MRColorToken(139, 243, 216, 0.35).color]
                                                           : [MRColorToken(30, 107, 255, 0.4).color, MRColorToken(24, 199, 160, 0.3).color],
                                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                                 : AnyShapeStyle(isHover ? p.fill3.color : p.fill2.color))
            if off {
                HatchShape().stroke(p.fill1.color, lineWidth: 3).clipShape(shape)
            }
            if sel {
                shape.strokeBorder(p.accent1.color, lineWidth: 2)
                MRInsetShadow(shape, color: .white.opacity(0.5), y: 1)
                Text(code).font(.mr(.mono, size: 11, weight: 700)).tracking(-0.22).foregroundStyle(p.text1.color)
            } else {
                MRInsetShadow(shape, color: p.strokeHair.color, spread: 1)
                MRInsetShadow(shape, color: p.strokeGlow.color, y: 1)
            }
            if let fr {
                shape.strokeBorder(MRColorToken(fr.tintHex).color, lineWidth: 1.5)
                SeatAvatar(initial: fr.initial, tintHex: fr.tintHex, presence: fr.presence, diameter: 22, dot: 7)
            }
            if off { MRIcon(.x, size: 12).foregroundStyle(p.text3.color) }
        }
        .frame(width: SZ, height: SZ)
        .opacity(off ? 0.34 : 1)
        .shadow(color: sel ? .black.opacity(0.4) : .clear, radius: sel ? 9 : 0, y: sel ? 8 : 0)
        .scaleEffect(sel ? 1.12 : 1)
        .offset(x: xc(r) - SZ / 2, y: cy + lanes[li] - SZ / 2 - (sel ? 2 : isHover ? 1.5 : 0))
        .zIndex(sel ? 5 : 0)
        .animation(.spring(response: MRMotion.snappyParams.response, dampingFraction: MRMotion.snappyParams.damping), value: sel)
        .contentShape(shape)
        .onHover { inside in if interactive { hover = inside ? code : (hover == code ? nil : hover) } }
        .onTapGesture {
            guard interactive, !off else { return }
            internalSeat = code; internalZone = zoneOf(r).key
            onSeat?(code, zoneOf(r).key); onZone?(zoneOf(r).key)
        }
        .allowsHitTesting(interactive)
        .accessibilityElement()
        .accessibilityLabel("Seat \(code), \(type(letters[li])), \(zoneOf(r).label) zone" + (fr.map { ", taken by \($0.name)" } ?? (off ? ", unavailable" : "")) + (sel ? ", selected" : ""))
        .accessibilityAddTraits(sel ? .isSelected : [])
    }

    private func tab(_ z: Zone, _ i: Int, on: Bool, seat: String?, p: MRPalette) -> some View {
        let c = MRColorToken(z.hex)
        let ink: Color = scheme == .dark ? c.color : Color(RGB(r: c.rgb.r * 0.46 + 0.0784 * 0.54, g: c.rgb.g * 0.46 + 0.086 * 0.54, b: c.rgb.b * 0.46 + 0.11 * 0.54))
        return HStack(spacing: 7) {
            MRIcon(z.icon, size: 14)
            Text(z.label).font(.mr(.ui, size: 13, weight: 500))
        }
        .foregroundStyle(ink)
        .frame(width: 3 * P - 8, height: 32)
        .background(Capsule().fill(on ? c.opacity(0.22) : p.fill1.color))
        .overlay(Capsule().strokeBorder(on ? c.color : p.strokeHair.color, lineWidth: 1))
        .shadow(color: on ? c.opacity(0.28) : .clear, radius: 11)
        .offset(x: xr0 + CGFloat(i) * 3 * P + 4, y: 0)
        .contentShape(Capsule())
        .onTapGesture {
            guard interactive else { return }
            internalZone = z.key
            let cs = Int((seat ?? "1A").dropLast()) ?? 1
            let ns = (cs - 1) / 3 == i ? (seat ?? "1A") : "\(i * 3 + 1)A"
            internalSeat = ns
            onZone?(z.key); onSeat?(ns, z.key)
        }
        .allowsHitTesting(interactive)
        .accessibilityLabel("\(z.label) zone, rows \(i * 3 + 1) to \(i * 3 + 3)")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Aircraft

    /// Local (u across, v along) to screen: `matrix(0 1 1 0 x0 cy)`.
    private func pt(_ u: CGFloat, _ v: CGFloat) -> CGPoint { CGPoint(x: v + x0, y: u + cy) }

    private func hullPath(V1: CGFloat) -> Path {
        var path = Path()
        let na: CGFloat = 36.6, nb: CGFloat = 91.1, ry: CGFloat = 66
        path.move(to: pt(0, 0))
        path.addCurve(to: pt(h, L), control1: pt(na, 0), control2: pt(h, nb))
        path.addLine(to: pt(h, V1))
        for i in 1...40 {
            let t = Double.pi * Double(i) / 40
            path.addLine(to: pt(h * CGFloat(cos(t)), V1 + ry * CGFloat(sin(t))))
        }
        path.addLine(to: pt(-h, L))
        path.addCurve(to: pt(0, 0), control1: pt(-h, nb), control2: pt(-na, 0))
        path.closeSubpath()
        return path
    }

    private func poly(_ pts: [(CGFloat, CGFloat)]) -> Path {
        var path = Path()
        for (i, q) in pts.enumerated() { i == 0 ? path.move(to: pt(q.0, q.1)) : path.addLine(to: pt(q.0, q.1)) }
        path.closeSubpath()
        return path
    }

    private func aircraft(_ p: MRPalette) -> some View {
        let V1 = xr0 + 12 * P - x0 + 4
        let rv = xr0 - x0, uT: CGFloat = 190
        let wLE = rv + 3.9 * P, wTE = rv + 8.5 * P, sLE: CGFloat = 0.52, sTE: CGFloat = 0.2, u0 = h - 12
        func wing(_ s: CGFloat) -> Path {
            poly([(s * u0, wLE - 12 * sLE), (s * uT, wLE + (uT - h) * sLE), (s * uT, wTE + (uT - h) * sTE), (s * u0, wTE)])
        }
        let sT = h + 44, sLE2 = V1 - 62, sTE2 = V1 - 10
        func stab(_ s: CGFloat) -> Path {
            poly([(s * (h - 8), sLE2), (s * sT, sLE2 + 44 * 0.62), (s * sT, sTE2 + 44 * 0.12), (s * (h - 8), sTE2)])
        }
        func pane(_ s: CGFloat) -> Path {
            var q = Path()
            q.move(to: pt(s * 5, 35)); q.addLine(to: pt(s * 5, 56.3))
            q.addQuadCurve(to: pt(s * 52.4, 72), control: pt(s * 24, 55.9))
            q.addLine(to: pt(s * 42, 48.4))
            q.addQuadCurve(to: pt(s * 5, 35), control: pt(s * 26, 36))
            q.closeSubpath()
            return q
        }
        let hull = hullPath(V1: V1)
        let t1 = p.text1.color
        func fade(_ a: Double, _ b: Double, mid: Double? = nil) -> Gradient {
            var st: [Gradient.Stop] = [.init(color: t1.opacity(a), location: 0)]
            if let mid { st.append(.init(color: t1.opacity(mid), location: 0.5)) }
            st.append(.init(color: t1.opacity(b), location: 1))
            return Gradient(stops: st)
        }
        return Canvas { ctx, _ in
            for s: CGFloat in [1, -1] {
                ctx.fill(wing(s), with: .linearGradient(fade(0.085, 0, mid: 0.05), startPoint: pt(s * h, 0), endPoint: pt(s * uT, 0)))
                ctx.fill(stab(s), with: .linearGradient(fade(0.07, 0), startPoint: pt(s * h, 0), endPoint: pt(s * sT, 0)))
            }
            ctx.fill(hull, with: .color(p.bg1.color.opacity(0.94)))
            ctx.fill(hull, with: .color(p.fill1.color))
            let box = hull.boundingRect
            ctx.fill(hull, with: .linearGradient(Gradient(stops: [.init(color: .white.opacity(0.05), location: 0), .init(color: .white.opacity(0), location: 0.18), .init(color: .white.opacity(0), location: 0.82), .init(color: .white.opacity(0.05), location: 1)]),
                                                 startPoint: CGPoint(x: 0, y: box.minY), endPoint: CGPoint(x: 0, y: box.maxY)))
            ctx.stroke(hull, with: .color(p.strokeHair.color), lineWidth: 1.2)
            var inner = ctx
            inner.clip(to: hull)
            inner.stroke(hull, with: .color(t1.opacity(0.035)), lineWidth: 30)
            inner.stroke(hull, with: .color(t1.opacity(0.04)), lineWidth: 16)
            inner.stroke(hull, with: .color(t1.opacity(0.05)), lineWidth: 6)
            ctx.fill(pane(-1), with: .color(p.fill3.color))
            ctx.fill(pane(1), with: .color(p.fill3.color))
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// `repeating-linear-gradient(135deg, fill-1 0 3px, transparent 3px 6px)`: 6 pt pitch diagonal stripes.
private nonisolated struct HatchShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        var x = -r.height
        while x < r.width {
            p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x + r.height, y: r.height))
            x += 8.5
        }
        return p
    }
}

/// `.av` circle with presence dot (default `pr`: accent, `idle`: text-3, `left`: amber).
struct SeatAvatar: View {
    var initial: String
    var tintHex: String
    var presence: TGPresence
    var diameter: CGFloat
    var dot: CGFloat
    var fontSize: CGFloat? = nil
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = MRPalette.resolve(scheme)
        let shape = Circle()
        Text(initial)
            .font(.mr(.ui, size: fontSize ?? (diameter <= 22 ? 10 : diameter >= 44 ? 17 : 13), weight: 600))
            .foregroundStyle(MRColorToken("#04101A").color)
            .frame(width: diameter, height: diameter)
            .background(MRColorToken(tintHex).color, in: shape)
            .overlay(MRInsetShadow(shape, color: .white.opacity(0.45), y: 1))
            .overlay(alignment: .bottomTrailing) {
                Circle().fill(dotColor(p)).frame(width: dot, height: dot)
                    .overlay(Circle().strokeBorder(p.bg1.color, lineWidth: 2).padding(-2))
                    .offset(x: 1, y: 1)
            }
    }

    private func dotColor(_ p: MRPalette) -> Color {
        switch presence {
        case .inFlight, .atGate: p.accent1.color
        case .idle: p.text3.color
        case .landed: p.amber.color
        }
    }
}
