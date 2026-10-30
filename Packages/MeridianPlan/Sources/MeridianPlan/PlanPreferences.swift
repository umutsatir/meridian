import Foundation
import MeridianCore

public enum CompanionMode: String, Sendable, Codable, CaseIterable { case solo, together }

public enum StartStyle: String, Sendable, Codable, CaseIterable { case ritual, quick }

/// The route, duration and scenario of the last flight; what Quick Start repeats.
public struct LastRoute: Sendable, Hashable, Codable {
    public var originIata: String
    /// `nil` for a free flight.
    public var destinationIata: String?
    /// `nil` for a free flight.
    public var durationMinutes: Int?
    public var scenarioID: String

    public init(originIata: String, destinationIata: String?, durationMinutes: Int?, scenarioID: String) {
        self.originIata = originIata
        self.destinationIata = destinationIata
        self.durationMinutes = durationMinutes
        self.scenarioID = scenarioID
    }
}

/// Choices that persist per user (PLAN-1, PLAN-8, RIT-6, PLAN-9).
public struct PlanPreferences: Sendable, Hashable, Codable {
    public var homeIata: String?
    public var favoriteIatas: [String]
    public var lastLandingIata: String?
    public var lastRoute: LastRoute?
    public var scenarioID: String
    public var topic: String
    public var mode: CompanionMode
    public var style: StartStyle
    public var pausePolicy: PausePolicy
    /// "Quick start checks in automatically": Quick Start skips the ritual.
    public var quickStartChecksInAutomatically: Bool
    /// RIT-6: bypass the ritual for every flight.
    public var skipRitualAlways: Bool
    public var hasSeenRulerCoachMark: Bool

    public init(
        homeIata: String? = nil,
        favoriteIatas: [String] = [],
        lastLandingIata: String? = nil,
        lastRoute: LastRoute? = nil,
        scenarioID: String = "study",
        topic: String = "",
        mode: CompanionMode = .solo,
        style: StartStyle = .ritual,
        pausePolicy: PausePolicy = .normal,
        quickStartChecksInAutomatically: Bool = true,
        skipRitualAlways: Bool = false,
        hasSeenRulerCoachMark: Bool = false
    ) {
        self.homeIata = homeIata
        self.favoriteIatas = favoriteIatas
        self.lastLandingIata = lastLandingIata
        self.lastRoute = lastRoute
        self.scenarioID = scenarioID
        self.topic = topic
        self.mode = mode
        self.style = style
        self.pausePolicy = pausePolicy
        self.quickStartChecksInAutomatically = quickStartChecksInAutomatically
        self.skipRitualAlways = skipRitualAlways
        self.hasSeenRulerCoachMark = hasSeenRulerCoachMark
    }
}
