import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit
import OrbitShareFeature

/// Full-screen recap experience. Lays out as an editorial reading
/// surface: oversized date, calm narrative paragraph, mood pill, capture
/// stats, then a list of highlight memories. No charts, no dashboards.
public struct DailyRecapView: View {
    @State private var model: DailyRecapViewModel
    @Environment(\.orbitTheme) private var orbitTheme
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
                if let recap = model.recap {
                    ToolbarItem(placement: .topBarLeading) {
                        OrbitShareCardButton(previewTitle: "Daily Recap") {
                            RecapShareCard(recap: recap)
                        }
                    }
                }
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
            if let snapshot = model.healthSnapshot {
                healthFooter(snapshot)
            }
        }
    }

    /// Quiet single line at the bottom of the recap surfacing the day's
    /// sleep + step totals from HealthKit. Visible only when the user has
    /// authorized read access AND we got at least one signal back.
    private func healthFooter(_ snapshot: HealthSnapshot) -> some View {
        HStack(spacing: OrbitSpacing.md) {
            if let sleep = snapshot.sleepDuration {
                healthStat(systemImage: "bed.double.fill", value: Self.formatSleep(sleep))
            }
            if snapshot.sleepDuration != nil, snapshot.steps != nil {
                Circle()
                    .fill(OrbitColor.textTertiary)
                    .frame(width: 3, height: 3)
            }
            if let steps = snapshot.steps {
                healthStat(systemImage: "figure.walk", value: Self.formatSteps(steps))
            }
            Spacer()
        }
        .padding(.top, OrbitSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Self.accessibilityLabel(for: snapshot))
    }

    private func healthStat(systemImage: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(OrbitColor.textTertiary)
            Text(value)
                .font(OrbitTypography.footnote)
                .foregroundStyle(OrbitColor.textSecondary)
        }
    }

    private static func formatSleep(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int((seconds / 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes)m asleep" }
        if minutes == 0 { return "\(hours)h asleep" }
        return "\(hours)h \(minutes)m asleep"
    }

    private static func formatSteps(_ steps: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let formatted = formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
        return "\(formatted) steps"
    }

    private static func accessibilityLabel(for snapshot: HealthSnapshot) -> String {
        var parts: [String] = []
        if let sleep = snapshot.sleepDuration { parts.append(formatSleep(sleep)) }
        if let steps = snapshot.steps { parts.append(formatSteps(steps)) }
        return parts.joined(separator: ", ")
    }

    private func header(_ recap: DailyRecap) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
            OrbitEyebrow(
                label: "Daily Recap",
                suffix: relativeDayLabel(recap.date),
                tint: orbitTheme.primary,
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
