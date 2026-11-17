import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit

/// A noticed place or person reminder: "At Mom's · Grab the ladder".
/// "Remind me" keeps it (after picking the spot, for places); "Not now"
/// hides it for good.
struct CueSuggestionCard: View {
    let suggestion: ListCueSuggestionsUseCase.Suggestion
    let onRemind: @MainActor () -> Void
    let onDismiss: @MainActor () -> Void

    @Environment(\.orbitTheme) private var orbitTheme

    private var isPlace: Bool {
        if case .place = suggestion.hint.target { return true }
        return false
    }

    var body: some View {
        OrbitCard(elevation: .resting) {
            VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                OrbitEyebrow(
                    label: suggestion.hint.targetLabel,
                    suffix: suggestion.memory.createdAt.formatted(.relative(presentation: .named)),
                    tint: orbitTheme.primary
                )
                Text(suggestion.hint.action.capitalizingFirstLetter())
                    .font(OrbitTypography.bodyEmphasized)
                    .foregroundStyle(OrbitColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: OrbitSpacing.sm) {
                    Spacer()
                    Button("Not now") { onDismiss() }
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textSecondary)
                        .buttonStyle(.plain)
                        .frame(minHeight: OrbitHitTarget.minimum)
                    Button {
                        onRemind()
                    } label: {
                        Label("Remind me", systemImage: isPlace ? "mappin.and.ellipse" : "person.fill")
                            .font(OrbitTypography.footnote)
                            .fontWeight(.semibold)
                            .foregroundStyle(orbitTheme.primary)
                            .padding(.horizontal, OrbitSpacing.md)
                            .padding(.vertical, OrbitSpacing.xs)
                            .background(orbitTheme.primary.opacity(0.12), in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remind me \(suggestion.hint.targetLabel.lowercased()): \(suggestion.hint.action)")
                }
            }
        }
    }
}
