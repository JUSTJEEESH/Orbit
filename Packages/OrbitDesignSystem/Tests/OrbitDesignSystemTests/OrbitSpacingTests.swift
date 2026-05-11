import Testing
@testable import OrbitDesignSystem

/// The spacing scale is part of Orbit's contract with every feature. These
/// tests fail loudly if anyone tries to reshape it without a deliberate
/// design review.
struct OrbitSpacingTests {
    @Test func spacingScaleIsMonotonic() {
        let scale: [CGFloat] = [
            OrbitSpacing.xxs,
            OrbitSpacing.xs,
            OrbitSpacing.sm,
            OrbitSpacing.md,
            OrbitSpacing.lg,
            OrbitSpacing.xl,
            OrbitSpacing.xxl,
            OrbitSpacing.xxxl,
        ]
        #expect(scale == scale.sorted())
    }

    @Test func hitTargetMeetsHIG() {
        #expect(OrbitHitTarget.minimum >= 44)
    }
}
