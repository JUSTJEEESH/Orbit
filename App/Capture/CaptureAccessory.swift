import SwiftUI
import OrbitDesignSystem
import OrbitKit

/// Orbit's capture entry point, living in the iOS 26 tab bar's bottom
/// accessory: the system draws the Liquid Glass and keeps every list's
/// content clear of it. Tap anywhere to write; tap the mic to talk.
///
/// When the tab bar minimizes on scroll the accessory moves inline and
/// shows just the two glyphs.
struct CaptureAccessory: View {
    let onCapture: @MainActor () -> Void
    let onVoiceCapture: @MainActor () -> Void

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        HStack(spacing: OrbitSpacing.sm) {
            Button {
                Haptics.play(.impactRigid)
                onCapture()
            } label: {
                HStack(spacing: OrbitSpacing.xs) {
                    Image(systemName: "plus")
                        .font(OrbitTypography.bodyEmphasized)
                    if placement != .inline {
                        Text("Capture a thought")
                            .font(OrbitTypography.callout)
                            .foregroundStyle(OrbitColor.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: OrbitHitTarget.minimum, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Capture")
            .accessibilityHint("Write a new memory.")

            Button {
                Haptics.play(.impactRigid)
                onVoiceCapture()
            } label: {
                Image(systemName: "mic.fill")
                    .font(OrbitTypography.bodyEmphasized)
                    .frame(width: OrbitHitTarget.minimum, height: OrbitHitTarget.minimum)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Record a voice memory")
        }
        .foregroundStyle(OrbitColor.textPrimary)
        .padding(.horizontal, OrbitSpacing.md)
    }
}
