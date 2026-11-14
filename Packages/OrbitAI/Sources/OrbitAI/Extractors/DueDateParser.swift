import Foundation

/// Finds a date in a short task phrase and splits it out.
///
/// `NSDataDetector` does the language work ("tomorrow at 5", "next
/// Friday", "Dec 3"). This adds the two things a reminder needs: the
/// phrase without the date words (for the task title), and whether a time
/// of day was actually said — "Friday" alone shouldn't ring at noon.
enum DueDateParser {
    struct Result: Equatable {
        let date: Date
        let hasTime: Bool
        let remainder: String
    }

    /// Words that mark a time of day. `NSDataDetector` gives day-only dates
    /// a default time, so whether one was spoken is read from the text.
    private static let timeMarkers = [
        "am", "pm", "a.m", "p.m", "noon", "midnight", "morning", "afternoon", "evening", "tonight", "o'clock", ":",
    ]

    /// Connector words left dangling once the date is removed.
    private static let trailingConnectors: Set<String> = ["at", "on", "by", "before", "this", "next", "in", "for", "around"]

    static func parse(_ phrase: String) -> Result? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        let range = NSRange(phrase.startIndex..<phrase.endIndex, in: phrase)
        guard let match = detector.firstMatch(in: phrase, options: [], range: range),
              let date = match.date,
              let matchRange = Range(match.range, in: phrase)
        else { return nil }

        let matched = phrase[matchRange].lowercased()
        let saysAtHour = matched.range(of: #"(\bat|@)\s*\d"#, options: .regularExpression) != nil
        let hasTime = saysAtHour || timeMarkers.contains { matched.contains($0) }

        var remainder = phrase
        remainder.removeSubrange(matchRange)
        var words = remainder.split(whereSeparator: \.isWhitespace).map(String.init)
        while let last = words.last, trailingConnectors.contains(last.lowercased()) {
            words.removeLast()
        }
        let cleaned = words.joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: " ,.;"))
        return Result(date: date, hasTime: hasTime, remainder: cleaned.isEmpty ? phrase : cleaned)
    }
}
