import Foundation

public enum Plan: String, Sendable, Codable, CaseIterable {
    case lifetime, annual, monthly

    public var hasTrial: Bool { self != .lifetime }
    public var source: ProSource {
        switch self {
        case .lifetime: .lifetime
        case .annual: .annual
        case .monthly: .monthly
        }
    }
}

/// A price as shown. Until Q2/Q15 are decided it is a placeholder like `$XX`.
public struct PriceDisplay: Sendable, Hashable, Codable {
    public let text: String
    public let isPlaceholder: Bool

    public init(text: String, isPlaceholder: Bool = false) {
        self.text = text
        self.isPlaceholder = isPlaceholder
    }

    public static let placeholder = PriceDisplay(text: "$XX", isPlaceholder: true)
}

/// Content and defaults of the paywall (S53). Deliberately has no countdown,
/// no "was" price and no discount badge: the honesty rules in PRD §9.13 are
/// enforced by the type having nowhere to put them.
public struct PaywallModel: Sendable, Hashable {
    public enum Section: String, Sendable, CaseIterable {
        case whatStaysFree, whatProAdds, plans, trialTimeline, restore
    }

    /// "What stays free" always comes first.
    public let sections: [Section] = [.whatStaysFree, .whatProAdds, .plans, .trialTimeline, .restore]
    public let plans: [Plan] = [.lifetime, .annual, .monthly]
    public private(set) var selectedPlan: Plan = .lifetime
    public private(set) var prices: [Plan: PriceDisplay]
    public let freeFeatures: [Feature]
    public let proFeatures: [Feature]

    public init(prices: [Plan: PriceDisplay] = [:]) {
        self.prices = Dictionary(uniqueKeysWithValues: Plan.allCases.map { ($0, prices[$0] ?? .placeholder) })
        freeFeatures = Feature.allCases.filter { FeatureGate.freeFeatures.contains($0) }
        proFeatures = Feature.allCases.filter { FeatureGate.proFeatures.contains($0) }
    }

    public mutating func select(_ plan: Plan) { selectedPlan = plan }

    public func price(for plan: Plan) -> PriceDisplay { prices[plan] ?? .placeholder }

    /// The trial timeline is shown only for plans that have a trial.
    public func trialTimeline(startingAt start: Date, calendar: Calendar = .current) -> TrialTimeline? {
        selectedPlan.hasTrial ? TrialTimeline(start: start, calendar: calendar) : nil
    }
}
