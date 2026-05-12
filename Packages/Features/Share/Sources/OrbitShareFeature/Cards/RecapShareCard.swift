import SwiftUI
import OrbitDesignSystem
import OrbitDomain

/// Daily-Recap share card. Designed to feel like the recap's own
/// editorial surface, just laid out for a 4:5 export instead of a
/// scrolling sheet.
public struct RecapShareCard: View {
    let recap: DailyRecap
    @Environment(\.orbitTheme) private var theme

    public init(recap: DailyRecap) {
        self.recap = recap
    }

    public var body: some View {
        ShareCardSurface {
            ShareCardBrandMark()

            Spacer(minLength: 64)

            Text("Daily Recap".uppercased())
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(theme.primary)
                .padding(.bottom, 18)

            Text(recap.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(OrbitColor.textPrimary)
                .padding(.bottom, 40)

            Text(narrativeForCard)
                .font(.system(size: narrativeFontSize, weight: .regular, design: .serif))
                .foregroundStyle(OrbitColor.textPrimary)
                .lineSpacing(8)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            statsRow

            Spacer().frame(height: 32)

            ShareCardFooterLine(
                leading: "Orbit Daily Recap",
                trailing: recap.date.formatted(.dateTime.year())
            )
        }
    }

    private var narrativeForCard: String {
        // The full recap narrative can run multiple sentences. Card
        // typography breathes best at ~120 chars — trim with a
        // sentence-aware fallback so we never end mid-clause.
        let narrative = recap.narrative.trimmingCharacters(in: .whitespacesAndNewlines)
        guard narrative.count > 220 else { return narrative }
        let sentences = narrative.split(separator: ".", omittingEmptySubsequences: true)
        var assembled = ""
        for sentence in sentences {
            let candidate = assembled + sentence + "."
            if candidate.count > 220 { break }
            assembled = candidate
        }
        return assembled.isEmpty ? String(narrative.prefix(220)) + "…" : assembled
    }

    private var narrativeFontSize: CGFloat {
        narrativeForCard.count > 160 ? 32 : 38
    }

    private var statsRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 40) {
            stat(value: "\(recap.captureCount)", label: recap.captureCount == 1 ? "capture" : "captures")
            if let mood = recap.mood, !mood.isEmpty {
                Rectangle()
                    .fill(OrbitColor.separator)
                    .frame(width: 1, height: 56)
                stat(value: mood.capitalized, label: "mood")
            }
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(OrbitColor.textPrimary)
            Text(label.uppercased())
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(OrbitColor.textTertiary)
        }
    }
}
