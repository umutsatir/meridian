import MapKit
import MeridianCore
import MeridianPlan
import MeridianUI
import SwiftUI

/// The planning screen (PRD §9.2): a map with the range ring, and a dock with
/// origin, duration and destinations.
struct PlanView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var camera: MapCameraPosition = .automatic
    @State private var showsSearch = false

    var body: some View {
        @Bindable var model = model
        let plan = model.plan
        let palette = MRPalette.resolve(scheme)

        ZStack(alignment: .bottom) {
            Map(position: $camera, interactionModes: [.pan, .zoom]) {
                if let ring = plan.rangeRing {
                    MapCircle(center: plan.origin.mapCoordinate, radius: ring.outerRadiusKm * 1000)
                        .foregroundStyle(palette.amber.color.opacity(0.06))
                        .stroke(palette.amber.color.opacity(0.7), lineWidth: 1.5)
                    MapCircle(center: plan.origin.mapCoordinate, radius: ring.innerRadiusKm * 1000)
                        .foregroundStyle(.clear)
                        .stroke(palette.amber.color.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
                Annotation("", coordinate: plan.origin.mapCoordinate) {
                    AirportTag(code: plan.origin.iata, city: plan.origin.city, isSelected: false)
                }
                ForEach(plan.destinations) { airport in
                    Annotation("", coordinate: airport.mapCoordinate) {
                        AirportTag(code: airport.iata, city: airport.city,
                                   minutes: minutes(to: airport), isSelected: airport.iata == plan.selectedDestinationIata)
                            .onTapGesture { model.plan.select(iata: airport.iata) }
                    }
                }
                if let destination = plan.selectedDestination {
                    MapPolyline(coordinates: route(from: plan.origin, to: destination))
                        .stroke(palette.accent1.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
            .mapControlVisibility(.hidden)

            Dock(showsSearch: $showsSearch)
                .padding(MRSpacing.l)
                .frame(maxWidth: 920)
        }
        .onAppear(perform: recenter)
        .onChange(of: plan.origin.iata) { recenter() }
        .onChange(of: plan.durationMinutes) { recenter() }
    }

    private func minutes(to airport: Airport) -> Int {
        FlightTiming.minutes(forKm: Geo.distanceKm(from: model.plan.origin.coordinate, to: airport.coordinate))
    }

    private func route(from a: Airport, to b: Airport) -> [CLLocationCoordinate2D] {
        (0...40).map { Geo.interpolate(from: a.coordinate, to: b.coordinate, fraction: Double($0) / 40).mapCoordinate }
    }

    private func recenter() {
        let plan = model.plan
        let radiusKm = plan.rangeRing?.outerRadiusKm ?? 1_500
        withAnimation(MRMotion.smooth) {
            camera = .camera(MapCamera(centerCoordinate: plan.origin.mapCoordinate,
                                       distance: max(250_000, radiusKm * 1000 * 4.2)))
        }
    }
}

private struct Dock: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Binding var showsSearch: Bool

    var body: some View {
        let plan = model.plan
        let palette = MRPalette.resolve(scheme)

        GlassPanel(padding: MRSpacing.m) {
            VStack(alignment: .leading, spacing: MRSpacing.m) {
                HStack(spacing: MRSpacing.s) {
                    OriginChip(showsSearch: $showsSearch)
                    Spacer()
                    Picker("Mode", selection: Binding(get: { plan.mode }, set: { model.plan.setMode($0) })) {
                        Text("Solo").tag(CompanionMode.solo)
                        Text("Together").tag(CompanionMode.together).disabled(true)
                    }
                    .pickerStyle(.segmented).frame(width: 180).labelsHidden()
                }

                DurationRuler()

                DestinationDock()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: MRSpacing.xs) {
                        ForEach(Scenario.defaults) { scenario in
                            ScenarioChip(name: scenario.name, symbol: scenario.symbol, colorHex: scenario.colorHex,
                                         isSelected: scenario.id == plan.scenarioID) {
                                model.plan.setScenario(id: scenario.id)
                            }
                        }
                    }
                }

                HStack(spacing: MRSpacing.s) {
                    TextField("What are you working on?", text: Binding(get: { plan.topic }, set: { model.plan.setTopic($0) }))
                        .textFieldStyle(.roundedBorder)
                    Button("Surprise me") { _ = model.plan.surpriseMe() }
                        .buttonStyle(MRButtonStyle(.secondary))
                    Button("Check in") { model.startFlight() }
                        .buttonStyle(MRButtonStyle(.primary))
                        .disabled(!plan.canConfirm)
                }
                .foregroundStyle(palette.text1.color)
            }
        }
    }
}

private struct OriginChip: View {
    @Environment(AppModel.self) private var model
    @Binding var showsSearch: Bool
    @State private var query = ""

    var body: some View {
        let plan = model.plan
        Button { showsSearch.toggle() } label: {
            Label("\(plan.origin.iata) · \(plan.origin.city)", systemImage: "airplane.departure")
                .mrText(.callout)
        }
        .buttonStyle(MRButtonStyle(.secondary))
        .keyboardShortcut("k", modifiers: .command)
        .accessibilityLabel("Departing from \(plan.origin.name). Change departure airport.")
        .popover(isPresented: $showsSearch, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: MRSpacing.xs) {
                TextField("Airport, city or code", text: $query).textFieldStyle(.roundedBorder)
                if query.isEmpty {
                    if model.plan.preferences.lastLandingIata != nil {
                        Button("Continue from last landing") {
                            _ = model.plan.continueFromLastLanding()
                            showsSearch = false
                        }
                    }
                    ForEach(plan.favoriteAirports) { row($0) }
                } else {
                    ForEach(plan.searchAirports(query, limit: 8)) { row($0) }
                }
                Divider()
                Button(plan.isFavoriteOrigin ? "Remove from favorites" : "Add \(plan.origin.iata) to favorites") {
                    model.plan.toggleFavoriteOrigin()
                }
            }
            .padding(MRSpacing.m).frame(width: 320)
        }
    }

    private func row(_ airport: Airport) -> some View {
        Button {
            model.plan.setOrigin(airport)
            query = ""
            showsSearch = false
        } label: {
            HStack {
                Text(airport.iata).mrText(.callout, .mono)
                Text(airport.city).lineLimit(1)
                Spacer()
                Text(airport.countryCode).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct DurationRuler: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let plan = model.plan
        let palette = MRPalette.resolve(scheme)
        VStack(alignment: .leading, spacing: MRSpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(plan.isFreeFlight ? "Free flight" : "\(plan.durationMinutes ?? 0) min")
                    .mrText(.title1, .mono).foregroundStyle(palette.text1.color)
                if let minutes = plan.durationMinutes {
                    Text(CabinClass(durationMinutes: minutes).label)
                        .mrText(.callout).foregroundStyle(palette.text2.color)
                }
                Spacer()
                ForEach(PlanState.quickChipMinutes, id: \.self) { minutes in
                    chip(minutes < 120 ? "\(minutes)" : "2h", selected: plan.durationMinutes == minutes) {
                        model.plan.applyQuickChip(minutes: minutes)
                    }
                }
                chip("∞", selected: plan.isFreeFlight) { model.plan.setFreeFlight() }
                    .accessibilityLabel("Free flight, no fixed end")
            }
            Slider(
                value: Binding(
                    get: { Double(plan.durationMinutes ?? PlanState.durationRange.upperBound) },
                    set: { model.plan.setDuration(minutes: Int($0)) }),
                in: Double(PlanState.durationRange.lowerBound)...Double(PlanState.durationRange.upperBound),
                step: Double(PlanState.detentMinutes)
            )
            .disabled(plan.isFreeFlight)
            .accessibilityLabel("Flight duration")
            .accessibilityValue(plan.isFreeFlight ? "Free flight" : "\(plan.durationMinutes ?? 0) minutes")
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(MRButtonStyle(selected ? .primary : .ghost))
    }
}

private struct DestinationDock: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let plan = model.plan
        let palette = MRPalette.resolve(scheme)
        if plan.isFreeFlight {
            Text("Free flights have no destination. Land when you are done.")
                .mrText(.body).foregroundStyle(palette.text2.color)
        } else if plan.destinations.isEmpty {
            Text("No airports at this flight time from \(plan.origin.city). Try a different length or departure.")
                .mrText(.body).foregroundStyle(palette.text2.color)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: MRSpacing.xs) {
                        ForEach(plan.destinations) { airport in
                            card(airport, selected: airport.iata == plan.selectedDestinationIata, palette: palette)
                                .id(airport.iata)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onChange(of: plan.selectedDestinationIata) { _, iata in
                    if let iata { withAnimation(MRMotion.snappy) { proxy.scrollTo(iata, anchor: .center) } }
                }
            }
        }
    }

    private func card(_ airport: Airport, selected: Bool, palette: MRPalette) -> some View {
        let minutes = FlightTiming.minutes(forKm: Geo.distanceKm(from: model.plan.origin.coordinate, to: airport.coordinate))
        return Button { model.plan.select(iata: airport.iata) } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(airport.iata).mrText(.headline, .condensed)
                    Text(airport.flag)
                }
                Text(airport.city).mrText(.callout).lineLimit(1)
                Text("\(minutes) min").mrText(.caption, .mono)
            }
            .frame(width: 130, alignment: .leading)
            .padding(MRSpacing.s)
            .foregroundStyle(selected ? palette.ink.color : palette.text1.color)
            .background(
                RoundedRectangle(cornerRadius: MRRadius.card, style: .continuous)
                    .fill(selected ? palette.paper.color : palette.bg2.color.opacity(0.6))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(airport.city), \(airport.iata), \(minutes) minutes")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

extension Airport {
    var mapCoordinate: CLLocationCoordinate2D { coordinate.mapCoordinate }

    var flag: String {
        countryCode.uppercased().unicodeScalars.compactMap { UnicodeScalar(127_397 + $0.value) }
            .map(String.init).joined()
    }
}

extension Coordinate {
    var mapCoordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
}

extension CabinClass {
    var label: String {
        switch self {
        case .economy: "Economy"
        case .premium: "Premium"
        case .business: "Business"
        case .first: "First"
        case .longHaul: "Long-haul"
        }
    }
}
