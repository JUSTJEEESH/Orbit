import Foundation
import NaturalLanguage
import Testing
@testable import OrbitAI

/// Name recognition is an OS-provided model that some simulator images (CI
/// runners included) ship without. The probe asks `NLTagger` directly — not
/// `EntityExtractor` — so wherever the model exists, the extractor tests
/// still run and still catch regressions in Orbit's code.
private let nameTaggerAvailable: Bool = {
    let text = "Tim Cook visited Paris."
    let tagger = NLTagger(tagSchemes: [.nameType])
    tagger.string = text
    var found = false
    tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: [.joinNames]) { tag, _ in
        if tag == .personalName || tag == .placeName { found = true }
        return !found
    }
    return found
}()

@Suite("Entity extractor")
struct EntityExtractorTests {

    @Test func extractsAtLeastOneDateFromCommonPhrasing() {
        let extractor = EntityExtractor()
        let result = extractor.extract(from: "Lunch with Pamela next Tuesday at 1pm.")
        #expect(!result.dates.isEmpty)
    }

    @Test(.enabled(if: nameTaggerAvailable, "OS name-recognition model unavailable"))
    func extractsPersonalNames() {
        let extractor = EntityExtractor()
        let result = extractor.extract(from: "Call Sarah Connor about the project.")
        #expect(result.people.contains("Sarah Connor"))
    }

    @Test(.enabled(if: nameTaggerAvailable, "OS name-recognition model unavailable"))
    func extractsPlaceNames() {
        let extractor = EntityExtractor()
        let result = extractor.extract(from: "Trip to Guatemala City in July.")
        #expect(result.locations.contains(where: { $0.contains("Guatemala") }))
    }

    @Test func handlesEmptyInput() {
        let extractor = EntityExtractor()
        #expect(extractor.extract(from: "") == .empty)
    }
}
