import SwiftUI

/// A pulsing red dot. Tiny and disciplined: appears only when audio is
/// actively recording so users always know the mic is hot.
public struct RecordingIndicator: View {
    private let isActive: Bool
    @State private var pulse: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// One breath of the pulse. A looping pulse needs a timing curve:
    /// springs settle, so they can't breathe continuously.
    private static let pulseDuration: Double = 0.9

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
        // Reduce Motion: a steady, full-strength dot still says "recording".
        guard !reduceMotion else {
            pulse = true
            return
        }
        withAnimation(.easeInOut(duration: Self.pulseDuration).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}
