import AppKit
import MeridianCore
import MeridianUI
import SwiftUI

// MARK: - Configuration (debug harness and defaults)

/// State the canvas artboards set through props (`color-by`, `view`, `fan`, `sel`, `hover-idx`, ...).
struct WalletConfig {
    var colorBy: PaperColorBy = .scenario
    var stack = false
    var fan = 0.15
    var sel = -1
    var hoverIdx = -1
    var filters = WalletFilters()
    /// Forces the empty state (canvas `empty`).
    var empty = false
    /// Shows the canvas' sample flights instead of `AppModel.walletFlights` (debug routes only).
    var fixture = false
    var detailIndex: Int?
    var detailBack = false
    var detailTilt = false
}

/// Set by a debug route's `setup` closure before the view is built.
@MainActor enum WalletDebug { static var current: WalletConfig? }

private enum WalletMode: Hashable { case grid, stack }

// MARK: - Wallet screen (S30, S30B-E, S30L, S30S, S30T)

struct WalletView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.shellSidebarInset) private var inset
    @Environment(\.mrPalette) private var p
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let config: WalletConfig
    @State private var colorBy: PaperColorBy
    @State private var mode: WalletMode
    @State private var fan: Double
    @State private var filters: WalletFilters
    @State private var detail: String?
    @FocusState private var searchFocused: Bool
    @FocusState private var focusedTicket: String?

    init(config: WalletConfig? = nil) {
        let c = config ?? WalletDebug.current ?? WalletConfig()
        self.config = c
        _colorBy = State(initialValue: c.colorBy)
        _mode = State(initialValue: c.stack ? .stack : .grid)
        _fan = State(initialValue: c.fan)
        _filters = State(initialValue: c.filters)
        _detail = State(initialValue: nil)
    }

    // MARK: Data

    private var live: Bool { !config.fixture }

    private var allTickets: [WalletTicket] {
        if config.empty { return [] }
        if config.fixture { return WalletFixtures.tickets(airport: airport) }
        return WalletBuilder.tickets(from: model.walletFlights, airport: airport, passenger: NSFullUserName().isEmpty ? "You" : NSFullUserName())
    }

    /// The canvas kit's airports first (short city names, as the Plan screen shows them), the bundled index as fallback.
    private func airport(_ iata: String) -> Airport? { PlanKit.index.airport(iata: iata) ?? model.airport(iata) }

    private var shown: [WalletTicket] { filters.apply(allTickets) }

    private var years: [String] {
        Array(Set(allTickets.map(\.year))).sorted(by: >).map(String.init)
    }

    private var summary: String {
        let all = allTickets
        if all.isEmpty { return "0 flights" }
        let list = shown
        let active = [filters.year == WalletFilters.allYears ? nil : filters.year,
                      filters.scenario == WalletFilters.allScenarios ? nil : filters.scenario,
                      filters.cabin == WalletFilters.allClasses ? nil : filters.cabin].compactMap { $0 }
        if !active.isEmpty || !filters.query.isEmpty {
            return ([("\(list.count) \(list.count == 1 ? "flight" : "flights")")] + active).joined(separator: " · ")
        }
        return config.fixture ? WalletFixtures.summary : WalletSummary.text(count: all.count, flights: model.walletFlights)
    }

    private var totalForDetail: Int { config.fixture && !filters.isActive ? WalletFixtures.total : shown.count }

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width, H = geo.size.height
            let left = inset + 28
            ZStack(alignment: .topLeading) {
                WalletGlow().allowsHitTesting(false)
                Group {
                    ZStack(alignment: .topLeading) {
                        if allTickets.isEmpty {
                            emptyState(W: W)
                        } else if mode == .grid {
                            grid(W: W, H: H, left: left)
                        } else {
                            stack(W: W, H: H)
                        }
                        header(left: left)
                        if !allTickets.isEmpty { filterRows(left: left) }
                    }
                }
                .modifier(DetailBackdrop(active: detail != nil))
                .allowsHitTesting(detail == nil)

                if let id = detail, let idx = shown.firstIndex(where: { $0.id == id }) {
                    TicketDetailView(
                        tickets: shown, index: Binding(get: { idx }, set: { detail = shown[$0].id }), total: totalForDetail,
                        colorBy: colorBy, stageLeft: inset + 8, startBack: config.detailBack, staticTilt: config.detailTilt, live: live,
                        onClose: { detail = nil },
                        onDelete: { t in delete(t) },
                        onSaveNotes: { t, text in saveNotes(t, text) })
                    .transition(.opacity)
                    .zIndex(30)
                }
            }
            .frame(width: W, height: H, alignment: .topLeading)
            .background(shortcuts)
            .onAppear { if let i = config.detailIndex, shown.indices.contains(i) { detail = shown[i].id } }
            .animation(reduceMotion ? nil : MRMotion.ease(MRMotion.d3), value: detail)
        }
    }

    private var shortcuts: some View {
        Button("") { searchFocused = true }.keyboardShortcut("f", modifiers: .command).opacity(0).allowsHitTesting(false).accessibilityHidden(true)
    }

    // MARK: Actions

    private func delete(_ t: WalletTicket) {
        guard let fid = t.flightID else { detail = nil; return }
        let list = shown
        let i = list.firstIndex(of: t) ?? 0
        // Stay on the neighbour, or close when it was the last ticket.
        let next = list.indices.contains(i + 1) ? list[i + 1].id : (i > 0 ? list[i - 1].id : nil)
        model.deleteFlight(id: fid)
        detail = next == t.id ? nil : next
    }

    private func saveNotes(_ t: WalletTicket, _ text: String) {
        guard let fid = t.flightID else { return }
        model.updateNotes(flightID: fid, notes: text)
    }

    // MARK: Header

    private func header(left: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Wallet").mrEyebrow().frame(height: 14)
                Text("Tickets").font(.mr(.serif, size: 42, weight: 500)).tracking(-0.84).frame(height: 46).padding(.top, 6)
                    .foregroundStyle(p.text1.color)
                Text(summary).mrText(.callout).foregroundStyle(p.text2.color).frame(height: 18).padding(.top, 4)
            }
            Spacer(minLength: 12)
            HStack(spacing: 12) {
                WalletSearchField(text: $filters.query, focused: $searchFocused)
                MRSegmented(selection: $mode, options: [.init(.grid, "Grid", icon: .grid, iconSize: 14), .init(.stack, "Stack", icon: .layers, iconSize: 14)])
                    .accessibilityLabel("View")
            }
        }
        .padding(.leading, left).padding(.trailing, 28).padding(.top, 48)
    }

    private func filterRows(left: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 12) {
                Text("Color by").mrEyebrow().padding(.trailing, 2).fixedSize()
                MRSegmented(selection: $colorBy, options: [
                    .init(.scenario, "Scenario"), .init(.class, "Class"), .init(.continent, "Continent"), .init(.month, "Month")])
                    .accessibilityLabel("Color by")
                Rectangle().fill(p.strokeHair.color).frame(width: 1, height: 20).padding(.horizontal, 6)
                WalletDropdown(options: [WalletFilters.allYears] + years, allLabel: WalletFilters.allYears, selection: $filters.year, label: "Year")
                WalletDropdown(options: [WalletFilters.allScenarios] + PaperScenario.allCases.map(\.label), allLabel: WalletFilters.allScenarios, selection: $filters.scenario, label: "Scenario")
                WalletDropdown(options: [WalletFilters.allClasses] + BoardingPassCabin.allCases.map(\.title), allLabel: WalletFilters.allClasses, selection: $filters.cabin, label: "Class")
            }
            .frame(height: 36).offset(y: 134 - 0)
            legend.offset(y: 174)
        }
        .padding(.leading, left)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Legend (color + label, never color alone)

    private var legend: some View {
        HStack(spacing: 14) {
            switch colorBy {
            case .scenario:
                ForEach(PaperScenario.allCases, id: \.self) { s in swatch(Circle().fill(MRColorToken(s.hex).color).frame(width: 10, height: 10), s.label) }
            case .class:
                ForEach(BoardingPassCabin.allCases, id: \.self) { c in swatch(Circle().fill(WalletColor.foil(c)).frame(width: 10, height: 10), c.title) }
            case .continent:
                ForEach(PaperContinent.allCases, id: \.self) { c in swatch(Circle().fill(MRColorToken(c.hex).color).frame(width: 10, height: 10), WalletColor.continentName(c)) }
            case .month:
                ForEach(0..<12, id: \.self) { m in
                    RoundedRectangle(cornerRadius: 3, style: .continuous).fill(WalletColor.month(m)).frame(width: 14, height: 10)
                        .accessibilityLabel(WalletColor.monthNames[m])
                }
            }
        }
        .fixedSize()
    }

    private func swatch<S: View>(_ dot: S, _ text: String) -> some View {
        HStack(spacing: 6) {
            dot
            Text(text).font(.mr(.ui, size: 12, weight: 500)).foregroundStyle(p.text2.color).lineLimit(1).fixedSize()
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Grid

    private func grid(W: CGFloat, H: CGFloat, left: CGFloat) -> some View {
        let n = max(1, Int((W - left - 28 + 16) / 196))
        let list = shown
        return ZStack(alignment: .topLeading) {
            ScrollView(.vertical) {
                if list.isEmpty {
                    Text("No tickets match.").mrText(.body).foregroundStyle(p.text2.color)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, left).padding(.top, 24)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(180), spacing: 16), count: n), alignment: .leading, spacing: 10) {
                        ForEach(Array(list.enumerated()), id: \.element.id) { i, t in
                            WalletTile(ticket: t, colorBy: colorBy, live: live, forcedHover: i == config.hoverIdx, selected: i == config.sel,
                                       focused: $focusedTicket) { open(t) }
                        }
                    }
                    .padding(.leading, left).padding(.top, 8).padding(.bottom, 130)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .scrollIndicators(.hidden)
            .frame(width: W, height: H - 204)
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 8 / max(1, H - 204))], startPoint: .top, endPoint: .bottom))
            .offset(y: 204)
            LinearGradient(colors: [.clear, p.bg1.color], startPoint: .top, endPoint: .init(x: 0.5, y: 0.86))
                .frame(width: W - inset - 28 + 28, height: 120).offset(x: inset, y: H - 120).allowsHitTesting(false)
        }
    }

    // MARK: Stack (S30S / S30T)

    private func stack(W: CGFloat, H: CGFloat) -> some View {
        let list = shown
        let off = 14 + fan * 44
        let base: CGFloat = 462
        let n = max(1, min(6, list.count, Int((base - 214) / off) + 1))
        let cx = (W + inset) / 2
        return ZStack(alignment: .topLeading) {
            ForEach(Array((0..<min(n, list.count)).reversed()), id: \.self) { k in
                let t = list[k]
                let y = base - CGFloat(k) * off
                let rot = (k % 2 == 1 ? 1.0 : -1.0) * min(1.6, Double(k) * 0.5) * (1 - fan * 0.6)
                Button { open(t) } label: {
                    BoardingPassView(t.model(colorBy: colorBy), state: t.state, scale: 0.7)
                        .frame(width: 252, height: 316, alignment: .topLeading)
                        .shadow(color: .black.opacity(0.35), radius: 7, y: CGFloat(6 + (k == 0 ? 8 : 0)) )
                }
                .buttonStyle(.plain)
                .rotationEffect(.degrees(rot), anchor: .bottom)
                .offset(x: cx - 134, y: y)
                .zIndex(Double(20 - k))
                .animation(reduceMotion ? nil : MRMotion.smooth, value: fan)
                .accessibilityLabel(t.accessibilityLabel)
            }
            LinearGradient(stops: [.init(color: p.bg1.color, location: 0.62), .init(color: p.bg1.color.opacity(0), location: 1)], startPoint: .top, endPoint: .bottom)
                .frame(width: W - inset, height: 214).offset(x: inset).allowsHitTesting(false).zIndex(40)
        }
        .frame(width: W, height: H, alignment: .topLeading)
        .background(WalletScrollCatcher { dy in
            fan = min(1, max(0, fan - dy * 0.002))
        })
    }

    private func open(_ t: WalletTicket) { detail = t.id }

    // MARK: Empty (S30E)

    private func emptyState(W: CGFloat) -> some View {
        VStack(spacing: 0) {
            WalletLockedTicket().frame(width: 216, height: 272).opacity(0.9)
            Text("No tickets yet.").font(.mr(.serif, size: 34, weight: 500)).tracking(-0.51).frame(height: 40).padding(.top, 30)
                .foregroundStyle(p.text1.color)
            Text("Your first flight will print here.").mrText(.body).foregroundStyle(p.text2.color).padding(.top, 6)
            Button {
                model.planStage = .plan; model.section = .fly
            } label: {
                HStack(spacing: 8) { MRIcon(.plane, size: 18); Text("Plan a flight") }
            }
            .buttonStyle(MRButtonStyle(.primary, size: .lg, pill: true)).padding(.top, 26)
        }
        .frame(width: W - inset, alignment: .center)
        .offset(x: inset, y: 170)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Backdrop behind the detail (`filter:blur(14px) saturate(.9)`, scale 1.04, opacity .65)

private struct DetailBackdrop: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        content
            .blur(radius: active ? 14 : 0).saturation(active ? 0.9 : 1)
            .scaleEffect(active ? 1.04 : 1).opacity(active ? 0.65 : 1)
    }
}

// MARK: - Window glow: `radial-gradient(60% 50% at 70% 0%, rgba(106,183,255,.10), transparent 70%)`

struct WalletGlow: View {
    @Environment(\.mrPalette) private var p
    var body: some View {
        Canvas { ctx, size in
            let rx = size.width * 0.6, ry = size.height * 0.5
            var c = ctx
            c.translateBy(x: size.width * 0.7, y: 0)
            c.scaleBy(x: rx, y: ry)
            let g = Gradient(stops: [.init(color: MRColorToken(106, 183, 255, 0.10).color, location: 0),
                                     .init(color: MRColorToken(106, 183, 255, 0).color, location: 0.7)])
            c.fill(Path(ellipseIn: CGRect(x: -1, y: -1, width: 2, height: 2)),
                   with: .radialGradient(g, center: .zero, startRadius: 0, endRadius: 1))
        }
    }
}

// MARK: - Tile

private struct WalletTile: View {
    let ticket: WalletTicket
    let colorBy: PaperColorBy
    let live: Bool
    let forcedHover: Bool
    let selected: Bool
    var focused: FocusState<String?>.Binding
    let onOpen: () -> Void

    @Environment(\.mrPalette) private var p
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        let lifted = (hovering || forcedHover) && !reduceMotion
        Button(action: onOpen) {
            ZStack(alignment: .topLeading) {
                BoardingPassView(ticket.model(colorBy: colorBy), state: ticket.state, scale: 0.5, live: live, hoverPose: forcedHover)
                HStack(spacing: 7) {
                    WalletColor.dot(ticket, by: colorBy, size: 8)
                    Text(WalletColor.label(ticket, by: colorBy)).font(.mr(.ui, size: 12, weight: 500)).foregroundStyle(p.text2.color).lineLimit(1)
                    Spacer(minLength: 0)
                    Text(verbatim: "\(ticket.km) km").font(.mr(.mono, size: 11, weight: 500)).foregroundStyle(p.text3.color)
                }
                .frame(width: 180, height: 14).offset(y: 234)
            }
            .frame(width: 180, height: 252, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused(focused, equals: ticket.id)
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(p.accent1.color, lineWidth: 2).padding(-8)
                    .shadow(color: MRColorToken(106, 183, 255, 0.3).color, radius: 15).allowsHitTesting(false)
            }
        }
        .mrFocusRing(focused.wrappedValue == ticket.id, cornerRadius: 12, offset: 6, color: p.accent1.color)
        .offset(y: lifted ? -6 : 0)
        .animation(reduceMotion ? nil : .spring(response: MRMotion.snappyParams.response, dampingFraction: MRMotion.snappyParams.damping), value: lifted)
        .onHover { if live { hovering = $0 } }
        .accessibilityLabel(ticket.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Controls

/// `.field` with the `⌘F` keycap.
private struct WalletSearchField: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    @Environment(\.mrPalette) private var p
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        HStack(spacing: 8) {
            MRIcon(.search, size: 14).foregroundStyle(p.text3.color)
            TextField("", text: $text, prompt: Text("Search tickets").foregroundStyle(p.text3.color))
                .textFieldStyle(.plain).font(.mr(.ui, size: 14, weight: 400)).foregroundStyle(p.text1.color)
                .focused(focused)
                .accessibilityLabel("Search tickets")
            MRKbd("⌘F")
        }
        .padding(.horizontal, 12).frame(width: 236, height: 36)
        .background((focused.wrappedValue || hovering) ? p.fill2.color : p.fill1.color, in: shape)
        .overlay(shape.strokeBorder(p.strokeHair.color, lineWidth: 1))
        .mrFocusRing(focused.wrappedValue, cornerRadius: 12, color: p.accent1.color)
        .onHover { hovering = $0 }
        .onExitCommand { text = ""; focused.wrappedValue = false }
    }
}

/// `.wl-dd`: 30 pt filter pill that opens a menu. Highlighted while a filter is active.
private struct WalletDropdown: View {
    let options: [String]
    let allLabel: String
    @Binding var selection: String
    let label: String
    @Environment(\.mrPalette) private var p
    @State private var hovering = false

    var body: some View {
        let on = selection != allLabel
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        Menu {
            ForEach(options, id: \.self) { o in
                Button { selection = o } label: {
                    if o == selection { Label(o, systemImage: "checkmark") } else { Text(o) }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selection).font(.mr(.ui, size: 13, weight: 500)).lineLimit(1)
                MRIcon(.chevD, size: 12).foregroundStyle(p.text3.color)
            }
            .foregroundStyle(on ? p.accent1.color : p.text1.color)
            .padding(.leading, 12).padding(.trailing, 10).frame(height: 30)
            .background(on ? MRColorToken(106, 183, 255, 0.14).color : (hovering ? p.fill2.color : p.fill1.color), in: shape)
            .overlay(shape.strokeBorder(on ? MRColorToken(106, 183, 255, 0.4).color : p.strokeHair.color, lineWidth: 1))
            .contentShape(shape)
        }
        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
        .onHover { hovering = $0 }
        .accessibilityLabel("\(label): \(selection)")
    }
}

/// The wallet's empty placeholder: the dashed locked ticket with its own label (canvas `label="Your first flight prints here"`).
private struct WalletLockedTicket: View {
    @Environment(\.mrPalette) private var p
    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 22, style: .circular).fill(p.fill1.color)
            RoundedRectangle(cornerRadius: 22, style: .circular).strokeBorder(p.text3.color, style: StrokeStyle(lineWidth: 1.5, dash: [4.5, 4.5]))
            VStack(spacing: 14) {
                MRIcon(.lock, size: 24)
                Text("Your first flight prints here").font(.mr(.ui, size: 13, weight: 400)).multilineTextAlignment(.center)
                    .frame(width: 150).lineSpacing(3)
            }
            .foregroundStyle(p.text3.color).padding(.top, 272 * 0.34)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Locked ticket. Your first flight prints here")
    }
}

// MARK: - Scroll (stack fan-out)

/// Catches trackpad / wheel scrolling over its frame without blocking clicks (local event monitor).
struct WalletScrollCatcher: NSViewRepresentable {
    let onScroll: (Double) -> Void

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        context.coordinator.view = v
        context.coordinator.install()
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) { context.coordinator.onScroll = onScroll }
    func makeCoordinator() -> Coordinator { Coordinator(onScroll) }
    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) { coordinator.remove() }

    @MainActor final class Coordinator {
        var onScroll: (Double) -> Void
        weak var view: NSView?
        private var monitor: Any?
        init(_ onScroll: @escaping (Double) -> Void) { self.onScroll = onScroll }
        func install() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, let view = self.view, view.window === event.window else { return event }
                let p = view.convert(event.locationInWindow, from: nil)
                guard view.bounds.contains(p) else { return event }
                self.onScroll(Double(event.scrollingDeltaY))
                return nil
            }
        }
        func remove() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil }
    }
}
