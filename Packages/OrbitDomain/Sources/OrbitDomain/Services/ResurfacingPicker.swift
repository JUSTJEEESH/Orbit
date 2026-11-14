import Foundation

/// Chooses which past memories to bring back in the daily "Worth
/// remembering" notification.
///
/// Rules, in order: never anything sealed or in Recently Deleted, never
/// anything from the last `minimumAge`, never the same memory twice in one
/// batch. Memories from this calendar day in earlier years come first (they
/// feel the most meaningful); the rest are older memories in a shuffled order
/// so the notification doesn't feel mechanical.
public struct ResurfacingPicker: Sendable {
    public static let minimumAge: TimeInterval = 14 * 24 * 60 * 60

    public init() {}

    /// - Parameters:
    ///   - days: start-of-day dates to fill, one memory each.
    /// - Returns: `(day, memory)` pairs; days with nothing left are skipped.
    public func pick<G: RandomNumberGenerator>(
        from memories: [Memory],
        for days: [Date],
        now: Date,
        calendar: Calendar = .current,
        using generator: inout G
    ) -> [(day: Date, memory: Memory)] {
        let eligible = memories.filter { memory in
            !memory.isInTrash
                && !memory.isSealed(at: now)
                && now.timeIntervalSince(memory.createdAt) >= Self.minimumAge
                && !Self.previewText(for: memory).isEmpty
        }
        var used: Set<UUID> = []
        var shuffled = eligible.shuffled(using: &generator)
        var result: [(day: Date, memory: Memory)] = []

        for day in days {
            let target = calendar.dateComponents([.month, .day], from: day)
            let anniversary = shuffled.first { memory in
                guard !used.contains(memory.id) else { return false }
                let created = calendar.dateComponents([.year, .month, .day], from: memory.createdAt)
                let dayYear = calendar.component(.year, from: day)
                return created.month == target.month && created.day == target.day && created.year != dayYear
            }
            guard let chosen = anniversary ?? shuffled.first(where: { !used.contains($0.id) }) else { continue }
            used.insert(chosen.id)
            shuffled.removeAll { $0.id == chosen.id }
            result.append((day, chosen))
        }
        return result
    }

    /// The line shown in the notification body.
    public static func previewText(for memory: Memory) -> String {
        let raw: String? = switch memory.content {
        case .text(let s):                  s
        case .voiceNote(let transcript, _): transcript
        case .image(let caption):           caption ?? memory.ai.summary
        case .link(_, let title, let summary): title ?? summary
        case .screenshot(let ocr):          memory.ai.summary ?? ocr
        case .location(let name, _, _):     name
        }
        return (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
