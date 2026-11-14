import SwiftUI
import OrbitDesignSystem
import OrbitKit

/// "Worth remembering" — one quiet notification a day with a memory from
/// your past.
struct SettingsResurfacingSection: View {
    let notifications: NotificationService
    let onSetEnabled: @MainActor (Bool) async -> Void

    @State private var isUpdating = false

    var body: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Memories")
            OrbitCard {
                Toggle(isOn: Binding(
                    get: { notifications.isResurfacingEnabled },
                    set: { newValue in
                        isUpdating = true
                        Task {
                            await onSetEnabled(newValue)
                            isUpdating = false
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
                        Text("Worth remembering")
                            .font(OrbitTypography.bodyEmphasized)
                            .foregroundStyle(OrbitColor.textPrimary)
                        Text("A quiet morning notification with one memory from your past — often from this day in an earlier year.")
                            .font(OrbitTypography.footnote)
                            .foregroundStyle(OrbitColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(OrbitColor.accentGreen)
                .disabled(isUpdating)
            }
        }
    }
}
