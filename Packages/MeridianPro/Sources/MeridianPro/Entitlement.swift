import Foundation

/// What a feature gate can unlock (PRD §9.13). Free features are listed too,
/// so a test can pin them and catch anything that quietly moves behind Pro.
public enum Feature: String, Sendable, Codable, CaseIterable {
    // Free forever
    case unlimitedFlights
    case mapTerra, mapMonochrome, mapStandard
    case windowView
    case coreSoundscapes, announcements
    case tickets, wallet, passport, stats
    case menuBar, miniMap, widgets
    case friendFlightsSmall
    // Pro
    case mapSatellite
    case flyoverViews
    case extraSoundscapes
    case friendFlightsLarge
}

public enum ProSource: String, Sendable, Codable, CaseIterable {
    case lifetime, annual, monthly
    /// Granted through Family Sharing by another member's purchase.
    case family
}

public enum Entitlement: Sendable, Hashable, Codable {
    case free
    case pro(ProSource)

    public var isPro: Bool { if case .pro = self { true } else { false } }
}

public enum FeatureGate {
    public static let freeFriendLimit = 4
    public static let proFriendLimit = 12
    public static let extraSoundscapeCount = 12

    /// Features that need Pro. Everything else is free for everyone.
    public static let proFeatures: Set<Feature> = [.mapSatellite, .flyoverViews, .extraSoundscapes, .friendFlightsLarge]

    /// The free set is a promise: it may grow, it must never shrink (PRD §13).
    public static var freeFeatures: Set<Feature> { Set(Feature.allCases).subtracting(proFeatures) }

    public static func isAvailable(_ feature: Feature, for entitlement: Entitlement) -> Bool {
        entitlement.isPro || !proFeatures.contains(feature)
    }

    public static func friendLimit(for entitlement: Entitlement) -> Int {
        entitlement.isPro ? proFriendLimit : freeFriendLimit
    }
}
