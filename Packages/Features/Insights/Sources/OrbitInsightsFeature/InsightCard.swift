import SwiftUI
import Charts
import OrbitDesignSystem
import OrbitDomain

/// The visual unit used for every insight surface — Home preview and the
/// patterns list. Two density modes: `.compact` for Home (no chart),
/// `.expanded` for the patterns screen (chart + detail).
public struct InsightCard: View {
    public enum Density { case compact, expanded }

    private let insight: SmartInsight
    private let density: Density
    @Environment(\.orbitTheme) private var orbitTheme

    public init(insight: SmartInsight, density: Density = .compact) {
        self.insight = insight
        self.density = density
    }

    public var body: some View {
        OrbitCard(elevation: density == .compact ? .resting : .lifted) {
            VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                OrbitEyebrow(
                    label: insight.kind.label,
                    suffix: shortTimestamp,
                    tint: orbitTheme.primary
                )
                headlineRow
                Text(insight.body)
                    .font(OrbitTypography.callout)
                    .foregroundStyle(OrbitColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if density == .expanded {
                    if let detail = insight.detail, detail != insight.body {
                        Text(detail)
                            .font(OrbitTypography.footnote)
                            .foregroundStyle(OrbitColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, OrbitSpacing.xxs)
                    }
                    if !insight.sparkline.isEmpty {
                        sparkline
                            .padding(.top, OrbitSpacing.sm)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    /// VoiceOver reads the insight as a single sentence, with the sparkline
    /// summarized as "trend over 8 weeks: 0, 1, 3, 4…" rather than silent.
    private var accessibilityLabel: String {
        var parts: [String] = ["\(insight.kind.label). \(insight.headline). \(insight.body)"]
        if density == .expanded {
            if let detail = insight.detail, detail != insight.body {
                parts.append(detail)
            }
            if !insight.sparkline.isEmpty {
                let series = insight.sparkline.map(String.init).joined(separator: ", ")
                parts.append("Weekly trend: \(series).")
            }
        }
        return parts.joined(separator: " ")
    }

    private var headlineRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: OrbitSpacing.xs) {
            Text(insight.headline)
                .font(.system(size: density == .compact ? 22 : 26, weight: .semibold, design: .serif))
                .foregroundStyle(OrbitColor.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if density == .compact {
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OrbitColor.textTertiary)
            }
        }
    }

    private var sparkline: some View {
        let max = (insight.sparkline.max() ?? 0)
        let series = insight.sparkline.enumerated().map { (index, value) in
            SparkPoint(week: index, count: value)
        }
        return Chart(series) { point in
            BarMark(
                x: .value("Week", point.week),
                y: .value("Count", point.count),
                width: .ratio(0.55)
            )
            .foregroundStyle(orbitTheme.primary.opacity(point.count == 0 ? 0.15 : 0.85))
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...Swift.max(1, max))
        .frame(height: 48)
        .accessibilityHidden(true)
    }

    private var shortTimestamp: String {
        insight.generatedAt.formatted(.relative(presentation: .named))
    }
}

private struct SparkPoint: Identifiable {
    let week: Int
    let count: Int
    var id: Int { week }
}
