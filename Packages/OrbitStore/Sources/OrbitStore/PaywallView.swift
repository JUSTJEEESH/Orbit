import SwiftUI
import OrbitDesignSystem
import OrbitKit

public struct PaywallView: View {
    @Bindable private var entitlements: EntitlementService
    @State private var selectedProductID: String?
    @State private var purchaseOutcome: EntitlementService.PurchaseOutcome?
    @State private var isPurchasing: Bool = false

    private let onDismiss: @MainActor () -> Void

    public init(
        entitlements: EntitlementService,
        onDismiss: @escaping @MainActor () -> Void
    ) {
        self.entitlements = entitlements
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            OrbitScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: OrbitSpacing.xl) {
                        hero
                        benefits
                        productList
                        legalLinks
                        Spacer(minLength: OrbitSpacing.xxxl)
                    }
                    .padding(.top, OrbitSpacing.lg)
                }
                .scrollIndicators(.hidden)

                VStack {
                    Spacer()
                    purchaseBar
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onDismiss)
                        .font(OrbitTypography.bodyEmphasized)
                        .foregroundStyle(OrbitColor.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Restore") {
                        Task { await entitlements.restore() }
                    }
                    .font(OrbitTypography.footnote)
                    .foregroundStyle(OrbitColor.textSecondary)
                }
            }
            .task { await entitlements.loadProducts() }
        }
    }

    // MARK: - Sections

    private var hero: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
            Text("ORBIT PRO")
                .font(OrbitTypography.caption)
                .foregroundStyle(OrbitColor.textTertiary)
            Text("Orbit, in full")
                .font(OrbitTypography.largeTitle)
                .foregroundStyle(OrbitColor.textPrimary)
            Text("Five upgrades that make Orbit feel like a daily companion — not an occasional one.")
                .font(OrbitTypography.body)
                .foregroundStyle(OrbitColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Benefit bullets are kept in lock-step with the gates that
    /// ProGateService enforces, so what we promise on the paywall is
    /// exactly what users get when they upgrade. Anything that's
    /// already free for everyone (captures, search, sync, widgets,
    /// HealthKit) deliberately stays off this list.
    private var benefits: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            benefit(
                icon: "calendar.badge.clock",
                title: "Daily Recap, every day",
                detail: "Not just three a week. A fresh AI recap of your day, on demand."
            )
            benefit(
                icon: "sparkle",
                title: "Unlimited Ask Orbit",
                detail: "No weekly cap on the questions you ask your own memories."
            )
            benefit(
                icon: "waveform",
                title: "Long-form voice notes",
                detail: "Up to an hour per note instead of one minute."
            )
            benefit(
                icon: "calendar",
                title: "Year in Review, in full",
                detail: "Monthly chart, top moments and people, and your memory rain finale."
            )
            benefit(
                icon: "paintpalette",
                title: "Themes & app icons",
                detail: "Sunset, Cosmic, and Forest — with matching home-screen icons."
            )
        }
    }

    private func benefit(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: OrbitSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(OrbitColor.textPrimary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OrbitTypography.bodyEmphasized)
                    .foregroundStyle(OrbitColor.textPrimary)
                Text(detail)
                    .font(OrbitTypography.footnote)
                    .foregroundStyle(OrbitColor.textSecondary)
            }
        }
    }

    private var productList: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Choose a plan")
            if entitlements.products.isEmpty && !entitlements.isLoadingProducts {
                OrbitCard {
                    VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
                        Text("Plans unavailable")
                            .font(OrbitTypography.bodyEmphasized)
                            .foregroundStyle(OrbitColor.textPrimary)
                        Text("Connect to the network and try again, or pull down to retry.")
                            .font(OrbitTypography.footnote)
                            .foregroundStyle(OrbitColor.textSecondary)
                    }
                }
            } else if entitlements.isLoadingProducts {
                HStack {
                    ProgressView()
                    Text("Loading plans…")
                        .font(OrbitTypography.callout)
                        .foregroundStyle(OrbitColor.textSecondary)
                }
            } else {
                ForEach(entitlements.products) { product in
                    productRow(product)
                }
            }
        }
    }

    private func productRow(_ product: OrbitProduct) -> some View {
        let isSelected = selectedProductID == product.id
        return Button {
            selectedProductID = product.id
        } label: {
            HStack(spacing: OrbitSpacing.md) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? OrbitColor.textPrimary : OrbitColor.textTertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName)
                        .font(OrbitTypography.bodyEmphasized)
                        .foregroundStyle(OrbitColor.textPrimary)
                    Text(planTagline(for: product))
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textSecondary)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(OrbitTypography.bodyEmphasized)
                    .foregroundStyle(OrbitColor.textPrimary)
            }
            .padding(OrbitSpacing.lg)
            .background(
                OrbitColor.surface,
                in: .rect(cornerRadius: OrbitRadius.lg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OrbitRadius.lg)
                    .stroke(isSelected ? OrbitColor.textPrimary : OrbitColor.separator, lineWidth: isSelected ? 2 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func planTagline(for product: OrbitProduct) -> String {
        // Free-trial copy takes precedence — it's the most persuasive
        // line we have, and burying it under "Billed annually" sells
        // the offer short.
        if let intro = product.introductoryOffer {
            switch product.kind {
            case .yearly:   return "\(intro), then \(product.displayPrice)/year."
            case .monthly:  return "\(intro), then \(product.displayPrice)/month."
            default:        return intro
            }
        }
        switch product.kind {
        case .monthly:  return "Billed monthly. Cancel anytime."
        case .yearly:   return "Best value. Billed once a year."
        case .lifetime: return "One-time. Yours forever."
        case .unknown:  return product.description
        }
    }

    private var purchaseBar: some View {
        VStack(spacing: OrbitSpacing.xs) {
            if let outcome = purchaseOutcome {
                outcomeBanner(outcome)
            }
            OrbitButton(
                isPurchasing
                    ? "Working…"
                    : (selectedProductID == nil ? "Choose a plan" : "Continue"),
                style: .primary,
                size: .large,
                action: purchase
            )
            .disabled(isPurchasing || selectedProductID == nil)
            .padding(.horizontal, OrbitSpacing.pageHorizontal)
            .padding(.bottom, OrbitSpacing.lg)
            .background(.thinMaterial)
        }
    }

    private func outcomeBanner(_ outcome: EntitlementService.PurchaseOutcome) -> some View {
        let text: String = {
            switch outcome {
            case .success: return "Welcome to Orbit Pro."
            case .pending: return "Waiting for approval."
            case .cancelled: return "Purchase cancelled."
            case .failed(let message): return message
            }
        }()
        let color: Color = {
            switch outcome {
            case .success: return OrbitColor.success
            case .pending: return OrbitColor.warning
            default: return OrbitColor.danger
            }
        }()
        return Text(text)
            .font(OrbitTypography.footnote)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, OrbitSpacing.pageHorizontal)
    }

    private var legalLinks: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
            Text("Subscriptions auto-renew until cancelled. Manage in Settings → Apple ID → Subscriptions.")
                .font(OrbitTypography.footnote)
                .foregroundStyle(OrbitColor.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Actions

    private func purchase() {
        guard let productID = selectedProductID,
              let product = entitlements.products.first(where: { $0.id == productID })
        else { return }
        isPurchasing = true
        purchaseOutcome = nil
        Task { @MainActor in
            let outcome = await entitlements.purchase(product)
            isPurchasing = false
            purchaseOutcome = outcome
            if outcome == .success {
                Haptics.play(.success)
                try? await Task.sleep(for: .milliseconds(600))
                onDismiss()
            } else if case .failed = outcome {
                Haptics.play(.failure)
            }
        }
    }
}
