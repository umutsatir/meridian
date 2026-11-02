import SwiftUI

/// The hero artifact: 360 x 600 pt of warm thermal paper (Ticket.dc.html, R01). Every measure is the canvas'.
/// `scale` mirrors the canvas prop (the view's frame is 360 x 600 times scale). Pass `live: true` for the wallet-tile
/// hover tilt (lift 8, tilt up to 6 degrees, perspective 900).
public struct BoardingPassView: View {
    private let model: BoardingPassModel
    private let state: BoardingPassState
    private let side: BoardingPassSide
    private let scale: CGFloat
    private let flat: Bool
    private let live: Bool
    private let hoverPose: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    public init(_ model: BoardingPassModel, state: BoardingPassState = .printed, side: BoardingPassSide = .front,
                scale: CGFloat = 1, flat: Bool = false, live: Bool = false, hoverPose: Bool = false) {
        self.model = model; self.state = state; self.side = side; self.scale = scale
        self.flat = flat; self.live = live; self.hoverPose = hoverPose
    }

    static func height(for state: BoardingPassState) -> CGFloat { state.isTornShape ? 452 : 600 }

    private func pass(h: CGFloat, rx: Double, ry: Double, lift lf: CGFloat) -> some View {
        Group {
            if state == .locked {
                PassLocked(size: CGSize(width: 360 * scale, height: 452 * scale))
            } else {
                PassPaper(model: model, state: state, side: side)
                    .modifier(PaperShadow(flat: flat, lift: lf))
                    .modifier(PaperTilt(rx: reduceMotion ? 0 : rx, ry: reduceMotion ? 0 : ry, lift: reduceMotion ? 0 : lf,
                                        size: CGSize(width: 360, height: h)))
            }
        }
        .frame(width: state == .locked ? 360 * scale : 360, height: state == .locked ? h * scale : h)
        .scaleEffect(state == .locked ? 1 : scale, anchor: .topLeading)
        .frame(width: 360 * scale, height: h * scale, alignment: .topLeading)
    }

    public var body: some View {
        let h = state == .locked ? 452 : Self.height(for: state)
        Group {
            if live {
                // The pointer is only a target; CardTiltSmoother advances rx / ry / lift every frame (no jump on first contact).
                CardTiltHost(normalize: { CGPoint(x: $0.x / (360 * scale) - 0.5, y: $0.y / (h * scale) - 0.5) }, enabled: true) { px, py, hover in
                    pass(h: h, rx: -py * 12, ry: px * 12, lift: 8 * hover)
                }
            } else {
                pass(h: h, rx: hoverPose ? -4 : 0, ry: hoverPose ? 5 : 0, lift: hoverPose ? 8 : 0)
                    .animation(reduceMotion ? nil : MRMotion.hoverTilt, value: hoverPose)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state == .locked ? "Locked boarding pass. Your next flight prints here" : model.accessibilityDescription(canTear: false))
    }
}

private struct PaperShadow: ViewModifier {
    var flat: Bool, lift: CGFloat
    func body(content: Content) -> some View {
        if flat { content } else {
            content.shadow(color: .black.opacity(0.45), radius: (24 + lift * 1.2) / 2, x: 0, y: 24 + lift * 1.6)
        }
    }
}

// MARK: - Locked placeholder

/// The canvas draws the placeholder box at `scale` but keeps its label at 13 pt, so this does too.
private struct PassLocked: View {
    var size = CGSize(width: 360, height: 452)
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let p = MRPalette.resolve(scheme)
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 22, style: .circular).fill(p.fill1.color)
            RoundedRectangle(cornerRadius: 22, style: .circular)
                .strokeBorder(p.text3.color, style: StrokeStyle(lineWidth: 1.5, dash: [4.5, 4.5]))
            VStack(spacing: 14) {
                MRIcon(.lock, size: 24)
                Text("Your next flight prints here")
                    .font(MRFonts.font(.ui, size: 13, weight: 400))
                    .multilineTextAlignment(.center)
                    .frame(width: 150)
                    .lineSpacing(18 - MRFonts.naturalLineHeight(.ui, size: 13, weight: 400))
            }
            .foregroundStyle(p.text3.color)
            .padding(.top, size.height * 0.34)
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Paper

struct PassPaper: View {
    let model: BoardingPassModel
    let state: BoardingPassState
    let side: BoardingPassSide

    private var torn: Bool { state.isTornShape }
    private var H: CGFloat { torn ? 452 : 600 }
    private var printing: Double? { if case .printing(let p) = state { return min(1, max(0, p)) }; return nil }
    private var tornPoly: [CGPoint]? { torn ? PaperShape.tornPolygon(seed: model.seed) : nil }

    private var bandHex: String {
        switch model.colorBy {
        case .scenario: model.scenario.hex
        case .class: model.cabin.foilStops[1].1
        case .continent: model.continent.hex
        case .month: PassPaper.monthHex(model.month)
        }
    }
    private var bandColor: Color { Color(hex: bandHex) }

    static func monthHex(_ m: Int) -> String {
        // hsl(month*30 62% 74%)
        let h = Double(m * 30 % 360) / 360, s = 0.62, l = 0.74
        let c = (1 - abs(2 * l - 1)) * s
        let x = c * (1 - abs((h * 6).truncatingRemainder(dividingBy: 2) - 1))
        let m0 = l - c / 2
        let (r, g, b): (Double, Double, Double)
        switch Int(h * 6) % 6 {
        case 0: (r, g, b) = (c, x, 0)
        case 1: (r, g, b) = (x, c, 0)
        case 2: (r, g, b) = (0, c, x)
        case 3: (r, g, b) = (0, x, c)
        case 4: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        func h2(_ v: Double) -> String { String(format: "%02X", Int(((v + m0) * 255).rounded())) }
        return "#" + h2(r) + h2(g) + h2(b)
    }

    var body: some View {
        let shape = PaperShape(height: H, polygon: tornPoly)
        ZStack(alignment: .topLeading) {
            // sheet: paper + 6 % top sheen
            Rectangle().fill(PaperInk.paper)
            Rectangle().fill(LinearGradient(colors: [.white.opacity(0.06), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(height: H * 0.4)
            PaperGrain().frame(width: 360, height: H)
            band
            foil
            if side == .front { PassFrontContent(model: model, state: state, bandColor: bandColor, H: H) }
            else { PassBackContent(model: model, bandColor: bandColor, H: H, torn: torn) }
            if let p = printing {
                Rectangle()
                    .fill(LinearGradient(colors: [Color(hex: "#F5F0E6").opacity(0), Color(hex: "#F5F0E6").opacity(0.88)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 360, height: 94)
                    .at(0, max(0, p * 600 - 94))
            }
            if torn {
                PassRim(seed: model.seed).at(0, 446)
            }
            Rectangle().fill(.white.opacity(0.9)).frame(width: 360, height: 1)   // .paper::after highlight
        }
        .frame(width: 360, height: H, alignment: .topLeading)
        .compositingGroup()
        .mask(shape)
        .mask(alignment: .top) { Rectangle().frame(width: 360, height: printing.map { $0 * 600 } ?? H) }
        .overlay(alignment: .topLeading) {
            if let p = printing {
                Capsule().fill(.white).frame(width: 372, height: 2)
                    .shadow(color: .white.opacity(0.55), radius: 6)
                    .shadow(color: .white, radius: 1)
                    .at(-6, p * 600 - 1)
            }
        }
        .frame(width: 360, height: H, alignment: .topLeading)
    }

    private var band: some View {
        Rectangle().fill(bandColor).frame(width: 360, height: 6)
    }

    private var foil: some View {
        let fw: CGFloat = model.colorBy == .class ? 7 : 4
        return Rectangle()
            .fill(LinearGradient(stops: model.cabin.foilStops.map { .init(color: Color(hex: $0.1), location: $0.0) }, startPoint: .leading, endPoint: .trailing))
            .opacity(0.95)
            .frame(width: fw, height: 450)
            .at(360 - fw, 0)
    }
}

struct PassRim: View {
    let seed: UInt64
    var body: some View {
        Path { p in
            let pts = PerforationEdge(seed: seed).body
            for (i, q) in pts.enumerated() {
                let pt = CGPoint(x: q.x, y: q.y - 446 - 0.5)
                i == 0 ? p.move(to: pt) : p.addLine(to: pt)
            }
        }
        .stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 1.1, lineJoin: .round))
        .frame(width: 360, height: 8, alignment: .topLeading)
    }
}

// MARK: - Front

struct PassFrontContent: View {
    let model: BoardingPassModel
    let state: BoardingPassState
    let bandColor: Color
    let H: CGFloat

    private var torn: Bool { state.isTornShape }
    private var cabinFoil: LinearGradient {
        LinearGradient(stops: model.cabin.foilStops.map { .init(color: Color(hex: $0.1), location: $0.0) }, startPoint: .leading, endPoint: .trailing)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            header
            routeBlock
            dataGrid
            scenarioRow
            passengerRow
            stamps
            if case .inflight(let prog) = state { progress(prog) }
            if !torn, !isPrintingOnlyHidden { stub }
        }
        .frame(width: 360, height: H, alignment: .topLeading)
    }

    private var isPrintingOnlyHidden: Bool { false }

    // header: left 24, right 28, top 6, 48 tall
    private var header: some View {
        HStack {
            PaperText("MERIDIAN AIR", size: 11, weight: 700, tracking: 0.24)
            Spacer(minLength: 0)
            PaperText("BOARDING PASS", size: 9.5, weight: 600, tracking: 0.12, color: PaperInk.caption)
        }
        .frame(width: 308, height: 48)
        .at(24, 6)
    }

    private func caption(_ s: String) -> some View {
        PaperText(s.uppercased(), size: 9.5, weight: 600, lh: 9.5, tracking: 0.12, color: PaperInk.caption)
    }

    // MARK: route block (y 54, 130 tall)
    private var routeBlock: some View {
        let fit = geoFit
        return ZStack(alignment: .topLeading) {
            if let fit {
                PaperDotMap(s: fit.s, ox: fit.ox, oy: fit.oy, size: CGSize(width: 360, height: 130)).opacity(0.085)
                ForEach(0..<2, id: \.self) { i in
                    let pt = i == 0 ? fit.p : fit.q
                    Circle().strokeBorder(PaperInk.ink, lineWidth: 1.5).opacity(0.34)
                        .frame(width: 7, height: 7).at(pt.x - 3.5, pt.y - 3.5)
                }
            }
            place(caption: "From", code: model.originCode, city: model.originCity, trailing: false).at(24, 6)
            middle.at(112, 42)
            place(caption: "To", code: model.destinationCode, city: model.destinationCity, trailing: true)
                .frame(width: 0, alignment: .trailing).at(332, 6)
        }
        .frame(width: 360, height: 130, alignment: .topLeading)
        .clipped()
        .at(0, 54)
    }

    private var geoFit: PaperGeo.Fit? {
        guard let a = model.originCoordinate, let b = model.destinationCoordinate else { return nil }
        return PaperGeo.fit(a, b, 360, 130)
    }

    private func place(caption cap: String, code: String, city: String, trailing: Bool) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 0) {
            caption(cap)
            PaperText(code, .condensed, size: 64, weight: 700, lh: 64, tracking: 0.005).padding(.top, 2)
            PaperText(city, size: 13, weight: 500).padding(.top, 2)
            RoundedRectangle(cornerRadius: 2).fill(bandColor).frame(width: 64, height: 3).padding(.top, 5)
        }
        .fixedSize()
    }

    private var middle: some View {
        VStack(spacing: 6) {
            ZStack {
                Path { p in p.move(to: CGPoint(x: 0, y: 9.75)); p.addLine(to: CGPoint(x: 136, y: 9.75)) }
                    .stroke(PaperInk.ink.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [4.5, 3]))
                    .frame(width: 136, height: 20)
                MRIcon(.plane, size: 18).rotationEffect(.degrees(90)).foregroundStyle(PaperInk.ink)
                    .padding(.horizontal, 6).background(PaperInk.paper)
            }
            .frame(width: 136, height: 20)
            Text(model.durationText)
                .font(MRFonts.font(.mono, size: 13, weight: 500)).tracking(0.26)
                .foregroundStyle(PaperInk.ink92).shadow(color: PaperInk.ink.opacity(0.35), radius: 0.3)
        }
        .frame(width: 136)
    }

    // MARK: data grid
    private var dataGrid: some View {
        ZStack(alignment: .topLeading) {
            cell("Date", 0, 8) {
                if state == .boarding { BoardingPill() } else { value(model.dateText) }
            }
            cell("Flight", 160, 8) { value(model.flightNumber) }
            cell("Gate", 0, 58) { value(model.gate) }
            cell("Seat", 160, 58) { value(model.seat) }
            cell("Boarding", 0, 108) { value(model.boardingTime) }
            cell("Distance", 160, 108) { value(model.distanceText) }
            Rectangle().fill(PaperInk.hair).frame(width: 308, height: 1)
        }
        .frame(width: 308, height: 150, alignment: .topLeading)
        .at(24, 184)
    }

    private func value(_ s: String) -> some View {
        PaperText(s, .mono, size: 17, weight: 500, lh: 18.7, tracking: -0.01)
    }

    private func cell<C: View>(_ cap: String, _ x: CGFloat, _ y: CGFloat, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) { caption(cap); content() }.fixedSize().at(x, y)
    }

    // MARK: scenario row
    private var scenarioRow: some View {
        HStack(spacing: 12) {
            ScenarioChipPaper(scenario: model.scenario, height: 30, font: 13, icon: 15)
            Text(model.topic)
                .font(MRFonts.font(.ui, size: 13, weight: 400)).foregroundStyle(PaperInk.ink92).opacity(0.8)
                .lineLimit(1).truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 308, height: 56, alignment: .leading)
        .at(24, 334)
    }

    // MARK: passenger line
    private var passengerRow: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(PaperInk.hair).frame(width: 308, height: 1)
            HStack {
                if state == .group { group } else {
                    PaperText(model.passengerName, .mono, size: 12, weight: 500, tracking: 0.06)
                }
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    PaperText("Class: \(model.cabin.title)", size: 12, weight: 500)
                    RoundedRectangle(cornerRadius: 3).fill(cabinFoil).frame(width: 28, height: 10)
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(PaperInk.ink.opacity(0.28), lineWidth: 1))
                }
            }
            .frame(width: 308, height: 40)
        }
        .frame(width: 308, height: 40, alignment: .topLeading)
        .at(24, 390)
    }

    private var group: some View {
        let colors = ["#7AA2FF", "#FFB86B", "#7ADDB2", "#FF8FB1", "#B49CFF", "#8EE3E8"]
        return HStack(spacing: 0) {
            ForEach(Array(model.groupInitials.enumerated()), id: \.offset) { i, n in
                Text(n).font(MRFonts.font(.ui, size: 9, weight: 700)).foregroundStyle(PaperInk.ink)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color(hex: colors[i % 6])))
                    .overlay(Circle().stroke(PaperInk.paper, lineWidth: 1.5).padding(-0.75))
                    .padding(.leading, i == 0 ? 0 : -5)
                    .zIndex(Double(i))
            }
            PaperText("\(model.groupInitials.count) on board", .mono, size: 11, weight: 500, color: PaperInk.ink92.opacity(0.75)).padding(.leading, 8)
        }
        .padding(.leading, 5)
    }

    // MARK: stamps
    @ViewBuilder private var stamps: some View {
        if state == .landed {
            LandedInkStamp(title: "Landed", subtitle: "\(model.destinationCity) · \(model.landTime)")
                .rotationEffect(.degrees(-6)).at(156, 314)
        } else if state == .diverted {
            let flown = model.flownMinutes ?? Int(Double(model.durationMinutes ?? 42) * 0.74)
            InkStampBox(title: "Diverted", subtitle: "\(flown) / \(model.durationMinutes ?? 42) MIN", color: PaperInk.stampWarn, seed: 6)
                .rotationEffect(.degrees(-6)).at(150, 312)
        }
    }

    private func progress(_ p: Double) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(PaperInk.ink.opacity(0.12)).frame(width: 360, height: 4).at(0, 445)
            Rectangle()
                .fill(LinearGradient(colors: [Color(hex: "#6AB7FF"), Color(hex: "#8BF3D8")], startPoint: .leading, endPoint: .trailing))
                .frame(width: 360 * min(1, max(0, p)), height: 5)
                .shadow(color: Color(hex: "#6AB7FF").opacity(0.75), radius: 7)
                .shadow(color: Color(hex: "#8BF3D8"), radius: 1.5)
                .at(0, 444)
        }
    }

    // MARK: perforation + stub
    private var stub: some View {
        let printingP: Double? = { if case .printing(let p) = state { return p }; return nil }()
        return ZStack(alignment: .topLeading) {
            Path { p in
                var x: CGFloat = 24
                while x < 340 { p.addEllipse(in: CGRect(x: x - 1, y: 449, width: 2, height: 2)); x += 8 }
            }.fill(PaperInk.ink.opacity(0.45))
            HStack {
                HStack(spacing: 6) {
                    MRIcon(.scissors, size: 12).foregroundStyle(PaperInk.caption)
                    PaperText("TEAR HERE", size: 9.5, weight: 600, lh: 9.5, tracking: 0.2, color: PaperInk.caption)
                }
                Spacer(minLength: 0)
                PaperText("\(model.originCode) → \(model.destinationCode)", .mono, size: 10, weight: 500, color: PaperInk.ink92.opacity(0.7))
            }
            .frame(width: 312, height: 18).at(24, 458)
            HStack(alignment: .bottom, spacing: 28) {
                stubCell("Seat", model.seat); stubCell("Gate", model.gate); stubCell("Time", model.boardingTime)
                Spacer(minLength: 0)
                stubCell(model.flightNumber, model.durationText, trailing: true)
            }
            .frame(width: 312, height: 34, alignment: .leading).at(24, 482)
            TornEdge.barcode(seed: model.seed &+ 7, width: 300, height: 56, rows: 7)
                .fill(PaperInk.ink.opacity(0.92))
                .frame(width: 300, height: 56, alignment: .topLeading)
                .mask(alignment: .leading) {
                    if let p = printingP {
                        Rectangle().frame(width: 300 * max(0, min(1, (p - 0.9) / 0.1)))
                    } else { Rectangle() }
                }
                .at(30, 524)
            Text(model.serial)
                .font(MRFonts.font(.mono, size: 7, weight: 500)).tracking(0.98)
                .foregroundStyle(PaperInk.ink92).opacity(0.65)
                .frame(width: 300, alignment: .center).at(30, 584)
        }
    }

    private func stubCell(_ cap: String, _ v: String, trailing: Bool = false) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 5) {
            caption(cap)
            PaperText(v, .mono, size: 16, weight: 500, lh: 16)
        }.fixedSize()
    }
}

// MARK: - Small paper parts

/// The scenario chip printed on paper: tinted pill, ink-mixed label, hairline ring.
struct ScenarioChipPaper: View {
    let scenario: PaperScenario
    var height: CGFloat = 30
    var font: CGFloat = 13
    var icon: CGFloat = 15
    var body: some View {
        let sc = PaperInk.rgb(scenario.hex), ink = PaperInk.rgb("#14110F"), paper = PaperInk.rgb("#F5F0E6")
        HStack(spacing: 7) {
            MRIcon(scenario.icon, size: icon)
            Text(scenario.label).font(MRFonts.font(.ui, size: font, weight: 600)).lineLimit(1).fixedSize()
        }
        .foregroundStyle(PaperInk.mix(sc, 52, ink, 48))
        .padding(.leading, 10).padding(.trailing, 13)
        .frame(height: height)
        .background(Capsule().fill(PaperInk.mix(sc, 30, paper, 70)))
        .overlay(Capsule().strokeBorder(PaperInk.mix(sc, 65, ink, 10), lineWidth: 1))
        .fixedSize()
    }
}

/// `.mx-pillamb`: amber BOARDING pill with the 1.6 s pulse ring.
struct BoardingPill: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.6) / 1.6
            let tri = t < 0.5 ? t * 2 : (1 - t) * 2
            let e = reduceMotion ? 0 : tri * tri * (3 - 2 * tri)
            Text("BOARDING").font(MRFonts.font(.ui, size: 11, weight: 700)).tracking(1.1)
                .foregroundStyle(PaperInk.ink).padding(.horizontal, 10).frame(height: 22)
                .background(Capsule().fill(PaperInk.amber))
                .overlay(Capsule().strokeBorder(.white.opacity(0.45), lineWidth: 1))
                .background(Capsule().fill(PaperInk.amber.opacity(0.55 * (1 - e))).padding(-7 * e))
        }
        .fixedSize()
    }
}

/// `.stamp`: ink-on-paper box stamp (Landed, Diverted) with worn ink.
struct InkStampBox: View {
    let title: String, subtitle: String
    let color: Color
    var seed: UInt32 = 5
    var body: some View {
        VStack(spacing: 2) {
            Text(title.uppercased()).font(MRFonts.font(.condensed, size: 36, weight: 700)).tracking(36 * 0.14).frame(height: 36)
            Text(subtitle.uppercased()).font(MRFonts.font(.mono, size: 11, weight: 600)).tracking(11 * 0.14).frame(height: 11)
        }
        .fixedSize()
        .padding(.init(top: 6, leading: 16, bottom: 5, trailing: 16))
        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(color, lineWidth: 3) }
        .overlay { RoundedRectangle(cornerRadius: 2).strokeBorder(color, lineWidth: 1).padding(6) }
        .padding(3)
        .foregroundStyle(color)
        .modifier(InkWear(seed: seed, keep: 0.9))
        .blendMode(.multiply)
        .opacity(0.92)
    }
}

/// Worn-ink holes (the `holes` branch of the canvas stamp filter).
struct InkWear: ViewModifier {
    let seed: UInt32
    let keep: Double
    func body(content: Content) -> some View {
        if let cg = PaperTextures.wearMask(seed: seed, keep: keep) {
            content.mask {
                Image(decorative: cg, scale: 1).resizable(resizingMode: .tile)
            }
        } else { content }
    }
}

// MARK: - Back

struct PassBackContent: View {
    let model: BoardingPassModel
    let bandColor: Color
    let H: CGFloat
    let torn: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack {
                PaperText("MERIDIAN AIR", size: 11, weight: 700, tracking: 0.24)
                Spacer(minLength: 0)
                PaperText("\(model.flightNumber) · \(model.dateText) · Seat \(model.seat)".uppercased(), size: 9.5, weight: 600, tracking: 0.12, color: PaperInk.caption)
            }
            .frame(width: 308, height: 48).at(24, 6)
            mapBox.at(24, 58)
            notes.at(24, 222)
            stats.at(24, 350)
            buttons.at(24, H - 14 - 34)
            if torn { PassRim(seed: model.seed).at(0, 446) }
        }
        .frame(width: 360, height: H, alignment: .topLeading)
    }

    private var mapBox: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12).fill(PaperInk.ink.opacity(0.045))
            if let a = model.originCoordinate, let b = model.destinationCoordinate {
                let fit = PaperGeo.fit(a, b, 308, 150)
                PaperDotMap(s: fit.s, ox: fit.ox, oy: fit.oy, size: CGSize(width: 308, height: 150)).opacity(0.28)
                let pts: [CGPoint] = PaperGeo.arc(a, b, n: 40).map { c in
                    let q = PaperGeo.eq(c)
                    return CGPoint(x: q.x / 1440 * fit.s + fit.ox, y: q.y / 720 * (fit.s / 2) + fit.oy)
                }
                let n = pts.count
                let lifted: [CGPoint] = pts.enumerated().map { i, q in
                    CGPoint(x: q.x, y: q.y - CGFloat(sin(Double(i) / Double(max(1, n - 1)) * .pi)) * 14)
                }
                Path { p in for (i, q) in lifted.enumerated() { i == 0 ? p.move(to: q) : p.addLine(to: q) } }
                    .stroke(PaperInk.ink, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [1, 4]))
                if let f = lifted.first, let l = lifted.last {
                    Circle().fill(PaperInk.paper).overlay(Circle().stroke(PaperInk.ink, lineWidth: 2)).frame(width: 8, height: 8).at(f.x - 4, f.y - 4)
                    Circle().fill(PaperInk.ink).frame(width: 8, height: 8).at(l.x - 4, l.y - 4)
                }
            }
            Text("\(model.originCode) → \(model.destinationCode)")
                .font(MRFonts.font(.condensed, size: 20, weight: 700)).tracking(0.2)
                .foregroundStyle(PaperInk.ink92).at(12, 10)
        }
        .frame(width: 308, height: 150, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(PaperInk.ink.opacity(0.14), lineWidth: 1))
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                PaperText("NOTES", size: 9.5, weight: 600, tracking: 0.12, color: PaperInk.caption)
                Spacer(minLength: 0)
                ScenarioChipPaper(scenario: model.scenario, height: 24, font: 11, icon: 12)
            }
            .frame(width: 308)
            Text(model.notes)
                .font(MRFonts.font(.serif, size: 19, weight: 500, italic: true))
                .lineSpacing(26 - MRFonts.naturalLineHeight(.serif, size: 19, weight: 500))
                .foregroundStyle(PaperInk.ink92)
                .padding(.top, (26 - MRFonts.naturalLineHeight(.serif, size: 19, weight: 500)) / 2)
                .frame(width: 308, height: 104, alignment: .topLeading).clipped()
                .padding(.top, 8)
        }
    }

    private var stats: some View {
        VStack(spacing: 0) {
            Rectangle().fill(PaperInk.hair).frame(height: 1)
            HStack(alignment: .top, spacing: 12) {
                stat("Focused", model.durationText)
                stat("Distance", model.distanceText)
                stat("Miles", "+\(model.distanceKm)")
            }
            .padding(.top, 14)
        }
        .frame(width: 308)
    }

    private func stat(_ cap: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            PaperText(cap.uppercased(), size: 9.5, weight: 600, lh: 9.5, tracking: 0.12, color: PaperInk.caption)
            PaperText(v, .mono, size: 17, weight: 500, lh: 18.7, tracking: -0.01)
        }
        .frame(width: (308 - 24) / 3, alignment: .leading)
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            pill("Edit", .pencil, PaperInk.ink, PaperInk.ink.opacity(0.4))
            pill("Share", .share, PaperInk.ink, PaperInk.ink.opacity(0.4))
            Spacer(minLength: 0)
            pill("Delete", .trash, PaperInk.stampRed, Color(red: 168 / 255, green: 42 / 255, blue: 36 / 255).opacity(0.55))
        }
        .frame(width: 308, height: 34)
    }

    private func pill(_ t: String, _ icon: MRIconName, _ fg: Color, _ border: Color) -> some View {
        HStack(spacing: 6) {
            MRIcon(icon, size: 13)
            Text(t).font(MRFonts.font(.ui, size: 12, weight: 600))
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 14).frame(height: 30)
        .overlay(Capsule().strokeBorder(border, lineWidth: 1))
    }
}

#Preview("BoardingPassView states") {
    ScrollView(.horizontal) {
        HStack(alignment: .top, spacing: 28) {
            BoardingPassView(.sample)
            BoardingPassView(.sample, state: .torn)
            BoardingPassView(.sample, state: .landed, side: .back)
            BoardingPassView(.sample, state: .boarding, scale: 0.6)
            BoardingPassView(.sample, state: .inflight(0.6), scale: 0.6)
            BoardingPassView(.sample, state: .landed, scale: 0.6)
            BoardingPassView(.sample, state: .group, scale: 0.6)
            BoardingPassView(.sample, state: .locked, scale: 0.6)
        }.padding(40)
    }
    .background(MRPalette.dark.bg0.color).preferredColorScheme(.dark)
}


// MARK: - Landed stamp animation (Ticket.dc.html `tk-stamp`)

private struct StampAnimationKey: EnvironmentKey { static let defaultValue: (animated: Bool, onThump: (@MainActor @Sendable () -> Void)?) = (false, nil) }
extension EnvironmentValues {
    var paperStampAnimation: (animated: Bool, onThump: (@MainActor @Sendable () -> Void)?) {
        get { self[StampAnimationKey.self] }
        set { self[StampAnimationKey.self] = newValue }
    }
}

public extension View {
    /// Plays the LANDED ink stamp entrance of a `.landed` boarding pass inside this view: 60 ms thump (scale 160 % to 96 %, ink in),
    /// 120 ms bleed to 100 %. `onThump` fires at the thump (sound and haptic).
    func paperLandedStampAnimation(_ on: Bool = true, onThump: (@MainActor @Sendable () -> Void)? = nil) -> some View {
        environment(\.paperStampAnimation, (on, onThump))
    }
}

private struct LandedInkStamp: View {
    let title: String, subtitle: String
    @Environment(\.paperStampAnimation) private var anim
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = false

    private struct Pose { var scale = 1.0, opacity = 1.0, blur = 0.0 }

    var body: some View {
        let box = InkStampBox(title: title, subtitle: subtitle, color: PaperInk.stampOK, seed: 5)
        if anim.animated && !reduceMotion {
            box
                .keyframeAnimator(initialValue: Pose(scale: 1.6, opacity: 0, blur: 1.5), trigger: start) { v, pose in
                    v.scaleEffect(pose.scale).opacity(pose.opacity).blur(radius: pose.blur)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) { CubicKeyframe(0.96, duration: 0.061); CubicKeyframe(1, duration: 0.119) }
                    KeyframeTrack(\.opacity) { CubicKeyframe(1, duration: 0.061); CubicKeyframe(1, duration: 0.119) }
                    KeyframeTrack(\.blur) { CubicKeyframe(0.2, duration: 0.061); CubicKeyframe(0, duration: 0.119) }
                }
                .task {
                    start = true
                    try? await Task.sleep(for: .milliseconds(60))
                    anim.onThump?()
                }
        } else {
            box.task { anim.onThump?() }
        }
    }
}
