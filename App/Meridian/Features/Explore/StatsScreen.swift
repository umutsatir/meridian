import MeridianCore
import MeridianMaps
import MeridianUI
import SwiftUI

// MARK: - Stats parts (Stats.dc.html)

private let gradA = Color(.sRGB, red: 106 / 255, green: 183 / 255, blue: 1)
private let gradB = Color(.sRGB, red: 139 / 255, green: 243 / 255, blue: 216 / 255)

/// kind="bars": stacked scenario bars with a goal line and a hover tooltip.
struct ExBarsChart: View {
    let series: ExBarSeries
    var w: CGFloat = 504, h: CGFloat = 176
    @Binding var hover: Int?
    var period: ExPeriod
    @Environment(\.mrPalette) private var p
    @Environment(\.colorScheme) private var scheme

    private func barColor(_ id: String) -> Color {
        let hex = ExScn.get(id).hex
        let t = MRColorToken(hex)
        guard scheme == .light else { return t.color }
        let m = MRColorToken("#2A2F3C")
        let k = 0.74
        return Color(.sRGB, red: Double(t.rgb.r) * k + Double(m.rgb.r) * (1 - k), green: Double(t.rgb.g) * k + Double(m.rgb.g) * (1 - k), blue: Double(t.rgb.b) * k + Double(m.rgb.b) * (1 - k))
    }

    var body: some View {
        let bars = series.bars
        let n = bars.count
        let mx = max(bars.map(\.hours).max() ?? 0, series.goal)
        let top = max(series.step, (mx / series.step).rounded(.up) * series.step)
        let inH = h - 32
        let area = w - 68, slot = area / CGFloat(max(1, n))
        let bw = min(series.barWidthCap, slot * 0.66)
        let hv = hover
        ZStack(alignment: .topLeading) {
            // container: left 34, top 6, height inH
            ZStack(alignment: .topLeading) {
                // grid + y labels
                ForEach(Array(stride(from: 0.0, through: top + 0.001, by: series.step).enumerated()), id: \.offset) { _, v in
                    let y = inH - v / top * inH
                    Rectangle().fill(p.strokeHair.color).frame(width: w - 34 - 34, height: 1).exAt(34, y)
                    Text(series.yUnitIsMinutes ? "\(Int((v * 60).rounded()))m" : (v == v.rounded() ? "\(Int(v)) h" : "\(v) h"))
                        .font(MRFonts.font(.mono, size: 11, weight: 500)).foregroundStyle(p.text3.color)
                        .fixedSize().frame(height: 11).offset(x: 0, y: y - 5.5)
                }
                // goal
                Path { q in q.move(to: .zero); q.addLine(to: CGPoint(x: w - 34 - 34, y: 0)) }
                    .stroke(p.accent2.color, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .opacity(0.6).exAt(34, inH - series.goal / top * inH)
                ForEach(Array(bars.enumerated()), id: \.offset) { i, b in
                    let hh = b.hours / top * inH
                    let height = max(b.hours > 0 ? 3 : 0, hh)
                    let x = 34 + slot * CGFloat(i) + (slot - bw) / 2
                    let dim = hv != nil && hv != i
                    VStack(spacing: 0) {
                        ForEach(Array(b.segs.reversed().enumerated()), id: \.offset) { _, s in
                            Rectangle().fill(barColor(s.scn)).frame(height: b.hours > 0 ? height * s.hours / b.hours : 0)
                        }
                    }
                    .frame(width: bw, height: height, alignment: .bottom)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 2, bottomTrailingRadius: 2, topTrailingRadius: 5, style: .continuous))
                    .opacity(dim ? 0.38 : 1)
                    .offset(x: x, y: inH - height - (hv == i ? 2 : 0))
                    .animation(MRMotion.ease(MRMotion.d2), value: hv)
                    .contentShape(Rectangle().inset(by: -4))
                    .onHover { inside in withAnimation(MRMotion.hover) { hover = inside ? i : (hover == i ? nil : hover) } }
                    .accessibilityElement().accessibilityLabel("\(b.xLabel.isEmpty ? "Item \(i + 1)" : b.xLabel): \(ExFmt.hours(b.hours))")
                    if !b.xLabel.isEmpty {
                        let sel = i == series.selected
                        Text(b.xLabel).font(MRFonts.font(.ui, size: 11, weight: sel ? 700 : 500))
                            .foregroundStyle(sel ? p.text1.color : p.text3.color).fixedSize().frame(height: 11)
                            .position(x: 34 + slot * CGFloat(i) + slot / 2, y: inH + 9 + 5.5)
                    }
                }
                if let hv, hv < n {
                    let b = bars[hv]
                    let hh = b.hours / top * inH
                    let bx = 34 + slot * CGFloat(hv) + (slot - bw) / 2 + bw / 2
                    let tx = max(40, min(w - 190, bx - 80)), ty = max(-4, (inH - hh) - 112)
                    ExBarTip(title: b.title, total: ExFmt.hours(b.hours), rows: b.segs.filter { $0.hours > 0.001 }).exAt(tx, ty).allowsHitTesting(false).zIndex(8)
                }
            }
            .frame(width: w - 34, height: inH, alignment: .topLeading)
            .exAt(34, 6)
        }
        .frame(width: w, height: h, alignment: .topLeading)
    }
}

private struct ExBarTip: View {
    let title: String, total: String
    let rows: [(scn: String, hours: Double)]
    @Environment(\.mrPalette) private var p
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ExT(s: title, size: 12, weight: 600, lh: 16, color: p.text1.color)
            ExT(s: total, fam: .mono, size: 13, weight: 500, lh: 16, color: p.text1.color).padding(.top, 2).padding(.bottom, 4)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                HStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 2).fill(ExScn.get(r.scn).color).frame(width: 8, height: 8)
                    ExT(s: ExScn.get(r.scn).name, size: 11, weight: 500, lh: 16, color: p.text2.color)
                    Spacer(minLength: 0)
                    ExT(s: ExFmt.hours(r.hours), fam: .mono, size: 11, weight: 500, lh: 16, color: p.text2.color)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(width: 160, alignment: .topLeading)
        .mrGlass(cornerRadius: 12, elevation: .e2)
    }
}

/// kind="heat": 26 week activity calendar.
struct ExHeatMap: View {
    let data: ExploreData
    @State private var hover: Int?
    @Environment(\.mrPalette) private var p
    @Environment(\.colorScheme) private var scheme

    private func fill(_ lvl: Int) -> AnyShapeStyle {
        let l = scheme == .light
        switch lvl {
        case 1: return AnyShapeStyle(l ? Color(.sRGB, red: 30 / 255, green: 107 / 255, blue: 1, opacity: 0.22) : gradA.opacity(0.28))
        case 2: return AnyShapeStyle(l ? Color(.sRGB, red: 30 / 255, green: 107 / 255, blue: 1, opacity: 0.42) : gradA.opacity(0.5))
        case 3: return AnyShapeStyle(l ? Color(.sRGB, red: 30 / 255, green: 107 / 255, blue: 1, opacity: 0.68) : gradA.opacity(0.74))
        case 4: return AnyShapeStyle(p.accentGradient)
        default: return AnyShapeStyle(p.fill1.color)
        }
    }

    var body: some View {
        let cs: CGFloat = 12, gp: CGFloat = 3
        ZStack(alignment: .topLeading) {
            ForEach(Array(data.heatMonths.enumerated()), id: \.offset) { i, m in
                Text(m).font(MRFonts.font(.ui, size: 11, weight: 500)).foregroundStyle(p.text3.color).fixedSize().frame(height: 14)
                    .exAt(28 + CGFloat(i * 4) * (cs + gp), 0)
            }
            ForEach(Array(["Mon", "Wed", "Fri"].enumerated()), id: \.offset) { i, t in
                Text(t).font(MRFonts.font(.ui, size: 10, weight: 500)).foregroundStyle(p.text3.color).fixedSize().frame(height: 14)
                    .exAt(0, 22 + CGFloat(i) * 2 * (cs + gp) - 1)
            }
            ForEach(Array(data.heat.enumerated()), id: \.offset) { i, c in
                RoundedRectangle(cornerRadius: 3, style: .continuous).fill(fill(c.level))
                    .frame(width: cs, height: cs)
                    .scaleEffect(hover == i ? 1.35 : 1)
                    .overlay { if hover == i { RoundedRectangle(cornerRadius: 3).stroke(p.text2.color, lineWidth: 1).scaleEffect(1.35) } }
                    .zIndex(hover == i ? 3 : 0)
                    .animation(MRMotion.ease(MRMotion.d2), value: hover)
                    .onHover { hv in withAnimation(MRMotion.hover) { hover = hv ? i : (hover == i ? nil : hover) } }
                    .help(c.tip)
                    .exAt(28 + CGFloat(c.week) * (cs + gp), 22 + CGFloat(c.day) * (cs + gp))
            }
            HStack(spacing: 4) {
                Text("Less").font(MRFonts.font(.ui, size: 11, weight: 500)).foregroundStyle(p.text3.color)
                ForEach(0..<5, id: \.self) { l in RoundedRectangle(cornerRadius: 3, style: .continuous).fill(fill(l)).frame(width: 12, height: 12) }
                Text("More").font(MRFonts.font(.ui, size: 11, weight: 500)).foregroundStyle(p.text3.color)
            }
            .fixedSize()
            .frame(width: 504 - 0, alignment: .trailing)
            .exAt(0, 22 + 7 * (cs + gp) + 8)
        }
        .frame(width: 504, height: 120, alignment: .topLeading)
    }
}

/// kind="ring" with label (the daily goal).
struct ExRing: View {
    let w: CGFloat, h: CGFloat
    let progress: Double
    let label: String, value: String, sub: String
    @Environment(\.mrPalette) private var p
    var body: some View {
        let lblH: CGFloat = 32
        let S = min(w, h - lblH)
        let left = (w - S) / 2, topY = lblH + (h - lblH - S) / 2
        let sw = max(10, S * 0.09), r = (S - sw) / 2 - 2
        let pr = max(0, min(1, progress))
        ZStack(alignment: .topLeading) {
            ExEyebrow(s: label, size: 10, lh: 32)
            ZStack {
                Circle().stroke(p.fill2.color, lineWidth: sw).frame(width: 2 * r, height: 2 * r)
                Circle().trim(from: 0, to: pr).stroke(gradA.opacity(0.4), style: StrokeStyle(lineWidth: sw, lineCap: .round)).frame(width: 2 * r, height: 2 * r)
                    .rotationEffect(.degrees(-90)).blur(radius: 5)
                Circle().trim(from: 0, to: pr)
                    .stroke(LinearGradient(colors: [gradA, gradB], startPoint: .topLeading, endPoint: .bottomTrailing), style: StrokeStyle(lineWidth: sw, lineCap: .round))
                    .frame(width: 2 * r, height: 2 * r).rotationEffect(.degrees(-90))
                VStack(spacing: 4) {
                    ExT(s: value, fam: .serif, size: (S * 0.22).rounded(), weight: 500, lh: (S * 0.22).rounded(), color: p.text1.color, em: -0.015)
                    ExT(s: sub, size: 13, weight: 400, lh: 18, color: p.text2.color)
                }
            }
            .frame(width: S, height: S)
            .exAt(left, topY)
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value) \(sub)")
    }
}

/// kind="top": top scenarios by hours.
struct ExTopScenarios: View {
    let rows: [(id: String, hours: Double)]
    let totalHours: Double
    @Environment(\.mrPalette) private var p
    var body: some View {
        let mx = max(0.0001, rows.first?.hours ?? 1)
        VStack(spacing: 14) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                let s = ExScn.get(r.id)
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(s.color.opacity(0.2)).frame(width: 26, height: 26)
                        .overlay { MRIcon(s.icon, size: 14).foregroundStyle(s.color) }
                    VStack(spacing: 6) {
                        HStack {
                            ExT(s: s.name, size: 13, weight: 500, lh: 16, color: p.text1.color)
                            Spacer(minLength: 0)
                            ExT(s: ExFmt.oneDecimal(r.hours) + " h · " + "\(Int((r.hours / max(0.0001, totalHours) * 100).rounded()))%", fam: .mono, size: 12, weight: 500, lh: 16, color: p.text2.color)
                        }
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(p.fill2.color)
                                RoundedRectangle(cornerRadius: 3).fill(s.color).frame(width: g.size.width * r.hours / mx)
                            }
                        }.frame(height: 6).clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
            }
        }
        .frame(width: 320, alignment: .topLeading)
    }
}

// MARK: - Screen

struct StatsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.mrPalette) private var p
    @Environment(\.shellSidebarInset) private var inset
    var data: ExploreData?
    var initialPeriod: ExPeriod = .week
    var initialHover: Int?
    var showsEmptyWhenNoData = true

    @State private var period: ExPeriod?
    @State private var hover: Int?
    @State private var recapOpen = false
    @State private var seeded = false

    private var d: ExploreData {
        data ?? ExploreData.real(flights: model.walletFlights, totalKm: model.totalKm, streak: model.streak, stamps: model.stamps, index: model.index,
                                 name: NSFullUserName().isEmpty ? "You" : NSFullUserName())
    }

    var body: some View {
        let d = d
        let left = max(inset, 236) + 28
        ZStack(alignment: .topLeading) {
            p.bg1.color
            ExGlow(rx: 0.6, ry: 0.5, cx: 0.8, cy: 0, color: gradA.opacity(0.10))
            if recapOpen {
                RecapView(data: d, onBack: { recapOpen = false })
            } else if d.isEmpty && showsEmptyWhenNoData {
                VStack(alignment: .leading, spacing: 0) {
                    ExPageHeader(eyebrow: "Explore", title: "Stats")
                }.exAt(left, 46)
                ExEmptyState(icon: .chart, title: "No flights yet", message: "Land your first flight and your hours, streak and scenarios show up here.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.leading, left)
            } else {
                content(d, left: left)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { if !seeded { seeded = true; period = initialPeriod; hover = initialHover } }
    }

    @ViewBuilder private func content(_ d: ExploreData, left: CGFloat) -> some View {
        let per = period ?? initialPeriod
        let x0 = left
        // header
        HStack(alignment: .bottom) {
            ExPageHeader(eyebrow: "Explore", title: "Stats")
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                MRSegmented(selection: Binding(get: { period ?? initialPeriod }, set: { period = $0; hover = nil }),
                            options: ExPeriod.allCases.map { .init($0, $0.title) })
                Button { recapOpen = true } label: {
                    HStack(spacing: 6) { MRIcon(.share, size: 14); Text("Share") }
                }.buttonStyle(MRButtonStyle(.secondary, size: .sm))
            }
        }
        .frame(width: 1244 - 264 + (x0 - 264 < 0 ? 0 : 0), alignment: .topLeading)
        .frame(width: 980, alignment: .topLeading)
        .exAt(x0, 46)

        if let series = d.series[per] {
            ExCard(w: 548, h: 236) {
                ExBarsChart(series: series, hover: $hover, period: per).exAt(22, 18)
            }.exAt(x0, 128)
        }
        ExCard(w: 206, h: 236) {
            ExRing(w: 166, h: 196, progress: d.dailyDoneHours / d.dailyGoalHours, label: "Daily goal", value: ExFmt.hours(d.dailyDoneHours).replacingOccurrences(of: " min", with: "").trimmingCharacters(in: .whitespaces), sub: "of \(Int(d.dailyGoalHours)) h").exAt(20, 18)
        }.exAt(x0 + 562, 128)
        ExCard(w: 198, h: 236) { streakCard(d) }.exAt(x0 + 782, 128)

        ExCard(w: 548, h: 188) { ExHeatMap(data: d).exAt(22, 16) }.exAt(x0, 378)
        tile("Total time", ExFmt.oneDecimal(d.hours), "h", d.hoursDeltaLabel).exAt(x0 + 562, 378)
        tile("Flights", "\(d.flights)", "", "\(d.thisWeekFlights) this week").exAt(x0 + 778, 378)
        tile("Distance", ExFmt.km(d.km), "km", String(format: "%.1f× around the world", d.aroundEarth)).exAt(x0 + 562, 479)
        tile("Countries", "\(d.countries)", "", "\(d.airports) airports").exAt(x0 + 778, 479)

        ExCard(w: 360, h: 184) { ExTopScenarios(rows: d.topScenarios, totalHours: d.hours).exAt(20, 14) }.exAt(x0, 580)
        longestCard(d).exAt(x0 + 374, 580)
        aroundCard(d).exAt(x0 + 688, 580)
    }

    private func streakCard(_ d: ExploreData) -> some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    ExEyebrow(s: "Streak", size: 10, lh: 12)
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(LinearGradient(colors: [gradA.opacity(0.28), gradB.opacity(0.14)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(gradA.opacity(0.4), lineWidth: 1))
                        .shadow(color: gradA.opacity(0.18), radius: 8)
                        .frame(width: 32, height: 32)
                        .overlay { ExPeakShape().stroke(p.accent2.color, style: StrokeStyle(lineWidth: 2.4 * 18 / 26, lineCap: .round, lineJoin: .round)).frame(width: 18, height: 16) }
                }.frame(width: 158, height: 32)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    ExT(s: "\(d.streak)", fam: .serif, size: 52, weight: 500, lh: 52, color: p.text1.color, em: -0.015)
                    ExT(s: "days", size: 15, weight: 500, lh: 15, color: p.text2.color)
                }.padding(.top, 26)
                ExT(s: "Best \(d.bestStreak) days", size: 13, weight: 400, lh: 18, color: p.text2.color).padding(.top, 8)
            }.exAt(20, 18)
            HStack(spacing: 0) {
                ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { i, t in
                    VStack(spacing: 6) {
                        dot(d.weekDots[i])
                        ExT(s: t, size: 11, weight: 500, lh: 11, color: p.text3.color)
                    }.frame(maxWidth: .infinity)
                }
            }
            .frame(width: 158)
            .exAt(20, 236 - 20 - 33)
        }
    }

    @ViewBuilder private func dot(_ s: Int) -> some View {
        switch s {
        case 1: Circle().fill(p.accentGradient).frame(width: 16, height: 16).shadow(color: gradA.opacity(0.45), radius: 5)
        case 2: Circle().strokeBorder(p.accent1.color, lineWidth: 1.5).frame(width: 16, height: 16)
        default: Circle().fill(p.fill2.color).frame(width: 16, height: 16)
        }
    }

    private func tile(_ label: String, _ value: String, _ unit: String, _ sub: String) -> some View {
        ExCard(w: 202, h: 87) {
            VStack(alignment: .leading, spacing: 0) {
                ExEyebrow(s: label, size: 10, lh: 12)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    ExT(s: value, fam: .serif, size: 32, weight: 500, lh: 36, color: p.text1.color, em: -0.015)
                    if !unit.isEmpty { ExT(s: unit, size: 12, weight: 500, lh: 12, color: p.text2.color) }
                }.padding(.top, 2)
                ExT(s: sub, size: 11, weight: 400, lh: 14, color: p.text2.color)
            }.exAt(16, 10)
        }
    }

    private func longestCard(_ d: ExploreData) -> some View {
        ExCard(w: 300, h: 184) {
            if let l = d.longest {
                VStack(alignment: .leading, spacing: 0) {
                    ExEyebrow(s: "Longest route")
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        ExT(s: ExFmt.km(l.km), fam: .serif, size: 44, weight: 500, lh: 44, color: p.text1.color, em: -0.02)
                        ExT(s: "km", size: 14, weight: 500, lh: 14, color: p.text2.color)
                    }.padding(.top, 12)
                    ExT(s: "\(l.from) → \(l.to)", fam: .mono, size: 13, weight: 500, lh: 16, color: p.text1.color).padding(.top, 12)
                    ExT(s: "\(ExFmt.hours(Double(l.durationMin) / 60).trimmingCharacters(in: .whitespaces)) · \(l.dateLabel)", size: 13, weight: 400, lh: 18, color: p.text3.color).padding(.top, 2)
                }.exAt(22, 18)
                let a = MapAirports.bundled.coordinate(l.from), b = MapAirports.bundled.coordinate(l.to)
                let mid = a.flatMap { a in b.map { b in ((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2) } }
                GlobeView(lon: d.isFixture ? 22 : (mid?.1 ?? 22), lat: d.isFixture ? 44 : (mid?.0 ?? 44), size: 200,
                          routes: [GlobeRoute(from: l.from, to: l.to, color: Color(.sRGB, red: 139 / 255, green: 243 / 255, blue: 216 / 255), width: 2, opacity: 0.95, lift: 0.12)].compactMap { $0 },
                          pins: [GlobePin(code: l.from, radius: 3.4), GlobePin(code: l.to, radius: 3.4)].compactMap { $0 },
                          showsGraticule: false, showsAtmosphere: false)
                    .opacity(0.95).exAt(164, -2)
            } else {
                ExEyebrow(s: "Longest route").exAt(22, 18)
                ExT(s: "Your longest flight shows here.", size: 13, weight: 400, lh: 18, color: p.text2.color).exAt(22, 60)
            }
        }
    }

    private func aroundCard(_ d: ExploreData) -> some View {
        ExCard(w: 292, h: 184) {
            VStack(alignment: .leading, spacing: 0) {
                ExEyebrow(s: "Around Earth")
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    ExT(s: ExFmt.oneDecimal(d.aroundEarth), fam: .serif, size: 44, weight: 500, lh: 44, color: p.text1.color, em: -0.02)
                    ExT(s: "×", size: 14, weight: 500, lh: 14, color: p.text2.color)
                }.padding(.top, 12)
                ExT(s: "\(ExFmt.km(d.km)) of 40,075 km. Equator tier is next.", size: 13, weight: 400, lh: 18, color: p.text2.color, wrap: 120).padding(.top, 12)
            }.exAt(22, 18)
            ExOrbit(fraction: d.km / 40_075).frame(width: 150, height: 150).exAt(128, 17)
        }
    }
}

/// The small Earth with the orbit progress of the "Around Earth" card.
struct ExOrbit: View {
    let fraction: Double
    @Environment(\.mrPalette) private var p
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let g = scheme == .dark ? MRMapPalette.Globe.dark : MRMapPalette.Globe.light
        let f = max(0, min(1, fraction))
        let ang = f * 2 * .pi - .pi / 2
        let px = 75 + 60 * cos(ang), py = 75 + 60 * sin(ang)
        ZStack(alignment: .topLeading) {
            Circle().stroke(p.fill3.color, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [1, 5])).frame(width: 120, height: 120).exAt(15, 15)
            Circle().trim(from: 0, to: f).stroke(LinearGradient(colors: [gradA, gradB], startPoint: .topLeading, endPoint: .bottomTrailing),
                                                 style: StrokeStyle(lineWidth: 3.5, lineCap: .round)).frame(width: 120, height: 120).rotationEffect(.degrees(-90)).exAt(15, 15)
            Circle().fill(g.seaA.color).frame(width: 80, height: 80).exAt(35, 35)
            Path { q in
                q.move(to: CGPoint(x: 52, y: 62))
                q.addQuadCurve(to: CGPoint(x: 78, y: 52), control: CGPoint(x: 62, y: 48))
                q.addQuadCurve(to: CGPoint(x: 92, y: 68), control: CGPoint(x: 92, y: 54))
                q.addQuadCurve(to: CGPoint(x: 74, y: 86), control: CGPoint(x: 88, y: 80))
                q.addQuadCurve(to: CGPoint(x: 50, y: 78), control: CGPoint(x: 62, y: 94))
                q.addLine(to: CGPoint(x: 52, y: 62))
            }.fill(g.land.color)
            Circle().fill(.white.opacity(0.18)).frame(width: 20, height: 20).exAt(px - 10, py - 10)
            Circle().fill(.white).frame(width: 10, height: 10).exAt(px - 5, py - 5)
        }
        .frame(width: 150, height: 150, alignment: .topLeading)
    }
}
