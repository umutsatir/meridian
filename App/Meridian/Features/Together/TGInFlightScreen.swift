import MeridianCore
import MeridianMaps
import MeridianUI
import SwiftUI

/// S43: the shared in-flight screen. A full-bleed cruise map with the Together layer: passenger strip, optional friend
/// markers (own route trail, status only) and "Anna landed" toasts. No chat anywhere (TOG-4).
/// The cruise screen itself (HUD, window view, phases) is built on another branch; when it lands, mount `TGFlightLayer`
/// on top of it and drop the map scaffolding below.
struct TGInFlightScreen: View {
    @Bindable var model: TogetherModel
    @Environment(\.mrPalette) private var p
    @State private var toastShown = false

    var body: some View {
        GeometryReader { geo in
            if model.frozenProgress != nil { scene(geo.size, date: Date()) } else {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in scene(geo.size, date: ctx.date) }
            }
        }
    }

    private func scene(_ size: CGSize, date: Date) -> some View {
        let c = model.config
        let prog = model.progress(at: date)
        let A = MapAirports.bundled.coordinate(c.from) ?? Coordinate(latitude: 51.47, longitude: -0.45)
        let B = MapAirports.bundled.coordinate(c.to) ?? Coordinate(latitude: 49.0, longitude: 2.55)
        let here = Geo.interpolate(from: A, to: B, fraction: prog)
        let W = size.width, H = size.height
        let a = EuropeProjection.xy(A), b = EuropeProjection.xy(B)
        let zFit = min(0.62 * (W - 220) / max(abs(a.x - b.x), 1), 0.5 * (H - 240) / max(abs(a.y - b.y), 1), 5)
        let zb = max(0.5, min(7, min(zFit, 3.2)))
        let off = CGSize(width: 0, height: H * 0.45 - H / 2)
        func scr(_ q: Coordinate) -> CGPoint { EuropeProjection.screenPoint(q, center: here, zoom: zb, size: size, offset: off) }
        let route = (0...90).map { scr(Geo.interpolate(from: A, to: B, fraction: Double($0) / 90)) }
        let k = Int(prog * 90)
        let trail = Array(route[0...k]) + [scr(here)]
        let future = [scr(here)] + Array(route[min(90, k + 1)...])
        let hp = scr(here)
        let ahead = scr(Geo.interpolate(from: A, to: B, fraction: min(1, prog + 0.01))), behind = scr(Geo.interpolate(from: A, to: B, fraction: max(0, prog - 0.01)))
        let heading = atan2(ahead.x - behind.x, -(ahead.y - behind.y)) * 180 / .pi
        let remMin = Int((Double(c.minutes) * (1 - prog)).rounded(.up)), remKm = Int((Double(c.km) * (1 - prog)).rounded())
        let annaLanded = model.annaLanded || prog > 0.9

        return ZStack(alignment: .topLeading) {
            EuropeMapView(style: .terra, center: here, zoom: zb, offset: off).frame(width: W, height: H)
            RadialGradient(colors: [.clear, MRColorToken(6, 8, 13, 0.55).color], center: .center, startRadius: 0.55 * max(W, H) * 0.55, endRadius: max(W, H) * 0.75)
                .allowsHitTesting(false)

            // route
            Canvas { ctx, _ in
                func path(_ pts: [CGPoint]) -> Path { var q = Path(); for (i, pt) in pts.enumerated() { i == 0 ? q.move(to: pt) : q.addLine(to: pt) }; return q }
                ctx.stroke(path(future), with: .color(MRColorToken("#F3F5FA").opacity(0.46)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [2, 7]))
                var glow = ctx; glow.addFilter(.blur(radius: 4))
                glow.stroke(path(trail), with: .color(MRColorToken("#6AB7FF").opacity(0.3)), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                ctx.stroke(path(trail), with: .linearGradient(Gradient(colors: [MRColorToken("#6AB7FF").color, MRColorToken("#8BF3D8").color]), startPoint: trail.first ?? .zero, endPoint: hp),
                           style: StrokeStyle(lineWidth: 3, lineCap: .round))
                for f in Self.crew { ctx.stroke(path(friendTrail(f, scr)), with: .color(MRColorToken(f.hex).opacity(0.55)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [2, 5])) }
            }.frame(width: W, height: H).allowsHitTesting(false)

            // airports
            dot(scr(A), MRColorToken("#FFFFFF").color); dot(scr(B), MRColorToken("#FFB547").color)
            AirportTag(code: c.from, showsIcon: true).position(x: scr(A).x, y: scr(A).y - 33.6)
            AirportTag(code: c.to, isSelected: true, showsIcon: true).position(x: scr(B).x, y: scr(B).y - 33.6)

            // friends and own plane
            ForEach(Self.crew, id: \.name) { f in
                let q = friendPos(f, scr)
                ZStack(alignment: .topLeading) {
                    MRIcon(.plane, size: 20).foregroundStyle(MRColorToken(f.hex).color).rotationEffect(.degrees(q.heading)).frame(width: 20, height: 20)
                    Text(f.name).font(.mr(.ui, size: 11, weight: 500)).foregroundStyle(p.text1.color)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(MRColorToken(18, 26, 46, 0.92).color))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(p.strokeHair.color, lineWidth: 1))
                        .fixedSize().offset(x: 24, y: -4)
                }.frame(width: 20, height: 20).position(q.point)
            }
            MRIcon(.plane, size: 30).foregroundStyle(.white).rotationEffect(.degrees(heading)).shadow(color: .black.opacity(0.5), radius: 4, y: 2).position(hp)

            TGFlightLayer(annaLanded: annaLanded, width: W)

            // controls
            HStack(spacing: 10) {
                Button {} label: { MRIcon(.pause, size: 18) }.buttonStyle(MRRoundButtonStyle()).accessibilityLabel("Pause")
                Button {} label: { MRIcon(.sound, size: 18) }.buttonStyle(MRRoundButtonStyle()).accessibilityLabel("Sound")
            }.offset(x: 20, y: 18)
            capsule([(.navigate, true), (.route, true), (.layers, false), (.cabinWindow, false)]).offset(x: W - 20 - 48, y: 18)
            capsule([(.plus, false), (.minus, false)]).offset(x: W - 20 - 48, y: 202)

            readout("Time remaining", "\(remMin)", "min").offset(x: 28, y: H - 26 - 54)
            readout("Distance remaining", "\(remKm)", "km", trailing: true).frame(width: 300, alignment: .trailing).offset(x: W - 28 - 300, y: H - 26 - 54)
        }
        .frame(width: W, height: H, alignment: .topLeading).clipped()
        .accessibilityElement(children: .contain)
        .onChange(of: prog >= 1) { _, done in if done && model.frozenProgress == nil { model.go(.landing) } }
        .onAppear { if prog >= 1 && model.frozenProgress == nil { model.go(.landing) } }
    }

    // MARK: Pieces

    private struct Friend { let name: String, hex: String, from: String, to: String, p: Double }
    private static let crew = [Friend(name: "Anna", hex: "#FF8FB1", from: "AMS", to: "LHR", p: 0.62), Friend(name: "Mert", hex: "#7ADDB2", from: "BRU", to: "LHR", p: 0.3)]

    private func friendTrail(_ f: Friend, _ scr: (Coordinate) -> CGPoint) -> [CGPoint] {
        guard let a = MapAirports.bundled.coordinate(f.from), let b = MapAirports.bundled.coordinate(f.to) else { return [] }
        return (0...59).map { scr(Geo.interpolate(from: a, to: b, fraction: Double($0) / 59)) }
    }

    private func friendPos(_ f: Friend, _ scr: (Coordinate) -> CGPoint) -> (point: CGPoint, heading: Double) {
        let t = friendTrail(f, scr)
        guard t.count == 60 else { return (.zero, 0) }
        let i = Int((f.p * 59).rounded()), j = min(59, i + 1)
        return (t[i], atan2(t[j].x - t[i].x, -(t[j].y - t[i].y)) * 180 / .pi)
    }

    private func dot(_ q: CGPoint, _ c: Color) -> some View {
        Circle().fill(p.bg1.color).frame(width: 10, height: 10).overlay(Circle().strokeBorder(c, lineWidth: 2).padding(-2)).position(q)
    }

    private func capsule(_ items: [(MRIconName, Bool)]) -> some View {
        VStack(spacing: 2) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, it in
                MRIcon(it.0, size: 18).foregroundStyle(it.1 ? p.bg0.color : p.text1.color)
                    .frame(width: 40, height: 40).background(Circle().fill(it.1 ? p.text1.color : .clear))
            }
        }.padding(4).tgCard(radius: 26, .e2)
    }

    private func readout(_ k: String, _ v: String, _ u: String, trailing: Bool = false) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 2) {
            Text(k).font(.mr(.ui, size: 13, weight: 500)).opacity(0.82).frame(height: 16)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(v).font(.mr(.ui, size: 36, weight: 600)).tracking(-0.54).monospacedDigit()
                Text(u).font(.mr(.ui, size: 19, weight: 500)).opacity(0.88)
            }.frame(height: 40)
        }
        .foregroundStyle(p.text1.color).shadow(color: .black.opacity(0.4), radius: 7, y: 1)
    }
}

/// The Together layer of S43: passenger strip (top centre) and the "Anna landed" toast. No chat (TOG-4). Mounted over the map
/// scaffold of `TGInFlightScreen` and over the real cruise screen (`LiveCruiseScreen`) of a flight started in Together mode.
struct TGFlightLayer: View {
    var annaLanded = false
    let width: CGFloat
    @Environment(\.mrPalette) private var p

    var body: some View {
        ZStack(alignment: .topLeading) {
            strip.position(x: width / 2, y: 14 + 28)
            if annaLanded {
                HStack(spacing: 12) {
                    SeatAvatar(initial: "A", tintHex: "#FF8FB1", presence: .landed, diameter: 32, dot: 10)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Anna landed").font(.mr(.ui, size: 14, weight: 600)).foregroundStyle(p.text1.color).frame(height: 18)
                        Text("Paris CDG · 42 min focused").font(.mr(.ui, size: 13)).foregroundStyle(p.text2.color).frame(height: 18)
                    }
                }
                .padding(.leading, 12).padding(.trailing, 18).padding(.vertical, 12)
                .tgCard(radius: 20, .e3).fixedSize().offset(x: width - 92 - 245, y: 84)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private var strip: some View {
        let pax: [(String, String, String, String, TGPresence)] = [("You", "E", "1A", "In flight", .inFlight), ("Anna", "A", "1C", annaLanded ? "Landed" : "In flight", annaLanded ? .landed : .inFlight),
                                                                    ("Mert", "M", "2A", "Away 2 min", .idle), ("Jo", "J", "2C", "In flight", .inFlight)]
        let hex = ["#7AA2FF", "#FF8FB1", "#7ADDB2", "#FFB86B"]
        return HStack(spacing: 0) {
            ForEach(Array(pax.enumerated()), id: \.offset) { i, a in
                HStack(spacing: 8) {
                    SeatAvatar(initial: a.1, tintHex: hex[i], presence: a.4, diameter: 32, dot: 10)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(a.0).font(.mr(.ui, size: 12, weight: 600)).foregroundStyle(p.text1.color).frame(height: 14)
                        Text("\(a.2) · \(a.3)").font(.mr(.mono, size: 10, weight: 500)).foregroundStyle(p.text3.color).frame(height: 12).fixedSize()
                    }
                }.padding(.leading, 4).padding(.trailing, 10)
            }
        }
        .padding(.horizontal, 10).frame(height: 56).tgCard(radius: 28, .e2)
        .accessibilityElement(children: .combine).accessibilityLabel("Passengers")
    }

}
