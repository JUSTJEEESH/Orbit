import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit

/// Dedicated capture surface for the daily gratitude ritual. Three fields,
/// generous serif copy, no rules — the user can leave one or two blank.
/// Saves through CaptureGratitudeUseCase as a single Memory tagged
/// `gratitude` so it flows through the rest of Orbit (search, recap,
/// timeline) like any other capture.
public struct GratitudeCaptureView: View {
    @State private var model: GratitudeCaptureViewModel
    @FocusState private var focusIndex: Int?
    private let onCompleted: @MainActor (UUID) -> Void
    private let onCancel: @MainActor () -> Void

    @Environment(\.orbitTheme) private var orbitTheme

    public init(
        viewModel: GratitudeCaptureViewModel,
        onCompleted: @escaping @MainActor (UUID) -> Void,
        onCancel: @escaping @MainActor () -> Void
    ) {
        self._model = State(initialValue: viewModel)
        self.onCompleted = onCompleted
        self.onCancel = onCancel
    }

    public var body: some View {
        NavigationStack {
            OrbitScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: OrbitSpacing.xl) {
                        header
                        VStack(spacing: OrbitSpacing.sm) {
                            ForEach(0..<model.entries.count, id: \.self) { index in
                                entryField(index: index)
                            }
                        }
                        if let message = model.errorMessage {
                            Text(message)
                                .font(OrbitTypography.footnote)
                                .foregroundStyle(OrbitColor.danger)
                        }
                        Spacer(minLength: OrbitSpacing.lg)
                        OrbitButton(
                            model.isSaving ? "Saving…" : "Save",
                            systemImage: "heart.fill",
                            style: .primary,
                            size: .large,
                            action: { Task { await save() } }
                        )
                        .disabled(model.isSaving || !model.hasAnyEntry)
                    }
                    .padding(.top, OrbitSpacing.lg)
                    .padding(.bottom, OrbitSpacing.xxxl)
                }
            }
            .navigationTitle("Gratitude")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onCancel)
                        .foregroundStyle(OrbitColor.textSecondary)
                }
            }
        }
        .onAppear { focusIndex = 0 }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.xs) {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundStyle(orbitTheme.primary)
                Text("Today")
                    .font(OrbitTypography.caption)
                    .foregroundStyle(OrbitColor.textSecondary)
                    .tracking(1.1)
            }
            .accessibilityHidden(true)
            Text("Three things you're grateful for")
                .scaledFont(size: 26, weight: .semibold, design: .serif)
                .foregroundStyle(OrbitColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("Big or small. The point is to notice.")
                .font(OrbitTypography.footnote)
                .foregroundStyle(OrbitColor.textSecondary)
                .italic()
                .padding(.top, OrbitSpacing.xxs)
        }
    }

    // MARK: - Entry field

    private func entryField(index: Int) -> some View {
        HStack(alignment: .top, spacing: OrbitSpacing.sm) {
            Text("\(index + 1)")
                .scaledFont(size: 18, weight: .semibold, design: .serif)
                .foregroundStyle(orbitTheme.primary)
                .frame(width: 22, alignment: .leading)
                .padding(.top, 8)
            OrbitTextField(
                placeholder(for: index),
                text: Binding(
                    get: { model.entries[index] },
                    set: { model.entries[index] = $0 }
                ),
                axis: .vertical
            )
            .focused($focusIndex, equals: index)
            .frame(minHeight: 56, alignment: .top)
            .submitLabel(index == model.entries.count - 1 ? .done : .next)
            .onSubmit {
                if index < model.entries.count - 1 {
                    focusIndex = index + 1
                } else {
                    focusIndex = nil
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Gratitude entry \(index + 1)")
    }

    private func placeholder(for index: Int) -> String {
        switch index {
        case 0: return "Something that went well…"
        case 1: return "Someone you appreciated…"
        default: return "A small joy…"
        }
    }

    // MARK: - Save

    private func save() async {
        if let id = await model.save() {
            onCompleted(id)
        }
    }
}
