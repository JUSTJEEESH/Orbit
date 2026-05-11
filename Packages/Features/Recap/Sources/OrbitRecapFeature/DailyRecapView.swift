import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit

/// Full-screen recap experience. Lays out as an editorial reading
/// surface: oversized date, calm narrative paragraph, mood pill, capture
/// stats, then a list of highlight memories. No charts, no dashboards.
public struct DailyRecapView: View {
    @State private var model: DailyRecapViewModel
    private let onDismiss: @MainActor () -> Void

    public init(
        viewModel: DailyRecapViewModel,
        onDismiss: @escaping @MainActor () -> Void
    ) {
        self._model = State(initialValue: viewModel)
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            OrbitScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: OrbitSpacing.xxl) {
                        content
                        Spacer(minLength: OrbitSpacing.xxxl)
                    }
                    .padding(.top, OrbitSpacing.lg)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDismiss)
                        .font(OrbitTypography.bodyEmphasized)
                }
            }
            .task { await model.load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, OrbitSpacing.xxxl)
        case .empty:
            emptyState
        case .failed(let message):
            errorState(message)
        case .loaded:
            if let recap = model.recap {
                loaded(recap)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            Text("Nothing to recap yet")
                .font(OrbitTypography.title2)
                .foregroundStyle(OrbitColor.textPrimary)
            Text("Capture a few moments today and Orbit will reflect the day back to you.")
                .font(OrbitTypography.body)
                .foregroundStyle(OrbitColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
            Text("Couldn't generate recap")
                .font(OrbitTypography.title3)
            Text(message)
                .font(OrbitTypography.footnote)
                .foregroundStyle(OrbitColor.textSecondary)
        }
    }

    private func loaded(_ recap: DailyRecap) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.xxl) {
            header(recap)
            narrative(recap)
            stats(recap)
            highlightsSection
        }
    }

    private func header(_ recap: DailyRecap) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
            OrbitEyebrow(
                label: "Daily Recap",
                suffix: relativeDayLabel(recap.date),
                tint: OrbitColor.accent,
                size: .prominent
            )
            Text(recap.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(OrbitTypography.largeTitle)
                .foregroundStyle(OrbitColor.textPrimary)
        }
    }

    private func narrative(_ recap: DailyRecap) -> some View {
        Text(recap.narrative)
            .font(.system(size: 22, weight: .regular, design: .serif))
            .foregroundStyle(OrbitColor.textPrimary)
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func stats(_ recap: DailyRecap) -> some View {
        HStack(spacing: OrbitSpacing.sm) {
            stat(value: "\(recap.captureCount)", label: recap.captureCount == 1 ? "capture" : "captures")
            if let mood = recap.mood, !mood.isEmpty {
                Divider()
                    .frame(height: 28)
                    .background(OrbitColor.separator)
                stat(value: mood.capitalized, label: "mood")
            }
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(OrbitTypography.title2)
                .foregroundStyle(OrbitColor.textPrimary)
            Text(label.uppercased())
                .font(OrbitTypography.caption)
                .tracking(1.0)
                .foregroundStyle(OrbitColor.textTertiary)
        }
    }

    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Highlights")
            if model.highlights.isEmpty {
                Text("No standout moments — every capture mattered equally.")
                    .font(OrbitTypography.footnote)
                    .foregroundStyle(OrbitColor.textSecondary)
            } else {
                ForEach(model.highlights) { memory in
                    OrbitCard(elevation: .resting) {
                        VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                            OrbitEyebrow(
                                label: eyebrowLabel(for: memory),
                                suffix: memory.createdAt.formatted(date: .omitted, time: .shortened),
                                tint: OrbitCategoryPalette.tint(for: memory.ai.category)
                            )
                            Text(headline(for: memory))
                                .font(OrbitTypography.body)
                                .foregroundStyle(OrbitColor.textPrimary)
                                .lineLimit(3)
                        }
                    }
                }
            }
        }
    }

    private func eyebrowLabel(for memory: Memory) -> String {
        if let category = memory.ai.category?.trimmingCharacters(in: .whitespacesAndNewlines),
           !category.isEmpty {
            return category
        }
        switch memory.content {
        case .text:        return "Note"
        case .voiceNote:   return "Voice"
        case .image:       return "Photo"
        case .link:        return "Link"
        case .screenshot:  return "Screenshot"
        case .location:    return "Place"
        }
    }

    private func headline(for memory: Memory) -> String {
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

    private func relativeDayLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "today" }
        if calendar.isDateInYesterday(date) { return "yesterday" }
        return date.formatted(.relative(presentation: .named))
    }
}
