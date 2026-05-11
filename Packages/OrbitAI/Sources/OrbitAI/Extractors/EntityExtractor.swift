import Foundation
import NaturalLanguage

public struct ExtractedEntities: Sendable, Equatable {
    public let dates: [Date]
    public let people: [String]
    public let locations: [String]

    public init(dates: [Date], people: [String], locations: [String]) {
        self.dates = dates
        self.people = people
        self.locations = locations
    }

    public static let empty = ExtractedEntities(dates: [], people: [], locations: [])
}

/// Lightweight, offline entity extraction. Uses `NSDataDetector` for dates
/// and `NLTagger` for people and place names. Fast and free; runs before
/// any LLM hop so the AI pipeline always has at least this much metadata.
public struct EntityExtractor: Sendable {
    public init() {}

    public func extract(from text: String) -> ExtractedEntities {
        guard !text.isEmpty else { return .empty }
        return ExtractedEntities(
            dates: extractDates(text),
            people: extractNames(text, tag: .personalName),
            locations: extractNames(text, tag: .placeName)
        )
    }

    private func extractDates(_ text: String) -> [Date] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = detector.matches(in: text, options: [], range: range)
        return matches.compactMap(\.date)
    }

    private func extractNames(_ text: String, tag desiredTag: NLTag) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]
        var collected: [String] = []
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: options
        ) { tag, range in
            if tag == desiredTag {
                collected.append(String(text[range]))
            }
            return true
        }
        // Dedupe but preserve order.
        var seen = Set<String>()
        return collected.filter { seen.insert($0).inserted }
    }
}
