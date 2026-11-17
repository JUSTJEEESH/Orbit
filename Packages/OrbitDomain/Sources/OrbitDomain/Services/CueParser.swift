import Foundation

/// "Remind me at Mom's to grab the ladder" / "Next time I see Alex, ask
/// about the trip": a task tied to a place or a person rather than a time.
public struct CueHint: Sendable, Hashable, Identifiable {
    public enum Target: Sendable, Hashable {
        /// As written ("Mom's", "the office"). Resolved to coordinates
        /// when the user confirms it.
        case place(String)
        case person(String)
    }

    /// Stable across launches (derived from the memory and the text), so a
    /// kept suggestion stays kept.
    public let id: UUID
    public let target: Target
    /// What to do ("grab the ladder").
    public let action: String

    public init(id: UUID, target: Target, action: String) {
        self.id = id
        self.target = target
        self.action = action
    }

    /// "At Mom's" / "With Alex".
    public var targetLabel: String {
        switch target {
        case .place(let name):  return "At \(name)"
        case .person(let name): return "With \(name)"
        }
    }
}

/// Finds place and person cues in memory text. On-device patterns, tuned
/// for precision: a missed cue still leaves the memory searchable, while
/// a false one would set an alert nobody asked for.
public enum CueParser {
    private enum Pattern {
        static let place = #"((?:my\s+|the\s+)?[A-Za-z][\w'’&-]*(?:\s+[A-Za-z][\w'’&-]*){0,3})"#
        // Names are matched case-sensitively (capitalized); everything else
        // is wrapped in (?i:...) so "Remind me" and "remind me" both work.
        static let person = #"((?:(?i:my)\s+)?(?i:(?:mom|mum|dad|wife|husband|partner|boss|sister|brother|grandma|grandpa|doctor|therapist|son|daughter|kids))|[A-Z][a-z]+(?:\s[A-Z][a-z]+)?)"#
        static let action = #"([^.!?\n]{3,120})"#
        static let placeArrive = #"(?i:when\s+I(?:'m|’m|\s+am)\s+at|when\s+I\s+get\s+to|when\s+I\s+arrive\s+at|next\s+time\s+I(?:'m|’m|\s+am)\s+at|once\s+I(?:'m|’m|\s+am)\s+at|when\s+I(?:'m|’m|\s+am)\s+back\s+at)"#
        static let personMeet = #"(?i:next\s+time\s+I\s+(?:see|talk\s+to|meet|speak\s+to|(?:'m|’m|am)\s+with)|next\s+time\s+I(?:'m|’m)\s+with|when\s+I\s+(?:next\s+)?(?:see|talk\s+to|meet|speak\s+to)|when\s+I(?:'m|’m|\s+am)\s+with)"#
        static let lead = #"(?i:(?:remind\s+me\s+to|I\s+(?:need|have|want)\s+to|I\s+should|don'?t\s+forget\s+to)\s+)?"#
        static let clauseEnd = #"(?=\s*(?:[.!?\n]|$))"#
    }

    private enum Kind { case place, person }

    /// (kind, regex, target group index, action group index)
    private static let rules: [(Kind, String, Int, Int)] = [
        // "Remind me at Mom's to grab the ladder" / "remind me when I get to Costco to…"
        (.place, #"(?i:remind\s+me)\s+(?:"# + Pattern.placeArrive + #"|(?i:at))\s+"# + Pattern.place + #"\s+(?i:to)\s+"# + Pattern.action, 0, 1),
        // "Remind me to buy batteries when I get to Costco"
        (.place, #"(?i:remind\s+me\s+to)\s+([^.!?\n]{3,120}?)\s+"# + Pattern.placeArrive + #"\s+"# + Pattern.place + Pattern.clauseEnd, 1, 0),
        // "When I get to the office, print the contract"
        (.place, Pattern.placeArrive + #"\s+"# + Pattern.place + #"\s*,\s*"# + Pattern.lead + Pattern.action, 0, 1),
        // "Remind me when I see Priya to give her the book"
        (.person, #"(?i:remind\s+me)\s+"# + Pattern.personMeet + #"\s+"# + Pattern.person + #"\s+(?i:to)\s+"# + Pattern.action, 0, 1),
        // "Remind me to return the drill next time I see my dad"
        (.person, #"(?i:remind\s+me\s+to)\s+([^.!?\n]{3,120}?)\s+"# + Pattern.personMeet + #"\s+"# + Pattern.person + Pattern.clauseEnd, 1, 0),
        // "Next time I see Alex, ask about the trip"
        (.person, Pattern.personMeet + #"\s+"# + Pattern.person + #"\s*,\s*"# + Pattern.lead + Pattern.action, 0, 1),
    ]

    /// Words that fit the place slot but are times ("remind me at noon to…").
    private static let notPlaces: Set<String> = [
        "noon", "midnight", "night", "lunch", "dinner", "breakfast", "lunchtime", "bedtime",
        "tonight", "tomorrow", "today", "the weekend", "the end of the day", "the moment", "some point",
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
    ]

    /// Cues in `text`, each with an ID derived from `memoryID` so the same
    /// sentence always yields the same suggestion.
    public static func cues(in text: String, memoryID: UUID) -> [CueHint] {
        var hints: [CueHint] = []
        var seen: Set<String> = []
        for (kind, pattern, targetIndex, actionIndex) in rules {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            for match in regex.matches(in: text, range: range) {
                let groups: [String] = (1..<match.numberOfRanges).map { index in
                    Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
                }
                guard groups.count > max(targetIndex, actionIndex) else { continue }
                let rawTarget = groups[targetIndex].trimmingCharacters(in: .whitespaces)
                let action = groups[actionIndex].trimmingCharacters(in: CharacterSet(charactersIn: " ,;:").union(.whitespacesAndNewlines))
                guard !action.isEmpty, !rawTarget.isEmpty, !notPlaces.contains(rawTarget.lowercased()) else { continue }
                let target: CueHint.Target = kind == .place
                    ? .place(rawTarget)
                    : .person(displayName(rawTarget))
                let key = "\(target)|\(action.lowercased())"
                guard seen.insert(key).inserted else { continue }
                hints.append(CueHint(id: StableUUID.make(from: "\(memoryID.uuidString)|cue|\(key)"), target: target, action: action))
            }
        }
        return hints
    }

    /// "my dad" → "Dad"; names stay as written.
    private static func displayName(_ raw: String) -> String {
        let trimmed = raw.lowercased().hasPrefix("my ") ? String(raw.dropFirst(3)) : raw
        return trimmed.prefix(1).uppercased() + trimmed.dropFirst()
    }
}

/// Deterministic UUIDs from text (FNV-1a, two 64-bit halves), for IDs that
/// must stay the same across launches without being stored.
public enum StableUUID {
    public static func make(from text: String) -> UUID {
        let bytes = Array(text.utf8)
        let high = fnv1a(bytes, seed: 0xcbf2_9ce4_8422_2325)
        let low = fnv1a(bytes, seed: 0x8422_2325_cbf2_9ce4)
        func byte(_ value: UInt64, _ index: Int) -> UInt8 { UInt8(truncatingIfNeeded: value >> (56 - index * 8)) }
        return UUID(uuid: (
            byte(high, 0), byte(high, 1), byte(high, 2), byte(high, 3),
            byte(high, 4), byte(high, 5), byte(high, 6), byte(high, 7),
            byte(low, 0), byte(low, 1), byte(low, 2), byte(low, 3),
            byte(low, 4), byte(low, 5), byte(low, 6), byte(low, 7)
        ))
    }

    private static func fnv1a(_ bytes: [UInt8], seed: UInt64) -> UInt64 {
        var hash = seed
        for byte in bytes {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }
}
