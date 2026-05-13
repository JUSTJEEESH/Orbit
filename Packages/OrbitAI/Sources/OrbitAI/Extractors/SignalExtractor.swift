import Foundation
import OrbitDomain

/// Synchronous, on-device signal extraction. Runs at capture time so the
/// Tasks tab, Reading list, and Habits surface have data the instant a
/// memory is saved — no waiting for the AI pipeline.
///
/// Heuristic by design. Foundation Models can do this better, but it's
/// expensive to spin up for every keystroke and the heuristic gets us 80%
/// of the value at 1% of the cost.
public struct SignalExtractor: SignalExtracting {
    private let entityExtractor: EntityExtractor

    public init() {
        self.entityExtractor = EntityExtractor()
    }

    public func extract(from memory: Memory) -> ExtractedSignals {
        let text = corpus(for: memory)
        guard !text.isEmpty else {
            // Even empty-text memories may carry implicit reading items
            // (a saved link, for example).
            return ExtractedSignals(readingItems: implicitReadingItems(for: memory.content))
        }

        let entities = entityExtractor.extract(from: text)
        let nearestDate = entities.dates.first

        return ExtractedSignals(
            taskHints: extractTaskHints(text, fallbackDate: nearestDate),
            habitMentions: extractHabits(text, occurredAt: memory.createdAt),
            readingItems: extractReadingItems(text) + implicitReadingItems(for: memory.content)
        )
    }

    // MARK: - Corpus

    private func corpus(for memory: Memory) -> String {
        var parts: [String] = []
        switch memory.content {
        case .text(let s):
            parts.append(s)
        case .voiceNote(let transcript, _):
            if let transcript { parts.append(transcript) }
        case .image(let caption):
            if let caption { parts.append(caption) }
        case .link(_, let title, let summary):
            if let title { parts.append(title) }
            if let summary { parts.append(summary) }
        case .screenshot(let ocr):
            if let ocr { parts.append(ocr) }
        case .location(let name, _, _):
            if let name { parts.append(name) }
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Task hints

    private static let taskPatterns: [String] = [
        // "I should X", "I need to X", "I must X", "I have to X", "I gotta X"
        #"(?i)\bI\s+(?:should|need\s+to|must|have\s+to|gotta|ought\s+to)\s+([^.!?\n]+)"#,
        // "remember to X" / "remind me to X"
        #"(?i)\b(?:remember|remind\s+me)\s+to\s+([^.!?\n]+)"#,
        // "TODO: X" / "TODO X"
        #"(?i)\bTODO[:\s]+([^.!?\n]+)"#
    ]

    private func extractTaskHints(_ text: String, fallbackDate: Date?) -> [TaskHint] {
        var hints: [TaskHint] = []
        for pattern in Self.taskPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, options: [], range: range)
            for match in matches {
                guard match.numberOfRanges >= 2,
                      let phraseRange = Range(match.range(at: 1), in: text),
                      let fullRange = Range(match.range(at: 0), in: text) else { continue }
                let phrase = String(text[phraseRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ",.;"))
                guard !phrase.isEmpty, phrase.count < 140 else { continue }
                hints.append(TaskHint(
                    phrase: phrase,
                    rawText: String(text[fullRange]),
                    dueDate: fallbackDate
                ))
            }
        }
        return dedupeTaskHints(hints)
    }

    /// Two hints with the same canonical phrase should collapse — the user
    /// isn't well-served by seeing "buy groceries" twice in their Tasks tab
    /// just because the regex matched both "I should buy groceries" and
    /// "remember to buy groceries".
    private func dedupeTaskHints(_ hints: [TaskHint]) -> [TaskHint] {
        var seen = Set<String>()
        return hints.filter { hint in
            let key = hint.phrase.lowercased()
            return seen.insert(key).inserted
        }
    }

    // MARK: - Habits

    /// Curated dictionary of normalized habits → trigger verbs. Word-boundary
    /// matched so "ran" doesn't fire on "errand". Single-word verbs only —
    /// multi-word ("worked out") would need a phrase-level match.
    private static let habitDictionary: [(habit: String, verbs: [String])] = [
        ("running",     ["ran", "jogged", "running", "jog"]),
        ("walking",     ["walked", "walking"]),
        ("biking",      ["biked", "biking", "cycled", "cycling"]),
        ("swimming",    ["swam", "swimming"]),
        ("hiking",      ["hiked", "hiking"]),
        ("yoga",        ["yoga"]),
        ("lifting",     ["lifted", "weights"]),
        ("workout",     ["workout", "gym"]),
        ("meditation",  ["meditated", "meditation", "mindfulness"]),
        ("reading",     ["read", "reading"]),
        ("writing",     ["wrote", "journaled", "journaling"]),
        ("stretching",  ["stretched", "stretching"])
    ]

    private func extractHabits(_ text: String, occurredAt: Date) -> [HabitMention] {
        let lower = text.lowercased()
        let scanRange = NSRange(lower.startIndex..<lower.endIndex, in: lower)
        var found: [HabitMention] = []
        var seen = Set<String>()

        for entry in Self.habitDictionary {
            for verb in entry.verbs {
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: verb))\\b"
                guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                      regex.firstMatch(in: lower, options: [], range: scanRange) != nil
                else { continue }
                if seen.insert(entry.habit).inserted {
                    found.append(HabitMention(habit: entry.habit, verb: verb, occurredAt: occurredAt))
                }
                break
            }
        }
        return found
    }

    // MARK: - Reading items

    /// Phrase patterns ranked by specificity. The first match wins per
    /// fragment to avoid double-counting.
    private static let readingPatterns: [(pattern: String, status: ReadingItem.Status)] = [
        (#"(?i)\bfinished\s+reading\s+["“]?([^.!?\n"”]+)["”]?"#,           .finished),
        (#"(?i)\b(?:want|need|hope)\s+to\s+read\s+["“]?([^.!?\n"”]+)["”]?"#, .wantToRead),
        (#"(?i)\bshould\s+read\s+["“]?([^.!?\n"”]+)["”]?"#,                 .wantToRead),
        (#"(?i)\b(?:currently\s+)?reading\s+["“]?([^.!?\n"”]+)["”]?"#,       .currentlyReading)
    ]

    private func extractReadingItems(_ text: String) -> [ReadingItem] {
        var items: [ReadingItem] = []
        var seen = Set<String>()

        for (pattern, status) in Self.readingPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            for match in regex.matches(in: text, options: [], range: range) {
                guard match.numberOfRanges >= 2,
                      let titleRange = Range(match.range(at: 1), in: text) else { continue }
                let title = String(text[titleRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ",.;:"))
                guard !title.isEmpty, title.count < 120 else { continue }
                if seen.insert(title.lowercased()).inserted {
                    items.append(ReadingItem(title: title, status: status))
                }
            }
        }
        return items
    }

    /// A bare `.link` capture is implicitly a "want to read" item. The user
    /// can promote/demote it later from the Reading list UI.
    private func implicitReadingItems(for content: MemoryContent) -> [ReadingItem] {
        guard case .link(let url, let title, _) = content else { return [] }
        return [ReadingItem(title: title, url: url, status: .wantToRead)]
    }
}
