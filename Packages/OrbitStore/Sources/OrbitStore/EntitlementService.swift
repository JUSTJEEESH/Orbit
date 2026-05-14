import Foundation
import Observation
import RevenueCat
import OrbitKit

/// Observable wrapper around RevenueCat's `customerInfoStream`. Owns one
/// job: answer "is this user Orbit Pro right now?" — exposed via
/// `state.isPro` so feature code never has to know about RevenueCat's
/// `CustomerInfo` shape.
///
/// Why RevenueCat: it handles StoreKit, receipt validation, cross-device
/// sync, and the subscriber-status webhook surface so we don't have to.
/// The trade-off is one third-party dependency; we contain it inside
/// OrbitStore so the rest of the codebase only ever imports OrbitStore.
@MainActor
@Observable
public final class EntitlementService {
    public enum ProState: Sendable, Equatable {
        /// Initial state before RevenueCat has reported in. Treat as
        /// "free" for gating purposes — never grant Pro features when
        /// the entitlement status is unknown.
        case unknown
        case free
        case pro(expiresAt: Date?)

        public var isPro: Bool {
            if case .pro = self { return true }
            return false
        }
    }

    public private(set) var state: ProState = .unknown

    private var observationTask: Task<Void, Never>?

    public init() {
        observeCustomerInfo()
        Task { @MainActor in
            await refresh()
        }
    }

    // MARK: - Public API

    /// Pulls the current customer info from RevenueCat and updates
    /// `state`. Used at app launch and after explicit restore flows.
    /// Silent on network failure — the streaming observer will pick up
    /// the next valid update.
    public func refresh() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            updateState(from: info)
        } catch {
            OrbitLog.app.error("RevenueCat customerInfo refresh failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Triggers RevenueCat's restore flow. Use for the "Restore
    /// Purchases" button shown in the paywall and in Settings →
    /// Subscription. RevenueCat handles the StoreKit interaction +
    /// receipt re-validation; we just observe the resulting customer
    /// info.
    public func restore() async {
        do {
            let info = try await Purchases.shared.restorePurchases()
            updateState(from: info)
        } catch {
            OrbitLog.app.error("RevenueCat restore failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Private

    /// Subscribes to RevenueCat's continuous customer-info stream so
    /// the app reacts immediately to status changes (purchase from any
    /// device, family-sharing flip, subscription cancellation, etc.).
    /// The Task lives for the lifetime of the service singleton.
    private func observeCustomerInfo() {
        observationTask = Task { @MainActor [weak self] in
            for await customerInfo in Purchases.shared.customerInfoStream {
                self?.updateState(from: customerInfo)
            }
        }
    }

    private func updateState(from info: CustomerInfo) {
        if let entitlement = info.entitlements.all[RevenueCatConfig.proEntitlementID],
           entitlement.isActive {
            state = .pro(expiresAt: entitlement.expirationDate)
        } else {
            state = .free
        }
    }
}
