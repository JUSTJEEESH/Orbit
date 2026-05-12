import SwiftUI
import OrbitDesignSystem
import OrbitDomain

/// Editorial single-memory share card. Treats the memory's body text (or
/// AI summary) as the hero — typeset in a serif at large size so a
/// posted card reads like a printed page, not a screenshot.
public struct MemoryShareCard: View {
    let memory: Memory
    @Environment(\.orbitTheme) private var theme

    public init(memory: Memory) {
        self.memory = memory
    }

    public var body: some View {
        ShareCardSurface {
            ShareCardBrandMark()

            Spacer(minLength: 80)

            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(tint)
                    .padding(.bottom, 20)
            }

            Text(hero)
                .font(.system(size: heroFontSize, weight: .regular, design: .serif))
                .foregroundStyle(OrbitColor.textPrimary)
                .lineSpacing(8)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            ShareCardFooterLine(
                leading: memory.createdAt.formatted(.dateTime.month(.wide).day().year()),
                trailing: trailingFooter
            )
        }
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

    /// Hero text scales down as length grows so a one-sentence quote
    /// fills the card while a longer reflection still fits.
    private var heroFontSize: CGFloat {
        let length = hero.count
        switch length {
        case 0..<80:   return 78
        case 80..<160: return 60
        case 160..<300: return 48
        default:       return 40
        }
    }

    private var eyebrow: String? {
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

    /// Semantic category tint when the memory has one (so "travel" stays
    /// warm orange regardless of the user's theme), falling back to the
    /// active theme's accent for uncategorized memories — that way the
    /// user's chosen accent is always visible on the card somewhere.
    private var tint: Color {
        if let category = memory.ai.category?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !category.isEmpty {
            return OrbitCategoryPalette.tint(for: category)
        }
        return theme.primary
    }

    /// Time-of-day on the trailing edge. Reinforces that this is a
    /// single moment, not a digest.
    private var trailingFooter: String? {
        memory.createdAt.formatted(date: .omitted, time: .shortened)
    }
}
