import SwiftUI
import Charts
import OrbitDesignSystem
import OrbitDomain

/// Year-in-Review share card.
///
/// The year as a 320pt heavy rounded numeric is the hero — bigger than
/// anything else on screen by an order of magnitude — supported by a
/// serif headline summarizing the year in one sentence. Below that, a
/// silent SwiftUI Chart sparkline traces the year's monthly cadence
/// (the *only* graphic on the card; no chart chrome, no axes, just the
/// shape of the year). Underneath the sparkline, three label/value
/// rows surface the year's most-recurring category, person, and place.
public struct YearInReviewShareCard: View {
    let review: YearInReview
    @Environment(\.orbitTheme) private var theme

    public init(review: YearInReview) {
        self.review = review
    }

    public var body: some View {
        ShareCardSurface {
            ShareCardTopRail(stamp: "Year in Review")

            Spacer().frame(height: 36)

            ShareCardHairline()

            Spacer().frame(height: 40)

            yearBlock

            Spacer().frame(height: 28)

            if !review.monthlyCounts.isEmpty {
                sparkline
                Spacer().frame(height: 32)
            }

            highlightRows

            Spacer()

            ShareCardHairline()

            Spacer().frame(height: 22)

            ShareCardPublisherLine()
        }
    }

    /// Year as the dominant graphic. SF Pro Display semibold — the
    /// Apple Journal register, not the Apple Music Replay one. Bigger
    /// than anything else on the card by an order of magnitude, with
    /// a serif editorial headline beneath summarizing volume.
    private var yearBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(review.year)")
                .font(.system(size: 220, weight: .semibold))
                .foregroundStyle(theme.primary)
                .fixedSize()

            Text(headline)
                .font(.system(size: 38, weight: .regular, design: .serif))
                .foregroundStyle(OrbitColor.textPrimary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Monthly cadence as a silent bar sparkline. No axes, no labels —
    /// just the shape of the year. Tinted theme.primary so the year
    /// number above and the sparkline below feel like the same thought.
    private var sparkline: some View {
        let domain = (1...12).map { month in
            review.monthlyCounts.first(where: { $0.month == month })?.count ?? 0
        }
        return Chart(Array(domain.enumerated()), id: \.offset) { index, count in
            BarMark(
                x: .value("Month", index + 1),
                y: .value("Captures", count),
                width: .ratio(0.55)
            )
            .foregroundStyle(theme.primary)
            .cornerRadius(2)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plot in
            plot.background(Color.clear)
        }
        .frame(height: 88)
    }

    private var highlightRows: some View {
        VStack(alignment: .leading, spacing: 22) {
            if let top = review.topCategory {
                ShareCardLabeledValue(label: "Top category", value: top.name.capitalized)
            }
            if let person = review.topPerson {
                ShareCardLabeledValue(label: "Recurring name", value: person.name)
            }
            if let place = review.topPlace {
                ShareCardLabeledValue(label: "Where you were", value: place.name)
            }
            if let month = review.mostActiveMonth, let monthName = Self.monthName(month) {
                ShareCardLabeledValue(label: "Busiest month", value: monthName)
            }
        }
    }

    private var headline: String {
        let captures = review.totalCaptures
        switch captures {
        case 0:        return "A quiet year of becoming."
        case 1..<50:   return "\(captures) moments worth holding onto."
        case 50..<200: return "\(captures) memories — a year in motion."
        default:       return "\(captures) memories. A year, fully lived."
        }
    }

    private static func monthName(_ month: Int) -> String? {
        guard (1...12).contains(month) else { return nil }
        var components = DateComponents()
        components.month = month
        guard let date = Calendar.current.date(from: components) else { return nil }
        return date.formatted(.dateTime.month(.wide))
    }
}
