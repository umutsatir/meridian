import Foundation
import MeridianCore
import MeridianMaps
import MeridianPlan
import Observation

/// One chip of the playground (ONB-3). The first eight are the built-in scenarios, the next six are
/// onboarding-only suggestions, the rest are custom scenarios the user typed.
struct OBChip: Identifiable, Hashable {
    var id: String
    var title: String
    var hex: String
    var icon: String   // icons.svg id
    var isCustom = false

    /// The canvas chips (Onboarding.dc.html `CH()`), in order.
    static let defaults: [OBChip] = [
        .init(id: "study", title: "Study", hex: "#7AA2FF", icon: "cap"),
        .init(id: "work", title: "Work", hex: "#FFB86B", icon: "case"),
        .init(id: "read", title: "Read", hex: "#7ADDB2", icon: "book"),
        .init(id: "create", title: "Create", hex: "#FF8FB1", icon: "spark"),
        .init(id: "code", title: "Coding", hex: "#B49CFF", icon: "code"),
        .init(id: "meditate", title: "Meditate", hex: "#8EE3E8", icon: "lotus"),
        .init(id: "fitness", title: "Fitness", hex: "#FF9B7A", icon: "dumbbell"),
        .init(id: "other", title: "Other", hex: "#C7CCDA", icon: "dot"),
        .init(id: "write", title: "Write", hex: "#FF8FB1", icon: "pencil"),
        .init(id: "design", title: "Design", hex: "#B49CFF", icon: "spark"),
        .init(id: "research", title: "Research", hex: "#7AA2FF", icon: "search"),
        .init(id: "language", title: "Language", hex: "#FFB86B", icon: "book"),
        .init(id: "plan", title: "Plan", hex: "#7ADDB2", icon: "calendar"),
        .init(id: "admin", title: "Admin", hex: "#C7CCDA", icon: "case"),
    ]
}

/// State of the onboarding flow (PRD §9.1). Nothing is written to the app until `finish`.
@Observable
final class OnboardingModel {
    static let stepCount = 7

    var step: Int
    /// Sub step of the permission step (1 notifications, 2 Focus, 3 accessibility).
    var sub: Int

    // S02
    var detected: DetectedPlace
    var home: String
    var query = ""
    // S03
    var chips: [OBChip] = OBChip.defaults
    var selected: [String]
    // S04
    var mapStyle: MapStyle
    var showsLabels = true
    // S05
    var notificationsAnswered = false
    var focusAnswered = false
    // S06
    var signedIn = false

    let index: AirportIndex

    init(index: AirportIndex, step: Int = 1, sub: Int = 1, home: String? = nil, mapStyle: MapStyle = .terra,
         selected: [String] = ["study", "read", "code"], detected: DetectedPlace? = nil) {
        self.index = index
        self.step = min(max(step, 1), Self.stepCount)
        self.sub = min(max(sub, 1), 3)
        let place = detected ?? AirportDetection.detect(index: index)
        self.detected = place
        self.home = home ?? place.airports.first ?? "LHR"
        self.mapStyle = mapStyle
        self.selected = selected
    }

    var homeAirport: Airport? { index.airport(iata: home) }

    func go(_ n: Int) {
        step = min(max(n, 1), Self.stepCount)
        sub = 1
    }

    func toggle(_ id: String) {
        if let i = selected.firstIndex(of: id) { selected.remove(at: i) } else { selected.append(id) }
    }

    /// ONB-3 "custom allowed": adds a chip and selects it.
    func addCustom(_ name: String) {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !chips.contains(where: { $0.title.caseInsensitiveCompare(title) == .orderedSame }) else { return }
        let id = "custom-" + title.lowercased().replacingOccurrences(of: " ", with: "-")
        chips.append(OBChip(id: id, title: title, hex: "#C7CCDA", icon: "dot", isCustom: true))
        selected.append(id)
    }

    /// Airports shown in the right column: the detected metro area, or search results.
    func rows() -> [Airport] {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return detected.airports.compactMap { index.airport(iata: $0) } }
        return Array(index.search(q, limit: 7))
    }

    // MARK: Persistence

    static let scenariosKey = "onboarding.scenarios"
    static let customScenariosKey = "onboarding.customScenarios"
    static let mapStyleKey = "onboarding.mapStyle"
    static let mapLabelsKey = "onboarding.mapLabels"
    static let completedKey = "onboarding.completed"

    /// The built-in scenarios that were picked, in order, plus the custom ones as `Scenario` values.
    var pickedScenarios: [Scenario] {
        selected.compactMap { id in
            guard let chip = chips.first(where: { $0.id == id }) else { return nil }
            if let d = Scenario.defaults.first(where: { $0.id == id }) { return d }
            return Scenario(id: chip.id, name: chip.title, symbol: "circle.fill", colorHex: chip.hex, isCustom: chip.isCustom)
        }
    }
}
