import SwiftUI

public struct OrbitTextField: View {
    private let placeholder: String
    private let systemImage: String?
    @Binding private var text: String
    private let axis: Axis
    private let focusBinding: FocusState<Bool>.Binding?

    public init(
        _ placeholder: String,
        text: Binding<String>,
        systemImage: String? = nil,
        axis: Axis = .horizontal,
        focused: FocusState<Bool>.Binding? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.systemImage = systemImage
        self.axis = axis
        self.focusBinding = focused
    }

    public var body: some View {
        HStack(spacing: OrbitSpacing.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(OrbitColor.textSecondary)
            }
            field
                .font(OrbitTypography.body)
                .foregroundStyle(OrbitColor.textPrimary)
                .tint(OrbitColor.accent)

            if focusBinding?.wrappedValue == true, !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(OrbitColor.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear text")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, OrbitSpacing.md)
        .frame(minHeight: 48)
        .background(OrbitColor.surfaceMuted, in: .rect(cornerRadius: OrbitRadius.md))
        .animation(.easeInOut(duration: 0.12), value: text.isEmpty)
    }

    @ViewBuilder
    private var field: some View {
        if let focusBinding {
            TextField(placeholder, text: $text, axis: axis)
                .focused(focusBinding)
        } else {
            TextField(placeholder, text: $text, axis: axis)
        }
    }
}
