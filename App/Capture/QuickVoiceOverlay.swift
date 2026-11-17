import SwiftUI
import OrbitDesignSystem

/// The floating card shown while holding to talk: a breathing dot, the
/// elapsed time and the words as they're heard. "Release to save."
struct QuickVoiceOverlay: View {
    let state: QuickVoiceCapture.State

    var body: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
            HStack(spacing: OrbitSpacing.sm) {
                RecordingIndicator(isActive: isRecording)
                Text(elapsedText)
                    .font(OrbitTypography.monoNumeric)
                    .foregroundStyle(OrbitColor.textPrimary)
                    .contentTransition(.numericText())
                Spacer()
                Text(isRecording ? "Release to save" : "Saving…")
                    .font(OrbitTypography.footnote)
                    .foregroundStyle(OrbitColor.textSecondary)
            }
            if !transcript.isEmpty {
                Text(transcript)
                    .font(OrbitTypography.body)
                    .foregroundStyle(OrbitColor.textPrimary)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentTransition(.opacity)
            }
        }
        .padding(OrbitSpacing.lg)
        .background(OrbitColor.surfaceElevated, in: .rect(cornerRadius: OrbitRadius.lg))
        .orbitShadow(.lifted)
        .padding(.horizontal, OrbitSpacing.pageHorizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isRecording ? "Recording. Release to save." : "Saving voice memory")
    }

    private var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }

    private var transcript: String {
        if case .recording(_, _, let text) = state { return text }
        return ""
    }

    private var elapsedText: String {
        guard case .recording(let elapsed, _, _) = state else { return "" }
        let seconds = Int(elapsed)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
