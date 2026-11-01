import MeridianPlan
import MeridianUI
import SwiftUI

/// Debug / design-reference routes of the ritual: ritual-seat, ritual-seat-together, ritual-printing, ritual-tear, ritual-gate.
/// Each draws the canvas artboard's state (S12, S12B, S13, S14A, S14B) with the canvas persona and LHR to CDG.
extension ScreenRegistry {
    static func registerRitualRoutes() {
        register("ritual-seat") { RitualDebugScreen(kind: .seat(together: false)).mrWindowChrome() }
        register("ritual-seat-together") { RitualDebugScreen(kind: .seat(together: true)).mrWindowChrome() }
        register("ritual-printing") { RitualDebugScreen(kind: .stage(RitualStill(t: 1300, annotate: true))).mrWindowChrome() }
        register("ritual-tear") { RitualDebugScreen(kind: .stage(RitualStill(t: 2400, tear: 0.46, grab: .right, annotate: true))).mrWindowChrome() }
        register("ritual-gate") { RitualDebugScreen(kind: .gate).mrWindowChrome() }
        // the live flow from the first step (Check in) on the canvas data
        register("ritual-live", setup: { m in m.planStage = .plan; m.plan.setScenario(id: "code"); m.plan.setTopic("Auth module refactor") }) {
            RitualLiveScreen().mrWindowChrome()
        }
    }
}

struct RitualDebugScreen: View {
    enum Kind { case seat(together: Bool), stage(RitualStill), gate }
    let kind: Kind
    @State private var seat = "1A"
    @State private var topic = "Auth module refactor"
    @State private var together = false

    var body: some View {
        let info = RitualFlightInfo.canvas
        ZStack(alignment: .topLeading) {
            switch kind {
            case .seat(let t):
                RitualBackdrop(kind: .seat)
                RitualCheckInView(info: info, seat: $seat, topic: $topic, together: $together, scenario: .code,
                                  zone: RitualZone.of(seat: seat), sidebarInset: 236, live: false)
                    .onAppear { if t { seat = "3C"; together = true } }
            case .stage(let still):
                RitualBackdrop(kind: .stage)
                RitualStageView(model: info.passModel(seat: "1A"), still: still, sidebarInset: 236)
            case .gate:
                RitualBackdrop(kind: .gate)
                RitualGateView(info: info, seat: "1A", topic: topic, staticCount: 3, sidebarInset: 236)
            }
            SidebarView(isRail: false, profileName: "Elif Kaya", km: 12022, ticketsBadge: { if case .gate = kind { "+1" } else { nil } }())
                .padding(8)
        }
        .coordinateSpace(name: "ritual")
    }
}

/// Runs the real ritual (`RitualFlowView`) from the seat step with the canvas persona.
struct RitualLiveScreen: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        Group {
            if let s = RitualCoordinator.shared.session { RitualFlowView(session: s, persona: ("Elif Kaya", 12022)) }
            else { Color.clear }
        }
        .onAppear { if RitualCoordinator.shared.session == nil { RitualCoordinator.shared.checkIn(model, quick: false) } }
    }
}
