import SwiftUI
import OrbitDesignSystem
import OrbitKit
import OrbitAI

public struct SettingsView: View {
    private let appConfig: AppConfig
    private let onDismiss: @MainActor () -> Void

    public init(appConfig: AppConfig, onDismiss: @escaping @MainActor () -> Void) {
        self.appConfig = appConfig
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            OrbitScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: OrbitSpacing.xl) {
                        accountSection
                        aboutSection
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
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Account")
            OrbitCard {
                VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
                    Text("Guest")
                        .font(OrbitTypography.bodyEmphasized)
                    Text("Sign in to sync across your devices.")
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textSecondary)
                }
            }
        }
    }

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
