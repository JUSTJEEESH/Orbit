import SwiftUI
import OrbitDesignSystem
import OrbitKit

/// Shown once after updating to Orbit 2 (and, in a shorter form, right
/// after onboarding for new users). It introduces what changed and asks the
/// one question 2.0 needs answered: should memories sync with iCloud?
struct WhatsNewView: View {
    enum Audience {
        /// Updated from 1.x: the full tour.
        case existingUser
        /// Just finished onboarding: only the iCloud question.
        case newUser
    }

    let audience: Audience
    /// Memories 1.x saved with Siri that 2.0 recovered (0 hides the row).
    let rescuedMemoryCount: Int
    let asksAboutSync: Bool
    let onChooseSync: @MainActor (Bool) -> Void
    let onContinue: @MainActor () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: OrbitSpacing.xxl) {
                    Text(title)
                        .font(OrbitTypography.largeTitle)
                        .foregroundStyle(OrbitColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, OrbitSpacing.xxxl)

                    VStack(alignment: .leading, spacing: OrbitSpacing.xl) {
                        ForEach(features) { feature in
                            FeatureRow(feature: feature)
                        }
                    }
                }
                .padding(.horizontal, OrbitSpacing.xl)
                .padding(.bottom, OrbitSpacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            buttons
                .padding(.horizontal, OrbitSpacing.xl)
                .padding(.vertical, OrbitSpacing.lg)
        }
        .background(OrbitColor.background.ignoresSafeArea())
        .interactiveDismissDisabled(asksAboutSync)
    }

    private var title: String {
        switch audience {
        case .existingUser: "What’s New in Orbit"
        case .newUser:      "Keep Your Memories Safe"
        }
    }

    @ViewBuilder
    private var buttons: some View {
        VStack(spacing: OrbitSpacing.sm) {
            if asksAboutSync {
                OrbitButton("Turn On iCloud Sync", systemImage: "icloud", style: .primary, size: .large) {
                    onChooseSync(true)
                }
                Button {
                    onChooseSync(false)
                } label: {
                    Text("Keep on This iPhone Only")
                        .font(OrbitTypography.bodyEmphasized)
                        .foregroundStyle(OrbitColor.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: OrbitHitTarget.minimum)
                }
                .buttonStyle(.plain)
                Text("You can change this anytime in Settings.")
                    .font(OrbitTypography.footnote)
                    .foregroundStyle(OrbitColor.textTertiary)
            } else {
                OrbitButton("Continue", style: .primary, size: .large) { onContinue() }
            }
        }
    }

    private var features: [Feature] {
        var items: [Feature] = []
        if rescuedMemoryCount > 0 {
            items.append(Feature(
                systemImage: "sparkles",
                title: rescuedMemoryCount == 1 ? "We found a lost memory" : "We found \(rescuedMemoryCount) lost memories",
                detail: "Things you saved with Siri in the previous version never showed up. They’re in your timeline now."
            ))
        }
        items.append(Feature(
            systemImage: "icloud",
            title: "On all your devices",
            detail: "Sync privately through your own iCloud. Your memories are stored in your account — Orbit can’t see them."
        ))
        guard audience == .existingUser else { return items }
        items += [
            Feature(
                systemImage: "arrow.uturn.backward",
                title: "Nothing is lost by accident",
                detail: "Deleted memories wait in Recently Deleted for 30 days, and every delete can be undone."
            ),
            Feature(
                systemImage: "pencil",
                title: "Edit anything",
                detail: "Fix a transcript, rename a link, or change tags — Orbit re-organizes it for you."
            ),
            Feature(
                systemImage: "magnifyingglass",
                title: "Sharper search",
                detail: "Results now show what you meant, not everything with a passing resemblance."
            ),
            Feature(
                systemImage: "square.and.arrow.up",
                title: "Take it with you",
                detail: "Export every memory, photo and recording in open formats from Settings."
            ),
        ]
        return items
    }
}

private struct Feature: Identifiable {
    var id: String { title }
    let systemImage: String
    let title: String
    let detail: String
}

private struct FeatureRow: View {
    let feature: Feature
    @Environment(\.orbitTheme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: OrbitSpacing.md) {
            Image(systemName: feature.systemImage)
                .font(OrbitTypography.title2)
                .foregroundStyle(theme.primary)
                .symbolRenderingMode(.hierarchical)
                .frame(width: OrbitSpacing.xxxl)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
                Text(feature.title)
                    .font(OrbitTypography.bodyEmphasized)
                    .foregroundStyle(OrbitColor.textPrimary)
                Text(feature.detail)
                    .font(OrbitTypography.callout)
                    .foregroundStyle(OrbitColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Existing user") {
    WhatsNewView(audience: .existingUser, rescuedMemoryCount: 4, asksAboutSync: true, onChooseSync: { _ in }, onContinue: {})
}

#Preview("New user") {
    WhatsNewView(audience: .newUser, rescuedMemoryCount: 0, asksAboutSync: true, onChooseSync: { _ in }, onContinue: {})
}
