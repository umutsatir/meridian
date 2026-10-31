import MeridianUI
import SwiftUI

/// Private paper boarding pass for the Together screens (`Ticket.dc.html`, states `printed`, `torn` and `group`).
/// The shared ticket component is built on another branch; when it lands, replace this view with it. Drawn in the
/// canvas' 360 x 600 space and scaled. Paper grain and the route dot-map watermark (opacity .085) are not drawn.
struct TGTicket: View {
    enum Variant { case printed, torn }
    var variant: Variant = .printed
    var from = "LHR", to = "CDG", fromCity = "London", toCity = "Paris"
    var minutes = 42, km = 348
    var seat = "1A", gate = "A12", boarding = "10:00", flight = "MR 0142", date = "THU 29 OCT"
    var name = "ELIF KAYA"
    var scenarioLabel = "Coding", scenarioHex = "#B49CFF", scenarioIcon: MRIconName = .code
    /// Initials for the group variant (`state="group"`): shows the avatar stack instead of the passenger name.
    var group: [String]? = nil
    var scale: CGFloat = 1
    var flat = false

    var height: CGFloat { variant == .torn ? 452 : 600 }
    private let ink = Color(red: 20 / 255, green: 17 / 255, blue: 15 / 255)
    private let paper = MRColorToken("#F5F0E6")

    var body: some View {
        ZStack(alignment: .topLeading) { sheet }
            .frame(width: 360, height: height, alignment: .topLeading)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: 360 * scale, height: height * scale, alignment: .topLeading)
            .shadow(color: flat ? .clear : .black.opacity(0.45), radius: 12, y: 24)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Boarding pass, \(from) to \(to), seat \(seat)")
    }

    // MARK: Sheet

    private var sheet: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(paper.color)
            LinearGradient(colors: [.white.opacity(0.06), .white.opacity(0)], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.4))
            Rectangle().fill(MRColorToken(scenarioHex).color).frame(height: 6)
            Rectangle().fill(MRColorToken("#868FA0").color.opacity(0.95)).frame(width: 4, height: 450).offset(x: 356)
            header
            route
            grid
            scenarioRow
            passengerRow
            if variant == .printed { stub }
            Rectangle().fill(.white.opacity(0.9)).frame(height: 1)
        }
        .frame(width: 360, height: height)
        .clipShape(variant == .torn ? AnyShape(TornBottom(seed: 7)) : AnyShape(Rectangle()))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .mask(Notches(y: 450).fill(style: FillStyle(eoFill: true)))
        .overlay(alignment: .topLeading) {
            if variant == .torn { TornRim(seed: 7).stroke(.white.opacity(0.85), lineWidth: 1.1) }
        }
    }

    private func cap(_ t: String) -> some View {
        Text(t).font(.mr(.ui, size: 9.5, weight: 600)).tracking(0.12 * 9.5).textCase(.uppercase).foregroundStyle(ink.opacity(0.7))
    }

    private func mono(_ t: String, _ size: CGFloat) -> some View {
        Text(t).font(.mr(.mono, size: size, weight: 500)).foregroundStyle(ink.opacity(0.92))
    }

    private var header: some View {
        HStack {
            Text("MERIDIAN AIR").font(.mr(.ui, size: 11, weight: 700)).tracking(0.24 * 11).foregroundStyle(ink.opacity(0.92))
            Spacer()
            cap("Boarding pass")
        }
        .frame(width: 308, height: 48).offset(x: 24, y: 6)
    }

    private var route: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                cap("From")
                Text(from).font(.mr(.condensed, size: 64, weight: 700)).tracking(0.32).foregroundStyle(ink.opacity(0.92)).frame(height: 64).padding(.top, 2)
                Text(fromCity).font(.mr(.ui, size: 13, weight: 500)).foregroundStyle(ink.opacity(0.92)).padding(.top, 2)
                Capsule().fill(MRColorToken(scenarioHex).color).frame(width: 64, height: 3).padding(.top, 5)
            }.offset(x: 24, y: 6)
            VStack(alignment: .trailing, spacing: 0) {
                cap("To")
                Text(to).font(.mr(.condensed, size: 64, weight: 700)).tracking(0.32).foregroundStyle(ink.opacity(0.92)).frame(height: 64).padding(.top, 2)
                Text(toCity).font(.mr(.ui, size: 13, weight: 500)).foregroundStyle(ink.opacity(0.92)).padding(.top, 2)
                Capsule().fill(MRColorToken(scenarioHex).color).frame(width: 64, height: 3).padding(.top, 5)
            }.frame(width: 140, alignment: .trailing).offset(x: 360 - 28 - 140, y: 6)
            VStack(spacing: 6) {
                ZStack {
                    DashLine().stroke(ink.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])).frame(height: 1.5)
                    MRIcon(.plane, size: 18).rotationEffect(.degrees(90)).foregroundStyle(ink)
                        .padding(.horizontal, 6).background(paper.color)
                }.frame(width: 136, height: 20)
                mono("\(minutes) min", 13).tracking(0.26)
            }.frame(width: 136).offset(x: 112, y: 42)
        }
        .frame(width: 360, height: 130, alignment: .topLeading)
        .offset(y: 54)
    }

    private var grid: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(ink.opacity(0.14)).frame(width: 308, height: 1)
            cell("Date", date, 0, 8); cell("Flight", flight, 160, 8)
            cell("Gate", gate, 0, 58); cell("Seat", seat, 160, 58)
            cell("Boarding", boarding, 0, 108); cell("Distance", "\(km) km", 160, 108)
        }
        .frame(width: 308, height: 150, alignment: .topLeading).offset(x: 24, y: 184)
    }

    private func cell(_ l: String, _ v: String, _ x: CGFloat, _ y: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) { cap(l); mono(v, 17).tracking(-0.17) }.offset(x: x, y: y)
    }

    private var scenarioRow: some View {
        let c = MRColorToken(scenarioHex)
        return HStack(spacing: 12) {
            HStack(spacing: 7) {
                MRIcon(scenarioIcon, size: 15)
                Text(scenarioLabel).font(.mr(.ui, size: 13, weight: 600))
            }
            .foregroundStyle(Color(red: c.rgb.r * 0.52 + 0.078 * 0.48, green: c.rgb.g * 0.52 + 0.067 * 0.48, blue: c.rgb.b * 0.52 + 0.059 * 0.48))
            .padding(.leading, 10).padding(.trailing, 13).frame(height: 30)
            .background(Capsule().fill(Color(red: c.rgb.r * 0.3 + 0.96 * 0.7, green: c.rgb.g * 0.3 + 0.94 * 0.7, blue: c.rgb.b * 0.3 + 0.9 * 0.7)))
            .overlay(Capsule().strokeBorder(Color(red: c.rgb.r * 0.65 + 0.078 * 0.35, green: c.rgb.g * 0.65 + 0.067 * 0.35, blue: c.rgb.b * 0.65 + 0.059 * 0.35), lineWidth: 1))
            Spacer()
        }
        .frame(width: 308, height: 56).offset(x: 24, y: 334)
    }

    private var passengerRow: some View {
        HStack {
            if let group {
                HStack(spacing: 0) {
                    ForEach(Array(group.enumerated()), id: \.offset) { i, n in
                        Text(n).font(.mr(.ui, size: 9, weight: 700)).foregroundStyle(ink)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(MRColorToken(["#7AA2FF", "#FFB86B", "#7ADDB2", "#FF8FB1", "#B49CFF", "#8EE3E8"][i % 6]).color))
                            .overlay(Circle().strokeBorder(paper.color, lineWidth: 1.5).padding(-1.5))
                            .padding(.leading, i == 0 ? 0 : -5)
                    }
                    Text("\(group.count) on board").font(.mr(.mono, size: 11, weight: 500)).foregroundStyle(ink.opacity(0.75)).padding(.leading, 8)
                }.padding(.leading, 5)
            } else {
                Text(name).font(.mr(.mono, size: 12, weight: 500)).tracking(0.72).foregroundStyle(ink.opacity(0.92))
            }
            Spacer()
            HStack(spacing: 8) {
                Text("Class: Economy").font(.mr(.ui, size: 12, weight: 500)).foregroundStyle(ink.opacity(0.92))
                RoundedRectangle(cornerRadius: 3).fill(MRFoil.economy.gradient).frame(width: 28, height: 10)
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(ink.opacity(0.28), lineWidth: 1))
            }
        }
        .frame(width: 308, height: 40)
        .overlay(alignment: .top) { Rectangle().fill(ink.opacity(0.14)).frame(height: 1) }
        .offset(x: 24, y: 390)
    }

    private var stub: some View {
        ZStack(alignment: .topLeading) {
            Perf().fill(ink.opacity(0.45)).frame(width: 320, height: 2).offset(x: 20, y: 449)
            HStack {
                HStack(spacing: 6) {
                    MRIcon(.scissors, size: 12)
                    cap("Tear here").tracking(0.2 * 9.5)
                }
                Spacer()
                Text("\(from) → \(to)").font(.mr(.mono, size: 10, weight: 500)).opacity(0.7).foregroundStyle(ink)
            }.frame(width: 312, height: 18).offset(x: 24, y: 458)
            HStack(alignment: .bottom, spacing: 28) {
                stubCell("Seat", seat); stubCell("Gate", gate); stubCell("Time", boarding)
                Spacer()
                VStack(alignment: .trailing, spacing: 5) { cap(flight); mono("\(minutes) min", 16) }
            }.frame(width: 312, height: 34).offset(x: 24, y: 482)
            Barcode(seed: 49).fill(ink.opacity(0.92)).frame(width: 300, height: 56).offset(x: 30, y: 524)
            Text("MR0142·\(from)\(to)·\(seat)·29OCT26·001149").font(.mr(.mono, size: 7, weight: 500)).tracking(0.98)
                .foregroundStyle(ink.opacity(0.65)).frame(width: 300).offset(x: 30, y: 584)
        }
    }

    private func stubCell(_ l: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 5) { cap(l); mono(v, 16) }
    }
}

// MARK: - Shapes

private nonisolated struct DashLine: Shape {
    func path(in r: CGRect) -> Path { var p = Path(); p.move(to: CGPoint(x: 0, y: r.midY)); p.addLine(to: CGPoint(x: r.maxX, y: r.midY)); return p }
}

private nonisolated struct Perf: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        var x: CGFloat = 4
        while x < r.maxX { p.addEllipse(in: CGRect(x: x - 1, y: r.midY - 1, width: 2, height: 2)); x += 8 }
        return p
    }
}

private nonisolated struct Barcode: Shape {
    let seed: UInt64
    func path(in r: CGRect) -> Path {
        var p = Path(); var s = seed &* 2654435761 &+ 12345; var x: CGFloat = 0
        while x < r.width {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            let w = CGFloat(1 + (s >> 33) % 3) * 1.4, gap = CGFloat(1 + (s >> 40) % 3) * 1.1
            p.addRect(CGRect(x: x, y: 0, width: min(w, r.width - x), height: r.height)); x += w + gap
        }
        return p
    }
}

/// Jagged bottom edge at y ≈ 450 (seeded), as `tornPolygon`.
private nonisolated func tornPoints(seed: UInt64) -> [CGPoint] {
    var s = seed &* 2654435761 &+ 99
    func rnd() -> CGFloat { s = s &* 6364136223846793005 &+ 1442695040888963407; return CGFloat((s >> 33) % 10_000) / 10_000 }
    let amp = 1.5 + rnd(); var pts: [CGPoint] = []; var x: CGFloat = 360
    while x > -4 { pts.append(CGPoint(x: max(0, x), y: 450 - amp + rnd() * amp * 2)); x -= 2.2 + rnd() * 3.4 }
    return pts
}

private nonisolated struct TornBottom: Shape {
    let seed: UInt64
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: .zero); p.addLine(to: CGPoint(x: 360, y: 0))
        for q in tornPoints(seed: seed) { p.addLine(to: q) }
        p.addLine(to: CGPoint(x: 0, y: 450)); p.closeSubpath(); return p
    }
}

private nonisolated struct TornRim: Shape {
    let seed: UInt64
    func path(in r: CGRect) -> Path {
        var p = Path()
        for (i, q) in tornPoints(seed: seed).enumerated() { i == 0 ? p.move(to: CGPoint(x: q.x, y: q.y - 0.5)) : p.addLine(to: CGPoint(x: q.x, y: q.y - 0.5)) }
        return p
    }
}

private nonisolated struct Notches: Shape {
    let y: CGFloat
    func path(in r: CGRect) -> Path {
        var p = Path(); p.addRect(CGRect(x: 0, y: 0, width: 360, height: 600))
        p.addEllipse(in: CGRect(x: -14, y: y - 14, width: 28, height: 28))
        p.addEllipse(in: CGRect(x: 346, y: y - 14, width: 28, height: 28))
        return p
    }
}

// MARK: - Stub tear slot

/// Thin slot for the stub that is being torn off (lobby, in turn). The real tearing component (drag, rip sound) is built
/// on another branch and replaces `content` / the transform; this slot only places the detached stub:
/// translate (34, 120) pt, rotate 24 deg around (20 %, 0) and fade out, all driven by `progress` 0...1.
struct StubTearSlot<Content: View>: View {
    var progress: Double
    var size: CGSize
    @ViewBuilder var content: () -> Content

    var body: some View {
        let u = max(0, min(1, progress)), e = u * u * (3 - 2 * u)
        content()
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .rotationEffect(.degrees(e * 24), anchor: UnitPoint(x: 0.2, y: 0))
            .offset(x: e * 34, y: e * 120)
            .opacity(u > 0 ? 1 - e * e : 0)
            .allowsHitTesting(false)
    }
}

/// The printed ticket clipped to its stub (below the perforation), scaled like the lobby row.
struct TGTicketStub: View {
    var scale: CGFloat = 0.4
    var t: TGTicket

    var body: some View {
        var full = t; full.variant = .printed; full.flat = true; full.scale = scale
        return full
            .frame(width: 360 * scale, height: 600 * scale, alignment: .topLeading)
            .clipShape(StubPolygon(scale: scale))
    }
}

private nonisolated struct StubPolygon: Shape {
    let scale: CGFloat
    func path(in r: CGRect) -> Path {
        var p = Path()
        let ys: [CGFloat] = [445, 435, 447.5, 437.5, 447.5, 435, 442.5]
        for (i, y) in ys.enumerated() { let q = CGPoint(x: CGFloat(i) * 60 * scale, y: y * scale); i == 0 ? p.move(to: q) : p.addLine(to: q) }
        p.addLine(to: CGPoint(x: 360 * scale, y: 442.5 * scale)); p.addLine(to: CGPoint(x: 360 * scale, y: 600 * scale)); p.addLine(to: CGPoint(x: 0, y: 600 * scale)); p.closeSubpath()
        return p
    }
}
