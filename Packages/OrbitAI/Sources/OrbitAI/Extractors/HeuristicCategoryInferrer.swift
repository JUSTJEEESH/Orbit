import Foundation

/// Picks a category for a capture without calling an LLM. Runs in two
/// situations:
///   - Apple Intelligence is unavailable on the device.
///   - The on-device model returned `nil` / empty category.
///
/// Rules read in priority order — once a category fires it wins. The
/// order is tuned so the strongest signal (an extracted place name or
/// 'passport') beats weaker signals (a single date that could mean a lot).
public enum HeuristicCategoryInferrer {

    public static func infer(text: String, entities: ExtractedEntities) -> String? {
        let lower = text.lowercased()

        // Strongest signal: explicit travel cues.
        let travelKeywords: Set<String> = [
            "trip", "flight", "fly", "passport", "vacation", "visit",
            "travel", "airline", "hotel", "airbnb", "itinerary", "boarding",
        ]
        if !entities.locations.isEmpty || containsAny(lower, travelKeywords) {
            return "travel"
        }

        let workKeywords: Set<String> = [
            "meeting", "client", "project", "deadline", "report",
            "office", "manager", "1:1", "standup", "review",
        ]
        if containsAny(lower, workKeywords) { return "work" }

        let healthKeywords: Set<String> = [
            "doctor", "appointment", "workout", "exercise", "gym",
            "yoga", "diet", "sleep", "meditation", "therapy",
        ]
        if containsAny(lower, healthKeywords) { return "health" }

        let financeKeywords: Set<String> = [
            "$", "budget", "invoice", "bill", "expense", "salary",
            "tax", "savings", "investment",
        ]
        if containsAny(lower, financeKeywords) { return "finance" }

        let learningKeywords: Set<String> = [
            "learn", "course", "study", "tutorial", "lesson",
            "class", "ebook", "lecture",
        ]
        if containsAny(lower, learningKeywords) { return "learning" }

        let taskKeywords: Set<String> = [
            "todo", "to-do", "buy", "need to", "remember to",
            "schedule", "pick up", "call back", "follow up",
        ]
        if containsAny(lower, taskKeywords) { return "task" }

        if !entities.dates.isEmpty { return "reminder" }

        let ideaKeywords: Set<String> = [
            "idea", "what if", "concept", "brainstorm",
        ]
        if containsAny(lower, ideaKeywords) { return "idea" }

        if !entities.people.isEmpty { return "social" }

        return nil // No strong signal — caller falls back to kind label.
    }

    private static func containsAny(_ haystack: String, _ needles: Set<String>) -> Bool {
        for needle in needles where haystack.contains(needle) {
            return true
        }
        return false
    }
}
