import Foundation
import MeridianPro
import Observation

/// App-side owner of the Pro entitlement and the paywall state. Wraps `MeridianPro.ProStore`
/// (StoreKit 2) and `PaywallModel`; the views only read this.
@MainActor
@Observable
final class ProModel {
    static let shared = ProModel()

    private(set) var entitlement: Entitlement = .free
    var paywall = PaywallModel()
    private(set) var isWorking = false
    /// Plain-words result of the last purchase or restore, shown as a toast.
    private(set) var lastMessage: String?

    @ObservationIgnored private let store = ProStore()
    @ObservationIgnored private var started = false

    var isPro: Bool { entitlement.isPro }

    private init() {}

    /// Call once at launch. Safe to call again.
    func start() async {
        guard !started else { return }
        started = true
        store.onEntitlementChange = { [weak self] new in self?.entitlement = new }
        await store.start()
        entitlement = store.entitlement
        paywall = PaywallModel(prices: store.displayPrices())
    }

    func select(_ plan: Plan) { paywall.select(plan) }

    /// "Start 7-day free trial" / "Buy Lifetime".
    func purchaseSelected() async {
        isWorking = true
        defer { isWorking = false }
        await start()
        do {
            switch try await store.purchase(paywall.selectedPlan) {
            case .purchased: lastMessage = L("Welcome to Meridian Pro.")
            case .cancelled: lastMessage = nil
            case .pending: lastMessage = L("Your purchase is waiting for approval.")
            }
        } catch {
            lastMessage = L("Purchases are not available yet. Nothing was charged.")
        }
    }

    func restore() async {
        isWorking = true
        defer { isWorking = false }
        await start()
        do {
            try await store.restore()
            lastMessage = store.entitlement.isPro ? L("Pro restored.") : L("No earlier purchase found.")
        } catch {
            lastMessage = L("Could not reach the App Store. Try again later.")
        }
    }

    func clearMessage() { lastMessage = nil }
}
