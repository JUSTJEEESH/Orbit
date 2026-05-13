import Foundation
import Observation
import OrbitDomain
import OrbitKit

@MainActor
@Observable
public final class ReadingListViewModel {
    public struct Sections: Equatable, Sendable {
        public var wantToRead: [ReadingListEntry]
        public var currentlyReading: [ReadingListEntry]
        public var finished: [ReadingListEntry]

        public var isEmpty: Bool {
            wantToRead.isEmpty && currentlyReading.isEmpty && finished.isEmpty
        }
    }

    public private(set) var sections: Sections = Sections(
        wantToRead: [],
        currentlyReading: [],
        finished: []
    )
    public private(set) var isLoading: Bool = false
    public private(set) var errorMessage: String?

    private let listEntries: ListReadingItemsUseCase
    private let updateStatus: UpdateReadingItemStatusUseCase

    public init(
        listEntries: ListReadingItemsUseCase,
        updateStatus: UpdateReadingItemStatusUseCase
    ) {
        self.listEntries = listEntries
        self.updateStatus = updateStatus
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let entries = try await listEntries()
            sections = Sections(
                wantToRead: entries.filter { $0.status == .wantToRead },
                currentlyReading: entries.filter { $0.status == .currentlyReading },
                finished: entries.filter { $0.status == .finished }
            )
            errorMessage = nil
        } catch {
            OrbitLog.app.error("Reading list load failed: \(String(describing: error), privacy: .public)")
            errorMessage = "Couldn't load your reading list. Try again in a moment."
        }
    }

    public func setStatus(_ entry: ReadingListEntry, to status: ReadingItem.Status) async {
        do {
            try await updateStatus(itemID: entry.id, in: entry.memoryID, newStatus: status)
            Haptics.play(.selection)
            await load()
        } catch {
            OrbitLog.app.error("Reading list status update failed: \(String(describing: error), privacy: .public)")
            errorMessage = "Couldn't update that book. Try again."
        }
    }

    public func advance(_ entry: ReadingListEntry) async {
        // Cycle status: want → reading → finished → want.
        let next: ReadingItem.Status = {
            switch entry.status {
            case .wantToRead:        return .currentlyReading
            case .currentlyReading:  return .finished
            case .finished:          return .wantToRead
            }
        }()
        await setStatus(entry, to: next)
    }
}
