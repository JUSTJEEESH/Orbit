import SwiftUI

public struct OrbitChip: View {
    public enum Style: Sendable {
        case neutral
        case accent
        case success
        case warning
        case danger
    }

    private let title: String
    private let systemImage: String?
    private let style: Style
    private let isSelected: Bool

    public init(
        _ title: String,
        systemImage: String? = nil,
        style: Style = .neutral,
        isSelected: Bool = false
    ) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.isSelected = isSelected
    }

    public var body: some View {
        HStack(spacing: OrbitSpacing.xxs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
            }
            Text(title)
                .font(OrbitTypography.caption)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, OrbitSpacing.sm)
        .padding(.vertical, OrbitSpacing.xxs + 2)
        .background(background, in: .rect(cornerRadius: OrbitRadius.pill))
    }

    private var foreground: Color {
        if isSelected { return OrbitColor.textInverted }
        switch style {
        case .neutral: return OrbitColor.textSecondary
        case .accent:  return OrbitColor.accent
        case .success: return OrbitColor.success
        case .warning: return OrbitColor.warning
        case .danger:  return OrbitColor.danger
        }
    }

    private var background: Color {
        if isSelected { return OrbitColor.textPrimary }
        return OrbitColor.surfaceMuted
    }
}
