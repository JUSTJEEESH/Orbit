import Foundation
import RevenueCat
import OrbitKit

/// One-call configuration of the RevenueCat SDK. Call this once at app
/// launch, before any other RevenueCat API is touched (typically from
/// `OrbitApp.body.task { }`).
///
/// All RevenueCat-aware code in the app lives behind OrbitStore so the
/// rest of the codebase never has to import `RevenueCat` directly. That
/// keeps the SDK's surface area contained and makes a future swap to a
/// different payments provider a one-package change.
public enum RevenueCatConfig {

    /// Canonical entitlement identifier configured in the RevenueCat
    /// dashboard. The dashboard attaches the three products
    /// (com.joshgreen.orbit.pro.monthly / .yearly / .lifetime) to this
    /// entitlement; the app only ever asks the question "is Orbit Pro
    /// active?" via this name.
    public static let proEntitlementID = "Orbit Pro"

    /// Configures the SDK with the supplied public API key. Safe to call
    /// once per app launch — calling more than once logs a warning but
    /// is otherwise idempotent.
    ///
    /// In DEBUG builds we set `Purchases.logLevel = .info` so the Xcode
    /// console surfaces purchase lifecycle events; Release builds stay
    /// quieter to avoid leaking transaction detail.
    public static func configure(apiKey: String) {
        #if DEBUG
        Purchases.logLevel = .info
        #else
        Purchases.logLevel = .warn
        #endif
        Purchases.configure(withAPIKey: apiKey)
        OrbitLog.app.notice("RevenueCat configured.")
    }
}
