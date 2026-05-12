import Foundation

/// Promotes a date-based reminder suggestion into a real `MemoryTask`.
/// Mirrors `PromoteHintToTaskUseCase` but derives the title from the
/// memory's headline (rather than an extracted phrase) and uses the
/// suggestion's date as the task's due-date.
public struct PromoteReminderToTaskUseCase: Sendable {
    private let tasks: any TaskRepository
    private let clock: any OrbitClock

    public init(tasks: any TaskRepository, clock: any OrbitClock) {
        self.tasks = tasks
        self.clock = clock
    }

    @discardableResult
    public func callAsFunction(memory: Memory, date: Date) async throws -> MemoryTask {
        let task = MemoryTask(
            title: Self.title(for: memory),
            dueDate: date,
            linkedMemoryID: memory.id,
            createdAt: clock.now()
        )
        try await tasks.save(task)
        return task
    }

    private static func title(for memory: Memory) -> String {
        if let summary = memory.ai.summary, !summary.isEmpty {
            return String(summary.prefix(120))
        }
        let raw: String = {
            switch memory.content {
            case .text(let s):                              return s
            case .voiceNote(let t, _):                      return t ?? "Voice note"
            case .image(let caption):                       return caption ?? "Photo"
            case .link(_, let title, let summary):          return summary ?? title ?? "Link"
            case .screenshot(let ocr):                      return ocr ?? "Screenshot"
            case .location(let name, _, _):                 return name ?? "Location"
            }
        }()
        return String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
    }
}
