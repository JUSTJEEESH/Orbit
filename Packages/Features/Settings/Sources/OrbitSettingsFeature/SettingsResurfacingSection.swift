import SwiftUI
import OrbitDesignSystem
import OrbitKit

/// A simple on/off setting whose change may take a moment (permissions).
public struct SettingsToggleState {
    public let isOn: Bool
    public let onSet: @MainActor (Bool) async -> Void

    public init(isOn: Bool, onSet: @escaping @MainActor (Bool) async -> Void) {
        self.isOn = isOn
        self.onSet = onSet
    }
}

/// "Memories" — the daily "Worth remembering" notification and the
/// Screenshot Inbox.
struct SettingsResurfacingSection: View {
    let notifications: NotificationService
    let onSetEnabled: @MainActor (Bool) async -> Void
    var screenshotInbox: SettingsToggleState?
    var meetingBriefings: SettingsToggleState?

    @State private var isUpdating = false
    @State private var isUpdatingScreenshots = false
    @State private var isUpdatingBriefings = false

    var body: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Memories")
            OrbitCard {
                VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
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

                if let screenshotInbox {
                    OrbitDivider()
                    Toggle(isOn: Binding(
                        get: { screenshotInbox.isOn },
                        set: { newValue in
                            isUpdatingScreenshots = true
                            Task {
                                await screenshotInbox.onSet(newValue)
                                isUpdatingScreenshots = false
                            }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
                            Text("Screenshot Inbox")
                                .font(OrbitTypography.bodyEmphasized)
                                .foregroundStyle(OrbitColor.textPrimary)
                            Text("Orbit reads new screenshots on your iPhone and suggests keeping them as memories. Nothing is saved without a tap.")
                                .font(OrbitTypography.footnote)
                                .foregroundStyle(OrbitColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(OrbitColor.accentGreen)
                    .disabled(isUpdatingScreenshots)
                }

                if let meetingBriefings {
                    OrbitDivider()
                    Toggle(isOn: Binding(
                        get: { meetingBriefings.isOn },
                        set: { newValue in
                            isUpdatingBriefings = true
                            Task {
                                await meetingBriefings.onSet(newValue)
                                isUpdatingBriefings = false
                            }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
                            Text("Before you meet")
                                .font(OrbitTypography.bodyEmphasized)
                                .foregroundStyle(OrbitColor.textPrimary)
                            Text("30 minutes before a calendar event with someone you\u{2019}ve noted, a quiet briefing: open promises, things to bring up, gift ideas. Reads your calendar on this iPhone only.")
                                .font(OrbitTypography.footnote)
                                .foregroundStyle(OrbitColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(OrbitColor.accentGreen)
                    .disabled(isUpdatingBriefings)
                }
                }
            }
        }
    }
}
