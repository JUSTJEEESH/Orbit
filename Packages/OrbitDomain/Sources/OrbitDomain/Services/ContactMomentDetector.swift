import Foundation

/// Tells "called Dad" apart from "Dad's birthday is in May": was this a
/// moment you actually spent with (or spoke to) someone? Powers "Last
/// together 23 days ago" on People pages.
///
/// A deliberately small English pattern set, run on device. It favors
/// precision — a missed moment falls back to "last mentioned", which is
/// still true, while a false one would claim time together that didn't
/// happen.
public enum ContactMomentDetector {
    /// Phrases that put the speaker with someone. Each is followed by an
    /// optional "my"/"with" and then the name.
    private static let verbs = [
        "called", "phoned", "rang", "facetimed", "texted", "messaged",
        "talked to", "talked with", "spoke to", "spoke with", "chatted with",
        "caught up with", "hung out with", "met up with", "met with", "met",
        "saw", "visited", "had lunch with", "had dinner with",
        "had breakfast with", "had coffee with", "had drinks with",
        "went out with", "spent the day with", "spent time with",
        "picked up", "dropped off",
    ]

    /// Whether `text` describes a contact moment with `name`.
    public static func isContact(with name: String, in text: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 1 else { return false }
        let verbAlternatives = verbs
            .map { NSRegularExpression.escapedPattern(for: $0).replacingOccurrences(of: " ", with: "\\s+") }
            .joined(separator: "|")
        let pattern = "\\b(?:\(verbAlternatives))\\s+(?:up\\s+)?(?:with\\s+)?(?:my\\s+)?\(NSRegularExpression.escapedPattern(for: trimmed))\\b"
        guard let regex = RegexCache.regex(pattern, options: [.caseInsensitive]) else { return false }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }
}
