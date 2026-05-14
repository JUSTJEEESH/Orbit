import Foundation

/// Records that the user dismissed a memory from a suggestion surface
/// (Home's "Worth revisiting" or Memory Detail's "Connected memories").
/// The next time the corresponding `List…UseCase` runs, the
/// dismissal store filters this memory out of the candidate pool —
/// the user sees a different suggestion in its place.
///
/// Dismissals are time-bounded by the store implementation (90 days at
/// time of writing); we don't surface that in the UI because "I dismissed
/// this once" is information the user shouldn't have to track.
public struct DismissSuggestionUseCase: Sendable {
    private let dismissalStore: any SuggestionDismissalStore
    private let clock: any OrbitClock

    public init(
        dismissalStore: any SuggestionDismissalStore,
        clock: any OrbitClock
    ) {
        self.dismissalStore = dismissalStore
        self.clock = clock
    }

    public func callAsFunction(memoryID: UUID) {
        dismissalStore.dismiss(memoryID, at: clock.now())
    }
}
