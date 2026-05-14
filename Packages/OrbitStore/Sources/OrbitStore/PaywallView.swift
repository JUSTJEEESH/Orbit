import SwiftUI
import RevenueCat
import RevenueCatUI
import OrbitDesignSystem
import OrbitKit

/// Orbit's paywall sheet. Internally hosts RevenueCat's prebuilt
/// `PaywallView` — the visual design is configured in the RevenueCat
/// dashboard, not in code, so we can iterate copy + offers without
/// shipping a new binary.
///
/// We keep the public init signature stable so the rest of the app
/// (RootView's modal sheet, ProGateSheet's upgrade button) doesn't have
/// to know the underlying SDK changed. The `entitlements` parameter is
/// preserved as a binding hook in case we ever need to read state at
/// presentation time, but RevenueCatUI's own callbacks
/// (`onPurchaseCompleted`, `onRestoreCompleted`) are what actually
/// drive the dismiss.
public struct PaywallView: View {
    private let onDismiss: @MainActor () -> Void

    @Bindable private var entitlements: EntitlementService

    public init(
        entitlements: EntitlementService,
        onDismiss: @escaping @MainActor () -> Void
    ) {
        self.entitlements = entitlements
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            RevenueCatUI.PaywallView()
                .onPurchaseCompleted { customerInfo in
                    // RevenueCatUI hands us the fresh CustomerInfo on
                    // a successful purchase. Our streaming observer
                    // also picks this up via customerInfoStream, but
                    // calling refresh() once here is cheap insurance.
                    Task { @MainActor in
                        await entitlements.refresh()
                        if customerInfo.entitlements
                            .all[RevenueCatConfig.proEntitlementID]?
                            .isActive == true {
                            Haptics.play(.success)
                            // Brief beat so the user sees the "purchased"
                            // confirmation animation before we dismiss.
                            try? await Task.sleep(for: .milliseconds(600))
                            onDismiss()
                        }
                    }
                }
                .onRestoreCompleted { customerInfo in
                    Task { @MainActor in
                        await entitlements.refresh()
                        if customerInfo.entitlements
                            .all[RevenueCatConfig.proEntitlementID]?
                            .isActive == true {
                            Haptics.play(.success)
                            onDismiss()
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close", action: onDismiss)
                            .font(OrbitTypography.bodyEmphasized)
                            .foregroundStyle(OrbitColor.textSecondary)
                    }
                }
        }
    }
}
