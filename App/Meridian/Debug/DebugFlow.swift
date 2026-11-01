#if DEBUG
import AppKit
import MeridianCore
import MeridianData
import MeridianPlan
import MeridianUI
import SwiftData
import SwiftUI

/// `--screen live-flow --delay 70 --screenshot flow-final.png`: drives the real app end to end on an in-memory store and
/// writes one PNG per stage (`flow-NN-*.png`, see `Scripts/flow-shot.sh`):
/// Plan, Check in, ritual (print, tear, gate), take-off, cruise, relaunch (FlightStore resume), landing, Add to wallet,
/// then Cards, Passport, Stats, Tickets.
///
/// Honest limits: the tear is the "Tear" button path of `TicketTearModel` (`tearWithButton`, the same finish a drag past 72 %
/// takes), not a pointer drag; time is accelerated by calling `AppModel.tick(at:)` with a later clock (the real clock is not sped up);
/// the relaunch is a second `AppModel` on the same container, not a process restart.
@MainActor @Observable
final class DebugFlowDriver {
    var model: AppModel
    @ObservationIgnored let container: ModelContainer
    @ObservationIgnored private var started = false

    init() {
        let c = (try? MeridianSchema.container()) ?? { fatalError("in-memory container") }()
        container = c
        model = AppModel(container: c, resumeOnLaunch: false)
    }

    private func wait(_ s: Double) async { try? await Task.sleep(for: .milliseconds(Int(s * 1000))) }
    private func snap(_ n: String) { DebugSnap.save("flow-\(n)") }

    func run() {
        guard !started else { return }
        started = true
        Task { @MainActor in await script() }
    }

    private func script() async {
        await wait(1.5)
        // 1. Plan
        model.hasOnboarded = true
        model.section = .fly
        model.planStage = .plan
        model.plan.dismissRulerCoachMark()
        _ = model.plan.setOrigin(iata: "LHR")
        model.plan.select(iata: "CDG")
        model.plan.setScenario(id: "code")
        model.plan.setTopic("Auth module refactor")
        await wait(2.5); snap("01-plan")
        // 2. Check in -> seat
        RitualCoordinator.shared.checkIn(model, quick: false)
        await wait(2.5); snap("02-seat")
        guard let s = RitualCoordinator.shared.session else { snap("02-FAILED-no-session"); return }
        // 3. print
        s.checkIn()
        await wait(1.4); snap("03-print-mid")
        await wait(2.6); snap("04-print-ready")
        // 4. tear (button path, simulated)
        s.stage.tearNow()
        await wait(0.45); snap("05-tearing")
        await wait(1.0); snap("06-stub-flying")
        await wait(3.0); snap("07-gate")
        // 5. board -> take-off sequence
        RitualCoordinator.shared.board()
        for i in 0..<8 {
            FileHandle.standardError.write(Data("\(Date().timeIntervalSinceReferenceDate) board+\(Double(i) * 0.25)s takeoff=\(model.takeoffPlaying) active=\(model.activeFlight != nil)\n".utf8))
            await wait(0.25)
        }
        snap("08-takeoff-roll")
        await wait(2.6); snap("09-takeoff-rotate")
        await wait(2.8); snap("10-cruise")
        // 6. relaunch while flying: a new AppModel on the same store resumes the active flight
        let resumed = AppModel(container: container, resumeOnLaunch: true)
        resumed.section = .fly
        model = resumed
        await wait(3.0); snap("11-resumed")
        // 7. landing with accelerated time
        let flightMin: Double = (model.activeFlight?.durationSec ?? 1800) / 60
        model.tick(at: .now.addingTimeInterval(flightMin * 60 + 5))
        await wait(1.2); snap("12-landing-early")
        await wait(2.8); snap("13-landing")
        // 8. Add to wallet
        model.landingAddRequests += 1
        await wait(0.5); snap("14-wallet-fly-mid")
        await wait(0.6); snap("15-wallet-fly-end")
        await wait(2.6); snap("16-after-wallet")
        // 9. the collections show the data
        model.section = .cards; await wait(2.0); snap("17-cards")
        model.section = .passport; await wait(2.5); snap("18-passport")
        model.section = .stats; await wait(2.5); snap("19-stats")
        model.section = .wallet; await wait(2.5); snap("20-tickets")
        // 10. Quick start (no ritual) plays the take-off too
        model.section = .fly; model.planStage = .plan
        await wait(1.0)
        RitualCoordinator.shared.checkIn(model, quick: true)
        await wait(2.0); snap("21-quick-or-ritual")
        if let q = RitualCoordinator.shared.session { q.checkIn(); RitualCoordinator.shared.cancel() }
        RitualCoordinator.startFlight(model, quick: true)
        await wait(2.0); snap("22-quick-takeoff")
        let summary = "active=\(model.activeFlight != nil) takeoff=\(model.takeoffPlaying) flights=\(model.walletFlights.count) km=\(Int(model.totalKm)) stamps=\(model.stamps) tiers=\(model.unlockedTiers.count)\n"
        FileHandle.standardError.write(Data(summary.utf8))
        try? summary.write(to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("flow-summary.txt"), atomically: true, encoding: .utf8)
    }
}

struct DebugFlowScreen: View {
    @State private var driver = DebugFlowDriver()
    var body: some View {
        AppShell()
            .environment(driver.model)
            .id(ObjectIdentifier(driver.model))
            .onAppear { driver.run() }
    }
}

extension ScreenRegistry {
    static func registerDebugFlow() {
        register("live-flow") { DebugFlowScreen() }
    }
}
#endif
