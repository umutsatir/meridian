import SwiftUI

/// Screenshot-harness routes for the onboarding artboards (`--screen onb-…`). Each shows one artboard
/// of Onboarding.dc.html; the detected place is pinned to London so shots do not depend on the Mac's time zone.
private struct OBRoute: View {
    let step: Int
    var sub = 1
    var language: String? = nil
    var live = false
    @Environment(AppModel.self) private var model

    var body: some View {
        OnboardingFlow(index: model.index, step: step, sub: sub, language: language, live: live,
                       detected: AirportDetection.place(for: "Europe/London", index: model.index))
    }
}

extension ScreenRegistry {
    static func registerOnboarding() {
        register("onb-welcome") { OBRoute(step: 1) }
        register("onb-welcome-tr") { OBRoute(step: 1, language: "tr") }
        register("onb-airport") { OBRoute(step: 2) }
        register("onb-scenarios") { OBRoute(step: 3, live: true) }
        register("onb-map") { OBRoute(step: 4) }
        register("onb-notifications") { OBRoute(step: 5, sub: 1) }
        register("onb-focus") { OBRoute(step: 5, sub: 2) }
        register("onb-accessibility") { OBRoute(step: 5, sub: 3) }
        register("onb-account") { OBRoute(step: 6) }
        register("onb-ready") { OBRoute(step: 7) }
    }
}
