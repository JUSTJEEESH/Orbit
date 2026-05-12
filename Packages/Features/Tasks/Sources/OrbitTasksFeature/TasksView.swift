import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit
import OrbitMemoryDetailFeature

public struct TasksView: View {
    public enum Section: Hashable {
        case tasks, reading, habits

        var title: String {
            switch self {
            case .tasks:   return "Tasks"
            case .reading: return "Reading"
            case .habits:  return "Habits"
            }
        }
    }

    @State private var model: TasksViewModel
    @State private var readingModel: ReadingListViewModel
    @State private var habitsModel: HabitsViewModel
    @State private var editing: MemoryTask?
    @State private var showingCompleted: Bool = false
    @State private var section: Section = .tasks
    @State private var sheetMemory: MemoryIDBox?
    private let refreshToken: Int
    private let makeDetailViewModel: @MainActor (UUID) -> MemoryDetailViewModel

    @Environment(\.orbitTheme) private var orbitTheme

    public init(
        viewModel: TasksViewModel,
        readingViewModel: ReadingListViewModel,
        habitsViewModel: HabitsViewModel,
        refreshToken: Int = 0,
        makeDetailViewModel: @escaping @MainActor (UUID) -> MemoryDetailViewModel
    ) {
        self._model = State(initialValue: viewModel)
        self._readingModel = State(initialValue: readingViewModel)
        self._habitsModel = State(initialValue: habitsViewModel)
        self.refreshToken = refreshToken
        self.makeDetailViewModel = makeDetailViewModel
    }

    public var body: some View {
        NavigationStack {
            OrbitScreen {
                VStack(spacing: 0) {
                    sectionPicker
                        .padding(.horizontal, OrbitSpacing.pageHorizontal)
                        .padding(.top, OrbitSpacing.md)
                    Group {
                        switch section {
                        case .tasks:   tasksBody
                        case .reading: ReadingListView(
                            model: readingModel,
                            onOpenMemory: { id in sheetMemory = MemoryIDBox(id: id) }
                        )
                        case .habits:  HabitsView(model: habitsModel)
                        }
                    }
                    .animation(.easeInOut(duration: 0.18), value: section)
                }
            }
            .navigationTitle(section.title)
            .navigationBarTitleDisplayMode(.large)
        }
        .task(id: refreshToken) {
            await model.load()
            // Reading + Habits each load themselves via their own .task
            // hooks; refreshing the tab pulls everything in step.
            await readingModel.load()
            await habitsModel.load()
        }
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
        .sheet(item: $sheetMemory) { box in
            NavigationStack {
                MemoryDetailView(
                    viewModel: makeDetailViewModel(box.id),
                    onDeleted: { sheetMemory = nil }
                )
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") { sheetMemory = nil }
                    }
                }
            }
        }
    }

    /// `sheet(item:)` requires an Identifiable; wrap the bare UUID so we
    /// can drive the memory-detail sheet from a single state value when
    /// the user taps a Reading-list row.
    private struct MemoryIDBox: Identifiable {
        let id: UUID
    }

    private var sectionPicker: some View {
        Picker("Section", selection: $section) {
            Text("Tasks").tag(Section.tasks)
            Text("Reading").tag(Section.reading)
            Text("Habits").tag(Section.habits)
        }
        .pickerStyle(.segmented)
    }

    private var tasksBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OrbitSpacing.xxl) {
                if hasAnyContent {
                    if !model.suggestions.isEmpty {
                        suggestionsSection
                    }
                    if !model.reminderSuggestions.isEmpty {
                        reminderSuggestionsSection
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

    private var hasAnyContent: Bool {
        !model.suggestions.isEmpty
        || !model.reminderSuggestions.isEmpty
        || !model.sections.soon.isEmpty
        || !model.sections.open.isEmpty
        || !model.sections.completed.isEmpty
    }

    private var reminderSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader(
                "Upcoming dates",
                subtitle: model.reminderSuggestions.count == 1
                    ? "1 memory mentions a future date"
                    : "\(model.reminderSuggestions.count) memories mention future dates"
            )
            .accessibilityAddTraits(.isHeader)
            VStack(spacing: OrbitSpacing.sm) {
                ForEach(model.reminderSuggestions) { suggestion in
                    reminderSuggestionCard(suggestion)
                }
            }
        }
    }

    private func reminderSuggestionCard(_ suggestion: ReminderSuggestion) -> some View {
        OrbitCard(elevation: .resting) {
            VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                OrbitEyebrow(
                    label: "Reminder",
                    suffix: suggestion.date.formatted(date: .abbreviated, time: .shortened),
                    tint: orbitTheme.primary
                )
                Text(reminderHeadline(for: suggestion.memory))
                    .font(OrbitTypography.bodyEmphasized)
                    .foregroundStyle(OrbitColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: OrbitSpacing.sm) {
                    Spacer()
                    Button {
                        Task { await model.promote(suggestion) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bell.badge")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Set reminder")
                                .font(OrbitTypography.footnote)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(orbitTheme.primary)
                        .padding(.horizontal, OrbitSpacing.md)
                        .padding(.vertical, OrbitSpacing.xs)
                        .background(orbitTheme.primary.opacity(0.12), in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Set reminder for \(suggestion.date.formatted(date: .abbreviated, time: .shortened))")
                }
            }
        }
    }

    private func reminderHeadline(for memory: Memory) -> String {
        if let summary = memory.ai.summary, !summary.isEmpty { return summary }
        switch memory.content {
        case .text(let s):                              return s
        case .voiceNote(let t, _):                      return t ?? "Voice note"
        case .image(let caption):                       return caption ?? "Photo"
        case .link(_, let title, let summary):          return summary ?? title ?? "Link"
        case .screenshot(let ocr):                      return ocr ?? "Screenshot"
        case .location(let name, _, _):                 return name ?? "Location"
        }
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
        OrbitEmptyState(
            systemImage: "checkmark.circle",
            title: "Nothing on your plate",
            message: "Tasks land here when you write \"I should…\" or \"remind me to…\" in a memory. We'll suggest them — you decide what becomes real."
        )
        .padding(.top, OrbitSpacing.xxl)
    }
}
