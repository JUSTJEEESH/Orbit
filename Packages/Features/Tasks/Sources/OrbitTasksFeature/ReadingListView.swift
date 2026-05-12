import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit

/// Smart-folder view over every memory's `signals.readingItems`. Grouped
/// by status with a one-tap circle that cycles want → reading → finished
/// → want. Tapping the row body opens the source memory.
struct ReadingListView: View {
    @Bindable var model: ReadingListViewModel
    let onOpenMemory: @MainActor (UUID) -> Void

    @Environment(\.orbitTheme) private var orbitTheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OrbitSpacing.xxl) {
                if model.sections.isEmpty {
                    emptyState
                } else {
                    if !model.sections.currentlyReading.isEmpty {
                        section(title: "Currently reading", entries: model.sections.currentlyReading)
                    }
                    if !model.sections.wantToRead.isEmpty {
                        section(title: "Want to read", entries: model.sections.wantToRead)
                    }
                    if !model.sections.finished.isEmpty {
                        section(title: "Finished", entries: model.sections.finished)
                    }
                }
                Spacer(minLength: 96)
            }
            .padding(.top, OrbitSpacing.lg)
        }
        .scrollIndicators(.hidden)
        .refreshable { await model.load() }
        .task { await model.load() }
    }

    private func section(title: String, entries: [ReadingListEntry]) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader(title)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: OrbitSpacing.sm) {
                ForEach(entries) { entry in
                    row(entry)
                }
            }
        }
    }

    private func row(_ entry: ReadingListEntry) -> some View {
        Button {
            onOpenMemory(entry.memoryID)
        } label: {
            OrbitCard(elevation: .resting) {
                HStack(alignment: .top, spacing: OrbitSpacing.md) {
                    statusButton(entry)
                    VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
                        Text(displayTitle(entry))
                            .font(OrbitTypography.body)
                            .foregroundStyle(entry.status == .finished
                                             ? OrbitColor.textTertiary
                                             : OrbitColor.textPrimary)
                            .strikethrough(entry.status == .finished, color: OrbitColor.textTertiary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let urlString = entry.url?.host {
                            Text(urlString)
                                .font(OrbitTypography.caption)
                                .foregroundStyle(OrbitColor.textTertiary)
                                .lineLimit(1)
                        }
                        Text(entry.memoryCreatedAt.formatted(.relative(presentation: .named)))
                            .font(OrbitTypography.caption)
                            .foregroundStyle(OrbitColor.textTertiary)
                    }
                }
            }
        }
        .buttonStyle(OrbitBloomButtonStyle(tint: orbitTheme.primary))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: entry))
        .accessibilityAction(named: nextStatusActionLabel(entry)) {
            Task { await model.advance(entry) }
        }
    }

    private func statusButton(_ entry: ReadingListEntry) -> some View {
        Button {
            Task { await model.advance(entry) }
        } label: {
            ZStack {
                Circle()
                    .stroke(strokeColor(for: entry.status), lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                Image(systemName: iconName(for: entry.status))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(strokeColor(for: entry.status))
                    .opacity(entry.status == .wantToRead ? 0 : 1)
            }
            .padding(.top, 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(statusButtonLabel(entry))
    }

    private func strokeColor(for status: ReadingItem.Status) -> Color {
        switch status {
        case .wantToRead:        return OrbitColor.separator
        case .currentlyReading:  return orbitTheme.primary
        case .finished:          return OrbitColor.textTertiary
        }
    }

    private func iconName(for status: ReadingItem.Status) -> String {
        switch status {
        case .wantToRead:        return "circle"
        case .currentlyReading:  return "book.fill"
        case .finished:          return "checkmark"
        }
    }

    private func displayTitle(_ entry: ReadingListEntry) -> String {
        if let title = entry.title, !title.isEmpty { return title }
        if let host = entry.url?.host { return host }
        return entry.url?.absoluteString ?? "Untitled"
    }

    private func nextStatusActionLabel(_ entry: ReadingListEntry) -> String {
        switch entry.status {
        case .wantToRead:        return "Mark as reading"
        case .currentlyReading:  return "Mark as finished"
        case .finished:          return "Move back to Want to read"
        }
    }

    private func statusButtonLabel(_ entry: ReadingListEntry) -> String {
        switch entry.status {
        case .wantToRead:        return "Want to read"
        case .currentlyReading:  return "Currently reading"
        case .finished:          return "Finished"
        }
    }

    private func accessibilityLabel(for entry: ReadingListEntry) -> String {
        "\(statusButtonLabel(entry)). \(displayTitle(entry)). Added \(entry.memoryCreatedAt.formatted(.relative(presentation: .named)))."
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
            Text("Nothing on the shelf yet")
                .font(OrbitTypography.title2)
                .foregroundStyle(OrbitColor.textPrimary)
            Text("Save a link or write \"I want to read…\" in a memory. Orbit will surface it here.")
                .font(OrbitTypography.body)
                .foregroundStyle(OrbitColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, OrbitSpacing.pageHorizontal)
        .padding(.top, OrbitSpacing.xxl)
    }
}
