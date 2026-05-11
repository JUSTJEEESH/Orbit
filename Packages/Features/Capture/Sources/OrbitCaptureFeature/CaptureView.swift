import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit

public struct CaptureView: View {
    private let captureMemory: CaptureMemoryUseCase
    private let onCompleted: @MainActor () -> Void
    private let onCancel: @MainActor () -> Void

    @State private var draft: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    public init(
        captureMemory: CaptureMemoryUseCase,
        onCompleted: @escaping @MainActor () -> Void,
        onCancel: @escaping @MainActor () -> Void
    ) {
        self.captureMemory = captureMemory
        self.onCompleted = onCompleted
        self.onCancel = onCancel
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

                    if let errorMessage {
                        Text(errorMessage)
                            .font(OrbitTypography.footnote)
                            .foregroundStyle(OrbitColor.danger)
                    }

                    Spacer()

                    OrbitButton(
                        isSaving ? "Saving…" : "Save memory",
                        systemImage: "checkmark",
                        style: .primary,
                        size: .large,
                        action: save
                    )
                    .disabled(!canSave)
                }
                .padding(.top, OrbitSpacing.lg)
            }
            .navigationTitle("Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onCancel)
                        .font(OrbitTypography.bodyEmphasized)
                        .foregroundStyle(OrbitColor.textSecondary)
                }
            }
            .onAppear { isFocused = true }
        }
    }

    private var canSave: Bool {
        !isSaving && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSaving = true
        errorMessage = nil
        Task {
            do {
                _ = try await captureMemory(content: .text(text))
                Haptics.play(.success)
                onCompleted()
            } catch {
                isSaving = false
                errorMessage = "Couldn't save. Try again."
                Haptics.play(.failure)
            }
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
        .disabled(true) // attachments arrive in Phase 2
        .opacity(0.5)
    }
}
