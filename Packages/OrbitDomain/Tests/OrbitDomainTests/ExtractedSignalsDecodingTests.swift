import Foundation
import Testing
@testable import OrbitDomain

/// Signals are stored as JSON on every memory. Blobs written by older
/// versions must keep decoding after new fields are added.
@Suite("Stored signals stay readable")
struct ExtractedSignalsDecodingTests {
    @Test func oneXSignalsWithoutPromisesStillDecode() throws {
        // Exactly the shape Orbit 1.x wrote: no `promises`, no `dueDateHasTime`.
        let json = """
        {"taskHints":[{"id":"3F2504E0-4F89-11D3-9A0C-0305E82C3301","phrase":"call mom","rawText":"I should call mom"}],
         "habitMentions":[],"readingItems":[]}
        """
        let signals = try JSONDecoder().decode(ExtractedSignals.self, from: Data(json.utf8))
        #expect(signals.taskHints.map(\.phrase) == ["call mom"])
        #expect(signals.taskHints.first?.dueDateHasTime == nil)
        #expect(signals.promises.isEmpty)
    }

    @Test func partialBlobsDecodeWithDefaults() throws {
        let signals = try JSONDecoder().decode(ExtractedSignals.self, from: Data("{}".utf8))
        #expect(signals == .empty)
    }

    @Test func promisesRoundTrip() throws {
        let original = ExtractedSignals(promises: [PromiseHint(person: "Sam", item: "send the photos")])
        let decoded = try JSONDecoder().decode(ExtractedSignals.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }
}
