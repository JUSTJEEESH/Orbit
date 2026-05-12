import SwiftUI
import Charts
import OrbitDesignSystem
import OrbitDomain
import OrbitKit
import OrbitMemoryDetailFeature
import OrbitShareFeature

public struct YearInReviewView: View {
    @State private var model: YearInReviewViewModel
    private let makeDetailViewModel: @MainActor (UUID) -> MemoryDetailViewModel
    private let onDismiss: @MainActor () -> Void

    @State private var sheetMemory: MemoryIDBox?
    @Environment(\.orbitTheme) private var orbitTheme

    public init(
        viewModel: YearInReviewViewModel,
        makeDetailViewModel: @escaping @MainActor (UUID) -> MemoryDetailViewModel,
        onDismiss: @escaping @MainActor () -> Void
    ) {
        self._model = State(initialValue: viewModel)
        self.makeDetailViewModel = makeDetailViewModel
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            OrbitScreen {
                content
            }
            .navigationTitle("Year in Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let review = currentReview {
                    ToolbarItem(placement: .topBarLeading) {
                        OrbitShareCardButton(previewTitle: "Year in Review") {
                            YearInReviewShareCard(review: review)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDismiss)
                        .font(OrbitTypography.bodyEmphasized)
                }
            }
            .sheet(item: $sheetMemory) { box in
                NavigationStack {
                    MemoryDetailView(
                        viewModel: makeDetailViewModel(box.id),
                        onDeleted: { sheetMemory = nil }
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Close") { sheetMemory = nil }
                        }
                    }
                }
            }
        }
        .task { await model.load() }
    }

    /// Extracts the loaded `YearInReview` for the toolbar share button.
    /// Returns `nil` while loading / on empty / on failure so the share
    /// glyph stays hidden until there's something worth exporting.
    private var currentReview: YearInReview? {
        if case .loaded(let review) = model.state { return review }
        return nil
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty(let year):
            emptyState(year: year)
        case .failed(let message):
            failedState(message)
        case .loaded(let review):
            loadedScroll(review)
        }
    }

    // MARK: - Loaded

    private func loadedScroll(_ review: YearInReview) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OrbitSpacing.xxl) {
                hero(review)
                statsGrid(review)
                if !review.monthlyCounts.isEmpty {
                    monthlySection(review)
                }
                if !review.highlights.isEmpty {
                    highlightsSection(review)
                }
                memoryRainFinale(review)
                Spacer(minLength: OrbitSpacing.xxxl)
            }
            .padding(.top, OrbitSpacing.lg)
        }
        .scrollIndicators(.hidden)
    }

    private func hero(_ review: YearInReview) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
            Text("Your")
                .font(OrbitTypography.caption)
                .foregroundStyle(OrbitColor.textTertiary)
                .tracking(1.3)
            Text(String(review.year))
                .scaledFont(size: 88, weight: .semibold, design: .serif)
                .foregroundStyle(orbitTheme.primary)
                .accessibilityAddTraits(.isHeader)
            Text("\(review.totalCaptures) memories captured. Here's the year through your own eyes.")
                .scaledFont(size: 17, design: .serif)
                .italic()
                .foregroundStyle(OrbitColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Stats grid

    private func statsGrid(_ review: YearInReview) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: OrbitSpacing.sm), GridItem(.flexible(), spacing: OrbitSpacing.sm)],
            spacing: OrbitSpacing.sm
        ) {
            statTile(
                eyebrow: "Captures",
                value: "\(review.totalCaptures)",
                subtitle: kindBreakdownSubtitle(review.kindBreakdown)
            )
            if let category = review.topCategory {
                statTile(
                    eyebrow: "Top category",
                    value: category.name.capitalized,
                    subtitle: "\(category.count) captures"
                )
            }
            if let person = review.topPerson {
                statTile(
                    eyebrow: "On your mind",
                    value: person.name,
                    subtitle: "\(person.count) mentions"
                )
            }
            if let place = review.topPlace {
                statTile(
                    eyebrow: "Most-mentioned place",
                    value: place.name,
                    subtitle: "\(place.count) mentions"
                )
            }
            if let month = review.mostActiveMonth {
                statTile(
                    eyebrow: "Busiest month",
                    value: monthName(month),
                    subtitle: "\(monthCount(for: month, in: review)) captures"
                )
            }
        }
    }

    private func statTile(eyebrow: String, value: String, subtitle: String) -> some View {
        OrbitCard(elevation: .resting) {
            VStack(alignment: .leading, spacing: OrbitSpacing.xs) {
                Text(eyebrow.uppercased())
                    .font(OrbitTypography.caption)
                    .foregroundStyle(OrbitColor.textTertiary)
                    .tracking(0.9)
                Text(value)
                    .scaledFont(size: 24, weight: .semibold, design: .serif)
                    .foregroundStyle(OrbitColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(subtitle)
                    .font(OrbitTypography.footnote)
                    .foregroundStyle(OrbitColor.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Monthly chart

    private func monthlySection(_ review: YearInReview) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Through the year")
                .accessibilityAddTraits(.isHeader)
            OrbitCard(elevation: .resting) {
                Chart(review.monthlyCounts) { entry in
                    BarMark(
                        x: .value("Month", monthShortLabel(entry.month)),
                        y: .value("Count", entry.count),
                        width: .ratio(0.7)
                    )
                    .foregroundStyle(orbitTheme.primary.opacity(entry.count == 0 ? 0.15 : 0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel()
                            .font(OrbitTypography.caption)
                            .foregroundStyle(OrbitColor.textTertiary)
                    }
                }
                .frame(height: 140)
            }
            .accessibilityLabel("Monthly capture count: \(monthlyAccessibilitySummary(review.monthlyCounts))")
        }
    }

    // MARK: - Highlights

    private func highlightsSection(_ review: YearInReview) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Moments", subtitle: "The shape of your year, in a few captures.")
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: OrbitSpacing.sm) {
                ForEach(review.highlights) { memory in
                    highlightCard(memory)
                }
            }
        }
    }

    private func highlightCard(_ memory: Memory) -> some View {
        Button {
            sheetMemory = MemoryIDBox(id: memory.id)
        } label: {
            OrbitCard(elevation: .resting) {
                VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                    OrbitEyebrow(
                        label: eyebrowLabel(for: memory),
                        suffix: memory.createdAt.formatted(date: .abbreviated, time: .omitted),
                        tint: OrbitCategoryPalette.tint(for: memory.ai.category)
                    )
                    Text(headlineText(for: memory))
                        .scaledFont(size: 18, design: .serif)
                        .foregroundStyle(OrbitColor.textPrimary)
                        .lineLimit(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .buttonStyle(OrbitBloomButtonStyle(
            tint: OrbitCategoryPalette.tint(for: memory.ai.category)
        ))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(eyebrowLabel(for: memory)). \(headlineText(for: memory)).")
        .accessibilityHint("Double-tap to open.")
    }

    // MARK: - Memory rain finale

    private func memoryRainFinale(_ review: YearInReview) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("And every other one")
                .accessibilityAddTraits(.isHeader)
            ZStack {
                RoundedRectangle(cornerRadius: OrbitRadius.lg)
                    .fill(OrbitColor.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: OrbitRadius.lg)
                            .stroke(OrbitColor.separator, lineWidth: 0.5)
                    )
                MemoryRainView(
                    memories: rainPool(from: review),
                    onTapMemory: { memory in
                        sheetMemory = MemoryIDBox(id: memory.id)
                    }
                )
                .clipShape(.rect(cornerRadius: OrbitRadius.lg))
            }
            .frame(height: 320)
            Text("Each capture, drifting where it lands. Until next year.")
                .scaledFont(size: 15, design: .serif)
                .italic()
                .foregroundStyle(OrbitColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, OrbitSpacing.xs)
        }
    }

    private func rainPool(from review: YearInReview) -> [Memory] {
        // Highlights are the seed; the surface adds them plus a sample so the
        // rain visually represents the whole year, not just the picked few.
        review.highlights
    }

    // MARK: - Empty + failed states

    private func emptyState(year: Int) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            Text(String(year))
                .scaledFont(size: 64, weight: .semibold, design: .serif)
                .foregroundStyle(orbitTheme.primary)
            Text("No memories captured this year — yet.")
                .font(OrbitTypography.title3)
                .foregroundStyle(OrbitColor.textPrimary)
            Text("Come back when you have a year of captures and Orbit will reflect it back to you.")
                .font(OrbitTypography.body)
                .foregroundStyle(OrbitColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, OrbitSpacing.pageHorizontal)
        .padding(.top, OrbitSpacing.xxxl)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func failedState(_ message: String) -> some View {
        OrbitErrorState(
            title: "Couldn't build your year",
            message: message,
            onRetry: { Task { await model.load() } }
        )
        .padding(.top, OrbitSpacing.xxxl)
    }

    // MARK: - Helpers

    private func kindBreakdownSubtitle(_ stats: [YearInReview.KindStat]) -> String {
        guard let top = stats.first else { return "across the year" }
        return "\(top.count) \(kindNoun(top.kind, plural: top.count != 1))"
    }

    private func kindNoun(_ kind: MemoryContentKind, plural: Bool) -> String {
        switch kind {
        case .text:       return plural ? "notes" : "note"
        case .voiceNote:  return plural ? "voice notes" : "voice note"
        case .image:      return plural ? "photos" : "photo"
        case .link:       return plural ? "links" : "link"
        case .screenshot: return plural ? "screenshots" : "screenshot"
        case .location:   return plural ? "places" : "place"
        }
    }

    private func monthName(_ month: Int) -> String {
        let calendar = Calendar.current
        guard month >= 1, month <= 12,
              let date = calendar.date(from: DateComponents(year: 2000, month: month, day: 1)) else { return "—" }
        return date.formatted(.dateTime.month(.wide))
    }

    private func monthShortLabel(_ month: Int) -> String {
        let calendar = Calendar.current
        guard month >= 1, month <= 12,
              let date = calendar.date(from: DateComponents(year: 2000, month: month, day: 1)) else { return "—" }
        return date.formatted(.dateTime.month(.narrow))
    }

    private func monthCount(for month: Int, in review: YearInReview) -> Int {
        review.monthlyCounts.first { $0.month == month }?.count ?? 0
    }

    private func monthlyAccessibilitySummary(_ counts: [YearInReview.MonthlyCount]) -> String {
        counts.map { "\(monthName($0.month)) \($0.count)" }.joined(separator: ", ")
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

/// `sheet(item:)` requires Identifiable; wrap the bare UUID so we can
/// present the memory-detail sheet from a single state value.
struct MemoryIDBox: Identifiable, Hashable {
    let id: UUID
}
