import SwiftUI

public struct OrbitTextField: View {
    private let placeholder: String
    private let systemImage: String?
    @Binding private var text: String
    private let axis: Axis

    public init(
        _ placeholder: String,
        text: Binding<String>,
        systemImage: String? = nil,
        axis: Axis = .horizontal
    ) {
        self.placeholder = placeholder
        self._text = text
        self.systemImage = systemImage
        self.axis = axis
    }

    public var body: some View {
        HStack(spacing: OrbitSpacing.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(OrbitColor.textSecondary)
            }
            TextField(placeholder, text: $text, axis: axis)
                .font(OrbitTypography.body)
                .foregroundStyle(OrbitColor.textPrimary)
                .tint(OrbitColor.accent)
        }
        .padding(.horizontal, OrbitSpacing.md)
        .frame(minHeight: 48)
        .background(OrbitColor.surfaceMuted, in: .rect(cornerRadius: OrbitRadius.md))
    }
}
