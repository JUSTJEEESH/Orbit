import Foundation
import OrbitDomain

/// What two memories actually have in common: shared people or places, and
/// shared subject words.
///
/// Why this exists: "Connected memories" used to rank on embedding
/// similarity plus recency alone. Short notes that share a template
/// ("Remind me to grab the ladder at Mom's" / "Remind me to get the speaker
/// from Scott") sit close together in sentence-embedding space, and any
/// note captured today got a recency boost, so unrelated errands all
/// "connected". A connection now requires evidence a person would agree
/// with: a shared person, place or subject word. Embeddings only rank the
/// memories that pass.
struct ConnectionEvidence: Equatable {
    let sharedEntities: Set<String>
    let sharedWords: Set<String>

    var isConnected: Bool { !sharedEntities.isEmpty || !sharedWords.isEmpty }

    /// 0…1. A shared person or place counts double a shared word; three
    /// points of overlap is as strong as it gets.
    var strength: Double {
        let points = Double(sharedEntities.count * 2 + sharedWords.count)
        return min(1, points / Self.fullStrengthPoints)
    }

    private static let fullStrengthPoints = 3.0

    init(sharedEntities: Set<String>, sharedWords: Set<String>) {
        self.sharedEntities = sharedEntities
        self.sharedWords = sharedWords
    }

    init(_ lhs: Memory, _ rhs: Memory) {
        let lhsEntities = Self.entities(of: lhs)
        let rhsEntities = Self.entities(of: rhs)
        let entities = lhsEntities.intersection(rhsEntities)
        // A shared entity is already counted; don't count its name again
        // as a shared word.
        let words = Self.subjectWords(in: lhs.analyzableText)
            .intersection(Self.subjectWords(in: rhs.analyzableText))
            .subtracting(entities.flatMap { $0.split(separator: " ").map(String.init) })
        self.init(sharedEntities: entities, sharedWords: words)
    }

    // MARK: - Extraction

    static func entities(of memory: Memory) -> Set<String> {
        let names = memory.ai.extractedPeople + memory.ai.extractedLocations
        return Set(names.map(normalizeName).filter { !$0.isEmpty && !ignoredWords.contains($0) })
    }

    /// Lowercased, possessive dropped: "Mom's" → "mom".
    static func normalizeName(_ name: String) -> String {
        var name = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for suffix in ["'s", "’s"] where name.hasSuffix(suffix) {
            name.removeLast(suffix.count)
        }
        return name
    }

    /// Words that say what a memory is about. Drops filler, request
    /// phrasing ("remind me to grab"), times and generic nouns, then folds
    /// possessives and simple plurals ("Mom's" → "mom", "keys" → "key").
    static func subjectWords(in text: String) -> Set<String> {
        let tokens = text.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .components(separatedBy: CharacterSet.letters.union(CharacterSet(charactersIn: "'")).inverted)
        var words = Set<String>()
        for token in tokens {
            var word = token.trimmingCharacters(in: CharacterSet(charactersIn: "'"))
            if word.hasSuffix("'s") { word.removeLast(2) }
            guard !word.contains("'") else { continue } // "don't", "i'll"
            if word.count > minimumPluralLength, word.hasSuffix("s"), !word.hasSuffix("ss") {
                word.removeLast()
            }
            guard word.count >= minimumWordLength, !ignoredWords.contains(word) else { continue }
            words.insert(word)
        }
        return words
    }

    private static let minimumWordLength = 3
    private static let minimumPluralLength = 3

    /// Words that appear in all kinds of unrelated notes. Plurals are listed
    /// in their folded form ("thing", not "things").
    static let ignoredWords: Set<String> = [
        // Function words
        "the", "and", "but", "for", "nor", "yet", "with", "from", "into", "onto", "upon", "about",
        "over", "under", "after", "before", "then", "than", "that", "this", "these", "those", "there",
        "here", "what", "when", "where", "which", "who", "whom", "whose", "why", "how", "all", "any",
        "some", "each", "every", "both", "few", "more", "most", "other", "such", "only", "own", "same",
        "too", "very", "just", "also", "again", "ever", "never", "not", "out", "off", "our", "your",
        "his", "her", "their", "them", "they", "she", "him", "you", "its", "was", "were", "are", "been",
        "being", "have", "has", "had", "having", "does", "did", "doing", "will", "would", "shall",
        "should", "can", "could", "may", "might", "must", "let", "via", "per", "like", "really",
        "maybe", "still", "even", "much", "many", "well", "back", "down", "away", "around", "because",
        "while", "until", "though", "although", "yes", "okay", "one", "two", "three", "first", "last",
        "next", "new", "old", "big", "little", "good", "great", "bad", "lot", "bit", "way",
        // Request and reminder phrasing
        "remind", "reminder", "remember", "forget", "need", "needed", "want", "wanted", "make", "sure",
        "grab", "get", "got", "getting", "pick", "picked", "bring", "take", "took", "put", "give",
        "gave", "drop", "send", "ask", "tell", "told", "said", "say", "call", "text", "email", "check",
        "buy", "go", "going", "went", "come", "came", "see", "saw", "look", "find", "keep", "try",
        "start", "finish", "done", "do", "use", "work", "help", "think", "thought", "know", "feel",
        "felt", "note", "todo", "task", "please", "gonna", "gotta", "wanna",
        // Times
        "today", "tonight", "tomorrow", "yesterday", "morning", "afternoon", "evening", "night",
        "week", "weekend", "month", "year", "day", "time", "now", "later", "soon", "monday",
        "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "noon", "hour", "minute",
        // Generic nouns
        "thing", "stuff", "something", "anything", "everything", "nothing", "someone", "anyone",
        "everyone", "place", "home", "house", "store", "people", "person", "part", "kind",
    ]
}
