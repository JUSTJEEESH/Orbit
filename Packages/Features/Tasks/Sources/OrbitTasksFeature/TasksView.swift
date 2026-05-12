import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit

public struct TasksView: View {
    @State private var model: TasksViewModel
    @State private var editing: MemoryTask?
    @State private var showingCompleted: Bool = false
    private let refreshToken: Int

    @Environment(\.orbitTheme) private var orbitTheme

    public init(viewModel: TasksViewModel, refreshToken: Int = 0) {
        self._model = State(initialValue: viewModel)
        self.refreshToken = refreshToken
    }

    public var body: some View {
        NavigationStack {
            OrbitScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: OrbitSpacing.xxl) {
                        if hasAnyContent {
                            if !model.suggestions.isEmpty {
                                suggestionsSection
                            }
                            if !model.sections.soon.isEmpty {
                                section(title: "Today & Soon", tasks: model.sections.soon)
                            }
                            if !model.sections.open.isEmpty {
                                section(title: "Open", tasks: model.sections.open)
                            }
                            if !model.sections.completed.isEmpty {
                                completedSection
                            }
                        } else {
                            emptyState
                        }
                        Spacer(minLength: 96)
                    }
                    .padding(.top, OrbitSpacing.lg)
                }
                .scrollIndicators(.hidden)
                .refreshable { await model.load() }
            }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.large)
        }
        .task(id: refreshToken) { await model.load() }
        .sheet(item: $editing) { task in
            TaskDetailSheet(
                task: task,
                linkedMemory: task.linkedMemoryID.flatMap { model.memoriesByID[$0] },
                onSave: { updated in
                    editing = nil
                    Task { await model.update(updated) }
                },
                onDelete: {
                    editing = nil
                    Task { await model.delete(task) }
                },
                onDismiss: { editing = nil }
            )
            .presentationDetents([.large])
        }
    }

    private var hasAnyContent: Bool {
        !model.suggestions.isEmpty
        || !model.sections.soon.isEmpty
        || !model.sections.open.isEmpty
        || !model.sections.completed.isEmpty
    }

    // MARK: - Sections

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader(
                "Suggested",
                subtitle: model.suggestions.count == 1
                    ? "1 task hint waiting"
                    : "\(model.suggestions.count) task hints waiting"
            )
            .accessibilityAddTraits(.isHeader)
            VStack(spacing: OrbitSpacing.sm) {
                ForEach(model.suggestions) { suggestion in
                    SuggestionCard(suggestion: suggestion) {
                        Task { await model.promote(suggestion) }
                    }
                }
            }
        }
    }

    private func section(title: String, tasks: [MemoryTask]) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader(title)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: OrbitSpacing.sm) {
                ForEach(tasks) { task in
                    TaskRowView(
                        task: task,
                        linkedMemory: task.linkedMemoryID.flatMap { model.memoriesByID[$0] },
                        onToggle: { Task { await model.toggle(task) } },
                        onTap: { editing = task }
                    )
                }
            }
        }
    }

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingCompleted.toggle()
                }
            } label: {
                HStack {
                    OrbitSectionHeader(
                        "Completed",
                        subtitle: "\(model.sections.completed.count) done"
                    )
                    Spacer()
                    Image(systemName: showingCompleted ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(OrbitColor.textSecondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Completed tasks")
            .accessibilityHint(showingCompleted ? "Double-tap to collapse." : "Double-tap to expand.")

            if showingCompleted {
                VStack(spacing: OrbitSpacing.sm) {
                    ForEach(model.sections.completed) { task in
                        TaskRowView(
                            task: task,
                            linkedMemory: task.linkedMemoryID.flatMap { model.memoriesByID[$0] },
                            onToggle: { Task { await model.toggle(task) } },
                            onTap: { editing = task }
                        )
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
            Text("Nothing on your plate")
                .font(OrbitTypography.title2)
                .foregroundStyle(OrbitColor.textPrimary)
            Text("Tasks land here when you write \"I should…\" or \"remind me to…\" in a memory. We'll suggest them — you decide what becomes real.")
                .font(OrbitTypography.body)
                .foregroundStyle(OrbitColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, OrbitSpacing.xxl)
    }
}
