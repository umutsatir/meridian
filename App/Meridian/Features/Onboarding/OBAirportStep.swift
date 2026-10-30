import MeridianCore
import MeridianMaps
import MeridianUI
import SwiftUI

/// S02: home airport, detected from the Mac (time zone) with search (ONB-2).
struct OBAirportStep: View {
    @Bindable var model: OnboardingModel
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var searchFocused: Bool
    @State private var pulse = false

    var body: some View {
        let p = MRPalette.resolve(scheme)
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                OT("Where do you\ntake off?").obType(.serif, 48, 500, lh: 52, tracking: -0.02)
                    .foregroundStyle(p.text1.color)
                OT("Your home airport is where every flight starts by default.")
                    .obType(.ui, 17, 400, lh: 26).foregroundStyle(p.text2.color)
                    .padding(.top, 12)
            }
            .frame(width: 520, alignment: .leading)
            .obAt(96, 96)

            detectedCard(p).obAt(96, 288)
            searchColumn(p).obAt(648, 96)
        }
        .frame(width: obCanvasWidth, height: obCanvasHeight, alignment: .topLeading)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    // MARK: Left card

    private func detectedCard(_ p: MRPalette) -> some View {
        let home = model.homeAirport
        let city = home?.city ?? model.detected.city
        return ZStack(alignment: .topLeading) {
            EuropeMapView(style: .terra, center: Coordinate(latitude: 51.5, longitude: -0.45), zoom: 3.4,
                          size: CGSize(width: 480, height: 176), showsLabels: true)
                .frame(width: 480, height: 176).clipped()
            LinearGradient(stops: [.init(color: .clear, location: 0.55), .init(color: p.glassTint.color, location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .frame(width: 480, height: 176)
            ZStack {
                Circle().fill(obRGBA(255, 181, 71, 0.22)).frame(width: 60, height: 60)
                    .scaleEffect(pulse ? 0.8 : 1).opacity(pulse ? 0.4 : 1)
                Circle().fill(MRColorToken.hex("#06080D")).frame(width: 16, height: 16)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 3).frame(width: 22, height: 22))
                    .background(Circle().fill(.white.opacity(0.14)).frame(width: 34, height: 34))
                    .shadow(color: .black.opacity(0.5), radius: 6, y: 4)
            }
            .frame(width: 60, height: 60).obAt(210, 58)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    MRIcon(.pin, size: 12)
                    OT("Detected from your Mac")
                }
                .mrText(.eyebrow).foregroundStyle(p.text2.color)
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(city).obType(.serif, 36, 500, lh: 40, tracking: -0.015).foregroundStyle(p.text1.color)
                    OBIata(code: home?.iata ?? model.home)
                }
                .padding(.top, 8)
                HStack(spacing: 0) {
                    OT("We think you're in \(model.detected.city). ")
                    Button { searchFocused = true } label: { OT("Change?").fontWeight(.semibold).foregroundStyle(p.accent1.color) }
                        .buttonStyle(.plain)
                }
                .mrText(.callout).foregroundStyle(p.text2.color)
                .padding(.top, 4)
            }
            .frame(width: 432, alignment: .leading)
            .obAt(24, 190)

            HStack(spacing: 8) {
                MRIcon(.info, size: 14)
                OT("You can change this anytime.")
            }
            .mrText(.callout).foregroundStyle(p.text3.color)
            .obAt(24, 340 - 20 - 18)
        }
        .frame(width: 480, height: 340, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .mrGlass(cornerRadius: 28, elevation: .e3)
        .accessibilityElement(children: .contain)
    }

    // MARK: Right column

    private func searchColumn(_ p: MRPalette) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                MRIcon(.search, size: 18).foregroundStyle(p.text3.color)
                TextField("", text: $model.query, prompt: Text("Search airports, cities, countries", tableName: "Onboarding").foregroundStyle(p.text3.color))
                    .textFieldStyle(.plain)
                    .font(.mr(.ui, size: 14, weight: 400))
                    .focused($searchFocused)
                    .accessibilityLabel(Text("Search airports", tableName: "Onboarding"))
                MRKbd("⌘F")
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(searchFocused ? p.fill2.color : p.fill1.color, in: shape)
            .overlay(shape.strokeBorder(p.strokeHair.color, lineWidth: 1))
            .mrFocusRing(searchFocused, cornerRadius: 14, color: p.accent1.color)
            .background(Button("") { searchFocused = true }.keyboardShortcut("f").opacity(0).allowsHitTesting(false))

            OT(model.query.trimmingCharacters(in: .whitespaces).isEmpty ? "Near you" : "Results")
                .mrText(.eyebrow).foregroundStyle(p.text2.color)
                .padding(.leading, 14).padding(.top, 22).padding(.bottom, 8)

            ForEach(model.rows()) { airport in
                AirportRow(airport: airport, city: model.detected.airports.contains(airport.iata) ? model.detected.city : airport.city,
                           selected: airport.iata == model.home,
                           distance: AirportDetection.distanceLabel(from: model.detected.center, to: airport)) {
                    model.home = airport.iata
                }
            }
            if model.rows().isEmpty {
                OT("No airports found.").mrText(.callout).foregroundStyle(p.text3.color).padding(.leading, 14)
            }
        }
        .frame(width: 536, alignment: .leading)
    }
}

private struct AirportRow: View {
    let airport: Airport
    let city: String
    let selected: Bool
    private var shortName: String { airport.name.replacingOccurrences(of: " Airport", with: "") }
    let distance: String
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isFocused) private var focused
    @State private var hovered = false

    var body: some View {
        let p = MRPalette.resolve(scheme)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        Button(action: action) {
            HStack(spacing: 14) {
                OBIata(code: airport.iata)
                VStack(alignment: .leading, spacing: 0) {
                    Text(city).obType(.ui, 15, 600, lh: 18).foregroundStyle(p.text1.color)
                    Text("\(shortName) ·\(airport.countryName() ?? airport.countryCode)")
                        .mrText(.callout).foregroundStyle(p.text2.color).lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(distance).obType(.mono, 12, 500, lh: 12).foregroundStyle(p.text3.color)
                if selected { MRIcon(.check, size: 18).foregroundStyle(p.accent1.color) }
            }
            .padding(.horizontal, 14)
            .frame(height: 58)
            .background { rowBackground(p, shape: shape) }
            .contentShape(shape)
            .mrFocusRing(focused, cornerRadius: 16, color: p.accent1.color)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(MRMotion.ease(MRMotion.d2), value: hovered)
        .accessibilityLabel("\(airport.city), \(airport.name), \(distance)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    @ViewBuilder
    private func rowBackground(_ p: MRPalette, shape: RoundedRectangle) -> some View {
        if selected {
            if p.isDark {
                shape.fill(LinearGradient(colors: [obRGBA(106, 183, 255, 0.18), obRGBA(139, 243, 216, 0.07)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(shape.strokeBorder(obRGBA(106, 183, 255, 0.34), lineWidth: 1))
            } else {
                shape.fill(obRGBA(30, 107, 255, 0.08)).overlay(shape.strokeBorder(obRGBA(30, 107, 255, 0.3), lineWidth: 1))
            }
        } else if hovered {
            shape.fill(p.fill1.color)
        }
    }
}
