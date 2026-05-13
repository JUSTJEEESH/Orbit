import SwiftUI

/// Maps AI-generated category labels to design system accent colors. Five
/// hue families, semantically grouped so the timeline reads as a calm
/// palette rather than a confetti of accent colors.
///
/// Unknown / missing categories return `.textSecondary` so the eyebrow
/// quietly recedes — color is *earned* by AI classification.
public enum OrbitCategoryPalette {

    /// Returns the accent color for an AI category. `nil` / empty / unknown
    /// → a neutral secondary text color, never a vivid accent.
    public static func tint(for category: String?) -> Color {
        guard let raw = category?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !raw.isEmpty
        else { return OrbitColor.textSecondary }

        switch raw {
        // Aurora — electric blue
        case "idea", "ideas", "learning", "research":
            return OrbitColor.accent

        // Sunset — warm orange
        case "travel", "social", "moment", "memory":
            return OrbitColor.accentWarm

        // Forest — vivid green
        case "task", "todo", "health", "fitness", "habit":
            return OrbitColor.accentGreen

        // Cobalt — deep cool blue
        case "work", "finance", "project", "money":
            return OrbitColor.accentCobalt

        // Plum — muted purple
        case "journal", "reminder", "personal", "emotion":
            return OrbitColor.accentPlum

        // Note + everything else → quiet neutral.
        case "note", "notes":
            return OrbitColor.textSecondary

        default:
            return OrbitColor.textSecondary
        }
    }
}
