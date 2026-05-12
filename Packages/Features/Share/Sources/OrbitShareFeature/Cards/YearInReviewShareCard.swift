import SwiftUI
import OrbitDesignSystem
import OrbitDomain

/// Year-in-Review share card. Big, declarative — the year as a
/// statement, not a dashboard. Top-line count and one or two qualitative
/// "tops" carry the design.
public struct YearInReviewShareCard: View {
    let review: YearInReview
    @Environment(\.orbitTheme) private var theme

    public init(review: YearInReview) {
        self.review = review
    }

    public var body: some View {
        ShareCardSurface {
            ShareCardBrandMark()

            Spacer(minLength: 56)

            Text("Year in Review".uppercased())
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(theme.primary)
                .padding(.bottom, 12)

            Text("\(review.year)")
                .font(.system(size: 188, weight: .heavy, design: .rounded))
                .foregroundStyle(OrbitColor.textPrimary)
                .padding(.bottom, 16)

            Text(headline)
                .font(.system(size: 44, weight: .regular, design: .serif))
                .foregroundStyle(OrbitColor.textPrimary)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 48)

            highlightsGrid

            Spacer()

            ShareCardFooterLine(
                leading: "Orbit Year in Review",
                trailing: nil
            )
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

    /// Two- or three-cell grid showing the year's most-recurring people,
    /// places, and categories. Quiet, label/value pairs so the card stays
    /// editorial — no chart chrome.
    private var highlightsGrid: some View {
        VStack(alignment: .leading, spacing: 28) {
            if let top = review.topCategory {
                row(label: "Top category", value: top.name.capitalized)
            }
            if let person = review.topPerson {
                row(label: "Recurring name", value: person.name)
            }
            if let place = review.topPlace {
                row(label: "Where you were", value: place.name)
            }
            if let month = review.mostActiveMonth, let monthName = Self.monthName(month) {
                row(label: "Busiest month", value: monthName)
            }
        }
    }

    private func row(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label.uppercased())
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(OrbitColor.textTertiary)
                .frame(width: 320, alignment: .leading)
            Text(value)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(OrbitColor.textPrimary)
                .lineLimit(1)
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
