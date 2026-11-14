import SwiftUI
import OrbitDesignSystem
import OrbitKit

/// "Privacy" — the optional Face ID / passcode lock.
struct SettingsPrivacySection: View {
    let appLock: AppLockService

    var body: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Privacy")
            OrbitCard {
                Toggle(isOn: Binding(
                    get: { appLock.isEnabled },
                    set: { newValue in Task { await appLock.setEnabled(newValue) } }
                )) {
                    VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
                        Text("Require \(appLock.methodName)")
                            .font(OrbitTypography.bodyEmphasized)
                            .foregroundStyle(OrbitColor.textPrimary)
                        Text(appLock.isAvailable
                             ? "Orbit locks when you leave it. Your passcode always works as a backup."
                             : "Set up a passcode in iOS Settings to lock Orbit.")
                            .font(OrbitTypography.footnote)
                            .foregroundStyle(OrbitColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(OrbitColor.accentGreen)
                .disabled(!appLock.isAvailable || appLock.isAuthenticating)
            }
        }
    }
}
