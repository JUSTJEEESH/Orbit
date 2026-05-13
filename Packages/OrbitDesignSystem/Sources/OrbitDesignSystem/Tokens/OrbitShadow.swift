import SwiftUI

/// Shadow tokens. Use sparingly — depth in Orbit comes from solid layering
/// first, shadow second.
public struct OrbitShadow: Sendable {
    public let color: Color
    public let radius: CGFloat
    public let x: CGFloat
    public let y: CGFloat

    public static let none = OrbitShadow(color: .clear, radius: 0, x: 0, y: 0)

    /// A barely-there resting shadow for cards on light mode. Dark mode should
    /// generally use `.none` and rely on surface contrast.
    public static let resting = OrbitShadow(
        color: Color.black.opacity(0.06),
        radius: 18,
        x: 0,
        y: 8
    )

    public static let lifted = OrbitShadow(
        color: Color.black.opacity(0.10),
        radius: 28,
        x: 0,
        y: 14
    )
}

public extension View {
    func orbitShadow(_ shadow: OrbitShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}
