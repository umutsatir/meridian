import MeridianCore
import MeridianMaps
import MeridianUI
import SwiftUI

/// The Fly section while a flight runs or just landed: take-off, cruise, landing summary, otherwise the Plan screen.
struct FlySectionView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let flight = model.activeFlight {
            if model.takeoffPlaying, let frame = CruiseFrame(flight: flight, index: model.index, now: .now) {
                TakeoffView(frame: frame) { model.takeoffPlaying = false }
            } else {
                LiveCruiseScreen()
            }
        } else if model.landingPresented, let info = LandingInfo(model: model) {
            LandingScreen(info: info, onFlyAgain: { model.flyAgainFromLanding() }, onWallet: { notes in
                // the wallet flight (S23) is built elsewhere: keep the notes on the ticket and close the summary
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { model.completeLanding(notes: notes) }
            })
        } else {
            PlanScreen()
        }
    }
}

/// Artboard host: a `CruiseScreen` with a preset `CruiseUI`.
private struct CruiseDemo: View {
    let frame: CruiseFrame
    @State private var ui: CruiseUI
    var sheetHold: Double?
    var toast = false

    init(p: Double, view: CruiseView = .map, style: MapStyle = .terra, policy: PausePolicy = .normal, sheetHold: Double? = nil, toast: Bool = false,
         configure: (CruiseUI) -> Void = { _ in }) {
        frame = .demo(p: p, policy: policy)
        let u = CruiseUI(view: view, style: style)
        configure(u)
        _ui = State(initialValue: u)
        self.sheetHold = sheetHold
        self.toast = toast
    }

    var body: some View { CruiseScreen(frame: frame, ui: ui, sheetHold: sheetHold, showsToast: toast).mrWindowChrome() }
}

private struct MealDemo: View {
    let mode: MealBreakView.Mode
    var tray = "full"
    var elapsed = 372
    var kind: MealBreakView.Kind = .timed
    var body: some View {
        MealBreakView(frame: .demo(p: 0.45), initialMode: mode, remain: 272, elapsed: elapsed, length: 5, kind: kind, tray: tray, live: false)
            .mrWindowChrome()
    }
}

extension ScreenRegistry {
    /// Cruise, take-off, window, dashboard, pause / land early, meal, descent and landing (S15 to S22).
    static func registerCruiseRoutes() {
        register("takeoff-roll") { TakeoffView(frame: .demo(p: 0.03), frozenT: 1800).mrWindowChrome() }
        register("takeoff-rotate") { TakeoffView(frame: .demo(p: 0.03), frozenT: 3900).mrWindowChrome() }
        register("takeoff-reduced") { TakeoffView(frame: .demo(p: 0.03), frozenT: 700, reduce: true).mrWindowChrome() }

        register("cruise-terra") { CruiseDemo(p: 0.45) }
        register("cruise-mono") { CruiseDemo(p: 0.45, style: .mono) }
        register("cruise-standard") { CruiseDemo(p: 0.45, style: .standard) }
        register("cruise-satellite") { CruiseDemo(p: 0.45, style: .satellite) }
        register("cruise-controls") { CruiseDemo(p: 0.45) { $0.capLabels = true } }
        register("cruise-style-menu") { CruiseDemo(p: 0.45, style: .standard) { $0.menu = .style } }
        register("cruise-free-camera") { CruiseDemo(p: 0.62) { $0.follow = false; $0.capLabels = true } }
        register("cruise-light") { CruiseDemo(p: 0.45, style: .mono) }
        register("cruise-large") { CruiseDemo(p: 0.45) }

        register("window") { CruiseDemo(p: 0.45, view: .window) { $0.scene = "day" } }
        register("window-scene-menu") { CruiseDemo(p: 0.45, view: .window) { $0.scene = "sunset"; $0.menu = .scene } }
        register("window-light") { CruiseDemo(p: 0.45, view: .window) { $0.scene = "blue" } }
        register("dashboard") { CruiseDemo(p: 0.45, view: .dash) }
        register("pause-land-early") { CruiseDemo(p: 0.74, sheetHold: 0.62) { $0.policySheet = true } }

        register("meal-break") { MealDemo(mode: .timed) }
        register("meal-choose") { MealDemo(mode: .choose) }
        register("meal-open") { MealDemo(mode: .open, tray: "half", kind: .open) }
        register("meal-over") { MealDemo(mode: .over, tray: "clear", elapsed: 40) }

        register("descent") { CruiseDemo(p: 0.965, toast: true) }
        register("landing") {
            ZStack(alignment: .topLeading) {
                LandingScreen(info: .demo(), animates: true)
                SidebarView(isRail: false, profileName: "Elif Kaya", km: 12370).padding(8)
            }
            .mrWindowChrome()
        }
    }
}
