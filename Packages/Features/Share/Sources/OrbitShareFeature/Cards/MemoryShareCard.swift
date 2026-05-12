import SwiftUI
import OrbitDesignSystem
import OrbitDomain

/// Pull-quote treatment for a single memory. The card reads like a
/// magazine sidebar: massive opening serif quotation mark anchors the
/// composition, body text in serif at a length-aware size, attribution
/// in small caps at the bottom. Asymmetric — left-aligned with deep
/// breathing room on the right edge — to feel like a printed page,
/// not a phone screenshot.
public struct MemoryShareCard: View {
    let memory: Memory
    @Environment(\.orbitTheme) private var theme

    public init(memory: Memory) {
        self.memory = memory
    }

    public var body: some View {
        ShareCardSurface {
            ShareCardTopRail(stamp: stamp)

            Spacer().frame(height: 36)

            ShareCardHairline()

            Spacer().frame(height: 72)

            quoteMark

            Spacer().frame(height: 18)

            Text(hero)
                .font(.system(size: heroFontSize, weight: .regular, design: .serif))
                .foregroundStyle(OrbitColor.textPrimary)
                .lineSpacing(heroLineSpacing)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 32)

            attribution

            Spacer()

            ShareCardHairline()

            Spacer().frame(height: 28)

            ShareCardPublisherLine()
        }
    }

    /// Decorative opening quotation mark. Tinted with the category color
    /// when one exists, theme primary otherwise. Anchors the eye and
    /// telegraphs "this is a moment worth saving."
    private var quoteMark: some View {
        Text("\u{201C}") // “
            .font(.system(size: 220, weight: .black, design: .serif))
            .foregroundStyle(tint)
            .frame(height: 88, alignment: .top)
            .offset(x: -8) // optical alignment — the serif overshoots its left bearing
    }

    /// Eyebrow + meta block. Category and time-of-day in small caps,
    /// the way Day One captions a journal photo.
    private var attribution: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Circle()
                    .fill(tint)
                    .frame(width: 8, height: 8)
                Text(eyebrowLabel.uppercased())
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(tint)
            }
            Text(memory.createdAt.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundStyle(OrbitColor.textSecondary)
            Text(memory.createdAt.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 18, weight: .regular, design: .rounded))
                .foregroundStyle(OrbitColor.textTertiary)
        }
    }

    private var stamp: String {
        let kindLabel: String
        switch memory.content {
        case .text:        kindLabel = "Note"
        case .voiceNote:   kindLabel = "Voice"
        case .image:       kindLabel = "Photo"
        case .link:        kindLabel = "Link"
        case .screenshot:  kindLabel = "Screenshot"
        case .location:    kindLabel = "Place"
        }
        return "Memory · \(kindLabel)"
    }

    private var hero: String {
        if let summary = memory.ai.summary?.trimmingCharacters(in: .whitespacesAndNewlines),
           !summary.isEmpty {
            return summary
        }
        switch memory.content {
        case .text(let s):                       return s
        case .voiceNote(let transcript, _):      return transcript ?? "Voice note"
        case .image(let caption):                return caption ?? "Photo"
        case .link(_, let title, let summary):   return summary ?? title ?? "Link"
        case .screenshot(let ocr):               return ocr ?? "Screenshot"
        case .location(let name, _, _):          return name ?? "Location"
        }
    }

    /// Hero text scales down as length grows so a one-line aphorism
    /// fills the card while a long reflection still fits. Tuned to the
    /// new 72pt horizontal padding + pull-quote whitespace.
    private var heroFontSize: CGFloat {
        switch hero.count {
        case 0..<60:    return 96
        case 60..<140:  return 76
        case 140..<260: return 58
        case 260..<400: return 46
        default:        return 38
        }
    }

    /// Tighter leading at large sizes reads cleaner, looser at smaller
    /// sizes keeps long passages breathable.
    private var heroLineSpacing: CGFloat {
        heroFontSize >= 76 ? 4 : 8
    }

    private var eyebrowLabel: String {
        if let category = memory.ai.category?.trimmingCharacters(in: .whitespacesAndNewlines),
           !category.isEmpty {
            return category
        }
        switch memory.content {
        case .text:        return "Note"
        case .voiceNote:   return "Voice"
        case .image:       return "Photo"
        case .link:        return "Link"
        case .screenshot:  return "Screenshot"
        case .location:    return "Place"
        }
    }

    /// Semantic category tint when the memory has one (so "travel"
    /// stays warm orange regardless of the user's theme), falling back
    /// to the active theme's accent for uncategorized memories so the
    /// user's chosen color is always visible somewhere on the card.
    private var tint: Color {
        if let category = memory.ai.category?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !category.isEmpty {
            return OrbitCategoryPalette.tint(for: category)
        }
        return theme.primary
    }
}
