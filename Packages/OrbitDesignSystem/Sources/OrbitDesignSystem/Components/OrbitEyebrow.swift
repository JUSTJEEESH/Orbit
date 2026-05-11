import SwiftUI

/// Editorial eyebrow line. A small-caps row that sits above content. The
/// `label` (typically a category) is rendered in `tint`; the trailing
/// `suffix` (usually a relative timestamp) stays neutral. Tracking is
/// loosened slightly so it reads as a magazine masthead, not a chip.
///
/// ```
/// TRAVEL · 2 HOURS AGO
/// Renew passport before July trip
/// ```
///
/// Use `OrbitCategoryPalette.tint(for:)` to derive the color.
public struct OrbitEyebrow: View {
    public enum Size: Sendable {
        case compact   // 11pt — Timeline / Home rows
        case prominent // 13pt — Memory detail header
    }

    private let label: String
    private let suffix: String?
    private let tint: Color
    private let size: Size

    public init(
        label: String,
        suffix: String? = nil,
        tint: Color,
        size: Size = .compact
    ) {
        self.label = label
        self.suffix = suffix
        self.tint = tint
        self.size = size
    }

    public var body: some View {
        HStack(spacing: 6) {
            Text(label.uppercased())
                .foregroundStyle(tint)
            if let suffix, !suffix.isEmpty {
                Text("·")
                    .foregroundStyle(OrbitColor.textTertiary)
                Text(suffix.uppercased())
                    .foregroundStyle(OrbitColor.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .font(font)
        .tracking(1.1)
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var font: Font {
        switch size {
        case .compact:
            return .system(size: 11, weight: .semibold)
        case .prominent:
            return .system(size: 13, weight: .semibold)
        }
    }

    private var accessibilityLabel: String {
        if let suffix, !suffix.isEmpty {
            return "\(label), \(suffix)"
        }
        return label
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        OrbitEyebrow(label: "Travel", suffix: "2 hours ago", tint: OrbitColor.accentWarm)
        OrbitEyebrow(label: "Idea", suffix: "yesterday", tint: OrbitColor.accent)
        OrbitEyebrow(label: "Task", suffix: "just now", tint: OrbitColor.accentGreen)
        OrbitEyebrow(label: "Work", suffix: "3 days ago", tint: OrbitColor.accentCobalt)
        OrbitEyebrow(label: "Journal", suffix: "last week", tint: OrbitColor.accentPlum)
        OrbitEyebrow(label: "Note", suffix: "4 days ago", tint: OrbitColor.textSecondary)
        OrbitEyebrow(label: "Memory", suffix: "Monday at 2pm", tint: OrbitColor.accentWarm, size: .prominent)
    }
    .padding()
    .background(OrbitColor.background)
    .preferredColorScheme(.dark)
}
