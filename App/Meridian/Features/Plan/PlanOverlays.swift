import MeridianCore
import MeridianPlan
import MeridianUI
import SwiftUI

// MARK: - Origin popover

/// The departure-airport popover (`pop` in `Planner.dc.html`).
struct OriginPopover: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Binding var isOpen: Bool
    @State private var query = ""
    @FocusState private var focused: Bool

    private static let favorites = ["LHR", "IST", "AMS", "KCO"]

    var body: some View {
        let p = MRPalette.resolve(scheme)
        let plan = model.plan
        let favs = Set(plan.preferences.favoriteIatas).union(Self.favorites)
        let q = query.lowercased()
        let options = plan.index.airports
            .filter { $0.iata != plan.origin.iata }
            .map { ($0, PlanKit.km(plan.origin, $0)) }
            .filter { q.isEmpty || $0.0.iata.lowercased().contains(q) || $0.0.city.lowercased().contains(q) || $0.0.name.lowercased().contains(q) }
            .sorted { (favs.contains($1.0.iata) ? 1 : 0, $0.1) < (favs.contains($0.0.iata) ? 1 : 0, $1.1) }
            .prefix(q.isEmpty ? 4 : 6)
        let last = plan.preferences.lastLandingIata.flatMap { plan.index.airport(iata: $0) }

        VStack(spacing: 1) {
            HStack(spacing: 8) {
                MRIcon(.search, size: 14).foregroundStyle(p.text3.color)
                TextField("Airport, city or code", text: $query).textFieldStyle(.plain)
                    .font(.mr(.ui, size: 14)).focused($focused).accessibilityLabel("Search airports")
            }
            .padding(.horizontal, 12).frame(height: 38)
            .background(p.fill1.color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(p.strokeHair.color))
            .padding(.horizontal, 2).padding(.top, 2).padding(.bottom, 8)

            Row(icon: .target, title: "Use my location", sub: "Nearest airport to you") {
                let home = plan.preferences.homeIata ?? plan.origin.iata
                set(home)
            }
            if let last {
                Row(icon: .history, title: "Continue from last landing", sub: "\(last.iata) · \(last.city)", trailingTag: last.iata) { set(last.iata) }
            }
            Text("Favorites and nearby").mrEyebrow().padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(options), id: \.0.iata) { a, km in
                Row(tag: a.iata, title: a.city, sub: a.name, dist: "\(PlanKit.fmtKm(km)) km", fav: favs.contains(a.iata)) { set(a.iata) }
            }
        }
        .padding(10).frame(width: 360)
        .mrGlass(cornerRadius: 24, elevation: .e3)
        .onAppear { focused = true }
    }

    private func set(_ iata: String) {
        model.plan.setOrigin(iata: iata)
        isOpen = false
    }

    private struct Row: View {
        var icon: MRIconName?
        var tag: String?
        let title: String
        let sub: String
        var dist: String?
        var fav = false
        var trailingTag: String?
        let action: () -> Void
        @Environment(\.colorScheme) private var scheme
        @State private var hovered = false
        init(icon: MRIconName? = nil, tag: String? = nil, title: String, sub: String, dist: String? = nil, fav: Bool = false, trailingTag: String? = nil, action: @escaping () -> Void) {
            self.icon = icon; self.tag = tag; self.title = title; self.sub = sub; self.dist = dist; self.fav = fav; self.trailingTag = trailingTag; self.action = action
        }
        var body: some View {
            let p = MRPalette.resolve(scheme)
            Button(action: action) {
                HStack(spacing: 12) {
                    if let icon { MRIcon(icon, size: 18).foregroundStyle(p.accent1.color) }
                    if let tag { AirportTag(code: tag) }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(title).font(.mr(.ui, size: 14, weight: 500)).frame(height: 18)
                        Text(sub).font(.mr(.ui, size: 13)).foregroundStyle(p.text3.color).lineLimit(1).frame(height: 18)
                    }
                    Spacer(minLength: 0)
                    if let dist { Text(dist).font(.mr(.mono, size: 11, weight: 500)).foregroundStyle(p.text2.color) }
                    if fav { MRIcon(.star, size: 14).foregroundStyle(p.amber.color) }
                    if let trailingTag { AirportTag(code: trailingTag) }
                }
                .foregroundStyle(p.text1.color)
                .padding(.horizontal, 12).frame(height: 46)
                .background(hovered ? p.fill2.color : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).onHover { hovered = $0 }
        }
    }
}

// MARK: - Search palette (⌘K) and Surprise me

/// `Search.dc.html`: the ⌘K palette with its split-flap "Surprise me" reveal.
struct SearchPalette: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    let width: CGFloat
    let onChoose: (Airport) -> Void
    let close: () -> Void
    var initialReveal: String?
    var initialSelection = 0

    @State private var query = ""
    @State private var selection: Int
    @State private var reveal: String?
    @State private var appeared = false
    @FocusState private var focused: Bool

    init(width: CGFloat, initialReveal: String? = nil, initialSelection: Int = 0, onChoose: @escaping (Airport) -> Void, close: @escaping () -> Void) {
        self.width = width; self.initialReveal = initialReveal; self.initialSelection = initialSelection
        self.onChoose = onChoose; self.close = close
        _selection = State(initialValue: initialSelection)
        _reveal = State(initialValue: initialReveal)
    }

    private struct Row: Identifiable {
        let airport: Airport, km: Double, minutes: Int
        var id: String { airport.iata }
    }

    private var minutes: Int { model.plan.durationMinutes ?? 42 }

    private var all: [Row] {
        let plan = model.plan, q = query.trimmingCharacters(in: .whitespaces).lowercased()
        var rows = plan.index.airports.filter { $0.iata != plan.origin.iata }.map { a -> Row in
            let km = PlanKit.km(plan.origin, a).rounded()
            return Row(airport: a, km: km, minutes: PlanState.canvasMinutes(forKm: km))
        }
        if q.isEmpty {
            rows.sort { abs($0.minutes - minutes) < abs($1.minutes - minutes) }   // stable in practice for the sample sizes
        } else {
            rows = rows.filter { r in
                "\(r.airport.iata) \(r.airport.city) \(r.airport.name) \(PlanKit.countryName(r.airport.countryCode))".lowercased().contains(q)
            }
            func rank(_ r: Row) -> Int { r.airport.iata.lowercased() == q ? 0 : (r.airport.city.lowercased().hasPrefix(q) ? 1 : 2) }
            rows = rows.enumerated().sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }.map(\.element)
        }
        return rows
    }

    var body: some View {
        let p = MRPalette.resolve(scheme)
        let rows = Array(all.prefix(6))
        let sel = min(selection, 5)
        let origin = model.plan.origin
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                MRIcon(.search, size: 20).foregroundStyle(p.text2.color)
                TextField("Search airports, cities, countries", text: $query)
                    .textFieldStyle(.plain).font(.mr(.ui, size: 18)).focused($focused)
                    .accessibilityLabel("Search airports")
                    .onSubmit { if rows.indices.contains(sel) { onChoose(rows[sel].airport) } }
                    .onChange(of: query) { selection = 0 }
                MRKbd("esc")
            }
            .padding(.horizontal, 14).frame(height: 56)
            MRDivider().padding(.top, 2).padding(.horizontal, 8).padding(.bottom, 8)

            if let code = reveal, let r = model.plan.index.airport(iata: code) {
                revealBlock(r, palette: p)
            } else {
                Text(query.isEmpty ? "Near \(minutes) minutes from \(origin.iata)" : "Airports").mrEyebrow()
                    .padding(.horizontal, 14).padding(.top, 4).padding(.bottom, 8).frame(maxWidth: .infinity, alignment: .leading)
                ForEach(Array(rows.enumerated()), id: \.element.id) { i, r in
                    SearchRow(row: r, selected: i == sel) { onChoose(r.airport) } hover: { selection = i }
                }
                if rows.isEmpty {
                    Text("No airports match “\(query)”. Try a city or a three-letter code.")
                        .font(.mr(.ui, size: 15)).foregroundStyle(p.text2.color).multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity).padding(.horizontal, 14).padding(.vertical, 26)
                }
                MRDivider().padding(.horizontal, 8).padding(.vertical, 8)
                Button(action: surprise) {
                    HStack(spacing: 14) {
                        MRIcon(.shuffle, size: 20).foregroundStyle(p.accent1.color).frame(width: 48)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Surprise me").font(.mr(.ui, size: 15, weight: 600)).frame(height: 20)
                            Text("A random destination near \(minutes) minutes away").font(.mr(.ui, size: 13)).foregroundStyle(p.text3.color).frame(height: 18)
                        }
                        Spacer(minLength: 0)
                        MRKbd("⌘R")
                    }
                    .foregroundStyle(p.text1.color)
                    .padding(.horizontal, 14).frame(height: 52).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 18) {
                HStack(spacing: 4) { MRKbd("↑"); MRKbd("↓"); Text("navigate").font(.mr(.ui, size: 12)) }
                HStack(spacing: 4) { MRKbd("⏎"); Text("choose").font(.mr(.ui, size: 12)) }
                HStack(spacing: 4) { MRKbd("esc"); Text("close").font(.mr(.ui, size: 12)) }
            }
            .foregroundStyle(p.text3.color).padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10).frame(width: 640)
        .mrGlass(cornerRadius: 28, elevation: .e3)
        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 10).scaleEffect(appeared ? 1 : 0.985)
        .onAppear {
            focused = true
            withAnimation(MRMotion.ease(0.26)) { appeared = true }
        }
        .onKeyPress(.downArrow) { selection = min(5, sel + 1); return .handled }
        .onKeyPress(.upArrow) { selection = max(0, sel - 1); return .handled }
        .onKeyPress(.escape) { close(); return .handled }
        .background { Button("") { surprise() }.keyboardShortcut("r", modifiers: .command).opacity(0).accessibilityHidden(true) }
    }

    private func surprise() {
        let pool = all.filter { abs($0.minutes - minutes) <= 12 }
        guard let pick = pool.randomElement() ?? all.first else { return }
        reveal = pick.airport.iata
    }

    private func revealBlock(_ r: Airport, palette p: MRPalette) -> some View {
        let km = PlanKit.km(model.plan.origin, r).rounded()
        let mins = PlanState.canvasMinutes(forKm: km)
        let row = "\(r.iata) · \(PlanKit.fmtShort(mins)) · \(r.countryCode)".uppercased()
        return VStack(alignment: .leading, spacing: 18) {
            Text("Your destination").mrEyebrow()
            VStack(alignment: .leading, spacing: 12) {
                MRSplitFlapBoard(r.city.uppercased(), length: 12, size: .m, live: true).padding(.bottom, 4)
                MRSplitFlapBoard(row, length: 22, size: .xs, tone: .white, live: true).padding(.bottom, 4)
            }
            .padding(.horizontal, 20).padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MRColorToken("#0B1020").color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            HStack(spacing: 10) {
                Button("Set destination") { onChoose(r) }.buttonStyle(MRButtonStyle(.primary))
                Button { surprise() } label: { HStack(spacing: 8) { MRIcon(.shuffle, size: 16); Text("Spin again") } }
                    .buttonStyle(MRButtonStyle(.secondary))
                Spacer()
                Text("\(PlanKit.countryName(r.countryCode)) · \(PlanKit.fmtKm(km)) km").font(.mr(.ui, size: 13)).foregroundStyle(p.text3.color)
            }
        }
        .padding(.horizontal, 22).padding(.top, 22).padding(.bottom, 14)
    }

    private struct SearchRow: View {
        let row: SearchPalette.Row
        let selected: Bool
        let pick: () -> Void
        let hover: () -> Void
        @Environment(\.colorScheme) private var scheme
        @State private var hovered = false
        var body: some View {
            let p = MRPalette.resolve(scheme)
            let dark = scheme == .dark
            let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
            let sub = selected ? p.text2.color : p.text3.color
            Button(action: pick) {
                HStack(spacing: 14) {
                    AirportTag(code: row.airport.iata).minWidth(48)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(row.airport.city).font(.mr(.ui, size: 15, weight: 500)).frame(height: 20)
                        Text("\(row.airport.name) · \(PlanKit.countryName(row.airport.countryCode))").font(.mr(.ui, size: 13)).foregroundStyle(sub).lineLimit(1).frame(height: 18)
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(PlanKit.fmtShort(row.minutes)).font(.mr(.mono, size: 14, weight: 500))
                        Text("\(PlanKit.fmtKm(row.km)) km").font(.mr(.mono, size: 11, weight: 500)).foregroundStyle(sub)
                    }
                }
                .foregroundStyle(p.text1.color)
                .padding(.horizontal, 14).frame(height: 52)
                .background {
                    if selected {
                        let a = dark ? (MRColorToken(106, 183, 255, 0.22), MRColorToken(139, 243, 216, 0.10), MRColorToken(106, 183, 255, 0.34))
                                     : (MRColorToken(30, 107, 255, 0.12), MRColorToken(24, 199, 160, 0.08), MRColorToken(30, 107, 255, 0.30))
                        shape.fill(LinearGradient(colors: [a.0.color, a.1.color], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(shape.stroke(a.2.color, lineWidth: 1).padding(-0.5))
                    } else if hovered { shape.fill(p.fill2.color) }
                }
                .contentShape(shape)
            }
            .buttonStyle(.plain).onHover { hovered = $0; if $0 { hover() } }
        }
    }
}
