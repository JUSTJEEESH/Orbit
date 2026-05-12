import Foundation
import Observation
import OrbitDomain

@MainActor
@Observable
public final class HabitsViewModel {
    public private(set) var habits: [HabitStats] = []
    public private(set) var isLoading: Bool = false
    public private(set) var errorMessage: String?

    private let listHabits: ListHabitsUseCase

    public init(listHabits: ListHabitsUseCase) {
        self.listHabits = listHabits
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            habits = try await listHabits()
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
