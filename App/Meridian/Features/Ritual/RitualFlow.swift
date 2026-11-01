import AppKit
import MeridianMaps
import MeridianCore
import MeridianPlan
import MeridianUI
import Observation
import SwiftUI

/// The ritual (PRD §9.3, RIT-1...6): seat -> print -> tear -> gate -> flight.
///
/// Plan's Check in / Quick start call `RitualCoordinator.shared.checkIn(model, quick:)` (via `PlanActions.checkIn`). That either runs the
/// ritual or, when it is bypassed (RIT-6), starts the flight at once. Every path ends in `RitualCoordinator.startFlight`.
@MainActor @Observable
final class RitualCoordinator {
    static let shared = RitualCoordinator()
    private(set) var session: RitualSession?

    /// Check in (`quick: false`) or Quick start (`quick: true`) from the Plan screen.
    func checkIn(_ model: AppModel, quick: Bool) {
        guard session == nil, model.activeFlight == nil else { return }
        TakeoffImages.prewarm()
        let replay = quick && model.plan.preferences.lastRoute != nil
        if !replay && !model.plan.canConfirm { return }
        if RitualPolicy.skips(plan: model.plan, quick: quick) {
            Self.startFlight(model, quick: quick)
            return
        }
        session = RitualSession(model: model, quick: replay)
    }

    /// Ends the ritual without flying (Escape). Nothing has been recorded yet.
    func cancel() {
        session?.stage.stop()
        withAnimation(MRMotion.ease(MRMotion.d3)) { session = nil }
    }

    /// The ritual's hand-over to the flight: the one place that starts it. The take-off sequence (Cruise) hooks in here.
    func board() {
        guard let s = session else { return }
        s.commitPlan()
        Self.startFlight(s.model, quick: s.quick)
        session = nil
    }

    /// Starts the flight for the plan (or repeats the last route for a Quick start). Also the path when the ritual is bypassed.
    static func startFlight(_ model: AppModel, quick: Bool) {
        if quick, model.plan.preferences.lastRoute != nil { model.quickStart() } else { model.startFlight() }
    }
}

/// State of one run of the ritual.
@MainActor @Observable
final class RitualSession: Identifiable {
    enum Phase { case seat, print, gate }

    let id = UUID()
    let model: AppModel
    /// Quick start: repeats the last route; the seat zone then does not change the scenario.
    let quick: Bool
    let info: RitualFlightInfo
    var phase: Phase = .seat
    var seat: String
    var topic: String
    var together: Bool
    var scenario: PaperScenario
    var zone: RitualZone
    let stage = RitualStageController()

    init(model: AppModel, quick: Bool) {
        self.model = model
        self.quick = quick
        info = RitualFlightInfo.make(plan: model.plan, quick: quick)
        seat = RitualPolicy.defaultSeat
        topic = info.topic
        together = model.plan.mode == .together
        scenario = info.scenario
        zone = RitualZone.of(seat: RitualPolicy.defaultSeat)
        stage.onFinished = { [weak self] in self?.phase = .gate }
    }

    /// Choosing a zone chooses its scenario (C06). Only when the user picks, and not for a Quick start replay.
    func pick(seat code: String, zone z: RitualZone) {
        seat = code
        pick(zone: z)
    }

    func pick(zone z: RitualZone) {
        guard z != zone else { return }
        zone = z
        if !quick { scenario = z.scenario }
    }

    /// Writes the choices into the plan before the flight is made.
    func commitPlan() {
        model.plan.setTopic(topic)
        model.plan.setMode(together ? .together : .solo)
        if !quick { model.plan.setScenario(id: scenario.rawValue) }
    }

    func checkIn() {
        MRSound.shared.play(.click)
        commitPlan()
        withAnimation(MRMotion.ease(MRMotion.d2)) { phase = .print }
    }
}

// MARK: - Host and flow

/// Overlay of `AppShell`: draws the ritual over the Fly section while a session runs.
struct RitualHost: View {
    var coordinator = RitualCoordinator.shared
    var body: some View {
        if let s = coordinator.session {
            RitualFlowView(session: s)
                .id(s.id)
                .transition(.opacity)
        }
    }
}

struct RitualFlowView: View {
    @Bindable var session: RitualSession
    var persona: (name: String, km: Double)?
    @Environment(AppModel.self) private var model
    @State private var ticketsFrame: CGRect = .zero

    var body: some View {
        GeometryReader { geo in
            let rail = geo.size.width < 1000
            let inset: CGFloat = rail ? 72 : 236
            ZStack(alignment: .topLeading) {
                RitualBackdrop(kind: session.phase == .seat ? .seat : (session.phase == .gate ? .gate : .stage))
                Group {
                    switch session.phase {
                    case .seat:
                        RitualCheckInView(info: session.info, seat: $session.seat, topic: $session.topic, together: $session.together,
                                          scenario: session.scenario, zone: session.zone, sidebarInset: inset,
                                          onSeat: { code, z in session.pick(seat: code, zone: z); MRSound.shared.play(.click); PaperHaptics.tick() },
                                          onZone: { z in session.pick(zone: z) },
                                          onCheckIn: { session.checkIn() },
                                          onQuickStart: { RitualCoordinator.shared.board() },
                                          onCancel: { RitualCoordinator.shared.cancel() })
                    case .print:
                        RitualStageView(model: session.info.passModel(seat: session.seat, topic: session.topic, scenario: session.scenario),
                                        controller: session.stage, sidebarInset: inset,
                                        ticketsIcon: ticketsFrame == .zero ? nil : CGPoint(x: ticketsFrame.minX + 19, y: ticketsFrame.midY),
                                        onCancel: { RitualCoordinator.shared.cancel() })
                    case .gate:
                        RitualGateView(info: session.info, seat: session.seat, topic: session.topic, staticCount: nil, sidebarInset: inset,
                                       blockingChip: RitualPolicy.blockingChip, onBoard: { RitualCoordinator.shared.board() })
                    }
                }
                .transition(.opacity)
                SidebarView(isRail: rail, profileName: persona?.name ?? (NSFullUserName().isEmpty ? "You" : NSFullUserName()), km: persona?.km,
                            ticketsBadge: session.stage.badge ? "+1" : nil)
                    .padding(8)
                    .allowsHitTesting(false)
            }
            .coordinateSpace(name: "ritual")
            .onPreferenceChange(SidebarTicketsFrameKey.self) { ticketsFrame = $0 }
            .animation(MRMotion.ease(MRMotion.d3), value: session.phase)
        }
        .background(MRPalette.resolve(.dark).bg0.color.opacity(0))
    }
}

// MARK: - Backdrop

/// The dimmed, blurred Europe map under the ritual (`MapLayer` terra, blur 14-18, a dark scrim).
struct RitualBackdrop: View {
    enum Kind { case seat, stage, gate }
    let kind: Kind
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let seat = kind == .seat
        ZStack {
            (kind == .gate ? Color(hex: "#06080D") : MRPalette.resolve(scheme).bg0.color)
            EuropeMapView(style: .terra, center: Coordinate(latitude: seat ? 49.8 : 49.6, longitude: seat ? 2.2 : 2.6), zoom: seat ? 1.4 : 1.1,
                          showsLabels: false)
                .saturation(seat ? 0.8 : 0.9)
                .colorMultiply(Color(white: seat ? 0.85 : 1))
                .blur(radius: seat ? 18 : 14)
                .scaleEffect(seat ? 1.08 : 1.06)
            Color(red: seat ? 6 / 255 : 5 / 255, green: seat ? 8 / 255 : 7 / 255, blue: seat ? 13 / 255 : 13 / 255)
                .opacity(seat ? 0.55 : (kind == .gate ? 0.34 : 0.30))
        }
        .clipped()
        .accessibilityHidden(true)
        .animation(MRMotion.ease(MRMotion.d4), value: kind)
    }
}
