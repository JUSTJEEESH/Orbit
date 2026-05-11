import Foundation
import Testing
@testable import OrbitAI

@Suite("Entity extractor")
struct EntityExtractorTests {

    @Test func extractsAtLeastOneDateFromCommonPhrasing() {
        let extractor = EntityExtractor()
        let result = extractor.extract(from: "Lunch with Pamela next Tuesday at 1pm.")
        #expect(!result.dates.isEmpty)
    }

    @Test func extractsPersonalNames() {
        let extractor = EntityExtractor()
        let result = extractor.extract(from: "Call Sarah Connor about the project.")
        #expect(result.people.contains("Sarah Connor"))
    }

    @Test func extractsPlaceNames() {
        let extractor = EntityExtractor()
        let result = extractor.extract(from: "Trip to Guatemala City in July.")
        #expect(result.locations.contains(where: { $0.contains("Guatemala") }))
    }

    @Test func handlesEmptyInput() {
        let extractor = EntityExtractor()
        #expect(extractor.extract(from: "") == .empty)
    }
}
