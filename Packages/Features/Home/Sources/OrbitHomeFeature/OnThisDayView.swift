import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit
import OrbitMemoryDetailFeature

/// Full chronological surface for "On This Day" — every memory captured
/// on this calendar day in any past year, grouped by year newest-first.
/// Editorial layout: serif headlines, generous spacing, hero memory per
/// year. Premium-feel nostalgia.
public struct OnThisDayView: View {
    private let content: OnThisDayContent
    private let makeDetailViewModel: @MainActor (UUID) -> MemoryDetailViewModel
    private let onDismiss: @MainActor () -> Void

    @Namespace private var heroNamespace
    @Environment(\.orbitTheme) private var orbitTheme

    public init(
        content: OnThisDayContent,
        makeDetailViewModel: @escaping @MainActor (UUID) -> MemoryDetailViewModel,
        onDismiss: @escaping @MainActor () -> Void
    ) {
        self.content = content
        self.makeDetailViewModel = makeDetailViewModel
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            OrbitScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: OrbitSpacing.xxl) {
                        header
                        ForEach(content.memoriesByYear) { group in
                            yearSection(group)
                        }
                        Spacer(minLength: 48)
                    }
                    .padding(.top, OrbitSpacing.lg)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("On This Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDismiss)
                        .font(OrbitTypography.bodyEmphasized)
                }
            }
            .navigationDestination(for: MemoryDetailRoute.self) { route in
                MemoryDetailView(
                    viewModel: makeDetailViewModel(route.memoryID),
                    onDeleted: {}
                )
                .navigationTransition(.zoom(sourceID: route.memoryID, in: heroNamespace))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(orbitTheme.primary)
                Text("On This Day")
                    .font(OrbitTypography.caption)
                    .foregroundStyle(OrbitColor.textSecondary)
                    .tracking(1.1)
            }
            .accessibilityHidden(true)
            Text(dateLabel)
                .font(OrbitTypography.largeTitle)
                .foregroundStyle(OrbitColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(OrbitTypography.callout)
                .foregroundStyle(OrbitColor.textSecondary)
                .padding(.top, OrbitSpacing.xxs)
        }
    }

    private func yearSection(_ group: OnThisDayContent.YearGroup) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: OrbitSpacing.xs) {
                Text("\(yearsAgo(group.year))")
                    .font(.system(size: 32, weight: .semibold, design: .serif))
                    .foregroundStyle(orbitTheme.primary)
                Text(yearLabel(group.year))
                    .font(OrbitTypography.footnote)
                    .foregroundStyle(OrbitColor.textSecondary)
                    .tracking(0.6)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            VStack(spacing: OrbitSpacing.sm) {
                ForEach(group.memories) { memory in
                    memoryCard(memory)
                }
            }
        }
    }

    private func memoryCard(_ memory: Memory) -> some View {
        NavigationLink(value: MemoryDetailRoute(memoryID: memory.id)) {
            OrbitCard(elevation: .resting) {
                VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                    OrbitEyebrow(
                        label: eyebrowLabel(for: memory),
                        suffix: memory.createdAt.formatted(date: .abbreviated, time: .shortened),
                        tint: OrbitCategoryPalette.tint(for: memory.ai.category)
                    )
                    Text(headlineText(for: memory))
                        .font(OrbitTypography.body)
                        .foregroundStyle(OrbitColor.textPrimary)
                        .lineLimit(5)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .buttonStyle(OrbitBloomButtonStyle(
            tint: OrbitCategoryPalette.tint(for: memory.ai.category)
        ))
        .matchedTransitionSource(id: memory.id, in: heroNamespace)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(eyebrowLabel(for: memory)). \(headlineText(for: memory)).")
        .accessibilityHint("Double-tap to open.")
    }

    // MARK: - Helpers

    private var dateLabel: String {
        content.today.formatted(.dateTime.month(.wide).day())
    }

    private var subtitle: String {
        let count = content.totalCount
        let yearCount = content.memoriesByYear.count
        let memoryWord = count == 1 ? "memory" : "memories"
        let yearWord = yearCount == 1 ? "year" : "years"
        return "\(count) \(memoryWord) across \(yearCount) \(yearWord)."
    }

    private func yearsAgo(_ year: Int) -> String {
        let currentYear = Calendar.current.component(.year, from: content.today)
        let delta = currentYear - year
        if delta == 1 { return "1 year ago" }
        return "\(delta) years ago"
    }

    private func yearLabel(_ year: Int) -> String {
        "· \(year)"
    }

    private func eyebrowLabel(for memory: Memory) -> String {
        if let category = memory.ai.category?.trimmingCharacters(in: .whitespacesAndNewlines),
           !category.isEmpty {
            return category
        }
        switch memory.content.kind {
        case .text:       return "Note"
        case .voiceNote:  return "Voice"
        case .image:      return "Photo"
        case .link:       return "Link"
        case .screenshot: return "Screenshot"
        case .location:   return "Place"
        }
    }

    private func headlineText(for memory: Memory) -> String {
        if let summary = memory.ai.summary, !summary.isEmpty { return summary }
        switch memory.content {
        case .text(let s):                                   return s
        case .voiceNote(let transcript, _):                  return transcript ?? "Voice note"
        case .image(let caption):                            return caption ?? "Photo"
        case .link(_, let title, let summary):               return summary ?? title ?? "Link"
        case .screenshot(let ocr):                           return ocr ?? "Screenshot"
        case .location(let name, _, _):                      return name ?? "Location"
        }
    }
}
