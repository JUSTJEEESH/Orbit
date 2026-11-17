import Foundation

/// "23 days ago", worked out in calendar days so "yesterday" means the
/// previous date, not 24 hours. A gentle aid for time blindness: exact
/// where it matters (the first weeks), rounded once precision stops
/// helping.
public enum TimeSince {
    /// Whole calendar days from `date` to `now` (0 = same day).
    public static func days(from date: Date, to now: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: date)
        let end = calendar.startOfDay(for: now)
        return max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
    }

    /// Plain-language phrase: "today", "yesterday", "9 days ago",
    /// "about 3 months ago", "over a year ago".
    public static func phrase(from date: Date, to now: Date, calendar: Calendar = .current) -> String {
        let days = days(from: date, to: now, calendar: calendar)
        switch days {
        case 0:
            return String(localized: "today")
        case 1:
            return String(localized: "yesterday")
        case ..<Threshold.exactDays:
            return String(localized: "\(days) days ago")
        case ..<Threshold.year:
            let months = max(2, Int((Double(days) / Threshold.daysPerMonth).rounded()))
            return String(localized: "about \(months) months ago")
        default:
            return days < Threshold.year * 2
                ? String(localized: "over a year ago")
                : String(localized: "over \(days / Threshold.year) years ago")
        }
    }

    private enum Threshold {
        /// Up to two months, count exact days: "47 days" still means something.
        static let exactDays = 60
        static let year = 365
        static let daysPerMonth = 30.44
    }
}
