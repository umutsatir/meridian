import Foundation
import MeridianCore
import MeridianPlan
import MeridianMaps
import SwiftUI

extension AppModel {
    /// Writes the onboarding choices (home airport, scenarios, map style) to `PlanPreferences` and
    /// UserDefaults, then leaves onboarding. Skipping at any step ends here with the defaults.
    func completeOnboarding(_ ob: OnboardingModel) {
        let d = UserDefaults.standard
        plan.setOrigin(iata: ob.home)
        let picked = ob.pickedScenarios
        if let first = picked.first(where: { !$0.isCustom }) ?? picked.first { plan.setScenario(id: first.id) }
        d.set(picked.map(\.id), forKey: OnboardingModel.scenariosKey)
        if let data = try? JSONEncoder().encode(picked.filter(\.isCustom)) { d.set(data, forKey: OnboardingModel.customScenariosKey) }
        d.set(ob.mapStyle.rawValue, forKey: OnboardingModel.mapStyleKey)
        d.set(ob.showsLabels, forKey: OnboardingModel.mapLabelsKey)
        d.set(true, forKey: OnboardingModel.completedKey)
        section = .fly
        hasOnboarded = true
    }
}

/// Shows onboarding on first launch, then the app.
struct LaunchGate: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.hasOnboarded {
            RootView()
        } else {
            OnboardingFlow(index: model.index) { model.completeOnboarding($0) }
        }
    }
}
