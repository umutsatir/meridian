import UniformTypeIdentifiers
import AppKit
import MeridianCore
import MeridianMaps
import MeridianUI
import SwiftUI

private let gA = Color(.sRGB, red: 106 / 255, green: 183 / 255, blue: 1)
private let gB = Color(.sRGB, red: 139 / 255, green: 243 / 255, blue: 216 / 255)
private let gradDiag = LinearGradient(colors: [gA, gB], startPoint: .topLeading, endPoint: .bottomTrailing)

private let allRoutes: [(String, String)] = [("LHR", "CDG"), ("LHR", "AMS"), ("LHR", "DUB"), ("LHR", "FRA"), ("LHR", "IST"), ("LHR", "MAD"), ("LHR", "CAI"), ("LHR", "JFK"), ("LHR", "DXB"), ("IST", "ESB"), ("FRA", "IST"), ("JFK", "BOS"), ("BOS", "YYZ"), ("YYZ", "SFO"), ("DXB", "DOH"), ("AMS", "BCN")]

// MARK: - One 360 x 640 story frame (Recap.dc.html)

/// A story frame. Always drawn in the dark palette (`data-theme="dark"`), at 360 x 640 points; exported at 3x.
struct RecapFrame: View {
    let index: Int
    let data: ExploreData
    @Environment(\.mrPalette) private var p

    var body: some View {
        let f = ((index % 8) + 8) % 8
        ZStack(alignment: .topLeading) {
            p.bg0.color
            switch f {
            case 0: cover
            case 1: hours
            case 2: distance
            case 3: favourite
            case 4: longest
            case 5: busiest
            case 6: routesFrame
            default: card
            }
            HStack {
                ExT(s: "Meridian", size: 10, weight: 600, lh: 10, color: p.text2.color, em: 0.2, upper: true)
                Spacer(minLength: 0)
                ExT(s: "\(f + 1) / 8", size: 10, weight: 600, lh: 10, color: p.text2.color, em: 0.2, upper: true)
            }.frame(width: 304).exAt(28, 26)
            HStack {
                ExT(s: data.name.uppercased(), fam: .mono, size: 10, weight: 500, lh: 10, color: p.text3.color, em: 0.06)
                Spacer(minLength: 0)
                ExT(s: String(data.year), fam: .mono, size: 10, weight: 500, lh: 10, color: p.text3.color, em: 0.06)
            }.frame(width: 304).exAt(28, 640 - 26 - 10)
        }
        .frame(width: 360, height: 640, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(.white.opacity(0.1), lineWidth: 1))
        .environment(\.colorScheme, .dark)
    }

    private func lbl(_ s: String, size: CGFloat = 11, lh: CGFloat = 14) -> some View {
        ExT(s: s, size: size, weight: 500, lh: lh, color: p.text2.color, em: 0.14, upper: true)
    }
    private func para(_ s: String, w: CGFloat = 304) -> some View {
        ExT(s: s, size: 16, weight: 400, lh: 24, color: p.text2.color, wrap: w)
    }
    private func serif(_ s: String, _ size: CGFloat, _ lh: CGFloat, color: Color? = nil, grad: Bool = false, italic: Bool = false, em: CGFloat = -0.025) -> some View {
        ExT(s: s, fam: .serif, size: size, weight: 500, lh: lh, color: color ?? p.text1.color, em: em, italic: italic, grad: grad ? gradDiag : nil)
    }
    private func hex(_ id: String) -> Color { ExScn.get(id).color }

    // 0
    private var cover: some View {
        ZStack(alignment: .topLeading) {
            ExGlow(rx: 0.8, ry: 0.5, cx: 0.5, cy: 0.78, color: Color(.sRGB, red: 70 / 255, green: 92 / 255, blue: 190 / 255, opacity: 0.4)).frame(width: 360, height: 640)
            GlobeView(lon: 8, lat: 38, size: 420,
                      routes: allRoutes.enumerated().compactMap { i, r in GlobeRoute(from: r.0, to: r.1, color: i % 3 != 0 ? gA : gB, width: 1.3, opacity: 0.8, lift: 0.08) },
                      pins: [GlobePin(code: "LHR", radius: 3.6), GlobePin(code: "JFK", radius: 3), GlobePin(code: "IST", radius: 3)].compactMap { $0 },
                      showsGraticule: false)
                .exAt(-30, 250)
            VStack(alignment: .leading, spacing: 0) {
                lbl("Year in flight")
                VStack(alignment: .leading, spacing: 0) {
                    serif("Your \(data.year),", 66, 66)
                    serif("in flight.", 66, 66, grad: true, italic: true)
                }.padding(.top, 16)
            }.exAt(28, 96)
        }
    }

    // 1
    private var hours: some View {
        ZStack(alignment: .topLeading) {
            ExGlow(rx: 0.9, ry: 0.5, cx: 0.2, cy: 0.3, color: gA.opacity(0.22)).frame(width: 360, height: 640)
            ExGlow(rx: 0.7, ry: 0.4, cx: 1, cy: 1, color: gB.opacity(0.14)).frame(width: 360, height: 640)
            VStack(alignment: .leading, spacing: 0) {
                lbl("Time in the air")
                serif(ExFmt.oneDecimal(data.hours), 150, 140, grad: true, em: -0.05).padding(.top, 20)
                serif("hours of focus.", 38, 42).padding(.top, 2)
                para("Nearly four days in the air, one flight at a time.", w: 280).padding(.top, 28)
            }.exAt(28, 110)
            HStack(spacing: 12) {
                statBox("Flights") { serif("\(data.flights)", 34, 38) }
                statBox("Average") {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        serif("\(data.avgMinutes)", 34, 38)
                        ExT(s: "min", size: 13, weight: 500, lh: 13, color: p.text2.color)
                    }
                }
            }.frame(width: 304).exAt(28, 640 - 80 - 90)
        }
    }

    private func statBox<C: View>(_ title: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            lbl(title, size: 10)
            c()
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(p.fill1.color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(p.strokeHair.color, lineWidth: 1))
    }

    // 2
    private var distance: some View {
        let fr = min(1, data.km / 40_075), ang = fr * 2 * .pi - .pi / 2
        let px = 180 + 128 * cos(ang), py = 180 + 128 * sin(ang)
        let g = MRMapPalette.Globe.dark
        return ZStack(alignment: .topLeading) {
            ExGlow(rx: 0.7, ry: 0.4, cx: 0.5, cy: 0.4, color: gA.opacity(0.2)).frame(width: 360, height: 640)
            ZStack(alignment: .topLeading) {
                Circle().stroke(p.fill3.color, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [1, 6])).frame(width: 256, height: 256).exAt(52, 52)
                Circle().trim(from: 0, to: fr).stroke(gradDiag, style: StrokeStyle(lineWidth: 4, lineCap: .round)).frame(width: 256, height: 256).rotationEffect(.degrees(-90)).exAt(52, 52)
                Circle().fill(g.seaA.color).frame(width: 164, height: 164).exAt(98, 98)
                Path { q in
                    q.move(to: CGPoint(x: 130, y: 150))
                    q.addQuadCurve(to: CGPoint(x: 186, y: 130), control: CGPoint(x: 152, y: 120))
                    q.addQuadCurve(to: CGPoint(x: 216, y: 166), control: CGPoint(x: 216, y: 140))
                    q.addQuadCurve(to: CGPoint(x: 176, y: 204), control: CGPoint(x: 206, y: 192))
                    q.addQuadCurve(to: CGPoint(x: 124, y: 184), control: CGPoint(x: 152, y: 228))
                    q.addLine(to: CGPoint(x: 130, y: 150))
                }.fill(g.land.color)
                Circle().fill(.white.opacity(0.16)).frame(width: 28, height: 28).exAt(px - 14, py - 14)
                Circle().fill(.white).frame(width: 12, height: 12).exAt(px - 6, py - 6)
            }.frame(width: 360, height: 360, alignment: .topLeading).exAt(0, 70)
            VStack(alignment: .leading, spacing: 0) {
                lbl("Distance")
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    serif(ExFmt.km(data.km), 64, 68)
                    ExT(s: "km", size: 18, weight: 500, lh: 18, color: p.text2.color)
                }.padding(.top, 10)
                para(String(format: "%.1f× around the world.", data.aroundEarth)).padding(.top, 8)
            }.exAt(28, 460)
        }
    }

    // 3
    private var favourite: some View {
        let fav = data.favourite ?? ("code", 0, 0)
        let s = ExScn.get(fav.id), c = s.color
        let mx = Double(data.mix.first?.count ?? 1)
        return ZStack(alignment: .topLeading) {
            ExGlow(rx: 0.8, ry: 0.45, cx: 0.3, cy: 0.24, color: c.opacity(0.3)).frame(width: 360, height: 640)
            VStack(alignment: .leading, spacing: 0) {
                lbl("Favourite scenario")
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(c.opacity(0.2)).frame(width: 64, height: 64)
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(c, lineWidth: 1.5))
                    .overlay { MRIcon(s.icon, size: 24).foregroundStyle(c) }
                    .shadow(color: c.opacity(0.4), radius: 18)
                    .padding(.top, 20)
                serif(s.name + ".", 76, 76, color: c).padding(.top, 20)
                para("\(fav.flights) flights, \(fav.pct)% of your year.").padding(.top, 12)
            }.exAt(28, 96)
            VStack(spacing: 0) {
                ForEach(Array(data.mix.enumerated()), id: \.offset) { _, m in
                    HStack(spacing: 10) {
                        ExT(s: ExScn.get(m.id).name, size: 12, weight: 500, lh: 12, color: p.text2.color).frame(width: 64, alignment: .leading)
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(p.fill2.color)
                                RoundedRectangle(cornerRadius: 3).fill(hex(m.id)).frame(width: g.size.width * Double(m.count) / mx)
                            }
                        }.frame(height: 6).clipShape(RoundedRectangle(cornerRadius: 3))
                        ExT(s: "\(m.count)", fam: .mono, size: 12, weight: 500, lh: 12, color: p.text1.color).frame(width: 26, alignment: .trailing)
                    }.frame(height: 30)
                }
            }.frame(width: 304).exAt(28, 380)
        }
    }

    // 4
    private var longest: some View {
        let l = data.longest
        let from = l?.from ?? "—", to = l?.to ?? "—"
        let amber = Color(.sRGB, red: 1, green: 184 / 255, blue: 107 / 255)
        return ZStack(alignment: .topLeading) {
            ExGlow(rx: 0.8, ry: 0.4, cx: 0.7, cy: 0.7, color: amber.opacity(0.2)).frame(width: 360, height: 640)
            VStack(alignment: .leading, spacing: 0) {
                lbl("Longest flight")
                VStack(alignment: .leading, spacing: 0) {
                    ExT(s: from, fam: .condensed, size: 104, weight: 700, lh: 96, color: p.text1.color, em: 0.005)
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        ExT(s: "→", fam: .condensed, size: 44, weight: 700, lh: 96, color: p.text3.color, em: 0.005)
                        ExT(s: " " + to, fam: .condensed, size: 104, weight: 700, lh: 96, color: p.text1.color, em: 0.005)
                    }
                }.padding(.top, 18)
                if let l {
                    ExT(s: "\(ExFmt.km(l.km)) km · \(ExFmt.hours(Double(l.durationMin) / 60).trimmingCharacters(in: .whitespaces))", fam: .mono, size: 15, weight: 500, lh: 18, color: p.text1.color).padding(.top, 14)
                    ExT(s: "\(l.fromCity) to \(l.toCity) · \(l.weekdayDate)", size: 13, weight: 400, lh: 18, color: p.text2.color).padding(.top, 4)
                }
            }.exAt(28, 96)
            if let l {
                let a = MapAirports.bundled.coordinate(l.from), b = MapAirports.bundled.coordinate(l.to)
                let mid = a.flatMap { a in b.map { b in ((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2) } }
                GlobeView(lon: data.isFixture ? 22 : (mid?.1 ?? 22), lat: data.isFixture ? 44 : (mid?.0 ?? 44), size: 300,
                          routes: [GlobeRoute(from: l.from, to: l.to, color: amber, width: 2.4, opacity: 0.95, lift: 0.12)].compactMap { $0 },
                          pins: [GlobePin(code: l.from, radius: 4), GlobePin(code: l.to, radius: 4)].compactMap { $0 },
                          showsGraticule: false, showsAtmosphere: false)
                    .exAt(30, 400)
            }
        }
    }

    // 5
    private var busiest: some View {
        let pink = Color(.sRGB, red: 1, green: 143 / 255, blue: 177 / 255)
        let parts = (data.busiest?.title ?? "—").components(separatedBy: ", ")
        var r = ExRNG(21)
        var cells: [(Double, Bool)] = []
        for i in 0..<56 { let hot = i == 29; let v = hot ? 1 : (r.next() < 0.35 ? 0 : r.next() * 0.55); cells.append((v, hot)) }
        return ZStack(alignment: .topLeading) {
            ExGlow(rx: 0.8, ry: 0.45, cx: 0.8, cy: 0.2, color: pink.opacity(0.22)).frame(width: 360, height: 640)
            VStack(alignment: .leading, spacing: 0) {
                lbl("Busiest day")
                VStack(alignment: .leading, spacing: 0) {
                    serif(parts.count > 1 ? parts[0] + "," : "", 72, 72)
                    serif(parts.count > 1 ? parts[1] : parts[0], 72, 72, color: pink, italic: true)
                }.padding(.top, 18)
                para(data.busiest?.line ?? "", w: 304).padding(.top, 14)
            }.exAt(28, 96)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 14), spacing: 5) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, c in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(c.1 ? pink : pink.opacity(0.08 + c.0 * 0.5))
                        .aspectRatio(1, contentMode: .fit)
                        .shadow(color: c.1 ? pink.opacity(0.7) : .clear, radius: 9)
                }
            }.frame(width: 304).exAt(28, 420)
            ExT(s: "8 weeks around \(shortDay)", fam: .mono, size: 10, weight: 500, lh: 10, color: p.text3.color, em: 0.08, upper: true).exAt(28, 572)
        }
    }
    private var shortDay: String {
        let t = data.busiest?.title ?? ""
        let comps = t.replacingOccurrences(of: ".", with: "").components(separatedBy: ", ").last?.components(separatedBy: " ") ?? []
        return comps.count == 2 ? "\(comps[0]) \(comps[1].prefix(3))" : ""
    }

    // 6
    private var routesFrame: some View {
        let rts = allRoutes.enumerated().compactMap { i, r in GlobeRoute(from: r.0, to: r.1, color: i % 3 != 0 ? gA : gB, width: 1.2, opacity: 0.85, lift: 0.9) }
        let pins = [GlobePin(code: "LHR", showsLabel: false, radius: 3), GlobePin(code: "JFK", showsLabel: false, radius: 3), GlobePin(code: "IST", showsLabel: false, radius: 3)].compactMap { $0 }
        return ZStack(alignment: .topLeading) {
            ExGlow(rx: 0.8, ry: 0.45, cx: 0.5, cy: 0.5, color: Color(.sRGB, red: 70 / 255, green: 92 / 255, blue: 190 / 255, opacity: 0.3)).frame(width: 360, height: 640)
            VStack(alignment: .leading, spacing: 0) {
                lbl("Every route")
                VStack(alignment: .leading, spacing: 0) { serif("Your year,", 52, 54); serif("drawn in light.", 52, 54) }.padding(.top, 14)
            }.exAt(28, 96)
            WorldFlatView(w: 760, visited: data.isFixture, routes: data.isFixture ? rts : [], pins: data.isFixture ? pins : [])
                .exAt(-190, 0).frame(width: 360, height: 290, alignment: .topLeading).clipped().exAt(0, 296)
            HStack(spacing: 28) {
                kpi("\(data.airports)", "airports"); kpi("\(data.countries)", "countries"); kpi("\(data.flights)", "stamps")
            }.exAt(28, 640 - 70 - 56)
        }
    }
    private func kpi(_ v: String, _ t: String) -> some View {
        VStack(alignment: .leading, spacing: 0) { serif(v, 34, 36); lbl(t, size: 10, lh: 12) }
    }

    // 7
    private var card: some View {
        let tier = MeridianUI.MembershipTier.allCases.first { $0.title == data.tierName } ?? .departure
        let info = MembershipCardInfo(memberName: data.name, memberNumber: "0048 1317 2204", since: "MAR 2025", distanceKm: Int(data.km), flights: data.flights, hours: ExFmt.oneDecimal(data.hours))
        let next = data.nextTierName
        let nextKm = data.nextTierKm
        let prog = nextKm > 0 ? min(1, data.km / nextKm) : 1
        return ZStack(alignment: .topLeading) {
            ExGlow(rx: 0.8, ry: 0.45, cx: 0.5, cy: 0.3, color: gB.opacity(0.2)).frame(width: 360, height: 640)
            VStack(alignment: .leading, spacing: 0) {
                lbl("Card reached")
                serif(data.tierName + ".", 72, 72, grad: true).padding(.top, 14)
            }.exAt(28, 96)
            MembershipCardView(tier: tier, size: .list, info: info).frame(width: 340, height: 214).rotationEffect(.degrees(-4)).exAt(10, 240)
            VStack(alignment: .leading, spacing: 0) {
                para(next.map { "Next up: \($0), \(ExFmt.km(data.nextTierRemaining)) km away. See you in \(data.year + 1)." } ?? "You reached the top.", w: 304)
                if next != nil {
                    MRProgressBar(prog).padding(.top, 16)
                    HStack {
                        ExT(s: "\(ExFmt.km(data.km)) km", fam: .mono, size: 10, weight: 500, lh: 12, color: p.text3.color)
                        Spacer(minLength: 0)
                        ExT(s: "\(ExFmt.km(nextKm)) km", fam: .mono, size: 10, weight: 500, lh: 12, color: p.text3.color)
                    }.padding(.top, 8)
                }
            }.frame(width: 304).exAt(28, 490)
        }
    }
}

// MARK: - Export

@MainActor
enum RecapExport {
    enum Ratio: String { case story, square
        var size: CGSize { self == .story ? CGSize(width: 1080, height: 1920) : CGSize(width: 1080, height: 1080) }
        var label: String { self == .story ? "1080 × 1920" : "1080 × 1080" }
    }

    /// Renders a frame with `ImageRenderer` at 3x (story) or into a square canvas.
    static func image(frame: Int, data: ExploreData, ratio: Ratio) -> NSImage? {
        let content: AnyView
        switch ratio {
        case .story:
            content = AnyView(RecapFrame(index: frame, data: data).frame(width: 360, height: 640))
        case .square:
            content = AnyView(ZStack {
                MRPalette.dark.bg0.color
                RecapFrame(index: frame, data: data).frame(width: 360, height: 640)
            }.frame(width: 640, height: 640).clipped())
        }
        let r = ImageRenderer(content: content.environment(\.colorScheme, .dark))
        r.scale = ratio == .story ? 3 : 1080.0 / 640.0
        return r.nsImage
    }

    static func png(_ image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    static func save(_ image: NSImage, name: String) {
        guard let data = png(image) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = name + ".png"
        if panel.runModal() == .OK, let url = panel.url { try? data.write(to: url) }
    }

    static func copy(_ image: NSImage) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }

    static func share(_ image: NSImage) {
        guard let view = NSApp.keyWindow?.contentView else { return }
        let picker = NSSharingServicePicker(items: [image])
        picker.show(relativeTo: CGRect(x: view.bounds.maxX - 160, y: view.bounds.maxY - 280, width: 1, height: 1), of: view, preferredEdge: .minY)
    }
}

// MARK: - Screen (RecapScreen.dc.html)

struct RecapView: View {
    let data: ExploreData
    var onBack: () -> Void
    var initialFrame = 0
    var initialHover: Int?
    @Environment(\.mrPalette) private var p
    @Environment(\.shellSidebarInset) private var inset
    @State private var frame = 0
    @State private var seeded = false
    @State private var ratio: RecapExport.Ratio = .story
    @State private var toast: String?
    @FocusState private var focused: Bool

    private let chapters: [(String, String)] = [("Cover", "Your 2026, in flight"), ("Hours", "94.5 hours of focus"), ("Distance", "12,022 km, 0.3× around the world"), ("Favourite scenario", "Coding, 31 flights"), ("Longest flight", "FRA to IST, 2 h 37 min"), ("Busiest day", "Tuesday 14 April"), ("Every route", "41 airports, 19 countries"), ("Card reached", "Jetstream")]

    private func subtitles() -> [(String, String)] {
        let d = data
        let longest = d.longest.map { "\($0.from) to \($0.to), \(ExFmt.hours(Double($0.durationMin) / 60).trimmingCharacters(in: .whitespaces))" } ?? "—"
        let fav = d.favourite.map { "\(ExScn.get($0.id).name), \($0.flights) flights" } ?? "—"
        let busy = d.busiest.map { $0.title.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ", ", with: " ") } ?? "—"
        return [("Cover", "Your \(d.year), in flight"), ("Hours", "\(ExFmt.oneDecimal(d.hours)) hours of focus"), ("Distance", "\(ExFmt.km(d.km)) km, \(String(format: "%.1f", d.aroundEarth))× around the world"),
                ("Favourite scenario", fav), ("Longest flight", longest), ("Busiest day", busy), ("Every route", "\(d.airports) airports, \(d.countries) countries"), ("Card reached", d.tierName)]
    }

    private func go(_ n: Int) { frame = (n + 8) % 8 }

    var body: some View {
        let x0 = max(inset, 236) + 28
        let ch = subtitles()
        ZStack(alignment: .topLeading) {
            ExPageHeader(eyebrow: "Stats · \(data.year)", title: "Year in flight", onEyebrow: onBack).exAt(x0, 46)
            VStack(spacing: 4) {
                ForEach(0..<8, id: \.self) { i in chapter(i, ch[i]) }
            }.frame(width: 260).exAt(x0, 150)

            ZStack(alignment: .topLeading) {
                HStack(spacing: 4) {
                    ForEach(0..<8, id: \.self) { i in Capsule().fill(i <= frame ? AnyShapeStyle(p.accentGradient) : AnyShapeStyle(p.fill3.color)).frame(height: 3) }
                }.frame(width: 360).exAt(0, -18)
                RecapFrame(index: frame, data: data).shadow(color: .black.opacity(0.45), radius: 25, y: 30)
                    .id(frame)
                roundButton(.chevL, "Previous") { go(frame - 1) }.exAt(-60, 298)
                roundButton(.chevR, "Next") { go(frame + 1) }.exAt(360 + 16, 298)
            }.frame(width: 360, height: 640, alignment: .topLeading).exAt(x0 + 296, 96)

            sharePanel.exAt(x0 + 720, 96)
            if let toast {
                MRToast(toast).exAt(x0 + 720, 560)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .focusable().focused($focused).focusEffectDisabled()
        .onKeyPress(.leftArrow) { go(frame - 1); return .handled }
        .onKeyPress(.rightArrow) { go(frame + 1); return .handled }
        .onExitCommand(perform: onBack)
        .onAppear { if !seeded { seeded = true; frame = initialFrame }; focused = true }
    }

    private func chapter(_ i: Int, _ c: (String, String)) -> some View {
        let on = i == frame, hv = i == initialHover
        return Button { go(i) } label: {
            HStack(spacing: 12) {
                ExT(s: String(format: "%02d", i + 1), fam: .mono, size: 11, weight: 500, lh: 11, color: p.text3.color).frame(width: 24, alignment: .leading)
                VStack(alignment: .leading, spacing: 0) {
                    ExT(s: c.0, size: 14, weight: 600, lh: 17, color: p.text1.color)
                    ExT(s: c.1, size: 12, weight: 400, lh: 15, color: p.text2.color)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14).frame(height: 54)
            .background {
                let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
                if on {
                    shape.fill(p.isDark ? AnyShapeStyle(LinearGradient(colors: [gA.opacity(0.2), gB.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color(.sRGB, red: 30 / 255, green: 107 / 255, blue: 1, opacity: 0.08)))
                        .overlay(shape.strokeBorder(p.isDark ? gA.opacity(0.34) : Color(.sRGB, red: 30 / 255, green: 107 / 255, blue: 1, opacity: 0.3), lineWidth: 1))
                } else if hv { shape.fill(p.fill1.color) }
            }
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(ExChapterStyle(fill: p.fill1.color))
        .accessibilityLabel("Chapter \(i + 1): \(c.0)")
    }

    private func roundButton(_ icon: MRIconName, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { MRIcon(icon, size: 18) }
            .buttonStyle(MRRoundButtonStyle()).frame(width: 44, height: 44).accessibilityLabel(label)
    }

    private var sharePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            ExT(s: "Share your year", size: 15, weight: 600, lh: 18, color: p.text1.color)
            ExT(s: "Shares an image. Never your tasks, notes or exact times.", size: 13, weight: 400, lh: 18, color: p.text2.color, wrap: 220).padding(.top, 4)
            HStack(spacing: 10) {
                ratioCard(.story, "Story 9:16", w: 26, h: 46, pad: 0)
                ratioCard(.square, "Square 1:1", w: 36, h: 36, pad: 5)
            }.padding(.top, 16)
            VStack(spacing: 8) {
                Button { if let i = img { RecapExport.share(i) } } label: { row(.share, "Share image") }.buttonStyle(MRButtonStyle(.primary))
                Button { if let i = img { RecapExport.copy(i); flash("Image copied") } } label: { row(.copy, "Copy image") }.buttonStyle(MRButtonStyle(.secondary))
                Button { if let i = img { RecapExport.save(i, name: "meridian-\(data.year)-\(frame + 1)") } } label: { row(.download, "Save as PNG") }.buttonStyle(MRButtonStyle(.secondary))
            }.padding(.top, 16)
            ExT(s: "Exports at \(ratio.label)", fam: .mono, size: 11, weight: 500, lh: 16, color: p.text3.color).padding(.top, 14)
        }
        .padding(20)
        .frame(width: 260, alignment: .leading)
        .mrGlass(cornerRadius: 26, elevation: .e3)
    }

    private var img: NSImage? { RecapExport.image(frame: frame, data: data, ratio: ratio) }
    private func flash(_ s: String) {
        toast = s
        Task { try? await Task.sleep(for: .seconds(1.6)); toast = nil }
    }
    private func row(_ icon: MRIconName, _ t: String) -> some View {
        HStack(spacing: 8) { MRIcon(icon, size: 18); Text(t) }.frame(maxWidth: .infinity)
    }

    private func ratioCard(_ r: RecapExport.Ratio, _ title: String, w: CGFloat, h: CGFloat, pad: CGFloat) -> some View {
        let on = ratio == r
        return Button { ratio = r } label: {
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 6).fill(p.fill3.color).frame(width: w, height: h).padding(.top, pad).padding(.bottom, pad == 0 ? 6 : 11)
                ExT(s: title, size: 11, weight: 500, lh: 11, color: on ? p.text1.color : p.text2.color)
            }
            .padding(.vertical, 10).frame(maxWidth: .infinity)
            .background(on ? p.fill2.color : p.fill1.color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(on ? p.accent1.color : p.strokeHair.color, lineWidth: on ? 1.5 : 1))
        }.buttonStyle(.plain)
    }
}

private struct ExChapterStyle: ButtonStyle {
    let fill: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.background(configuration.isPressed ? fill : .clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
