import Foundation
import Observation
import OrbitDomain
import OrbitKit

@MainActor
@Observable
public final class GratitudeCaptureViewModel {
    /// Three text fields; the user fills as many or as few as feels true.
    /// We persist whatever's non-empty.
    public var entries: [String] = ["", "", ""]
    public var isSaving: Bool = false
    public var errorMessage: String?

    private let capture: CaptureGratitudeUseCase

    public init(capture: CaptureGratitudeUseCase) {
        self.capture = capture
    }

    public var hasAnyEntry: Bool {
        entries.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    @discardableResult
    public func save() async -> UUID? {
        guard !isSaving, hasAnyEntry else { return nil }
        isSaving = true
        defer { isSaving = false }
        do {
            let memory = try await capture(entries: entries)
            if memory != nil {
                Haptics.play(.success)
            }
            return memory?.id
        } catch {
            errorMessage = "Couldn't save. Try again."
            Haptics.play(.failure)
            return nil
        }
    }
}
