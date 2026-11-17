import SwiftUI
import OrbitDesignSystem
import OrbitKit

/// Orbit's capture entry point, living in the iOS 26 tab bar's bottom
/// accessory: the system draws the Liquid Glass and keeps every list's
/// content clear of it.
///
/// - Tap the bar to write.
/// - Tap the mic to open voice capture.
/// - **Hold the mic to talk**; let go to save.
///
/// When the tab bar minimizes on scroll the accessory moves inline and
/// shows just the two glyphs.
struct CaptureAccessory: View {
    let onCapture: @MainActor () -> Void
    let onVoiceCapture: @MainActor () -> Void
    let onHoldStart: @MainActor () -> Void
    let onHoldEnd: @MainActor () -> Void

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @State private var isHolding = false
    @State private var holdTask: Task<Void, Never>?

    /// How long a press must last before it counts as hold-to-talk rather
    /// than a tap.
    private static let holdThreshold: Duration = .milliseconds(300)

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

            micControl
        }
        .foregroundStyle(OrbitColor.textPrimary)
        .padding(.horizontal, OrbitSpacing.md)
    }

    private var micControl: some View {
        Image(systemName: isHolding ? "waveform" : "mic.fill")
            .font(OrbitTypography.bodyEmphasized)
            .foregroundStyle(isHolding ? OrbitColor.danger : OrbitColor.textPrimary)
            .contentTransition(.symbolEffect(.replace))
            .scaleEffect(isHolding ? 1.2 : 1)
            .animation(OrbitMotion.snap, value: isHolding)
            .frame(width: OrbitHitTarget.minimum, height: OrbitHitTarget.minimum)
            .contentShape(.rect)
            .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity) {
                // Never fires: the press is handled entirely below so a
                // short press can still act as a tap.
            } onPressingChanged: { pressing in
                pressing ? pressBegan() : pressEnded()
            }
            .accessibilityElement()
            .accessibilityLabel("Record a voice memory")
            .accessibilityHint("Opens voice capture. You can also touch and hold to record, and release to save.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onVoiceCapture() }
    }

    private func pressBegan() {
        holdTask = Task { @MainActor in
            try? await Task.sleep(for: Self.holdThreshold)
            guard !Task.isCancelled else { return }
            isHolding = true
            onHoldStart()
        }
    }

    private func pressEnded() {
        holdTask?.cancel()
        holdTask = nil
        if isHolding {
            isHolding = false
            onHoldEnd()
        } else {
            // A short press is a tap.
            Haptics.play(.impactRigid)
            onVoiceCapture()
        }
    }
}
