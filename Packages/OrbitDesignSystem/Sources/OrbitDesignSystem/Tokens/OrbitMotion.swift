import SwiftUI

/// Motion tokens. All animations route through these constants so the entire
/// app shares one motion language. Springs only — no eased curves.
public enum OrbitMotion {
    /// Quick UI affordances (taps, button presses).
    public static let snap: Animation = .spring(response: 0.28, dampingFraction: 0.86)

    /// Default content transitions (sheet present, list reorder).
    public static let smooth: Animation = .spring(response: 0.42, dampingFraction: 0.88)

    /// Hero / matched-geometry transitions.
    public static let cinematic: Animation = .spring(response: 0.55, dampingFraction: 0.82)

    /// Subtle ambient motion (resurfacing, breathing dots).
    public static let ambient: Animation = .spring(response: 0.9, dampingFraction: 0.95)

    /// Returns the spring animation, or `nil` when the user has Reduce
    /// Motion enabled. Use with `withAnimation(OrbitMotion.respectfully(_:))`
    /// or `.animation(OrbitMotion.respectfully(_:), value: ...)` to honor
    /// the accessibility setting automatically.
    public static func respectfully(
        _ animation: Animation,
        reduceMotion: Bool
    ) -> Animation? {
        reduceMotion ? nil : animation
    }
}

/// View modifier that honors Reduce Motion by swapping springs for `nil`
/// (which yields an instant state change with no animation).
public struct OrbitAnimatedModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: Value

    public func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

public extension View {
    /// Animates `value` with the supplied spring unless Reduce Motion is on,
    /// in which case state changes apply instantly.
    func orbitAnimation<Value: Equatable>(_ animation: Animation, value: Value) -> some View {
        modifier(OrbitAnimatedModifier(animation: animation, value: value))
    }
}
