import Foundation

public struct DeleteMemoryUseCase: Sendable {
    private let repository: any MemoryRepository

    public init(repository: any MemoryRepository) {
        self.repository = repository
    }

    public func callAsFunction(id: UUID) async throws {
        try await repository.delete(id: id)
    }
}
