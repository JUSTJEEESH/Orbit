import Foundation
import Observation
import StoreKit
import OrbitKit

/// StoreKit 2 wrapper. Owns three jobs:
///   1. Load product metadata from the App Store (or the local `.storekit`
///      config when running in Xcode).
///   2. Drive purchase + restore flows.
///   3. Observe `Transaction.updates` so external purchases (Family Sharing,
///      Ask to Buy, restore on another device) flip the Pro state live.
///
/// We surface a coarse `ProState` instead of leaking individual products so
/// feature code can ask one question: "is this user Pro?"
@MainActor
@Observable
public final class EntitlementService {
    public enum ProState: Sendable, Equatable {
        case unknown
        case free
        case pro(expiresAt: Date?)

        public var isPro: Bool { if case .pro = self { return true }; return false }
    }

    public enum PurchaseOutcome: Sendable, Equatable {
        case success
        case pending
        case cancelled
        case failed(String)
    }

    public private(set) var state: ProState = .unknown
    public private(set) var products: [OrbitProduct] = []
    public private(set) var isLoadingProducts: Bool = false

    public static let monthlyID = "com.joshgreen.orbit.pro.monthly"
    public static let yearlyID = "com.joshgreen.orbit.pro.yearly"
    public static let lifetimeID = "com.joshgreen.orbit.pro.lifetime"

    public static let defaultProductIDs: Set<String> = [
        monthlyID,
        yearlyID,
        lifetimeID,
    ]

    private let productIdentifiers: Set<String>
    private var updatesTask: Task<Void, Never>?

    public init(productIdentifiers: Set<String> = EntitlementService.defaultProductIDs) {
        self.productIdentifiers = productIdentifiers
        observeUpdates()
        Task { @MainActor in
            await loadProducts()
            await refreshEntitlements()
        }
    }

    // Intentionally no `deinit`. EntitlementService is a singleton on
    // AppEnvironment for the whole app lifetime, so the Transaction.updates
    // observation task naturally tears down with the process. Touching the
    // MainActor-isolated `updatesTask` from a nonisolated `deinit` is
    // illegal under Swift 6 strict concurrency.

    // MARK: - Public API

    public func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let storeProducts = try await Product.products(for: productIdentifiers)
            self.products = storeProducts
                .map(Self.makeOrbitProduct(from:))
                .sorted(by: Self.byKind)
        } catch {
            self.products = []
        }
    }

    /// Purchases the product whose `id` matches the supplied `OrbitProduct`.
    public func purchase(_ product: OrbitProduct) async -> PurchaseOutcome {
        do {
            let storeProducts = try await Product.products(for: [product.id])
            guard let storeProduct = storeProducts.first else { return .failed("Product unavailable") }
            let result = try await storeProduct.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshEntitlements()
                    return .success
                case .unverified(_, let error):
                    OrbitLog.app.error("Purchase verification failed: \(String(describing: error), privacy: .public)")
                    return .failed("Couldn't verify your purchase. Try again in a moment.")
                }
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed("Purchase didn't complete. Try again.")
            }
        } catch {
            OrbitLog.app.error("Purchase failed: \(String(describing: error), privacy: .public)")
            return .failed("Purchase didn't complete. Check your payment method and try again.")
        }
    }

    public func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            // Restore failures are non-fatal; keep current state.
        }
    }

    public func refreshEntitlements() async {
        var pro = false
        var earliestExpiry: Date?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard productIdentifiers.contains(transaction.productID) else { continue }
            pro = true
            if let expiration = transaction.expirationDate {
                if let current = earliestExpiry {
                    if expiration < current { earliestExpiry = expiration }
                } else {
                    earliestExpiry = expiration
                }
            }
        }
        state = pro ? .pro(expiresAt: earliestExpiry) : .free
    }

    // MARK: - Private

    private func observeUpdates() {
        updatesTask = Task { @MainActor [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
    }

    private static func makeOrbitProduct(from product: Product) -> OrbitProduct {
        OrbitProduct(
            id: product.id,
            displayName: product.displayName,
            description: product.description,
            displayPrice: product.displayPrice,
            kind: kind(for: product),
            introductoryOffer: introductoryOfferDescription(for: product)
        )
    }

    /// Returns a friendly summary like "7-day free trial" for a
    /// subscription's introductory offer, or nil when none is configured.
    /// We deliberately render this as a single-line tagline so it can sit
    /// alongside the regular price in the paywall product row.
    private static func introductoryOfferDescription(for product: Product) -> String? {
        guard
            product.type == .autoRenewable,
            let offer = product.subscription?.introductoryOffer
        else { return nil }

        let period = offer.period
        let unitWord: String = {
            switch period.unit {
            case .day:   return period.value == 1 ? "day" : "days"
            case .week:  return period.value == 1 ? "week" : "weeks"
            case .month: return period.value == 1 ? "month" : "months"
            case .year:  return period.value == 1 ? "year" : "years"
            @unknown default: return "days"
            }
        }()
        // Apple's StoreKit returns a Week with value 1 for "P1W", but
        // users read "7-day" more naturally than "1-week" for trials.
        // Normalize the common case.
        let valueLabel: String
        if period.unit == .week, period.value == 1 {
            valueLabel = "7-day"
        } else {
            valueLabel = "\(period.value)-\(unitWord)"
        }

        switch offer.paymentMode {
        case .freeTrial:
            return "\(valueLabel) free trial"
        case .payAsYouGo, .payUpFront:
            return "\(valueLabel) intro at \(offer.displayPrice)"
        default:
            return nil
        }
    }

    private static func kind(for product: Product) -> OrbitProduct.Kind {
        if product.type == .nonConsumable { return .lifetime }
        if product.type == .autoRenewable {
            if let period = product.subscription?.subscriptionPeriod {
                switch period.unit {
                case .month: return .monthly
                case .year: return .yearly
                default: return .unknown
                }
            }
        }
        return .unknown
    }

    private static func byKind(_ lhs: OrbitProduct, _ rhs: OrbitProduct) -> Bool {
        order(lhs.kind) < order(rhs.kind)
    }

    private static func order(_ kind: OrbitProduct.Kind) -> Int {
        switch kind {
        case .monthly:  return 0
        case .yearly:   return 1
        case .lifetime: return 2
        case .unknown:  return 3
        }
    }
}
