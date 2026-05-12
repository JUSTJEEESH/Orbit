import ActivityKit
import WidgetKit
import SwiftUI
import OrbitKit
import OrbitDesignSystem

/// The Live Activity surface shown while a voice capture is in progress.
/// Three render targets — Lock Screen banner, expanded Dynamic Island, and
/// compact / minimal Dynamic Island — share the same time-from-start
/// `Text(_:style:.timer)` so we never have to push per-tick updates.
struct CaptureLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CaptureActivityAttributes.self) { context in
            lockScreenView(state: context.state)
                .widgetURL(URL(string: "orbit://capture"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        RecordingDot()
                        Text("Orbit")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(OrbitColor.textPrimary)
                    }
                    .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startedAt, style: .timer)
                        .font(.system(size: 16, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(OrbitColor.textPrimary)
                        .frame(maxWidth: 80, alignment: .trailing)
                        .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Capturing a voice note")
                        .font(.system(size: 13))
                        .foregroundStyle(OrbitColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)
                }
            } compactLeading: {
                RecordingDot()
            } compactTrailing: {
                Text(context.state.startedAt, style: .timer)
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .frame(maxWidth: 56)
            } minimal: {
                RecordingDot()
            }
            .widgetURL(URL(string: "orbit://capture"))
        }
    }

    private func lockScreenView(state: CaptureActivityAttributes.ContentState) -> some View {
        HStack(spacing: 12) {
            RecordingDot(size: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text("Capturing in Orbit")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(OrbitColor.textPrimary)
                Text("Tap to return to the capture sheet.")
                    .font(.system(size: 12))
                    .foregroundStyle(OrbitColor.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            Text(state.startedAt, style: .timer)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(OrbitColor.textPrimary)
                .frame(minWidth: 80, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .activityBackgroundTint(OrbitColor.background)
        .activitySystemActionForegroundColor(OrbitColor.textPrimary)
    }
}

/// A simple pulsing red dot used across all three Live Activity surfaces.
/// Kept tiny and deterministic — premium feel is the steady heartbeat, not
/// a flashy strobe.
private struct RecordingDot: View {
    var size: CGFloat = 8

    @State private var on: Bool = false

    var body: some View {
        Circle()
            .fill(.red)
            .frame(width: size, height: size)
            .opacity(on ? 1.0 : 0.45)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}
