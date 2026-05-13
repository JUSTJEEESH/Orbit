import Foundation

/// Structured signals extracted from a memory's text. These power the
/// "do something useful with this" features — Tasks tab, Reading list,
/// Habit tracking — without forcing the user to tag anything manually.
///
/// Extraction runs at capture time (cheap, regex + dictionary), separate
/// from the AI pipeline. Signals are present immediately after save; the
/// AI pipeline still upgrades the surrounding `MemoryAIMetadata` (summary,
/// category, embedding) in the background.
public struct ExtractedSignals: Codable, Sendable, Hashable {
    public var taskHints: [TaskHint]
    public var habitMentions: [HabitMention]
    public var readingItems: [ReadingItem]

    public init(
        taskHints: [TaskHint] = [],
        habitMentions: [HabitMention] = [],
        readingItems: [ReadingItem] = []
    ) {
        self.taskHints = taskHints
        self.habitMentions = habitMentions
        self.readingItems = readingItems
    }

    public static let empty = ExtractedSignals()

    public var isEmpty: Bool {
        taskHints.isEmpty && habitMentions.isEmpty && readingItems.isEmpty
    }
}

/// "I should call mom" / "remember to buy groceries" — a candidate task
/// surfaced from the memory's text. The Tasks UI promotes one of these
/// into a real `MemoryTask` when the user accepts it.
public struct TaskHint: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    /// The actionable phrase ("call mom", "buy groceries"). Trimmed +
    /// normalized so it can be displayed verbatim as a task title.
    public var phrase: String
    /// The original sentence the hint was extracted from, in case the
    /// promoted phrase loses context the UI wants to preserve.
    public var rawText: String
    /// A nearby date if the extractor found one (e.g. "by Friday").
    /// Optional — task hints without dates are still useful.
    public var dueDate: Date?

    public init(
        id: UUID = UUID(),
        phrase: String,
        rawText: String,
        dueDate: Date? = nil
    ) {
        self.id = id
        self.phrase = phrase
        self.rawText = rawText
        self.dueDate = dueDate
    }
}

/// A habit detection — "ran today", "meditated for 20 minutes". The
/// `habit` is normalized; the `verb` preserves the exact wording the user
/// captured. `occurredAt` is the memory's `createdAt`, since habits are
/// almost always logged in real time.
public struct HabitMention: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var habit: String
    public var verb: String
    public var occurredAt: Date

    public init(
        id: UUID = UUID(),
        habit: String,
        verb: String,
        occurredAt: Date
    ) {
        self.id = id
        self.habit = habit
        self.verb = verb
        self.occurredAt = occurredAt
    }
}

/// A book / article / link the user wants to (or did) read. Rendered into
/// a Reading List smart folder; the same record can flow through
/// want-to-read → currently-reading → finished as the user updates it.
public struct ReadingItem: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var title: String?
    public var url: URL?
    public var status: Status

    public enum Status: String, Codable, Sendable {
        case wantToRead
        case currentlyReading
        case finished
    }

    public init(
        id: UUID = UUID(),
        title: String? = nil,
        url: URL? = nil,
        status: Status = .wantToRead
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.status = status
    }
}

/// Domain-side abstraction for the OrbitAI implementation. Keeps the
/// domain layer pure (no NaturalLanguage import) while still letting
/// CaptureMemoryUseCase invoke extraction synchronously at save time.
public protocol SignalExtracting: Sendable {
    func extract(from memory: Memory) -> ExtractedSignals
}

/// Default implementation used in previews + tests where signal
/// extraction isn't relevant. Production wiring uses the OrbitAI
/// implementation.
public struct NoOpSignalExtractor: SignalExtracting {
    public init() {}
    public func extract(from memory: Memory) -> ExtractedSignals { .empty }
}
