import SwiftUI
import Charts
import OrbitDesignSystem
import OrbitDomain
import OrbitKit

/// Emergent habit tracker — habits aren't user-defined, they're aggregated
/// from `signals.habitMentions` across the memory store. Each row shows
/// total mentions, last-seen relative time, and a 12-week sparkline so the
/// user can see the cadence at a glance.
struct HabitsView: View {
    @Bindable var model: HabitsViewModel

    @Environment(\.orbitTheme) private var orbitTheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OrbitSpacing.xxl) {
                if model.habits.isEmpty {
                    emptyState
                } else {
                    header
                    VStack(spacing: OrbitSpacing.sm) {
                        ForEach(model.habits) { habit in
                            row(habit)
                        }
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

    private var header: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
            HStack(spacing: 6) {
                Image(systemName: "figure.run")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(orbitTheme.primary)
                Text("Last 12 weeks")
                    .font(OrbitTypography.caption)
                    .foregroundStyle(OrbitColor.textSecondary)
                    .tracking(1.0)
            }
            Text("Habits that emerged")
                .font(OrbitTypography.title2)
                .foregroundStyle(OrbitColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("Pulled from the verbs you mention. No setup needed — keep capturing and the shape fills in.")
                .font(OrbitTypography.footnote)
                .foregroundStyle(OrbitColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func row(_ habit: HabitStats) -> some View {
        OrbitCard(elevation: .resting) {
            HStack(alignment: .center, spacing: OrbitSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.habit.capitalized)
                        .font(OrbitTypography.bodyEmphasized)
                        .foregroundStyle(OrbitColor.textPrimary)
                    HStack(spacing: 8) {
                        Text("\(habit.totalMentions) \(habit.totalMentions == 1 ? "mention" : "mentions")")
                            .font(OrbitTypography.footnote)
                            .foregroundStyle(OrbitColor.textSecondary)
                        Text("·")
                            .foregroundStyle(OrbitColor.textTertiary)
                        Text(habit.lastMentionedAt.formatted(.relative(presentation: .named)))
                            .font(OrbitTypography.footnote)
                            .foregroundStyle(OrbitColor.textSecondary)
                    }
                }
                Spacer()
                sparkline(for: habit)
                    .frame(width: 110, height: 36)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(habit.habit). \(habit.totalMentions) mentions. Last \(habit.lastMentionedAt.formatted(.relative(presentation: .named))).")
    }

    private func sparkline(for habit: HabitStats) -> some View {
        let points = habit.weeklyCounts.enumerated().map { (idx, count) in
            SparkPoint(week: idx, count: count)
        }
        let maxCount = max(1, habit.weeklyCounts.max() ?? 1)
        return Chart(points) { point in
            BarMark(
                x: .value("Week", point.week),
                y: .value("Count", point.count),
                width: .ratio(0.55)
            )
            .foregroundStyle(orbitTheme.primary.opacity(point.count == 0 ? 0.15 : 0.85))
            .clipShape(RoundedRectangle(cornerRadius: 2.5))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...maxCount)
    }

    private struct SparkPoint: Identifiable {
        let week: Int
        let count: Int
        var id: Int { week }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
            Text("No habits yet")
                .font(OrbitTypography.title2)
                .foregroundStyle(OrbitColor.textPrimary)
            Text("Write \"ran 5k\" or \"meditated\" in a capture — Orbit will track the cadence here over time.")
                .font(OrbitTypography.body)
                .foregroundStyle(OrbitColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, OrbitSpacing.pageHorizontal)
        .padding(.top, OrbitSpacing.xxl)
    }
}
