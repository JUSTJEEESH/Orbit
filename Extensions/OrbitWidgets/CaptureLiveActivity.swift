import ActivityKit
import WidgetKit
import SwiftUI
import OrbitKit
import OrbitDesignSystem

/// The Live Activity surface shown while a voice capture is in progress.
/// Three render targets — Lock Screen banner, expanded Dynamic Island, and
/// compact / minimal Dynamic Island — share the same time-from-start
/// `Text(_:style:.timer)` so we never have to push per-tick updates.
///
/// Visual approach: a small refined recording mark (mic glyph + pulsing
/// ring) replaces the bare red dot, a 7-bar decorative waveform pulses on
/// its own cycle per bar, and the lock screen carries the editorial
/// eyebrow used everywhere else (`● ORBIT · RECORDING`) so this surface
/// reads as part of the widget + onboarding family.
struct CaptureLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CaptureActivityAttributes.self) { context in
            lockScreenView(state: context.state)
                .widgetURL(URL(string: "orbit://capture"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        RecordingMark(size: 16)
                        Text("Orbit")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(OrbitColor.textPrimary)
                    }
                    .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startedAt, style: .timer)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(OrbitColor.textPrimary)
                        .frame(maxWidth: 96, alignment: .trailing)
                        .minimumScaleFactor(0.7)
                        .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 10) {
                        WaveformBars(height: 22)
                        Text("Recording")
                            .font(.system(size: 13))
                            .foregroundStyle(OrbitColor.textSecondary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 6)
                    .padding(.top, 2)
                }
            } compactLeading: {
                RecordingMark(size: 14)
            } compactTrailing: {
                Text(context.state.startedAt, style: .timer)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .frame(maxWidth: 60)
                    .minimumScaleFactor(0.75)
            } minimal: {
                RecordingMark(size: 12)
            }
            .widgetURL(URL(string: "orbit://capture"))
        }
    }

    private func lockScreenView(state: CaptureActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Editorial eyebrow — matches the widget family
            // (Worth Revisiting, Most Recent, Quick Capture all use the
            // same dot-and-tracking caps treatment).
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                Text("ORBIT · RECORDING")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.9)
                    .foregroundStyle(OrbitColor.textTertiary)
            }

            // Hero timer + waveform on one row. The timer is the
            // glanceable element; the waveform is the "alive" signal.
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(state.startedAt, style: .timer)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(OrbitColor.textPrimary)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(1)
                WaveformBars(height: 22)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .activityBackgroundTint(OrbitColor.background)
        .activitySystemActionForegroundColor(OrbitColor.textPrimary)
    }
}

/// Recording mark: a small mic glyph wrapped in a thin pulsing ring.
/// Replaces the bare red dot. Reads as "premium app capturing audio"
/// rather than "generic alarm." Size parameterized so the same view
/// renders at 12 / 14 / 16pt across the three Dynamic Island regions
/// (minimal / compact / expanded) without per-region tweaks.
private struct RecordingMark: View {
    var size: CGFloat = 14

    @State private var pulse: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.red.opacity(pulse ? 0.0 : 0.55), lineWidth: 1.5)
                .frame(width: size * 1.9, height: size * 1.9)
                .scaleEffect(pulse ? 1.0 : 0.55)
                .animation(
                    .easeOut(duration: 1.2).repeatForever(autoreverses: false),
                    value: pulse
                )
            Image(systemName: "mic.fill")
                .font(.system(size: size * 0.85, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Color.red, in: .circle)
                .padding(2)
        }
        .frame(width: size * 1.9, height: size * 1.9)
        .onAppear { pulse = true }
    }
}

/// Seven decorative bars that pulse at their own period each, producing
/// a "live equalizer" look without needing per-tick Live Activity
/// updates (which iOS rate-limits aggressively). Each bar's
/// `.animation(.repeatForever)` is client-side rendering; the Activity
/// itself only updates when `CaptureActivityAttributes.ContentState`
/// changes.
private struct WaveformBars: View {
    var height: CGFloat = 22
    var color: Color = .red

    @State private var animate: Bool = false

    /// Per-bar (period, peak-height-fraction) tuples. Periods picked
    /// to be coprime-ish so the bars never sync up into a single
    /// breathing motion. Heights vary so the silhouette has texture
    /// even at peak amplitude.
    private let configs: [(duration: Double, peakFraction: CGFloat)] = [
        (0.70, 0.55),
        (0.92, 0.90),
        (0.58, 1.00),
        (1.08, 0.70),
        (0.80, 0.95),
        (0.96, 0.60),
        (0.74, 0.85)
    ]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(configs.indices, id: \.self) { i in
                let config = configs[i]
                Capsule()
                    .fill(color.opacity(0.85))
                    .frame(width: 3, height: animate ? height * config.peakFraction : height * 0.20)
                    .animation(
                        .easeInOut(duration: config.duration).repeatForever(autoreverses: true),
                        value: animate
                    )
            }
        }
        .frame(height: height)
        .onAppear { animate = true }
    }
}
