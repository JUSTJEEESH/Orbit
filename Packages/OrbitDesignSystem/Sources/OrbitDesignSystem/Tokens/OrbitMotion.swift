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
}
