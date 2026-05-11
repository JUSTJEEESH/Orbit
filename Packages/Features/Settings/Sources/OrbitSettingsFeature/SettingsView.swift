import SwiftUI
import OrbitDesignSystem
import OrbitKit
import OrbitAI
import OrbitAccount
import OrbitStore

public struct SettingsView: View {
    private let appConfig: AppConfig
    @Bindable private var account: AccountService
    @Bindable private var entitlements: EntitlementService
    private let currentTheme: OrbitTheme
    private let onSelectTheme: @MainActor (OrbitTheme) -> Void
    private let onPresentPaywall: @MainActor () -> Void
    private let onDeleteAccount: @MainActor @Sendable () async throws -> Void
    private let onReindexAll: @MainActor @Sendable () async -> Void
    private let onDismiss: @MainActor () -> Void

    @State private var showDeleteConfirmation = false
    @State private var deletionError: String?
    @State private var isReindexing = false

    public init(
        appConfig: AppConfig,
        account: AccountService,
        entitlements: EntitlementService,
        currentTheme: OrbitTheme,
        onSelectTheme: @escaping @MainActor (OrbitTheme) -> Void,
        onPresentPaywall: @escaping @MainActor () -> Void,
        onDeleteAccount: @escaping @MainActor @Sendable () async throws -> Void,
        onReindexAll: @escaping @MainActor @Sendable () async -> Void,
        onDismiss: @escaping @MainActor () -> Void
    ) {
        self.appConfig = appConfig
        self.account = account
        self.entitlements = entitlements
        self.currentTheme = currentTheme
        self.onSelectTheme = onSelectTheme
        self.onPresentPaywall = onPresentPaywall
        self.onDeleteAccount = onDeleteAccount
        self.onReindexAll = onReindexAll
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            OrbitScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: OrbitSpacing.xl) {
                        accountSection
                        appearanceSection
                        subscriptionSection
                        aboutSection
                        dangerSection
                        #if DEBUG
                        developerSection
                        #endif
                    }
                    .padding(.vertical, OrbitSpacing.lg)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDismiss() }
                        .font(OrbitTypography.bodyEmphasized)
                }
            }
            .confirmationDialog(
                "Delete account?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete everything", role: .destructive) {
                    Task { @MainActor in
                        do {
                            try await onDeleteAccount()
                            Haptics.play(.success)
                            onDismiss()
                        } catch {
                            deletionError = error.localizedDescription
                            Haptics.play(.failure)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This signs you out and permanently erases every memory on this device. This can't be undone.")
            }
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Account")
            OrbitCard {
                accountCardContent
            }
        }
    }

    @ViewBuilder
    private var accountCardContent: some View {
        switch account.state {
        case .guest:
            VStack(alignment: .leading, spacing: OrbitSpacing.xs) {
                Text("Guest")
                    .font(OrbitTypography.bodyEmphasized)
                    .foregroundStyle(OrbitColor.textPrimary)
                Text("Sign in with Apple to sync across your devices.")
                    .font(OrbitTypography.footnote)
                    .foregroundStyle(OrbitColor.textSecondary)
            }

        case .signedIn(let identity):
            VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(identity.fullName ?? "Signed in")
                        .font(OrbitTypography.bodyEmphasized)
                        .foregroundStyle(OrbitColor.textPrimary)
                    if let email = identity.email {
                        Text(email)
                            .font(OrbitTypography.footnote)
                            .foregroundStyle(OrbitColor.textSecondary)
                    }
                }
                OrbitButton("Sign out", style: .secondary) {
                    account.signOut()
                    Haptics.play(.warning)
                }
            }

        case .revoked:
            VStack(alignment: .leading, spacing: OrbitSpacing.xs) {
                Text("Apple ID changed")
                    .font(OrbitTypography.bodyEmphasized)
                    .foregroundStyle(OrbitColor.textPrimary)
                Text("Your previous sign-in is no longer valid. Please sign in again from the welcome flow.")
                    .font(OrbitTypography.footnote)
                    .foregroundStyle(OrbitColor.textSecondary)
            }
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Appearance", subtitle: "Choose the accent that runs through Orbit.")
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: OrbitSpacing.sm),
                    GridItem(.flexible(), spacing: OrbitSpacing.sm),
                ],
                spacing: OrbitSpacing.sm
            ) {
                ForEach(OrbitTheme.all) { theme in
                    themeTile(theme)
                }
            }
        }
    }

    private func themeTile(_ theme: OrbitTheme) -> some View {
        let isSelected = theme == currentTheme
        return Button {
            Haptics.play(.selection)
            onSelectTheme(theme)
        } label: {
            VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(theme.primary)
                        .frame(width: 44, height: 44)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(OrbitColor.textInverted, theme.primary)
                            .offset(x: 6, y: -6)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.name)
                        .font(OrbitTypography.bodyEmphasized)
                        .foregroundStyle(OrbitColor.textPrimary)
                    Text(theme.promotionalCopy)
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(OrbitSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(OrbitColor.surface, in: .rect(cornerRadius: OrbitRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: OrbitRadius.lg)
                    .stroke(
                        isSelected ? theme.primary : OrbitColor.separator,
                        lineWidth: isSelected ? 2 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subscription

    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Subscription")
            OrbitCard {
                VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                    HStack(spacing: OrbitSpacing.xs) {
                        Image(systemName: entitlements.state.isPro ? "sparkles" : "lock")
                            .foregroundStyle(entitlements.state.isPro ? OrbitColor.accent : OrbitColor.textSecondary)
                        Text(entitlements.state.isPro ? "Orbit Pro" : "Free")
                            .font(OrbitTypography.bodyEmphasized)
                            .foregroundStyle(OrbitColor.textPrimary)
                        Spacer()
                    }
                    Text(subscriptionDetail)
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !entitlements.state.isPro {
                        OrbitButton("Upgrade to Pro", systemImage: "sparkles", style: .primary) {
                            onPresentPaywall()
                        }
                    } else {
                        OrbitButton("Restore purchases", style: .secondary) {
                            Task { await entitlements.restore() }
                        }
                    }
                }
            }
        }
    }

    private var subscriptionDetail: String {
        switch entitlements.state {
        case .unknown:
            return "Checking your subscription…"
        case .free:
            return "You're on the free plan. Upgrade for unlimited captures, AI organization, and sync."
        case .pro(let expiresAt):
            if let expiresAt {
                return "Renews \(expiresAt.formatted(date: .abbreviated, time: .omitted))."
            }
            return "Lifetime plan. Yours forever."
        }
    }

    // MARK: - Danger

    private var dangerSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Danger zone")
            OrbitCard {
                VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                    Text("Delete account & data")
                        .font(OrbitTypography.bodyEmphasized)
                        .foregroundStyle(OrbitColor.textPrimary)
                    Text("Sign out and erase every memory on this device. There's no recovery.")
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let deletionError {
                        Text(deletionError)
                            .font(OrbitTypography.footnote)
                            .foregroundStyle(OrbitColor.danger)
                    }
                    OrbitButton("Delete account", systemImage: "trash", style: .destructive) {
                        Haptics.play(.warning)
                        showDeleteConfirmation = true
                    }
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("About")
            OrbitCard {
                VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
                    keyValue("Version", "\(appConfig.marketingVersion) (\(appConfig.buildNumber))")
                    OrbitDivider()
                    keyValue("Environment", appConfig.environment.rawValue.capitalized)
                }
            }
        }
    }

    #if DEBUG
    private var developerSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Developer")

            aiStatusCard

            OrbitCard {
                VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                    Text("Re-categorize all memories")
                        .font(OrbitTypography.bodyEmphasized)
                        .foregroundStyle(OrbitColor.textPrimary)
                    Text("Re-runs the AI pipeline against every existing memory so older rows pick up the latest categorization rules.")
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    OrbitButton(
                        isReindexing ? "Reindexing…" : "Run now",
                        systemImage: "arrow.triangle.2.circlepath",
                        style: .secondary
                    ) {
                        isReindexing = true
                        Task { @MainActor in
                            await onReindexAll()
                            isReindexing = false
                            Haptics.play(.success)
                        }
                    }
                    .disabled(isReindexing)
                }
            }

            NavigationLink {
                DesignSystemGallery()
            } label: {
                OrbitCard {
                    HStack {
                        Text("Design System Gallery")
                            .font(OrbitTypography.bodyEmphasized)
                            .foregroundStyle(OrbitColor.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(OrbitColor.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var aiStatusCard: some View {
        let status = SystemModelStatus.current()
        return OrbitCard {
            VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                HStack(spacing: OrbitSpacing.xs) {
                    Image(systemName: status.isAvailable
                          ? "checkmark.circle.fill"
                          : "exclamationmark.triangle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(status.isAvailable
                                         ? OrbitColor.success
                                         : OrbitColor.warning)
                    Text("Apple Intelligence")
                        .font(OrbitTypography.bodyEmphasized)
                        .foregroundStyle(OrbitColor.textPrimary)
                    Spacer()
                    Text(status.summary)
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textSecondary)
                }
                Text(status.detail)
                    .font(OrbitTypography.footnote)
                    .foregroundStyle(OrbitColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    #endif

    private func keyValue(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
                .font(OrbitTypography.callout)
                .foregroundStyle(OrbitColor.textSecondary)
            Spacer()
            Text(value)
                .font(OrbitTypography.callout)
                .foregroundStyle(OrbitColor.textPrimary)
        }
        .padding(.vertical, OrbitSpacing.xxs)
    }
}
