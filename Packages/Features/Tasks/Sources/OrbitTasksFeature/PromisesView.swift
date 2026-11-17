import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit

/// The Promise Ledger: things you told people you'd do. Orbit notices them
/// in what you capture ("I told Sam I'd send the photos"); you keep the real
/// ones and wave away the rest. Nothing is added without a tap.
struct PromisesView: View {
    let model: PromisesViewModel
    let onOpenTask: @MainActor (MemoryTask) -> Void
    let onOpenMemory: @MainActor (UUID) -> Void

    @Environment(\.orbitTheme) private var orbitTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OrbitSpacing.xxl) {
                if model.isEmpty {
                    emptyState
                } else {
                    if !model.ledger.suggestions.isEmpty { noticedSection }
                    if !model.ledger.open.isEmpty {
                        tasksSection("Open", subtitle: openSubtitle, tasks: model.ledger.open)
                    }
                    if !model.ledger.kept.isEmpty {
                        tasksSection("Kept", subtitle: nil, tasks: model.ledger.kept)
                    }
                }
                if let message = model.errorMessage {
                    Text(message)
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.danger)
                }
                // Clears the floating tab bar and capture accessory.
                Spacer(minLength: OrbitSpacing.xxxl * 2)
            }
            .padding(.top, OrbitSpacing.lg)
            .animation(OrbitMotion.respectfully(OrbitMotion.smooth, reduceMotion: reduceMotion), value: model.ledger)
        }
        .scrollIndicators(.hidden)
        .refreshable { await model.refresh() }
        .task { await model.refresh() }
    }

    private var openSubtitle: String {
        model.ledger.open.count == 1 ? "1 promise to keep" : "\(model.ledger.open.count) promises to keep"
    }

    // MARK: - Noticed

    private var noticedSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Noticed", subtitle: "Keep the ones you meant")
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: OrbitSpacing.sm) {
                ForEach(model.ledger.suggestions) { suggestion in
                    noticedCard(suggestion)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
            }
        }
    }

    private func noticedCard(_ suggestion: PromiseLedger.Suggestion) -> some View {
        OrbitCard(elevation: .resting) {
            VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                OrbitEyebrow(
                    label: "For \(suggestion.promise.person)",
                    suffix: suggestion.memory.createdAt.formatted(.relative(presentation: .named)),
                    tint: orbitTheme.primary
                )
                Text(suggestion.promise.item.capitalizingFirstLetter())
                    .font(OrbitTypography.bodyEmphasized)
                    .foregroundStyle(OrbitColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let due = suggestion.promise.dueDate {
                    Label(due.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textSecondary)
                }
                Button {
                    onOpenMemory(suggestion.memory.id)
                } label: {
                    Text("From: \(Self.snippet(suggestion.memory))")
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the memory this came from.")

                HStack(spacing: OrbitSpacing.sm) {
                    Spacer()
                    Button("Not a promise") {
                        Task { await model.dismiss(suggestion) }
                    }
                    .font(OrbitTypography.footnote)
                    .foregroundStyle(OrbitColor.textSecondary)
                    .buttonStyle(.plain)

                    Button {
                        Task { await model.keep(suggestion) }
                    } label: {
                        Label("Keep", systemImage: "hand.raised.fill")
                            .font(OrbitTypography.footnote)
                            .fontWeight(.semibold)
                            .foregroundStyle(orbitTheme.primary)
                            .padding(.horizontal, OrbitSpacing.md)
                            .padding(.vertical, OrbitSpacing.xs)
                            .background(orbitTheme.primary.opacity(0.12), in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Keep promise to \(suggestion.promise.person): \(suggestion.promise.item)")
                }
            }
        }
    }

    // MARK: - Kept

    private func tasksSection(_ title: String, subtitle: String?, tasks: [MemoryTask]) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader(title, subtitle: subtitle)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: OrbitSpacing.sm) {
                ForEach(tasks) { task in
                    TaskRowView(
                        task: task,
                        linkedMemory: nil,
                        onToggle: { Task { await model.toggle(task) } },
                        onTap: { onOpenTask(task) }
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        OrbitEmptyState(
            systemImage: "hand.raised",
            title: "No promises yet",
            message: "When you write something like \u{201C}I told Sam I\u{2019}d send the photos,\u{201D} Orbit notices it here, so nothing you promised slips."
        )
        .padding(.top, OrbitSpacing.xxl)
    }

    private static func snippet(_ memory: Memory) -> String {
        if let summary = memory.ai.summary, !summary.isEmpty { return summary }
        switch memory.content {
        case .text(let text):             return text
        case .voiceNote(let text, _):     return text ?? "Voice note"
        case .image(let caption):         return caption ?? "Photo"
        case .link(_, let title, _):      return title ?? "Link"
        case .screenshot(let text):       return text ?? "Screenshot"
        case .location(let name, _, _):   return name ?? "Place"
        }
    }
}
