import SwiftUI
import OrbitDesignSystem
import OrbitDomain

/// Daily Recap share card.
///
/// Leads with the calendar — day-of-week as a serif headline, the day
/// number as a 280pt numeric hero, month + year tucked beside it as
/// small caps support. Below the date block, the recap narrative reads
/// like an editor's note. Stats sit at the very bottom as a tight
/// stat-line, the way Things 3 surfaces counts: huge value, tiny label.
public struct RecapShareCard: View {
    let recap: DailyRecap
    @Environment(\.orbitTheme) private var theme

    public init(recap: DailyRecap) {
        self.recap = recap
    }

    public var body: some View {
        ShareCardSurface {
            ShareCardTopRail(stamp: "Daily Recap")

            Spacer().frame(height: 36)

            ShareCardHairline()

            Spacer().frame(height: 60)

            dateHero

            Spacer().frame(height: 48)

            Text(narrativeForCard)
                .font(.system(size: narrativeFontSize, weight: .regular, design: .serif))
                .foregroundStyle(OrbitColor.textPrimary)
                .lineSpacing(narrativeFontSize >= 36 ? 4 : 6)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            ShareCardHairline()

            Spacer().frame(height: 28)

            statsRow

            Spacer().frame(height: 28)

            ShareCardHairline()

            Spacer().frame(height: 22)

            ShareCardPublisherLine()
        }
    }

    /// Calendar-block hero. Day-of-week in serif at the top, the
    /// numeric day as a giant 280pt glyph beside the month/year.
    /// Asymmetric weight — bold left, quiet right — gives the card
    /// the same architecture as the date stamp on a printed letter.
    private var dateHero: some View {
        HStack(alignment: .firstTextBaseline, spacing: 28) {
            Text(dayNumber)
                .font(.system(size: 260, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.primary)
                .baselineOffset(0)
                .fixedSize()

            VStack(alignment: .leading, spacing: 8) {
                Text(weekdayName)
                    .font(.system(size: 56, weight: .regular, design: .serif))
                    .foregroundStyle(OrbitColor.textPrimary)
                Text(monthYear.uppercased())
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .tracking(2.4)
                    .foregroundStyle(OrbitColor.textTertiary)
            }
            Spacer()
        }
    }

    private var statsRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 56) {
            stat(value: "\(recap.captureCount)", label: recap.captureCount == 1 ? "capture" : "captures")
            if let mood = recap.mood, !mood.isEmpty {
                Rectangle()
                    .fill(OrbitColor.separator)
                    .frame(width: 1, height: 60)
                stat(value: mood.capitalized, label: "mood")
            }
            Spacer()
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(OrbitColor.textPrimary)
            Text(label.uppercased())
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .tracking(2.0)
                .foregroundStyle(OrbitColor.textTertiary)
        }
    }

    private var narrativeForCard: String {
        let narrative = recap.narrative.trimmingCharacters(in: .whitespacesAndNewlines)
        guard narrative.count > 240 else { return narrative }
        // Sentence-aware trim — never cut mid-clause.
        let sentences = narrative.split(separator: ".", omittingEmptySubsequences: true)
        var assembled = ""
        for sentence in sentences {
            let candidate = assembled + sentence + "."
            if candidate.count > 240 { break }
            assembled = candidate
        }
        return assembled.isEmpty ? String(narrative.prefix(240)) + "…" : assembled
    }

    private var narrativeFontSize: CGFloat {
        switch narrativeForCard.count {
        case 0..<120:    return 40
        case 120..<200:  return 34
        default:         return 30
        }
    }

    private var dayNumber: String {
        let day = Calendar.current.component(.day, from: recap.date)
        return "\(day)"
    }

    private var weekdayName: String {
        recap.date.formatted(.dateTime.weekday(.wide))
    }

    private var monthYear: String {
        recap.date.formatted(.dateTime.month(.wide).year())
    }
}
