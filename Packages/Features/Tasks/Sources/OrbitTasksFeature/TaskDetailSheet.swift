import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit

/// Editing sheet for a single task. Tighter than a navigation push because
/// the Tasks UI is already a tab — the user lands back on the list
/// immediately on Save / Cancel.
struct TaskDetailSheet: View {
    let original: MemoryTask
    let linkedMemory: Memory?
    let onSave: @MainActor (MemoryTask) -> Void
    let onDelete: @MainActor () -> Void
    let onDismiss: @MainActor () -> Void

    @State private var title: String
    @State private var notes: String
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var showDeleteConfirmation = false

    @Environment(\.orbitTheme) private var orbitTheme

    init(
        task: MemoryTask,
        linkedMemory: Memory?,
        onSave: @escaping @MainActor (MemoryTask) -> Void,
        onDelete: @escaping @MainActor () -> Void,
        onDismiss: @escaping @MainActor () -> Void
    ) {
        self.original = task
        self.linkedMemory = linkedMemory
        self.onSave = onSave
        self.onDelete = onDelete
        self.onDismiss = onDismiss
        _title = State(initialValue: task.title)
        _notes = State(initialValue: task.notes ?? "")
        _hasDueDate = State(initialValue: task.dueDate != nil)
        _dueDate = State(initialValue: task.dueDate ?? Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
    }

    var body: some View {
        NavigationStack {
            OrbitScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: OrbitSpacing.lg) {
                        titleField
                        notesField
                        dueDateRow
                        if let memory = linkedMemory {
                            sourceMemorySection(memory)
                        }
                        Spacer(minLength: 0)
                        deleteButton
                    }
                    .padding(.vertical, OrbitSpacing.lg)
                }
            }
            .navigationTitle("Edit task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onDismiss)
                        .foregroundStyle(OrbitColor.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Haptics.play(.success)
                        onSave(makeUpdated())
                    }
                    .font(OrbitTypography.bodyEmphasized)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog(
                "Delete this task?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    onDelete()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This can't be undone.")
            }
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
            sectionLabel("Title")
            OrbitTextField("What needs doing?", text: $title)
        }
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
            sectionLabel("Notes")
            OrbitTextField("Optional", text: $notes, axis: .vertical)
                .frame(minHeight: 80, alignment: .top)
        }
    }

    private var dueDateRow: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
            sectionLabel("Due")
            OrbitCard(elevation: .resting) {
                VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                    Toggle(isOn: $hasDueDate) {
                        Text(hasDueDate ? "Has due date" : "No due date")
                            .font(OrbitTypography.body)
                            .foregroundStyle(OrbitColor.textPrimary)
                    }
                    .tint(orbitTheme.primary)
                    if hasDueDate {
                        DatePicker(
                            "Due date",
                            selection: $dueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    }
                }
            }
        }
    }

    private func sourceMemorySection(_ memory: Memory) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
            sectionLabel("From memory")
            OrbitCard(elevation: .resting) {
                VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
                    OrbitEyebrow(
                        label: eyebrowLabel(for: memory),
                        suffix: memory.createdAt.formatted(.relative(presentation: .named)),
                        tint: OrbitCategoryPalette.tint(for: memory.ai.category)
                    )
                    Text(memorySnippet(memory))
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            Haptics.play(.warning)
            showDeleteConfirmation = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "trash")
                Text("Delete task")
            }
            .font(OrbitTypography.bodyEmphasized)
            .foregroundStyle(OrbitColor.danger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, OrbitSpacing.md)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(OrbitTypography.caption)
            .foregroundStyle(OrbitColor.textTertiary)
            .tracking(0.9)
    }

    private func makeUpdated() -> MemoryTask {
        var copy = original
        copy.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        copy.dueDate = hasDueDate ? dueDate : nil
        return copy
    }

    private func eyebrowLabel(for memory: Memory) -> String {
        if let category = memory.ai.category?.trimmingCharacters(in: .whitespacesAndNewlines),
           !category.isEmpty {
            return category
        }
        switch memory.content.kind {
        case .text:       return "Note"
        case .voiceNote:  return "Voice"
        case .image:      return "Photo"
        case .link:       return "Link"
        case .screenshot: return "Screenshot"
        case .location:   return "Place"
        }
    }

    private func memorySnippet(_ memory: Memory) -> String {
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
}
