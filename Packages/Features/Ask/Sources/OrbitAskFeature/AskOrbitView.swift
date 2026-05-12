import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit
import OrbitMemoryDetailFeature

public struct AskOrbitView: View {
    @State private var model: AskOrbitViewModel
    @State private var sheetOnMemory: UUID?
    @FocusState private var fieldFocus: Bool

    private let makeDetailViewModel: @MainActor (UUID) -> MemoryDetailViewModel
    private let onDismiss: @MainActor () -> Void

    @Environment(\.orbitTheme) private var orbitTheme

    public init(
        viewModel: AskOrbitViewModel,
        makeDetailViewModel: @escaping @MainActor (UUID) -> MemoryDetailViewModel,
        onDismiss: @escaping @MainActor () -> Void
    ) {
        self._model = State(initialValue: viewModel)
        self.makeDetailViewModel = makeDetailViewModel
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            OrbitScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: OrbitSpacing.xl) {
                        header
                        questionField
                        answerSurface
                        Spacer(minLength: 96)
                    }
                    .padding(.top, OrbitSpacing.lg)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Ask Orbit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDismiss)
                        .font(OrbitTypography.bodyEmphasized)
                }
            }
            .sheet(item: detailBinding) { box in
                NavigationStack {
                    MemoryDetailView(
                        viewModel: makeDetailViewModel(box.id),
                        onDeleted: { sheetOnMemory = nil }
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Close") { sheetOnMemory = nil }
                        }
                    }
                }
            }
        }
        .onAppear { fieldFocus = true }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(orbitTheme.primary)
                Text("Ask")
                    .font(OrbitTypography.caption)
                    .foregroundStyle(OrbitColor.textSecondary)
                    .tracking(1.1)
            }
            Text("What's on your mind?")
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundStyle(OrbitColor.textPrimary)
            Text("Orbit reads only your memories. Nothing leaves your phone.")
                .font(OrbitTypography.footnote)
                .foregroundStyle(OrbitColor.textSecondary)
                .padding(.top, OrbitSpacing.xxs)
        }
    }

    // MARK: - Question field

    private var questionField: some View {
        HStack(spacing: OrbitSpacing.sm) {
            OrbitTextField(
                "Ask anything…",
                text: $model.question,
                systemImage: "sparkle"
            )
            .focused($fieldFocus)
            .submitLabel(.search)
            .onSubmit { model.submit() }

            Button {
                model.submit()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(OrbitColor.textInverted)
                    .frame(width: 40, height: 40)
                    .background(
                        model.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? OrbitColor.textTertiary
                            : orbitTheme.primary,
                        in: .circle
                    )
            }
            .buttonStyle(.plain)
            .disabled(model.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Ask")
        }
    }

    // MARK: - Answer

    @ViewBuilder
    private var answerSurface: some View {
        switch model.state {
        case .idle:
            suggestionPrompts
        case .thinking:
            thinkingView
        case .answered(let answer):
            answerCard(answer)
        case .failed(let message):
            failureView(message)
        }
    }

    private var suggestionPrompts: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            Text("Try")
                .font(OrbitTypography.caption)
                .foregroundStyle(OrbitColor.textTertiary)
                .tracking(0.9)
            VStack(alignment: .leading, spacing: OrbitSpacing.xs) {
                ForEach(Self.starterPrompts, id: \.self) { prompt in
                    Button {
                        model.question = prompt
                        model.submit()
                    } label: {
                        HStack {
                            Text(prompt)
                                .font(OrbitTypography.body)
                                .foregroundStyle(OrbitColor.textPrimary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(OrbitColor.textTertiary)
                        }
                        .padding(.horizontal, OrbitSpacing.md)
                        .padding(.vertical, OrbitSpacing.sm)
                        .background(OrbitColor.surfaceMuted, in: .rect(cornerRadius: OrbitRadius.md))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var thinkingView: some View {
        OrbitCard(elevation: .resting) {
            HStack(spacing: OrbitSpacing.sm) {
                ProgressView()
                Text("Thinking…")
                    .font(OrbitTypography.callout)
                    .foregroundStyle(OrbitColor.textSecondary)
            }
        }
        .accessibilityLabel("Thinking")
    }

    private func answerCard(_ answer: AskOrbitAnswer) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.lg) {
            OrbitCard(elevation: .lifted) {
                VStack(alignment: .leading, spacing: OrbitSpacing.md) {
                    Text(answer.question)
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textTertiary)
                        .italic()
                    Text(answer.narrative)
                        .font(.system(size: 19, design: .serif))
                        .foregroundStyle(OrbitColor.textPrimary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !model.sourceMemories.isEmpty {
                VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                    Text("Sources")
                        .font(OrbitTypography.caption)
                        .foregroundStyle(OrbitColor.textTertiary)
                        .tracking(0.9)
                    VStack(spacing: OrbitSpacing.xs) {
                        ForEach(model.sourceMemories) { memory in
                            sourceChip(memory)
                        }
                    }
                }
            }
        }
    }

    private func sourceChip(_ memory: Memory) -> some View {
        Button {
            sheetOnMemory = memory.id
        } label: {
            HStack(alignment: .top, spacing: OrbitSpacing.sm) {
                Circle()
                    .fill(OrbitCategoryPalette.tint(for: memory.ai.category))
                    .frame(width: 6, height: 6)
                    .padding(.top, 7)
                VStack(alignment: .leading, spacing: 2) {
                    Text(snippet(for: memory))
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(memory.createdAt.formatted(.relative(presentation: .named)))
                        .font(OrbitTypography.caption)
                        .foregroundStyle(OrbitColor.textTertiary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(OrbitColor.textTertiary)
            }
            .padding(.horizontal, OrbitSpacing.md)
            .padding(.vertical, OrbitSpacing.sm)
            .background(OrbitColor.surface, in: .rect(cornerRadius: OrbitRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: OrbitRadius.md)
                    .stroke(OrbitColor.separator, lineWidth: 0.5)
            )
        }
        .buttonStyle(OrbitBloomButtonStyle(tint: OrbitCategoryPalette.tint(for: memory.ai.category)))
        .accessibilityLabel("Source memory: \(snippet(for: memory))")
    }

    private func snippet(for memory: Memory) -> String {
        if let summary = memory.ai.summary, !summary.isEmpty { return summary }
        switch memory.content {
        case .text(let s):                          return s
        case .voiceNote(let t, _):                  return t ?? "Voice note"
        case .image(let caption):                   return caption ?? "Photo"
        case .link(_, let title, let summary):      return summary ?? title ?? "Link"
        case .screenshot(let ocr):                  return ocr ?? "Screenshot"
        case .location(let name, _, _):             return name ?? "Place"
        }
    }

    private func failureView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
            Text("Couldn't answer")
                .font(OrbitTypography.title3)
                .foregroundStyle(OrbitColor.textPrimary)
            Text(message)
                .font(OrbitTypography.callout)
                .foregroundStyle(OrbitColor.textSecondary)
            Button("Try again") { model.submit() }
                .font(OrbitTypography.bodyEmphasized)
                .foregroundStyle(orbitTheme.primary)
        }
    }

    /// Binding helper so the conditional sheet stays clean inside the body
    /// builder.
    private var detailBinding: Binding<MemoryIDBox?> {
        Binding(
            get: { sheetOnMemory.map(MemoryIDBox.init) },
            set: { sheetOnMemory = $0?.id }
        )
    }

    private static let starterPrompts: [String] = [
        "What was I worried about last week?",
        "Show me everything about my drone idea.",
        "What books did I want to read?",
        "When did I last mention travel?"
    ]
}

/// `sheet(item:)` requires an Identifiable; we wrap the bare UUID so the
/// memory-detail sheet can be presented imperatively from a state UUID.
private struct MemoryIDBox: Identifiable {
    let id: UUID
}
