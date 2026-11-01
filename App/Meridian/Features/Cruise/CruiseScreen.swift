import MeridianCore
import MeridianCruise
import MeridianMaps
import MeridianPlan
import MeridianUI
import SwiftUI

/// The cruise screen of `Flight.dc.html`: map, window or dashboard view, the controls and the overlays, drawn for a
/// `CruiseFrame`. `LiveCruiseScreen` feeds it from the running flight; the artboards feed it numbers.
struct CruiseScreen: View {
    let frame: CruiseFrame
    @Bindable var ui: CruiseUI
    var actions = CruiseActions()
    /// Artboard S19: the fraction of the hold ring that is drawn.
    var sheetHold: Double?
    /// Artboard S21 and the live T-5 alert.
    var showsToast = false
    var resumed: (title: String, message: String)?
    var showsPausedBar: Bool?

    @Environment(\.colorScheme) private var scheme
    @FocusState private var keyFocus: Bool

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let p = MRPalette.resolve(scheme)
            ZStack(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                base(size: size, p: p)

                // top left controls
                CruiseTopLeft(frame: frame, ui: ui, actions: actions)

                switch ui.view {
                case .map:
                    CruiseMapControls(frame: frame, ui: ui, size: size, onWindow: { ui.view = .window; ui.menu = nil })
                        .zIndex(30)
                case .window:
                    CruiseWindowControls(frame: frame, ui: ui, onMap: { ui.view = .map; ui.menu = nil })
                        .zIndex(30)
                case .dash:
                    EmptyView()
                }

                if ui.view != .dash {
                    let inkWin = ui.view == .window ? Color(RGB(hex: "#F3F5FA")) : nil
                    let amber = frame.isAmber ? p.amber.color : nil
                    CruiseReadout(key: frame.isAmber ? "Last minute" : (frame.isFree ? "Time elapsed" : "Time remaining"),
                                  parts: frame.isFree ? Self.elapsedParts(frame.elapsedSec) : frame.remainingParts, ink: amber ?? inkWin)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(.leading, 28).padding(.bottom, 32)
                    CruiseReadout(key: "Distance remaining", parts: [(CruiseFrame.km(frame.distanceRemainingKm), "km")], trailing: true, ink: inkWin)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(.trailing, 28).padding(.bottom, 32)
                }

                if (showsPausedBar ?? frame.paused) && !ui.policySheet {
                    CruiseHoldBar(frame: frame, ui: ui, actions: actions)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 26)
                        .zIndex(30)
                }

                if showsToast || ui.toastVisible {
                    CruiseLandingToast()
                        .position(x: (size.width / 2 + 40).rounded(), y: 18 + 35)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(80)
                }
                if let resumed {
                    CruiseResumedBanner(title: resumed.title, message: resumed.message)
                        .position(x: size.width / 2, y: 18 + 31)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(80)
                }
                }
                .blur(radius: ui.policySheet ? 8 : 0)
                if ui.policySheet {
                    CruisePolicySheet(frame: frame, ui: ui, actions: actions, fixedHold: sheetHold, size: size).zIndex(70)
                }
                if ui.mealOpen {
                    MealBreakView(frame: frame, initialMode: frame.mealHold ? .open : .choose, elapsed: 0,
                                  onResume: { ui.mealOpen = false; actions.endBreak() }, onStart: { _, _ in actions.startBreak() }).zIndex(70)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .background(ui.view == .dash ? Color.black : p.bg1.color)
            .animation(MRMotion.ease(MRMotion.d3), value: ui.policySheet)
            .animation(MRMotion.ease(MRMotion.d3), value: ui.view)
            .background {
                Color.clear.focusable().focusEffectDisabled().focused($keyFocus)
                    .onKeyPress(.space) { handleSpace(); return .handled }
                    .onKeyPress(.escape) { handleEscape() }
                    .onKeyPress(characters: CharacterSet(charactersIn: "wWfFmM+=-_")) { press in handleKey(press.characters, size: size) }
            }
            .onAppear { keyFocus = true }
        }
    }

    @ViewBuilder
    private func base(size: CGSize, p: MRPalette) -> some View {
        ZStack(alignment: .topLeading) {
            switch ui.view {
            case .map:
                CruiseMapLayer(frame: frame, ui: ui, size: size)
                // scrim under the readouts (map only)
                LinearGradient(colors: [.clear, p.bg0.color.opacity(0.62)], startPoint: .top, endPoint: .bottom)
                    .frame(height: (size.height * 0.26).rounded())
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .allowsHitTesting(false)
            case .window:
                CruiseWindowView(frame: frame, ui: ui, size: size)
            case .dash:
                CruiseDashboard(frame: frame, size: size)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    static func elapsedParts(_ sec: Int) -> [(value: String, unit: String)] {
        let m = sec / 60
        if sec >= 3600 { return [(String(m / 60), "h"), (String(format: "%02d", m % 60), "min")] }
        return [(String(m), "min")]
    }

    private func handleSpace() {
        if frame.policy.allowsPause || frame.paused { actions.togglePause() } else { ui.policySheet = true }
    }

    private func handleEscape() -> KeyPress.Result {
        if ui.policySheet { ui.policySheet = false; return .handled }
        if ui.menu != nil { ui.menu = nil; return .handled }
        if ui.view == .window { ui.view = .map; return .handled }
        return .ignored
    }

    private func handleKey(_ chars: String, size: CGSize) -> KeyPress.Result {
        switch chars.lowercased() {
        case "m": if !frame.held { ui.mealOpen = true }
        case "w": ui.view = ui.view == .map ? .window : .map; ui.menu = nil
        case "f" where ui.view == .map:
            let cam = CruiseCamera(frame: frame, ui: ui, size: size)
            if ui.follow { ui.follow = false; ui.cam = cam.center } else { ui.follow = true; ui.cam = nil }
        case "+", "=": if ui.view == .map { ui.zoom(by: 0.18) }
        case "-", "_": if ui.view == .map { ui.zoom(by: -0.18) }
        default: return .ignored
        }
        return .handled
    }
}

// MARK: - Live

/// The running flight: ticks once a second, fires the T-5 heads-up (`LandingAlert`, `MRSound` seatbelt chime) and
/// maps the controls to real `AppModel` actions.
struct LiveCruiseScreen: View {
    @Environment(AppModel.self) private var model
    @State private var ui: CruiseUI = { let u = CruiseUI(); u.sceneAuto = true; return u }()
    @State private var alert = LandingAlert()
    @State private var toastUntil: Date?
    @AppStorage("flight.landingAlert") private var alertEnabled = true

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let flight = model.activeFlight, let frame = CruiseFrame(flight: flight, index: model.index, now: context.date) {
                CruiseScreen(frame: frame, ui: ui, actions: actions,
                             showsToast: toastUntil.map { context.date < $0 } ?? false,
                             resumed: resumedText(frame))
                    .overlay {
                        // Together mode: the passenger strip rides on top of the cruise screen (S43)
                        if model.plan.mode == .together && ui.view != .dash {
                            GeometryReader { geo in TGFlightLayer(annaLanded: frame.progress > 0.9, width: geo.size.width) }
                        }
                    }
                    .onChange(of: context.date) { _, now in poll(flight, now) }
                    .onAppear { ui.mealOpen = flight.hold?.kind == .meal }
            }
        }
    }

    private var actions: CruiseActions {
        CruiseActions(togglePause: { model.togglePause() }, landEarly: { model.landEarly() },
                      startBreak: { model.startMealBreak() }, endBreak: { model.endHold() },
                      toggleSound: { on in if on { MRSound.shared.layersOn() } else { MRSound.shared.layersOff() } })
    }

    private func resumedText(_ frame: CruiseFrame) -> (title: String, message: String)? {
        guard let banner = model.resumeBanner else { return nil }
        switch banner.kind {
        case .landedWhileAway:
            return ("Landed in \(frame.destination?.city ?? "your destination") while you were away.", "Your ticket is in your wallet.")
        default:
            return ("Flight resumed.", "Your plane kept flying while you were away.")
        }
    }

    private func poll(_ flight: Flight, _ now: Date) {
        if alert.poll(flight: flight, at: now, isEnabled: alertEnabled) != nil {
            toastUntil = now.addingTimeInterval(6)
            MRSound.shared.play(.seatbelt)
        }
    }
}
