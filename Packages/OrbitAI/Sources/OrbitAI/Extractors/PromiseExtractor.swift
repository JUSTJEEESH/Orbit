import Foundation
import OrbitDomain

/// Finds promises made to other people in captured text — the raw material
/// for the Promise Ledger. Conservative on purpose: a missed promise is
/// better than an invented one.
enum PromiseExtractor {
    /// A person: a capitalized name (one or two words) or a close relation.
    private static let person = #"((?:my\s+)?(?:mom|mum|dad|wife|husband|partner|boss|sister|brother|friend|son|daughter)|[A-Z][a-z]+(?:\s[A-Z][a-z]+)?)"#
    /// Verbs that usually start a promise addressed to someone.
    private static let handOffVerbs = "send|give|call|text|email|show|pay|bring|get back to|lend|introduce"

    private struct Pattern: Sendable {
        let regex: String
        /// Builds (person, item) from the capture groups.
        let build: @Sendable ([String]) -> (String, String)?
    }

    private static let patterns: [Pattern] = [
        // "I told Sam I'd send the photos" / "I told Sam I would call"
        Pattern(regex: #"\bI\s+told\s+"# + person + #"\s+(?:that\s+)?I(?:'d|’d|\s+would|'ll|’ll|\s+will)\s+([^.!?\n]+)"#) { groups in
            (groups[0], groups[1])
        },
        // "I promised Mom to call her back" / "I promised Sam I'd …"
        Pattern(regex: #"\bI\s+promised\s+"# + person + #"\s+(?:that\s+)?(?:I(?:'d|’d|\s+would|'ll|’ll|\s+will)\s+|to\s+)([^.!?\n]+)"#) { groups in
            (groups[0], groups[1])
        },
        // "I owe Alex a coffee"
        Pattern(regex: #"\bI\s+owe\s+"# + person + #"\s+([^.!?\n]+)"#) { groups in
            (groups[0], groups[1])
        },
        // "I'll send Sam the slides" → person Sam, item "send the slides"
        Pattern(regex: #"\bI(?:'ll|’ll|\s+will)\s+("# + handOffVerbs + #")\s+"# + person + #"(?:\s+([^.!?\n]+))?"#) { groups in
            let verb = groups[0]
            let rest = groups.count > 2 ? groups[2] : ""
            return (groups[1], rest.isEmpty ? verb : "\(verb) \(rest)")
        },
    ]

    /// Words that look like names at the start of a sentence but aren't.
    private static let notNames: Set<String> = ["I", "The", "This", "That", "Then", "Today", "Tomorrow", "It", "We", "They"]

    static func extract(from text: String) -> [PromiseHint] {
        var hints: [PromiseHint] = []
        var seen: Set<String> = []
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern.regex) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            for match in regex.matches(in: text, range: range) {
                let groups: [String] = (1..<match.numberOfRanges).map { index in
                    Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
                }
                guard let (rawPerson, rawItem) = pattern.build(groups) else { continue }
                let person = rawPerson.trimmingCharacters(in: .whitespaces)
                guard !notNames.contains(person) else { continue }
                var item = rawItem.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ",.;"))
                var due: Date?
                if let parsed = DueDateParser.parse(item) {
                    item = parsed.remainder
                    due = parsed.date
                }
                guard !item.isEmpty, item.count < 140 else { continue }
                let key = "\(person.lowercased())|\(item.lowercased())"
                guard seen.insert(key).inserted else { continue }
                hints.append(PromiseHint(person: displayName(person), item: item, dueDate: due))
            }
        }
        return hints
    }

    /// "my mom" → "Mom"; names stay as written.
    private static func displayName(_ raw: String) -> String {
        let trimmed = raw.hasPrefix("my ") ? String(raw.dropFirst(3)) : raw
        return trimmed.prefix(1).uppercased() + trimmed.dropFirst()
    }
}
