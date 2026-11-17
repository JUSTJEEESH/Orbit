import SwiftUI

/// Three quiet dots that rise in turn — Orbit's "working on it" signal for
/// AI moments (Ask Orbit, recaps). Calmer than a spinner. With Reduce Motion
/// the dots sit still; the accompanying label carries the meaning.
public struct OrbitThinkingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var dotSize: CGFloat = 6

    private static let dotCount = 3
    /// How far a dot rises, as a fraction of its size.
    private static let lift: CGFloat = 0.6

    public init() {}

    public var body: some View {
        HStack(spacing: dotSize * 0.75) {
            ForEach(0..<Self.dotCount, id: \.self) { index in
                Circle()
                    .fill(OrbitColor.textTertiary)
                    .frame(width: dotSize, height: dotSize)
                    .phaseAnimator([false, true]) { dot, raised in
                        dot.offset(y: raised && !reduceMotion ? -dotSize * Self.lift : 0)
                    } animation: { _ in
                        reduceMotion ? nil : OrbitMotion.smooth.delay(Double(index) * 0.12)
                    }
            }
        }
        .accessibilityHidden(true)
    }
}
