import SwiftUI

/// A pulsing red dot. Tiny and disciplined: appears only when audio is
/// actively recording so users always know the mic is hot.
public struct RecordingIndicator: View {
    private let isActive: Bool
    @State private var pulse: Bool = false

    public init(isActive: Bool) {
        self.isActive = isActive
    }

    public var body: some View {
        Circle()
            .fill(OrbitColor.danger)
            .frame(width: 12, height: 12)
            .scaleEffect(pulse ? 1.0 : 0.6)
            .opacity(pulse ? 1.0 : 0.5)
            .onAppear { if isActive { startPulse() } }
            .onChange(of: isActive) { _, newValue in
                if newValue { startPulse() } else { pulse = false }
            }
            .accessibilityLabel(isActive ? "Recording" : "Idle")
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}
