import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit

/// Compact card for a single task hint waiting to be promoted. Renders the
/// phrase the SignalExtractor pulled, the source memory's headline, and a
/// theme-tinted "Add" capsule that promotes the hint into a real task.
struct SuggestionCard: View {
    let suggestion: ListTaskSuggestionsUseCase.Suggestion
    let onPromote: @MainActor () -> Void

    @Environment(\.orbitTheme) private var orbitTheme

    var body: some View {
        OrbitCard(elevation: .resting) {
            VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                OrbitEyebrow(
                    label: "Suggested",
                    suffix: suggestion.memory.createdAt.formatted(.relative(presentation: .named)),
                    tint: orbitTheme.primary
                )
                Text(suggestion.hint.phrase.capitalizingFirstLetter())
                    .font(OrbitTypography.bodyEmphasized)
                    .foregroundStyle(OrbitColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text("From: \(snippet)")
                    .font(OrbitTypography.footnote)
                    .foregroundStyle(OrbitColor.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: OrbitSpacing.sm) {
                    Spacer()
                    Button {
                        onPromote()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .scaledFont(size: 13, weight: .semibold)
                            Text("Add task")
                                .font(OrbitTypography.footnote)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(orbitTheme.primary)
                        .padding(.horizontal, OrbitSpacing.md)
                        .padding(.vertical, OrbitSpacing.xs)
                        .background(orbitTheme.primary.opacity(0.12), in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add task: \(suggestion.hint.phrase)")
                }
            }
        }
    }

    private var snippet: String {
        let memory = suggestion.memory
        if let summary = memory.ai.summary, !summary.isEmpty {
            return summary
        }
        switch memory.content {
        case .text(let s):                          return s
        case .voiceNote(let t, _):                  return t ?? "Voice note"
        case .image(let caption):                   return caption ?? "Photo"
        case .link(_, let title, let summary):      return summary ?? title ?? "Link"
        case .screenshot(let ocr):                  return ocr ?? "Screenshot"
        case .location(let name, _, _):             return name ?? "Place"
        }
    }
}

private extension String {
    func capitalizingFirstLetter() -> String {
        guard let first = first else { return self }
        return first.uppercased() + dropFirst()
    }
}
