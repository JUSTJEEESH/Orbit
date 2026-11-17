import Foundation
import Observation
import OrbitDomain
import OrbitKit
import os

/// Place and person reminders Orbit noticed ("Remind me at Mom's to grab
/// the ladder"). Person reminders keep in one tap; place reminders first
/// ask where the place is, through `PlacePickerSheet`.
@MainActor
@Observable
public final class CueRemindersViewModel {
    public private(set) var suggestions: [ListCueSuggestionsUseCase.Suggestion] = []
    public private(set) var errorMessage: String?
    /// The place suggestion waiting for the user to pick a location.
    public var pickingPlaceFor: ListCueSuggestionsUseCase.Suggestion?

    private let list: ListCueSuggestionsUseCase
    private let keepUseCase: KeepCueReminderUseCase
    private let dismissals: any PromiseDismissalStore
    let placeFinder: PlaceFinder
    private let onTaskMutated: @MainActor @Sendable (MemoryTask) async -> Void

    public init(
        list: ListCueSuggestionsUseCase,
        keep: KeepCueReminderUseCase,
        dismissals: any PromiseDismissalStore,
        placeFinder: PlaceFinder,
        onTaskMutated: @escaping @MainActor @Sendable (MemoryTask) async -> Void = { _ in }
    ) {
        self.list = list
        self.keepUseCase = keep
        self.dismissals = dismissals
        self.placeFinder = placeFinder
        self.onTaskMutated = onTaskMutated
    }

    public func refresh() async {
        do {
            suggestions = try await list(dismissed: dismissals.dismissedIDs())
            errorMessage = nil
        } catch {
            OrbitLog.app.error("Cue suggestions load failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Person: keeps now. Place: opens the picker.
    public func remind(_ suggestion: ListCueSuggestionsUseCase.Suggestion) async {
        switch suggestion.hint.target {
        case .place:
            pickingPlaceFor = suggestion
        case .person:
            await keep(suggestion, place: nil)
        }
    }

    /// Called by the picker with the confirmed spot.
    public func keep(_ suggestion: ListCueSuggestionsUseCase.Suggestion, at candidate: PlaceCandidate, name: String) async {
        pickingPlaceFor = nil
        // Arrival alerts need location access; ask now if the user chose
        // a Maps result without granting it yet.
        guard await placeFinder.ensureAuthorization() else {
            errorMessage = "Turn on Location for Orbit in Settings so iPhone can remind you when you arrive."
            return
        }
        let place = PlaceCue(name: name, latitude: candidate.latitude, longitude: candidate.longitude)
        await keep(suggestion, place: place)
    }

    public func dismiss(_ suggestion: ListCueSuggestionsUseCase.Suggestion) {
        dismissals.dismiss(suggestion.id)
        suggestions.removeAll { $0.id == suggestion.id }
    }

    private func keep(_ suggestion: ListCueSuggestionsUseCase.Suggestion, place: PlaceCue?) async {
        do {
            let task = try await keepUseCase(suggestion, place: place)
            Haptics.play(.success)
            suggestions.removeAll { $0.id == suggestion.id }
            errorMessage = nil
            await onTaskMutated(task)
        } catch {
            OrbitLog.app.error("Keep cue reminder failed: \(String(describing: error), privacy: .public)")
            errorMessage = "Couldn\u{2019}t save that reminder. Try again."
            Haptics.play(.failure)
        }
    }
}
