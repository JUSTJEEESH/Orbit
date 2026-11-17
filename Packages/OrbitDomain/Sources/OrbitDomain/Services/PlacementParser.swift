import Foundation

/// "Passport is in the blue box, top shelf" / "I left my keys in the car".
/// One place where something was put, as written in a memory.
public struct ItemPlacement: Sendable, Hashable {
    /// What was put away, lowercased, without "my"/"the" ("passport").
    public let item: String
    /// "in", "under", "next to", "at"…
    public let preposition: String
    /// Where, as written, with "my" turned into "your" for the reply.
    public let location: String
    /// "put", "left", "keep"… for "I put my…" sentences; nil for "X is in…".
    public let verb: String?
    /// "is" or "are", for "X is in…" sentences.
    public let copula: String?

    public init(item: String, preposition: String, location: String, verb: String?, copula: String?) {
        self.item = item
        self.preposition = preposition
        self.location = location
        self.verb = verb
        self.copula = copula
    }

    /// The reply: "Your passport is in the blue box, top shelf." or
    /// "You left your keys in the car."
    public var sentence: String {
        if let verb {
            return "You \(verb) your \(item) \(preposition) \(location)."
        }
        return "Your \(item) \(copula ?? "is") \(preposition) \(location)."
    }
}

/// Finds placements in memory text and the item in a "where's my…"
/// question. Pure, on-device pattern matching, deliberately conservative:
/// a missed placement just means Ask Orbit falls back to a normal answer,
/// while a wrong one would send someone to the wrong shelf.
public enum PlacementParser {
    private static let determiner = #"(?:my|the|our|his|her|their|a|an)"#
    private static let determiners: Set<String> = ["my", "the", "our", "his", "her", "their", "a", "an"]
    /// Up to three words for the item ("spare car key").
    private static let itemPhrase = #"([A-Za-z][\w'’-]*(?:\s+[A-Za-z][\w'’-]*){0,2})"#
    private static let containerPrepositions = #"(on\s+top\s+of|next\s+to|in\s+the\s+back\s+of|inside|underneath|under|behind|beside|above|below|in|on)"#
    /// Where: starts with a determiner, runs to the end of the clause.
    private static let location = #"((?:the|my|our|a|an|his|her|their)\s+[^.!?\n;]{2,80})"#

    /// "passport is in the blue box" / "the spare keys are under the mat"
    private static let statePattern = #"(?i)(?:^|[.!?\n]\s*|\b)(?:"# + determiner + #"\s+)?"# + itemPhrase
        + #"\s+(is|are)\s+(?:kept\s+|stored\s+|hidden\s+|now\s+)?"# + containerPrepositions + #"\s+"# + location

    /// "I put my passport in the blue box" / "left my wallet at home"
    private static let actionPattern = #"(?i)\bI\s+(put|left|stashed|hid|stored|placed|keep|kept|moved|dropped)\s+(?:"# + determiner + #"\s+)?"#
        + itemPhrase + #"\s+(?:"# + containerPrepositions + #"\s+"# + location + #"|(at)\s+([^.!?\n;]{2,40}))"#

    /// Subjects that aren't objects you put somewhere ("the meeting is in
    /// the morning", "it is in the works").
    private static let notItems: Set<String> = [
        "it", "this", "that", "there", "here", "what", "which", "who", "everything", "nothing", "something",
        "meeting", "appointment", "call", "party", "event", "game", "show", "plan", "problem", "issue",
        "answer", "truth", "point", "deadline", "flight", "class", "trip", "life", "news", "weather",
        "baby", "he", "she", "they", "we", "i", "you",
    ]
    /// Locations that are times or idioms, not places.
    private static let notLocationStarts = [
        "the morning", "the afternoon", "the evening", "the night", "the works", "the past",
        "the future", "the middle of", "the mood", "the way", "a hurry", "a meeting", "the meantime",
    ]

    // MARK: - Memory text

    public static func placements(in text: String) -> [ItemPlacement] {
        var found: [ItemPlacement] = []
        for match in matches(of: statePattern, in: text) {
            guard match.count >= 4 else { continue }
            if let placement = make(item: match[0], preposition: match[2], location: match[3], verb: nil, copula: match[1].lowercased()) {
                found.append(placement)
            }
        }
        for match in matches(of: actionPattern, in: text) {
            guard match.count >= 6 else { continue }
            let verb = match[0].lowercased()
            let placement = match[2].isEmpty
                ? make(item: match[1], preposition: match[4], location: match[5], verb: verb, copula: nil)
                : make(item: match[1], preposition: match[2], location: match[3], verb: verb, copula: nil)
            if let placement { found.append(placement) }
        }
        return found
    }

    // MARK: - Questions

    /// "Where's my passport?" → "passport". Nil when it isn't a where-is
    /// question.
    public static func item(inQuestion question: String) -> String? {
        let pattern = #"(?i)^\s*where(?:'s|’s|\s+is|\s+are|\s+did\s+i\s+(?:put|leave|store|hide|keep|stash)|\s+do\s+i\s+keep|\s+have\s+i\s+(?:put|left))?\s+(?:"# + determiner + #"\s+)?([^?]+?)\s*(?:again)?\s*\??\s*$"#
        guard let groups = matches(of: pattern, in: question).first, let raw = groups.first else { return nil }
        let item = clean(raw)
        guard !item.isEmpty, !notItems.contains(item), item.split(separator: " ").count <= 4 else { return nil }
        return item
    }

    /// Whether a placement is about the item someone asked for. Loose on
    /// plurals and qualifiers: "keys" finds "car keys", "key" finds "keys".
    public static func matches(placementItem: String, question: String) -> Bool {
        let placementWords = normalizedWords(placementItem)
        let questionWords = normalizedWords(question)
        guard !placementWords.isEmpty, !questionWords.isEmpty else { return false }
        return placementWords.hasSuffix(questionWords) || questionWords.hasSuffix(placementWords)
    }

    // MARK: - Helpers

    private static func make(item rawItem: String, preposition: String, location rawLocation: String, verb: String?, copula: String?) -> ItemPlacement? {
        // "I think the passport is…" matches with "think the passport";
        // the item is what follows the last determiner.
        let words = clean(rawItem).split(whereSeparator: \.isWhitespace).map(String.init)
        let item = (words.lastIndex(where: determiners.contains).map { Array(words[($0 + 1)...]) } ?? words)
            .joined(separator: " ")
        guard !item.isEmpty, !notItems.contains(item), !notItems.contains(item.split(separator: " ").last.map(String.init) ?? "") else { return nil }
        var location = trimClause(rawLocation)
        let lowered = location.lowercased()
        guard location.count >= 2, !notLocationStarts.contains(where: { lowered.hasPrefix($0) }) else { return nil }
        location = location.replacingOccurrences(of: #"(?i)\bmy\b"#, with: "your", options: .regularExpression)
        let prep = preposition.lowercased().replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return ItemPlacement(item: item, preposition: prep, location: location, verb: verb, copula: copula)
    }

    /// Ends the location at the next clause ("in the car, then went in").
    private static func trimClause(_ raw: String) -> String {
        var text = raw
        if let range = text.range(of: #"(?i)(?:,\s*|\s+)(?:and then|then|but|because|so that|so|while|when|before|after)\b.*$"#, options: .regularExpression) {
            text.removeSubrange(range)
        }
        return text.trimmingCharacters(in: CharacterSet(charactersIn: " ,.;:").union(.whitespacesAndNewlines))
    }

    private static func clean(_ raw: String) -> String {
        raw.lowercased()
            .replacingOccurrences(of: #"^(?:my|the|our|his|her|their|a|an)\s+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Lowercased words with a trailing plural "s" dropped ("keys" → "key").
    private static func normalizedWords(_ text: String) -> [String] {
        clean(text).split(whereSeparator: \.isWhitespace).map { word in
            let word = String(word)
            return word.count > 3 && word.hasSuffix("s") && !word.hasSuffix("ss") ? String(word.dropLast()) : word
        }
    }

    /// Capture groups of every match (empty string for a group that
    /// didn't participate).
    private static func matches(of pattern: String, in text: String) -> [[String]] {
        guard let regex = RegexCache.regex(pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).map { match in
            (1..<match.numberOfRanges).map { index in
                Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
            }
        }
    }
}

private extension Array where Element == String {
    func hasSuffix(_ suffix: [String]) -> Bool {
        suffix.count <= count && Array(self[(count - suffix.count)...]) == suffix
    }
}
