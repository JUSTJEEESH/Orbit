import SwiftUI
import RevenueCat
import RevenueCatUI
import OrbitDesignSystem
import OrbitKit

/// Orbit's wrapper around RevenueCat's prebuilt Customer Center — the
/// self-serve UI where a user can view their subscription, cancel,
/// request a refund, see purchase history, and manage their plan.
/// Configuration (sections, support URLs, branding) lives in the
/// RevenueCat dashboard.
///
/// Present this as a modal sheet from Settings → Subscription, gated by
/// `entitlements.state.isPro` (it's only meaningful for Pro
/// subscribers; free users see the paywall instead).
public struct OrbitCustomerCenterView: View {
    private let onDismiss: @MainActor () -> Void

    public init(onDismiss: @escaping @MainActor () -> Void) {
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            CustomerCenterView()
                .navigationTitle("Manage subscription")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done", action: onDismiss)
                            .font(OrbitTypography.bodyEmphasized)
                            .foregroundStyle(OrbitColor.textSecondary)
                    }
                }
        }
    }
}
