import Foundation

/// A stretch of a voice note's transcript with when it was said. Lets search
/// land on the exact moment in a recording, and playback jump there.
public struct TranscriptSegment: Codable, Sendable, Hashable {
    public var text: String
    /// Seconds from the start of the recording.
    public var start: TimeInterval
    public var end: TimeInterval

    public init(text: String, start: TimeInterval, end: TimeInterval) {
        self.text = text
        self.start = start
        self.end = end
    }
}

public extension Array where Element == TranscriptSegment {
    /// When the first segment containing `query` begins, case- and
    /// diacritic-insensitively. Nil when the words aren't in the recording.
    func startTime(of query: String) -> TimeInterval? {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return nil }
        if let direct = first(where: { $0.text.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil }) {
            return direct.start
        }
        // Phrases can span segments: match the first word instead.
        guard let firstWord = needle.split(separator: " ").first.map(String.init), firstWord != needle else { return nil }
        return first(where: { $0.text.range(of: firstWord, options: [.caseInsensitive, .diacriticInsensitive]) != nil })?.start
    }
}
