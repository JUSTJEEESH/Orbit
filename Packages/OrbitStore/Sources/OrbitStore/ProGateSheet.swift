import SwiftUI
import OrbitDesignSystem
import OrbitKit

/// The soft contextual paywall. Shown when a free user lands on a
/// gated surface — leads with a celebratory framing ("you've savored
/// your free recaps") instead of scolding the user for hitting a
/// limit, then routes them to the full PaywallView for product
/// selection.
///
/// Presented at the medium detent so it doesn't feel like a hard wall
/// — users can flick it away without losing context.
public struct ProGateSheet: View {
    private let gate: ProGate
    private let onSeeProDetails: @MainActor () -> Void
    private let onDismiss: @MainActor () -> Void

    public init(
        gate: ProGate,
        onSeeProDetails: @escaping @MainActor () -> Void,
        onDismiss: @escaping @MainActor () -> Void
    ) {
        self.gate = gate
        self.onSeeProDetails = onSeeProDetails
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            OrbitScreen {
                VStack(alignment: .leading, spacing: OrbitSpacing.lg) {
                    eyebrow
                    icon
                    headline
                    Spacer(minLength: OrbitSpacing.md)
                    ctaStack
                }
                .padding(.vertical, OrbitSpacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Not now", action: onDismiss)
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var eyebrow: some View {
        Text(gate.label.uppercased())
            .font(OrbitTypography.caption)
            .tracking(1.4)
            .foregroundStyle(OrbitColor.textTertiary)
    }

    private var icon: some View {
        Image(systemName: gate.systemImage)
            .font(.system(size: 44, weight: .light))
            .foregroundStyle(OrbitColor.textPrimary)
            .padding(.top, OrbitSpacing.xs)
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
            Text(gate.celebratoryHeadline)
                .font(OrbitTypography.title2)
                .foregroundStyle(OrbitColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(gate.supportingCopy)
                .font(OrbitTypography.body)
                .foregroundStyle(OrbitColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var ctaStack: some View {
        VStack(spacing: OrbitSpacing.sm) {
            OrbitButton(
                "See Orbit Pro",
                systemImage: "sparkles",
                style: .primary,
                size: .large
            ) {
                Haptics.play(.tap)
                onSeeProDetails()
            }
            Button("Maybe later", action: onDismiss)
                .font(OrbitTypography.callout)
                .foregroundStyle(OrbitColor.textSecondary)
                .padding(.top, OrbitSpacing.xxs)
        }
    }
}
