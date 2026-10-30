import MeridianCore
import MeridianMaps
import MeridianUI
import SwiftUI

enum SeatTVMode: String { case map, window }

/// CSS `linear-gradient(<angle>deg, ...)` for a box of `size`.
func cssLinearGradient(angle: Double, stops: [Gradient.Stop], size: CGSize) -> LinearGradient {
    let a = angle * .pi / 180
    let dx = sin(a), dy = -cos(a)
    let length = abs(size.width * dx) + abs(size.height * dy)
    let cx = size.width / 2, cy = size.height / 2
    let start = CGPoint(x: cx - dx * length / 2, y: cy - dy * length / 2)
    let end = CGPoint(x: cx + dx * length / 2, y: cy + dy * length / 2)
    return LinearGradient(stops: stops,
                          startPoint: UnitPoint(x: start.x / size.width, y: start.y / size.height),
                          endPoint: UnitPoint(x: end.x / size.width, y: end.y / size.height))
}

/// `SeatTV.dc.html` (M03 / M03B): the seat-back screen. It is drawn on the 1280 x 800 artboard and scaled to the
/// size of the window, so the proportions of the bezel never change.
struct SeatTVView: View {
    var info: SystemFlightInfo
    @Binding var mode: SeatTVMode
    var onClose: () -> Void = {}

    static let artboard = CGSize(width: 1280, height: 800)
    private static let screen = CGSize(width: 1236, height: 756)

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / Self.artboard.width, geo.size.height / Self.artboard.height)
            ZStack {
                Color.black
                content
                    .frame(width: Self.artboard.width, height: Self.artboard.height)
                    .scaleEffect(scale)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .environment(\.colorScheme, .dark)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) { mode = .map; return .handled }
        .onKeyPress(.rightArrow) { mode = .window; return .handled }
        .onKeyPress(.escape) { onClose(); return .handled }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Seat-back screen, \(mode == .map ? "map view" : "window view")")
    }

    private var content: some View {
        let W = Self.screen.width, H = Self.screen.height
        return ZStack(alignment: .topLeading) {
            Color.black
            ZStack(alignment: .topLeading) {
                Color(red: 5 / 255, green: 7 / 255, blue: 13 / 255)
                if mode == .map { mapLayer(W, H) } else { windowLayer(W, H) }
                topRow(W)
                infoBar(W, H)
                Text("← → switch view · Esc close")
                    .font(MRFonts.font(.mono, size: 11, weight: 500)).foregroundStyle(sysRGBA(243, 245, 250, 0.5))
                    .position(x: W - 38 - 70, y: H - 7 - 7)
            }
            .frame(width: W, height: H)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.07), lineWidth: 1))
            .offset(x: 22, y: 22)
            // bezel reflection
            Rectangle().fill(cssLinearGradient(angle: 112, stops: [
                .init(color: .white.opacity(0.13), location: 0), .init(color: .white.opacity(0.04), location: 0.14),
                .init(color: .white.opacity(0), location: 0.30)], size: Self.artboard))
                .blendMode(.screen).allowsHitTesting(false)
            Rectangle().fill(cssLinearGradient(angle: 112, stops: [
                .init(color: .white.opacity(0), location: 0.54), .init(color: .white.opacity(0.05), location: 0.60),
                .init(color: .white.opacity(0), location: 0.66)], size: Self.artboard))
                .blendMode(.screen).allowsHitTesting(false)
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(.white.opacity(0.05), lineWidth: 1)
                .frame(width: W, height: H)
                .shadow(color: .black.opacity(0.6), radius: 20)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .offset(x: 22, y: 22).allowsHitTesting(false)
        }
    }

    // MARK: Map

    private struct Frame {
        let sp: [CGPoint]
        let here: CGPoint
        let heading: Double
        let k0: Int
        let zoom: Double
        let mid: Coordinate
    }

    private func frame(_ W: Double, _ H: Double) -> Frame? {
        guard let a = info.origin, let b = info.destination else { return nil }
        let pts = systemArc(from: a, to: b, steps: 60)
        let prog = min(1, max(0, info.progress))
        let si = prog * Double(pts.count - 1)
        let k0 = Int(si.rounded(.down)), k1 = min(pts.count - 1, k0 + 1), f = si - Double(k0)
        let hereC = Coordinate(latitude: pts[k0].latitude + (pts[k1].latitude - pts[k0].latitude) * f,
                               longitude: pts[k0].longitude + (pts[k1].longitude - pts[k0].longitude) * f)
        let A = EuropeProjection.xy(pts[0]), B = EuropeProjection.xy(pts[pts.count - 1])
        let z = min(0.56 * W / max(abs(A.x - B.x), 1), 0.46 * H / max(abs(A.y - B.y), 1), 6)
        let mid = pts[pts.count / 2]
        let C = EuropeProjection.xy(mid)
        func scr(_ c: Coordinate) -> CGPoint {
            let q = EuropeProjection.xy(c)
            return CGPoint(x: (q.x - C.x) * z + W / 2, y: (q.y - C.y) * z + H / 2 - 70)
        }
        let sp = pts.map(scr)
        let ahead = sp[min(sp.count - 1, k0 + 2)]
        return Frame(sp: sp, here: scr(hereC), heading: atan2(ahead.x - sp[k0].x, -(ahead.y - sp[k0].y)) * 180 / .pi,
                     k0: k0, zoom: z, mid: mid)
    }

    @ViewBuilder
    private func mapLayer(_ W: Double, _ H: Double) -> some View {
        if let f = frame(W, H) {
            EuropeMapView(style: .terra, theme: .dark, center: f.mid, zoom: f.zoom,
                          size: CGSize(width: W, height: H))
            RadialGradient(stops: [.init(color: sysRGBA(6, 8, 13, 0), location: 0.52), .init(color: sysRGBA(6, 8, 13, 0.72), location: 1)],
                           center: UnitPoint(x: 0.5, y: 0.42), startRadius: 0, endRadius: max(W, H) * 0.62)
                .frame(width: W, height: H)
            LinearGradient(colors: [sysRGBA(6, 8, 13, 0), sysRGBA(6, 8, 13, 0.7)], startPoint: .top, endPoint: .bottom)
                .frame(width: W, height: 300).offset(y: H - 300)
            route(f)
        }
    }

    private func route(_ f: Frame) -> some View {
        func line(_ pts: [CGPoint]) -> Path {
            var p = Path()
            for (i, q) in pts.enumerated() { i == 0 ? p.move(to: q) : p.addLine(to: q) }
            return p
        }
        let trail = line(Array(f.sp[0...f.k0]) + [f.here])
        let future = line(Array(f.sp[f.k0...]))
        return ZStack(alignment: .topLeading) {
            future.stroke(.white.opacity(0.5), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 9]))
            trail.stroke(sysRGBA(106, 183, 255, 0.28), style: StrokeStyle(lineWidth: 12, lineCap: .round))
            trail.stroke(LinearGradient(colors: [sysRGBA(106, 183, 255), sysRGBA(139, 243, 216)], startPoint: .leading, endPoint: .trailing),
                         style: StrokeStyle(lineWidth: 4, lineCap: .round))
            Circle().fill(.white).frame(width: 12, height: 12).position(f.sp[0])
            Circle().strokeBorder(sysRGBA(255, 181, 71), lineWidth: 2.5).frame(width: 12, height: 12).position(f.sp[f.sp.count - 1])
            MRIcon(.plane, size: 64).foregroundStyle(.white).rotationEffect(.degrees(f.heading))
                .shadow(color: .black.opacity(0.55), radius: 5, y: 6).position(f.here)
            place(info.originName, "\(info.originCode) · departed \(info.departedText)")
                .offset(x: f.sp[0].x - 60, y: f.sp[0].y + 16)
            place(info.destinationName, "\(info.destinationCode) · lands \(info.landsText)")
                .offset(x: f.sp[f.sp.count - 1].x + 16, y: f.sp[f.sp.count - 1].y + 12)
        }
        .accessibilityHidden(true)
    }

    private func place(_ name: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(name).font(MRFonts.font(.ui, size: 15, weight: 600)).frame(height: 18)
            Text(sub).font(MRFonts.font(.mono, size: 12, weight: 500)).foregroundStyle(sysRGBA(243, 245, 250, 0.62)).frame(height: 16)
        }
        .foregroundStyle(sysRGBA(243, 245, 250))
        .fixedSize()
    }

    private func windowLayer(_ W: Double, _ H: Double) -> some View {
        // The cabin window scene belongs to the in-flight screens; until it is wired the seat screen shows its sky.
        ZStack(alignment: .topLeading) {
            RadialGradient(colors: [sysRGBA(18, 22, 31), sysRGBA(4, 5, 8)], center: UnitPoint(x: 0.5, y: 0.4), startRadius: 0, endRadius: W * 0.6)
            MRSky.allCases[0].gradient.frame(width: W, height: 680).offset(y: 24)
            LinearGradient(colors: [sysRGBA(6, 8, 13, 0), sysRGBA(6, 8, 13, 0.7)], startPoint: .top, endPoint: .bottom)
                .frame(width: W, height: 220).offset(y: H - 220)
        }
        .frame(width: W, height: H)
    }

    // MARK: Chrome

    private func topRow(_ W: Double) -> some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 14) {
                MRIcon(.plane, size: 20).foregroundStyle(MRPalette.dark.accent1.color)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(sysRGBA(18, 26, 46, 0.6)))
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(.white.opacity(0.16), lineWidth: 1))
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(info.flightNumber) · Cruise").font(MRFonts.font(.ui, size: 11, weight: 600)).tracking(1.1).textCase(.uppercase)
                        .foregroundStyle(sysRGBA(243, 245, 250, 0.8)).frame(height: 14)
                    Text("\(info.originCity) to \(info.destinationCity)").font(MRFonts.font(.ui, size: 18, weight: 600))
                        .foregroundStyle(sysRGBA(243, 245, 250)).frame(height: 22)
                }
            }
            .offset(x: 34, y: 30)
            HStack(spacing: 16) {
                Text(info.clockLine).font(MRFonts.font(.mono, size: 13, weight: 500)).foregroundStyle(sysRGBA(243, 245, 250, 0.7))
                segmented
            }
            .frame(width: W - 34, alignment: .trailing)
            .offset(y: 30)
        }
    }

    private var segmented: some View {
        HStack(spacing: 2) {
            tab(.map, "Map", .map)
            tab(.window, "Window", .window)
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(sysRGBA(18, 26, 46, 0.6)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.16), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("View")
    }

    private func tab(_ value: SeatTVMode, _ title: String, _ icon: MRIconName) -> some View {
        let on = mode == value
        return Button { mode = value } label: {
            HStack(spacing: 8) { MRIcon(icon, size: 16); Text(title).font(MRFonts.font(.ui, size: 14, weight: 500)) }
                .foregroundStyle(on ? Color.white : sysRGBA(243, 245, 250, 0.72))
                .padding(.horizontal, 18).frame(height: 34)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(on ? .white.opacity(0.18) : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }

    private func infoBar(_ W: Double, _ H: Double) -> some View {
        let pct = Int((info.progress * 100).rounded())
        let stats: [(String, String, String)] = [
            ("Time to go", info.timeString, ""), ("Distance to go", "\(info.distanceToGoKm)", "km"),
            ("Ground speed", "\(info.groundSpeedKmh)", "km/h"), ("Altitude", Self.grouped(info.altitudeM), "m"),
            ("Outside air", "\(info.outsideAirC < 0 ? "−" : "")\(abs(info.outsideAirC))", "°C"),
        ]
        return VStack(spacing: 14) {
            HStack(spacing: 16) {
                Text(info.originCode).font(MRFonts.font(.mono, size: 14, weight: 500))
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.16)).frame(height: 6)
                        Capsule().fill(LinearGradient(colors: [sysRGBA(106, 183, 255), sysRGBA(139, 243, 216)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: g.size.width * info.progress, height: 6)
                        Circle().fill(.white).frame(width: 16, height: 16)
                            .overlay(Circle().stroke(sysRGBA(106, 183, 255, 0.3), lineWidth: 4).padding(-4))
                            .offset(x: g.size.width * info.progress - 8)
                    }
                    .frame(height: g.size.height)
                }
                .frame(height: 16)
                Text(info.destinationCode).font(MRFonts.font(.mono, size: 14, weight: 500))
            }
            .foregroundStyle(sysRGBA(243, 245, 250))
            .padding(.horizontal, 22)
            HStack(spacing: 0) {
                ForEach(Array(stats.enumerated()), id: \.offset) { i, s in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(s.0).font(MRFonts.font(.ui, size: 11, weight: 600)).tracking(1.1).textCase(.uppercase)
                            .foregroundStyle(sysRGBA(243, 245, 250, 0.62)).frame(height: 14)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(s.1).font(MRFonts.font(.serif, size: 34, weight: 500)).tracking(-0.68).monospacedDigit()
                            if !s.2.isEmpty {
                                Text(s.2).font(MRFonts.font(.ui, size: 13, weight: 500)).foregroundStyle(sysRGBA(243, 245, 250, 0.7))
                            }
                        }
                        .foregroundStyle(sysRGBA(243, 245, 250)).lineLimit(1).frame(height: 38, alignment: .leading)
                    }
                    .padding(.horizontal, 22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .leading) { if i > 0 { Rectangle().fill(.white.opacity(0.12)).frame(width: 1) } }
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(width: W - 68, height: 150)
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(sysRGBA(14, 20, 36, 0.62)))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(.white.opacity(0.10), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 22, y: 18)
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(
            cssLinearGradient(angle: 135, stops: [.init(color: .white.opacity(0.10), location: 0), .init(color: .white.opacity(0.02), location: 0.4),
                                                  .init(color: .white.opacity(0.05), location: 1)], size: CGSize(width: W - 68, height: 150)))
            .allowsHitTesting(false))
        .offset(x: 34, y: H - 30 - 150)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Flight information. \(pct) percent of the way. \(info.timeString) to go, \(info.distanceToGoKm) kilometres, \(info.groundSpeedKmh) kilometres per hour, altitude \(info.altitudeM) metres.")
    }

    static func grouped(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        return f.string(from: NSNumber(value: n)) ?? String(n)
    }
}
