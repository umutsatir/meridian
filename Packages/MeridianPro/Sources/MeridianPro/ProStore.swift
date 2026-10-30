#if canImport(StoreKit)
import Foundation
import StoreKit

/// App Store product identifiers. TODO(Q15): placeholders until pricing and
/// trial lengths are decided and the products exist in App Store Connect.
public enum ProductID: String, Sendable, CaseIterable {
    case lifetime = "app.meridian.pro.lifetime"
    case annual = "app.meridian.pro.annual"
    case monthly = "app.meridian.pro.monthly"

    public var plan: Plan {
        switch self {
        case .lifetime: .lifetime
        case .annual: .annual
        case .monthly: .monthly
        }
    }
}

/// StoreKit 2 bridge: loads products, purchases, restores and follows
/// transaction updates. No server-side receipt validation in v1 (PRD §9.13).
@MainActor
public final class ProStore {
    public private(set) var products: [Plan: Product] = [:]
    public private(set) var entitlement: Entitlement = .free
    public var onEntitlementChange: ((Entitlement) -> Void)?

    private var updatesTask: Task<Void, Never>?

    public init() {}

    /// Stops listening for transactions. There is no `deinit` cancel on purpose:
    /// `isolated deinit` needs a newer runtime than the macOS 14 deployment target.
    public func stop() {
        updatesTask?.cancel()
        updatesTask = nil
    }

    /// Call once at launch: loads products, reads current entitlements, and
    /// starts listening for transactions that finish outside the app.
    public func start() async {
        updatesTask = updatesTask ?? Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        await loadProducts()
        await refreshEntitlement()
    }

    public func loadProducts() async {
        guard let loaded = try? await Product.products(for: ProductID.allCases.map(\.rawValue)) else { return }
        products = Dictionary(loaded.compactMap { product in
            ProductID(rawValue: product.id).map { ($0.plan, product) }
        }, uniquingKeysWith: { first, _ in first })
    }

    public func displayPrices() -> [Plan: PriceDisplay] {
        products.mapValues { PriceDisplay(text: $0.displayPrice) }
    }

    public enum PurchaseResult: Sendable { case purchased, cancelled, pending }

    public func purchase(_ plan: Plan) async throws -> PurchaseResult {
        guard let product = products[plan] else { throw StoreKitError.unknown }
        switch try await product.purchase() {
        case .success(let verification):
            await handle(verification)
            return .purchased
        case .userCancelled: return .cancelled
        case .pending: return .pending
        @unknown default: return .cancelled
        }
    }

    /// "Restore purchases": syncs with the App Store, then re-reads entitlements.
    public func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlement()
    }

    public func refreshEntitlement() async {
        var best: Entitlement = .free
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil else { continue }
            guard let candidate = Self.entitlement(for: transaction) else { continue }
            if Self.rank(candidate) > Self.rank(best) { best = candidate }
        }
        update(best)
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await transaction.finish()
        await refreshEntitlement()
    }

    private func update(_ new: Entitlement) {
        guard new != entitlement else { return }
        entitlement = new
        onEntitlementChange?(new)
    }

    /// Family Sharing: a transaction owned by a family member is `.familyShared`.
    nonisolated static func entitlement(for transaction: Transaction) -> Entitlement? {
        guard let id = ProductID(rawValue: transaction.productID) else { return nil }
        if transaction.ownershipType == .familyShared { return .pro(.family) }
        return .pro(id.plan.source)
    }

    /// Lifetime beats subscriptions beats family when several apply.
    private static func rank(_ e: Entitlement) -> Int {
        switch e {
        case .free: 0
        case .pro(.family): 1
        case .pro(.monthly): 2
        case .pro(.annual): 3
        case .pro(.lifetime): 4
        }
    }
}
#endif
