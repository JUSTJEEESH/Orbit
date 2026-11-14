import SwiftUI
import OrbitDesignSystem

/// What Settings needs to show and change iCloud sync.
public struct SettingsSyncState {
    public enum Status: Sendable {
        case off
        case on
        /// Turned on, but iCloud couldn't be used this launch.
        case unavailable
    }

    public let status: Status
    public let onSetEnabled: @MainActor (Bool) -> Void

    public init(status: Status, onSetEnabled: @escaping @MainActor (Bool) -> Void) {
        self.status = status
        self.onSetEnabled = onSetEnabled
    }
}

/// iCloud sync toggle with a plain-language status line.
struct SettingsSyncSection: View {
    let state: SettingsSyncState

    var body: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("iCloud")
            OrbitCard {
                VStack(alignment: .leading, spacing: OrbitSpacing.xs) {
                    Toggle(isOn: Binding(
                        get: { state.status != .off },
                        set: { state.onSetEnabled($0) }
                    )) {
                        VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
                            Text("Sync with iCloud")
                                .font(OrbitTypography.bodyEmphasized)
                                .foregroundStyle(OrbitColor.textPrimary)
                            Text(detail)
                                .font(OrbitTypography.footnote)
                                .foregroundStyle(state.status == .unavailable ? OrbitColor.warning : OrbitColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(OrbitColor.accentGreen)
                }
            }
        }
    }

    private var detail: String {
        switch state.status {
        case .off:
            "Your memories are stored only on this iPhone. Turn on to keep them in your private iCloud and on all your devices."
        case .on:
            "Memories sync privately through your iCloud account. Photos and recordings stay on this iPhone for now."
        case .unavailable:
            "iCloud isn’t available right now — check that you’re signed in to iCloud. Your memories are safe on this iPhone."
        }
    }
}
