import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit

/// Dedicated "Letter to Future Me" capture surface. Same data flow as the
/// regular capture sheet — saves through CaptureMemoryUseCase — but with
/// a quieter, more editorial scaffold: serif body editor, forced surface
/// date, and a sealed-envelope save action.
public struct LetterCaptureView: View {
    @State private var body: String = ""
    @State private var surfaceDate: Date
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    @FocusState private var fieldFocus: Bool

    private let captureMemory: CaptureMemoryUseCase
    private let onCompleted: @MainActor (UUID) -> Void
    private let onCancel: @MainActor () -> Void

    @Environment(\.orbitTheme) private var orbitTheme

    public init(
        captureMemory: CaptureMemoryUseCase,
        onCompleted: @escaping @MainActor (UUID) -> Void,
        onCancel: @escaping @MainActor () -> Void
    ) {
        self.captureMemory = captureMemory
        self.onCompleted = onCompleted
        self.onCancel = onCancel
        // Default to "one year from today" — the most emotionally resonant
        // anchor for a letter, and easy to tap forward or back from.
        _surfaceDate = State(initialValue: Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date())
    }

    public var body: some View {
        NavigationStack {
            OrbitScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: OrbitSpacing.xl) {
                        header
                        editor
                        surfaceDatePicker
                        if let errorMessage {
                            Text(errorMessage)
                                .font(OrbitTypography.footnote)
                                .foregroundStyle(OrbitColor.danger)
                        }
                        Spacer(minLength: OrbitSpacing.lg)
                        OrbitButton(
                            isSaving ? "Sealing…" : "Seal letter until \(surfaceDate.formatted(date: .abbreviated, time: .omitted))",
                            systemImage: "envelope.fill",
                            style: .primary,
                            size: .large,
                            action: { Task { await save() } }
                        )
                        .disabled(isSaving || trimmedBody.isEmpty)
                    }
                    .padding(.top, OrbitSpacing.lg)
                    .padding(.bottom, OrbitSpacing.xxxl)
                }
            }
            .navigationTitle("Letter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                        .foregroundStyle(OrbitColor.textSecondary)
                }
            }
        }
        .onAppear { fieldFocus = true }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.xs) {
            HStack(spacing: 6) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(orbitTheme.primary)
                Text("Letter to Future You")
                    .font(OrbitTypography.caption)
                    .foregroundStyle(OrbitColor.textSecondary)
                    .tracking(1.1)
            }
            .accessibilityHidden(true)
            Text("Dear future self,")
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(OrbitColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
        }
    }

    // MARK: - Editor

    private var editor: some View {
        OrbitCard(elevation: .resting) {
            ZStack(alignment: .topLeading) {
                if body.isEmpty {
                    Text("Tell yourself something you'll want to remember…")
                        .font(.system(size: 17, design: .serif))
                        .italic()
                        .foregroundStyle(OrbitColor.textTertiary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $body)
                    .font(.system(size: 17, design: .serif))
                    .foregroundStyle(OrbitColor.textPrimary)
                    .frame(minHeight: 220)
                    .focused($fieldFocus)
                    .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: - Surface date

    private var surfaceDatePicker: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
            Text("Surfaces on")
                .font(OrbitTypography.caption)
                .foregroundStyle(OrbitColor.textTertiary)
                .tracking(0.9)
            OrbitCard(elevation: .resting) {
                VStack(alignment: .leading, spacing: OrbitSpacing.md) {
                    HStack(spacing: OrbitSpacing.sm) {
                        quickPickButton(months: 1, label: "1 mo")
                        quickPickButton(months: 6, label: "6 mo")
                        quickPickButton(months: 12, label: "1 yr")
                        quickPickButton(months: 60, label: "5 yr")
                    }
                    DatePicker(
                        "Surface date",
                        selection: $surfaceDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(orbitTheme.primary)
                }
            }
        }
    }

    private func quickPickButton(months: Int, label: String) -> some View {
        Button {
            surfaceDate = Calendar.current.date(byAdding: .month, value: months, to: Date()) ?? Date()
            Haptics.play(.selection)
        } label: {
            Text(label)
                .font(OrbitTypography.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(orbitTheme.primary)
                .padding(.horizontal, OrbitSpacing.md)
                .padding(.vertical, OrbitSpacing.xs)
                .background(orbitTheme.primary.opacity(0.12), in: .capsule)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save

    private var trimmedBody: String {
        body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() async {
        guard !trimmedBody.isEmpty, surfaceDate > Date() else { return }
        isSaving = true
        defer { isSaving = false }
        errorMessage = nil
        do {
            let memory = try await captureMemory(
                content: .text(trimmedBody),
                surfaceDate: surfaceDate,
                isLetter: true
            )
            Haptics.play(.success)
            onCompleted(memory.id)
        } catch {
            errorMessage = "Couldn't seal the letter. Try again."
            Haptics.play(.failure)
        }
    }
}
