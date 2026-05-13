import Foundation

public struct ListMemoriesUseCase: Sendable {
    private let repository: any MemoryRepository

    public init(repository: any MemoryRepository) {
        self.repository = repository
    }

    public func callAsFunction(filter: MemoryFilter = .all) async throws -> [Memory] {
        try await repository.list(filter: filter)
    }
}
