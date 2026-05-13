import SwiftUI
import OrbitKit

public struct OrbitButton: View {
    public enum Style: Sendable {
        case primary
        case secondary
        case ghost
        case destructive
    }

    public enum Size: Sendable {
        case regular
        case large
    }

    private let title: String
    private let systemImage: String?
    private let style: Style
    private let size: Size
    private let action: @MainActor () -> Void

    public init(
        _ title: String,
        systemImage: String? = nil,
        style: Style = .primary,
        size: Size = .regular,
        action: @escaping @MainActor () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.size = size
        self.action = action
    }

    public var body: some View {
        Button {
            Haptics.play(.tap)
            action()
        } label: {
            HStack(spacing: OrbitSpacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: iconSize, weight: .semibold))
                }
                Text(title)
                    .font(font)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(background, in: .rect(cornerRadius: OrbitRadius.md))
            .contentShape(.rect(cornerRadius: OrbitRadius.md))
        }
        .buttonStyle(OrbitPressedButtonStyle())
    }

    private var height: CGFloat {
        switch size {
        case .regular: return 48
        case .large:   return 56
        }
    }

    private var font: Font {
        switch size {
        case .regular: return OrbitTypography.bodyEmphasized
        case .large:   return OrbitTypography.title3
        }
    }

    private var iconSize: CGFloat {
        switch size {
        case .regular: return 16
        case .large:   return 18
        }
    }

    private var foreground: Color {
        switch style {
        case .primary:     return OrbitColor.textInverted
        case .secondary:   return OrbitColor.textPrimary
        case .ghost:       return OrbitColor.textPrimary
        case .destructive: return OrbitColor.textInverted
        }
    }

    private var background: Color {
        switch style {
        case .primary:     return OrbitColor.textPrimary
        case .secondary:   return OrbitColor.surfaceMuted
        case .ghost:       return .clear
        case .destructive: return OrbitColor.danger
        }
    }
}

/// Pressed-state scale + opacity. Calm, not bouncy.
struct OrbitPressedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(OrbitMotion.snap, value: configuration.isPressed)
    }
}
