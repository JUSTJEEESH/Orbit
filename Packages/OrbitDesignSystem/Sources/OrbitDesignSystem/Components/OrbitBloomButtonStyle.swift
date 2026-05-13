import SwiftUI

/// Tints the button's surface with a category color while pressed, then
/// fades back out on release. Layered as an overlay so it composes cleanly
/// over `OrbitCard` and any other rounded surface.
///
/// Combine with `NavigationLink(value:)` to add a contextual bloom to a
/// row that pushes into detail:
///
/// ```swift
/// NavigationLink(value: route) {
///     MemoryRow(memory: memory)
/// }
/// .buttonStyle(OrbitBloomButtonStyle(tint: tint))
/// ```
public struct OrbitBloomButtonStyle: ButtonStyle {
    private let tint: Color
    private let cornerRadius: CGFloat
    private let intensity: Double

    public init(
        tint: Color,
        cornerRadius: CGFloat = OrbitRadius.lg,
        intensity: Double = 0.14
    ) {
        self.tint = tint
        self.cornerRadius = cornerRadius
        self.intensity = intensity
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? intensity : 0))
                    .allowsHitTesting(false)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.85), value: configuration.isPressed)
    }
}
