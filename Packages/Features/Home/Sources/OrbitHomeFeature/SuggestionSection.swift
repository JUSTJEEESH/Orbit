import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit
import OrbitMemoryDetailFeature

/// "Worth revisiting" surface on Home — a small ranked list of memories the
/// SuggestionEngine has scored as related to today's deterministic
/// memory-of-the-day. The anchor itself is not shown; the header + curated
/// ordering imply the editorial choice without needing to expose the engine.
///
/// Tap a card → opens the memory's detail view via the parent's
/// `NavigationStack`. Hero zoom transition shares the heroNamespace with
/// the Recent section so the visual handoff matches.
struct SuggestionSection: View {
    let feed: MemorySuggestionFeed
    let heroNamespace: Namespace.ID
    /// Called when the user picks "Don't suggest again" from a card's
    /// long-press menu. Parent (HomeView) wires this to the dismiss
    /// use case + a reload so the card disappears immediately.
    let onDismiss: @MainActor (UUID) -> Void

    @Environment(\.orbitTheme) private var orbitTheme

    var body: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Worth revisiting")
                .accessibilityAddTraits(.isHeader)
            ForEach(feed.related) { related in
                NavigationLink(value: MemoryDetailRoute(memoryID: related.memory.id)) {
                    SuggestionCardContent(memory: related.memory)
                }
                .buttonStyle(OrbitBloomButtonStyle(
                    tint: OrbitCategoryPalette.tint(for: related.memory.ai.category)
                ))
                .matchedTransitionSource(id: related.memory.id, in: heroNamespace)
                .contextMenu {
                    Button(role: .destructive) {
                        Haptics.play(.tap)
                        onDismiss(related.memory.id)
                    } label: {
                        Label("Don't suggest again", systemImage: "eye.slash")
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityLabel(for: related.memory))
                .accessibilityHint("Double-tap to open. Long-press for more.")
                .accessibilityAction(named: "Don't suggest again") {
                    onDismiss(related.memory.id)
                }
            }
        }
    }

    private func accessibilityLabel(for memory: Memory) -> String {
        let eyebrow = eyebrowText(for: memory)
        let headline = headlineText(for: memory)
        let relative = memory.createdAt.formatted(.relative(presentation: .named))
        return "Worth revisiting. \(eyebrow). \(headline). \(relative)."
    }

    private func eyebrowText(for memory: Memory) -> String {
        if let category = memory.ai.category?.trimmingCharacters(in: .whitespacesAndNewlines),
           !category.isEmpty {
            return category
        }
        return contentLabel(for: memory.content.kind)
    }

    private func headlineText(for memory: Memory) -> String {
        if let summary = memory.ai.summary, !summary.isEmpty { return summary }
        switch memory.content {
        case .text(let s):                          return s
        case .voiceNote(let transcript, _):         return transcript ?? "Voice note"
        case .image(let caption):                   return caption ?? "Photo"
        case .link(_, let title, let summary):      return summary ?? title ?? "Link"
        case .screenshot(let ocr):                  return ocr ?? "Screenshot"
        case .location(let name, _, _):             return name ?? "Location"
        }
    }

    private func contentLabel(for kind: MemoryContentKind) -> String {
        switch kind {
        case .text:        return "note"
        case .voiceNote:   return "voice"
        case .image:       return "photo"
        case .link:        return "link"
        case .screenshot:  return "screenshot"
        case .location:    return "place"
        }
    }
}

/// The card body. Pulled into its own view so the NavigationLink stays a
/// clean one-liner — and so we can preview it without a navigation stack.
private struct SuggestionCardContent: View {
    let memory: Memory

    var body: some View {
        OrbitCard(elevation: .resting) {
            VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                OrbitEyebrow(
                    label: eyebrowLabel,
                    suffix: memory.createdAt.formatted(.relative(presentation: .named)),
                    tint: OrbitCategoryPalette.tint(for: memory.ai.category)
                )
                HStack(alignment: .top, spacing: OrbitSpacing.sm) {
                    Image(systemName: icon(for: memory.content.kind))
                        .scaledFont(size: 14, weight: .regular)
                        .foregroundStyle(OrbitColor.textTertiary)
                        .padding(.top, 3)
                        .accessibilityHidden(true)
                    Text(headlineText)
                        .font(OrbitTypography.body)
                        .foregroundStyle(OrbitColor.textPrimary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var eyebrowLabel: String {
        if let category = memory.ai.category?.trimmingCharacters(in: .whitespacesAndNewlines),
           !category.isEmpty {
            return category
        }
        switch memory.content.kind {
        case .text:        return "note"
        case .voiceNote:   return "voice"
        case .image:       return "photo"
        case .link:        return "link"
        case .screenshot:  return "screenshot"
        case .location:    return "place"
        }
    }

    private var headlineText: String {
        if let summary = memory.ai.summary, !summary.isEmpty { return summary }
        switch memory.content {
        case .text(let s):                          return s
        case .voiceNote(let transcript, _):         return transcript ?? "Voice note"
        case .image(let caption):                   return caption ?? "Photo"
        case .link(_, let title, let summary):      return summary ?? title ?? "Link"
        case .screenshot(let ocr):                  return ocr ?? "Screenshot"
        case .location(let name, _, _):             return name ?? "Location"
        }
    }

    private func icon(for kind: MemoryContentKind) -> String {
        switch kind {
        case .text:        return "text.alignleft"
        case .voiceNote:   return "waveform"
        case .image:       return "photo"
        case .link:        return "link"
        case .screenshot:  return "rectangle.on.rectangle"
        case .location:    return "mappin"
        }
    }
}
