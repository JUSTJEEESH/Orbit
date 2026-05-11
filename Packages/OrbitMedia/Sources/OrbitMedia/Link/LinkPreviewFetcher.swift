import Foundation
import LinkPresentation

/// Fetches lightweight metadata for a URL captured by the user. Used to make
/// link memories self-explanatory in the timeline without requiring a remote
/// AI call.
public actor LinkPreviewFetcher {
    public struct Preview: Sendable, Equatable {
        public let title: String?
        public let summary: String?

        public init(title: String?, summary: String?) {
            self.title = title
            self.summary = summary
        }
    }

    public init() {}

    public func fetch(_ url: URL) async throws -> Preview {
        let metadata = try await LPMetadataProvider().startFetchingMetadata(for: url)
        // We deliberately don't synthesize a summary here — that's the AI
        // pipeline's job in Phase 3. The title alone is enough to make a
        // link memory legible in the timeline.
        return Preview(title: metadata.title, summary: nil)
    }
}
