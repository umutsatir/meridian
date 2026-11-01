import MeridianCore
import MeridianMaps
import MeridianPlan
import MeridianUI
import SwiftUI

/// The Fly section before a flight: Home (globe) or Plan (map), with the origin popover, the ⌘K palette and its toast.
/// The debug parameters let the screenshot harness draw the canvas artboards' states.
struct PlanScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var hour: Int?
    var initialMapStyle: MapStyle = .terra
    var initialReveal: String?
    var initialSelection = 0

    @State private var popOpen = false
    @State private var mapStyle: MapStyle
    @State private var toast: String?

    init(hour: Int? = nil, mapStyle: MapStyle = .terra, initialReveal: String? = nil, initialSelection: Int = 0) {
        self.hour = hour; self.initialMapStyle = mapStyle; self.initialReveal = initialReveal; self.initialSelection = initialSelection
        _mapStyle = State(initialValue: mapStyle)
    }

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            ZStack(alignment: .topLeading) {
                Group {
                    switch model.planStage {
                    case .home: PlanHomeView(popOpen: $popOpen, hour: hour)
                    case .plan: PlanMapView(popOpen: $popOpen, mapStyle: $mapStyle, onCheckIn: PlanActions.checkIn(model))
                    }
                }
                .modifier(BackdropDim(active: model.searchOpen))

                if popOpen {
                    Color.black.opacity(0.001).onTapGesture { popOpen = false }
                    OriginPopover(isOpen: $popOpen)
                        .offset(x: model.planStage == .home ? 28 : 74, y: model.planStage == .home ? 140 : 70)
                        .zIndex(60)
                }
                if model.searchOpen {
                    Color(red: 5 / 255, green: 7 / 255, blue: 13 / 255).opacity(0.42)
                        .onTapGesture { model.searchOpen = false }
                    SearchPalette(width: W, initialReveal: initialReveal, initialSelection: initialSelection,
                                  onChoose: { choose($0) }, close: { model.searchOpen = false })
                        .offset(x: (W - 640) / 2, y: 120)
                        .zIndex(80)
                }
                if let toast {
                    MRToast("Destination set to \(toast)", message: "Press Check in to print your boarding pass.")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom).padding(.bottom, 36)
                        .transition(.move(edge: .bottom).combined(with: .opacity)).zIndex(90)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .onChange(of: model.planStage) { popOpen = false }
    }

    /// Destination picked in the palette: fit the ruler so the airport is inside the ring, select it, go to Plan.
    private func choose(_ airport: Airport) {
        model.searchOpen = false
        model.planStage = .plan
        let mn = PlanState.canvasMinutes(forKm: PlanKit.km(model.plan.origin, airport))
        var m = PlanState.snap(mn)
        for _ in 0..<8 {
            model.plan.setDuration(minutes: m)
            if model.plan.destinations.contains(where: { $0.iata == airport.iata }) { model.plan.select(iata: airport.iata); break }
            m += PlanState.detentMinutes
        }
        withAnimation(MRMotion.smooth) { toast = airport.city }
        Task {
            try? await Task.sleep(for: .seconds(2.6))
            withAnimation(MRMotion.smooth) { toast = nil }
        }
    }
}

/// The single call site of "Check in" / "Quick start". It starts the ritual (Features/Ritual: seat, printing, tear, gate), which
/// is skipped when "Quick start checks in automatically" is on or the ritual is turned off (RIT-6).
enum PlanActions {
    @MainActor static func checkIn(_ model: AppModel) -> (Bool) -> Void {
        { quick in RitualCoordinator.shared.checkIn(model, quick: quick) }
    }
}

/// The canvas dims and blurs the screen behind the palette (`blur(6px) brightness(.7)` plus the 4 px scrim blur).
private struct BackdropDim: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        if active { content.colorMultiply(Color(white: 0.7)).blur(radius: 7.2) } else { content }
    }
}
