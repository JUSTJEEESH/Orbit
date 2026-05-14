import SwiftUI
import WatchKit

/// Single-screen watch UI. Three states share the screen: idle (big record
/// button), recording (live timer + waveform + stop button), and
/// post-stop status (sending / sent / failed). Tight visual rhythm —
/// premium feel on the watch is brevity, not chrome.
///
/// The recording-state waveform mirrors the Live Activity treatment (per-bar
/// independent animation periods so the bars never sync into a single
/// breathing motion) so the Watch and lock-screen surfaces feel like one
/// family for the same action.
struct WatchRootView: View {
    @State private var recorder = WatchRecorder()
    @State private var errorMessage: String?
    /// Flips true ~6s into a `.sending` state if the transfer hasn't
    /// completed. The Watch's WCSession.transferFile is fire-and-forget;
    /// when the iPhone app is suspended the file queues and the Watch
    /// has no signal beyond "still sending." This hint surfaces the
    /// one thing the user can do to unblock it without falsely claiming
    /// failure.
    @State private var sendingHint: Bool = false
    private let session = WatchSession.shared

    var body: some View {
        ZStack {
            if recorder.isRecording {
                recordingView
            } else {
                idleStateView
            }
        }
        .animation(.easeInOut(duration: 0.22), value: recorder.isRecording)
        .animation(.easeInOut(duration: 0.22), value: session.state)
        .animation(.easeInOut(duration: 0.22), value: sendingHint)
        .onChange(of: session.state) { _, newState in
            if case .sending = newState {
                sendingHint = false
                Task {
                    try? await Task.sleep(for: .seconds(6))
                    if case .sending = session.state {
                        sendingHint = true
                    }
                }
            } else {
                sendingHint = false
            }
        }
    }

    // MARK: - Idle

    @ViewBuilder
    private var idleStateView: some View {
        switch session.state {
        case .idle:
            recordButton
        case .sending:
            statusView(
                systemImage: "arrow.up.circle",
                tint: .secondary,
                message: sendingHint
                    ? "Sending…\nOpen Orbit on iPhone to finish."
                    : "Sending…"
            )
        case .sent:
            statusView(systemImage: "checkmark.circle.fill", tint: .green, message: "Saved to Orbit")
        case .failed(let message):
            failureView(message: message)
        }
    }

    private var recordButton: some View {
        VStack(spacing: 12) {
            Button {
                Task { await beginRecording() }
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 92, height: 92)
                    .background(.red, in: .circle)
            }
            .buttonStyle(.plain)
            Text(errorMessage ?? "Capture")
                .font(.footnote)
                .fontWeight(errorMessage == nil ? .semibold : .regular)
                .foregroundStyle(errorMessage == nil ? Color.secondary : Color.orange)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    // MARK: - Recording

    private var recordingView: some View {
        VStack(spacing: 10) {
            Text(formatted(recorder.elapsed))
                .font(.system(size: 38, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
            WatchWaveformBars()
                .frame(height: 14)
                .padding(.horizontal, 24)
            Button {
                Task { await endRecording() }
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 68, height: 68)
                    .background(.red, in: .circle)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    // MARK: - Status

    private func statusView(systemImage: String, tint: Color, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(tint)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
    }

    private func failureView(message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
            Button("Try again") { session.reset() }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Actions

    private func beginRecording() async {
        errorMessage = nil
        do {
            _ = try await recorder.start()
            playTactileStart()
        } catch {
            errorMessage = error.localizedDescription
            playTactileError()
        }
    }

    private func endRecording() async {
        guard let result = recorder.stop() else { return }
        playTactileStop()
        session.send(fileAt: result.url, duration: result.duration)
    }

    // MARK: - Haptics

    private func playTactileStart() {
        WKInterfaceDevice.current().play(.start)
    }
    private func playTactileStop() {
        WKInterfaceDevice.current().play(.stop)
    }
    private func playTactileError() {
        WKInterfaceDevice.current().play(.failure)
    }

    // MARK: - Helpers

    private func formatted(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Five decorative bars that pulse on independent periods. Mirrors the
/// Live Activity waveform but at watch-appropriate dimensions: shorter
/// bars (max 14pt), fewer bars (5 instead of 7), tighter spacing.
/// Pure client-side animation — no per-tick updates flowing from the
/// recorder, which is important on watchOS where wakeups are
/// power-expensive.
private struct WatchWaveformBars: View {
    @State private var animate: Bool = false

    /// Per-bar (period, peak-fraction). Periods picked to be coprime-ish
    /// so the bars never sync into a single breathing motion.
    private let configs: [(duration: Double, peakFraction: CGFloat)] = [
        (0.70, 0.60),
        (0.92, 1.00),
        (0.58, 0.85),
        (1.04, 0.75),
        (0.78, 0.95)
    ]

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(configs.indices, id: \.self) { i in
                let config = configs[i]
                Capsule()
                    .fill(Color.red.opacity(0.85))
                    .frame(width: 3, height: animate ? 14 * config.peakFraction : 3)
                    .animation(
                        .easeInOut(duration: config.duration).repeatForever(autoreverses: true),
                        value: animate
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear { animate = true }
    }
}

#Preview {
    WatchRootView()
}
