import SwiftUI
import WatchKit

/// Single-screen watch UI. Three states share the screen: idle (big record
/// button), recording (live timer + stop button), and post-stop status
/// (sending / sent / failed). Tight visual rhythm — premium feel on the
/// watch is brevity, not chrome.
struct WatchRootView: View {
    @State private var recorder = WatchRecorder()
    @State private var errorMessage: String?
    private let session = WatchSession.shared

    var body: some View {
        ZStack {
            if recorder.isRecording {
                recordingView
            } else {
                idleStateView
            }
        }
        .animation(.easeInOut(duration: 0.18), value: recorder.isRecording)
        .animation(.easeInOut(duration: 0.18), value: session.state)
    }

    // MARK: - Idle

    @ViewBuilder
    private var idleStateView: some View {
        switch session.state {
        case .idle:
            recordButton
        case .sending:
            statusView(systemImage: "arrow.up.circle", tint: .secondary, message: "Sending to iPhone…")
        case .sent:
            statusView(systemImage: "checkmark.circle.fill", tint: .green, message: "Saved")
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
            Text(errorMessage ?? "Tap to capture")
                .font(.footnote)
                .foregroundStyle(errorMessage == nil ? Color.secondary : Color.orange)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    // MARK: - Recording

    private var recordingView: some View {
        VStack(spacing: 18) {
            Text(formatted(recorder.elapsed))
                .font(.system(size: 42, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
            Button {
                Task { await endRecording() }
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background(.red, in: .circle)
            }
            .buttonStyle(.plain)
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

#Preview {
    WatchRootView()
}
