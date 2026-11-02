import MeridianCore
import MeridianCruise
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
                // the ticket has flown into the wallet (S23): keep the notes on it and close the summary
                model.completeLanding(notes: notes)
            }, animates: true)
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
        // `--at-progress 0.31` pins the plane (follow-camera checks compare two instants of the same route)
        let args = ProcessInfo.processInfo.arguments
        let at = args.firstIndex(of: "--at-progress").flatMap { $0 + 1 < args.count ? Double(args[$0 + 1]) : nil }
        frame = .demo(p: at ?? p, policy: policy)
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
        register("takeoff-roll") { TakeoffView(frame: .demo(p: 0.03), frozenT: 1800, dusk: false).mrWindowChrome() }
        register("takeoff-rotate") { TakeoffView(frame: .demo(p: 0.03), frozenT: 3900, dusk: false).mrWindowChrome() }
        register("takeoff-reduced") { TakeoffView(frame: .demo(p: 0.03), frozenT: 700, reduce: true, dusk: false).mrWindowChrome() }

        register("cruise-terra") { CruiseDemo(p: 0.45) }
        register("cruise-mono") { CruiseDemo(p: 0.45, style: .mono) }
        register("cruise-standard") { CruiseDemo(p: 0.45, style: .standard) }
        register("cruise-satellite") { CruiseDemo(p: 0.45, style: .satellite) }
        register("cruise-controls") { CruiseDemo(p: 0.45) { $0.capLabels = true } }
        register("cruise-style-menu") { CruiseDemo(p: 0.45, style: .standard) { $0.menu = .style } }
        register("cruise-free-camera") { CruiseDemo(p: 0.62) { $0.follow = false; $0.capLabels = true } }
        register("cruise-light") { CruiseDemo(p: 0.45, style: .mono) }
        register("cruise-large") { CruiseDemo(p: 0.45) }

        // Follow camera (Phase E): north up, heading up, street zoom, free camera with the Recenter button
        register("cruise-follow-north") { CruiseDemo(p: 0.45) }
        register("cruise-follow-heading") { CruiseDemo(p: 0.45) { $0.camera.orientation = .headingUp } }
        register("cruise-follow-zoomed") { CruiseDemo(p: 0.45) { $0.camera.scale = 3000 } }
        register("cruise-follow-zoomed-heading") { CruiseDemo(p: 0.45) { $0.camera.scale = 3000; $0.camera.orientation = .headingUp } }
        register("cruise-follow-recenter") { CruiseDemo(p: 0.45) { $0.camera.following = false; $0.camera.freeCenterP = EuropeProjection.xy(Coordinate(latitude: 50.9, longitude: 0.6)); $0.camera.scale = 5 } }
        register("cruise-follow-dbg") { CruiseDemo(p: 0.45) { u in
            let a = ProcessInfo.processInfo.arguments
            if let i = a.firstIndex(of: "--scale"), let v = Double(a[i + 1]) { u.camera.scale = v }
            u.camera.orientation = .headingUp } }
        // the live flight with a pinned zoom / orientation (`--follow-scale 3000 --follow-heading`), for CPU and motion checks
        register("cruise-follow-live", setup: { $0.startFlight() }) {
            LiveCruiseScreen { u in
                let a = ProcessInfo.processInfo.arguments
                if let i = a.firstIndex(of: "--follow-scale"), i + 1 < a.count, let v = Double(a[i + 1]) { u.camera.scale = v }
                if a.contains("--follow-heading") { u.camera.orientation = .headingUp }
            }.mrWindowChrome()
        }
        register("cruise-follow-world") { CruiseDemo(p: 0.45) { $0.camera.scale = 0.3 } }

        register("window") { CruiseDemo(p: 0.45, view: .window) { $0.scene = "day" } }
        register("window-scene-menu") { CruiseDemo(p: 0.45, view: .window) { $0.scene = "sunset"; $0.menu = .scene } }
        register("window-light") { CruiseDemo(p: 0.45, view: .window) { $0.scene = "blue" } }
        // Live window (real satellite ground, sun and weather): frozen position / time, `--at lat,lon,ISO8601 --heading --alt --weather cover,mm,code` override
        func live(_ name: String, lat: Double, lon: Double, at: String, heading: Double = 90, alt: Double = 30_000, weather: WeatherCondition? = nil) {
            register(name, setup: { _ in
                WindowFixture.active = .make(lat: lat, lon: lon, at: at, heading: heading, altitudeFt: alt, weather: weather)
            }) { CruiseDemo(p: 0.45, view: .window) { $0.sceneAuto = true; $0.offersAutoScene = true } }
        }
        live("window-live-day", lat: 47.2, lon: 8.4, at: "2026-06-21T10:30:00Z", heading: 70, alt: 24_000, weather: .init(cloudCover: 30, precipitationMM: 0, weatherCode: 2, windKmh: 10))
        live("window-live-real", lat: 47.2, lon: 8.4, at: "2026-06-21T10:30:00Z", heading: 70, alt: 24_000)
        live("window-live-sunset", lat: 47.2, lon: 8.4, at: "2026-06-21T19:15:00Z", heading: 340, alt: 24_000, weather: .init(cloudCover: 25, precipitationMM: 0, weatherCode: 1, windKmh: 10))
        live("window-live-night", lat: 49.02, lon: 2.68, at: "2026-06-21T22:40:00Z", heading: 0, alt: 18_000, weather: .clear)
        live("window-live-rain", lat: 50.6, lon: 7.2, at: "2026-06-21T10:30:00Z", heading: 70, alt: 22_000, weather: .init(cloudCover: 95, precipitationMM: 2.4, weatherCode: 63, windKmh: 28))
        live("window-live-fog", lat: 47.2, lon: 8.4, at: "2026-06-21T07:30:00Z", heading: 70, alt: 12_000, weather: .init(cloudCover: 100, precipitationMM: 0, weatherCode: 45, windKmh: 4))
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
                SidebarView(isRail: false, profileName: "Elif Kaya", km: 12022).padding(8)
            }
            .mrWindowChrome()
        }
        // S23: the ticket on its way into the wallet (canvas `fly: .72`)
        register("wallet-in") {
            let e = 0.72 * 0.72 * (3 - 2 * 0.72)
            ZStack(alignment: .topLeading) {
                LandingScreen(info: .demo(), animates: true, fixedFly: 0.72)
                SidebarView(isRail: false, profileName: "Elif Kaya", km: 12022 + Double((348 * e).rounded())).padding(8)
            }
            .environment(\.shellTicketsFrame, CGRect(x: 19, y: 221, width: 188, height: 38))
            .coordinateSpace(name: "ritual")
            .mrWindowChrome()
        }
    }
}
