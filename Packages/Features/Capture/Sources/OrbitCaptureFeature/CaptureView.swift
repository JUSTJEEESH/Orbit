import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit

public struct CaptureView: View {
    private let onDismiss: @MainActor () -> Void
    @State private var draft: String = ""
    @FocusState private var isFocused: Bool

    public init(onDismiss: @escaping @MainActor () -> Void) {
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            OrbitScreen {
                VStack(alignment: .leading, spacing: OrbitSpacing.lg) {
                    OrbitTextField(
                        "What's on your mind?",
                        text: $draft,
                        axis: .vertical
                    )
                    .focused($isFocused)
                    .frame(minHeight: 180, alignment: .top)

                    HStack(spacing: OrbitSpacing.sm) {
                        attachmentChip("photo.on.rectangle", label: "Photo")
                        attachmentChip("link", label: "Link")
                        attachmentChip("mic.fill", label: "Voice")
                    }

                    Spacer()

                    OrbitButton("Save memory", systemImage: "checkmark", style: .primary, size: .large) {
                        Haptics.play(.success)
                        // Phase 2 will wire this to the CaptureMemory use case.
                        onDismiss()
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.top, OrbitSpacing.lg)
            }
            .navigationTitle("Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { onDismiss() }
                        .font(OrbitTypography.bodyEmphasized)
                        .foregroundStyle(OrbitColor.textSecondary)
                }
            }
            .onAppear { isFocused = true }
        }
    }

    private func attachmentChip(_ icon: String, label: String) -> some View {
        Button {
            Haptics.play(.selection)
        } label: {
            HStack(spacing: OrbitSpacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(label)
                    .font(OrbitTypography.callout)
            }
            .foregroundStyle(OrbitColor.textPrimary)
            .padding(.horizontal, OrbitSpacing.md)
            .padding(.vertical, OrbitSpacing.xs)
            .background(OrbitColor.surfaceMuted, in: .rect(cornerRadius: OrbitRadius.pill))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CaptureView(onDismiss: {}).preferredColorScheme(.dark)
}
