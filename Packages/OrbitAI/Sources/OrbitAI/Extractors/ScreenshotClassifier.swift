import Foundation

/// Decides what a screenshot *is* from its recognized text, so the
/// Screenshot Inbox can suggest the right thing to do with it.
///
/// Heuristic and on-device: dates come from `NSDataDetector`, the rest from
/// small keyword sets. Good enough to suggest; the user always confirms.
public struct ScreenshotClassifier: Sendable {
    public enum Kind: Sendable, Equatable {
        /// Something happening on a date — a ticket, booking, invite.
        case event(Date)
        case receipt
        case recipe
        /// Anything else worth keeping.
        case note
    }

    public struct Suggestion: Sendable, Equatable {
        public let kind: Kind
        public let tags: [String]
        /// A short, human title from the first meaningful line.
        public let title: String?
    }

    public init() {}

    private static let receiptWords = ["subtotal", "total", "receipt", "invoice", "order #", "paid", "tax", "amount due"]
    private static let recipeWords = ["ingredients", "tbsp", "tsp", "tablespoon", "teaspoon", "cups", "preheat", "bake", "simmer"]
    private static let eventWords = ["ticket", "boarding", "flight", "gate", "seat", "reservation", "booking", "check-in", "admit", "doors", "rsvp", "appointment"]
    /// Lines shorter than this rarely make a meaningful title.
    private static let minimumTitleLength = 4

    public func classify(_ text: String, now: Date = Date()) -> Suggestion {
        let lower = text.lowercased()
        let title = Self.title(from: text)

        if let date = Self.firstFutureDate(in: text, after: now), Self.eventWords.contains(where: lower.contains) || Self.hasTime(text) {
            return Suggestion(kind: .event(date), tags: ["plans"], title: title)
        }
        if Self.recipeWords.filter(lower.contains).count >= 2 {
            return Suggestion(kind: .recipe, tags: ["recipes"], title: title)
        }
        if Self.receiptWords.contains(where: lower.contains) && lower.range(of: #"\d+[.,]\d{2}"#, options: .regularExpression) != nil {
            return Suggestion(kind: .receipt, tags: ["receipts"], title: title)
        }
        return Suggestion(kind: .note, tags: [], title: title)
    }

    private static func firstFutureDate(in text: String, after now: Date) -> Date? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector.matches(in: text, options: [], range: range)
            .compactMap(\.date)
            .first { $0 > now }
    }

    private static func hasTime(_ text: String) -> Bool {
        text.range(of: #"\b\d{1,2}:\d{2}\b"#, options: .regularExpression) != nil
    }

    private static func title(from text: String) -> String? {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.count >= minimumTitleLength && $0.contains(where: \.isLetter) }
    }
}
