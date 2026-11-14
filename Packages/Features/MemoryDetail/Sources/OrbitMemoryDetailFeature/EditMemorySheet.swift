import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit

/// Edits a memory's text (the note, transcript, caption, link title,
/// screenshot text or place name — whichever this memory has) and its tags.
struct EditMemorySheet: View {
    let memory: Memory
    /// Persists the edit. Throws to keep the sheet open with an error.
    let onSave: @MainActor (String, [String]) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var tags: [String]
    @State private var newTag = ""
    @State private var isSaving = false
    @State private var saveFailed = false
    @FocusState private var focusedField: Field?

    private enum Field { case text, tag }

    init(memory: Memory, onSave: @escaping @MainActor (String, [String]) async throws -> Void) {
        self.memory = memory
        self.onSave = onSave
        self._text = State(initialValue: memory.content.editableText)
        self._tags = State(initialValue: memory.tags.map(\.name))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: OrbitSpacing.xl) {
                    textSection
                    tagsSection
                    if saveFailed {
                        Text("Couldn’t save your changes. Please try again.")
                            .font(OrbitTypography.footnote)
                            .foregroundStyle(OrbitColor.danger)
                    }
                }
                .padding(.horizontal, OrbitSpacing.pageHorizontal)
                .padding(.vertical, OrbitSpacing.lg)
            }
            .background(OrbitColor.background)
            .navigationTitle("Edit Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .bold()
                        .disabled(isSaving || !hasChanges)
                }
            }
            .interactiveDismissDisabled(hasChanges)
            .onAppear { focusedField = .text }
        }
    }

    private var textSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.xs) {
            OrbitSectionHeader(Self.label(for: memory.content.kind))
            TextField(Self.placeholder(for: memory.content.kind), text: $text, axis: .vertical)
                .font(OrbitTypography.body)
                .foregroundStyle(OrbitColor.textPrimary)
                .lineLimit(3...)
                .focused($focusedField, equals: .text)
                .padding(OrbitSpacing.md)
                .background(OrbitColor.surface, in: .rect(cornerRadius: OrbitRadius.md))
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.xs) {
            OrbitSectionHeader("Tags")
            FlowingTags(tags: tags) { removed in
                Haptics.play(.selection)
                tags.removeAll { $0 == removed }
            }
            HStack(spacing: OrbitSpacing.xs) {
                Image(systemName: "number")
                    .foregroundStyle(OrbitColor.textTertiary)
                    .accessibilityHidden(true)
                TextField("Add a tag", text: $newTag)
                    .font(OrbitTypography.callout)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($focusedField, equals: .tag)
                    .onSubmit(addTag)
            }
            .padding(OrbitSpacing.md)
            .background(OrbitColor.surface, in: .rect(cornerRadius: OrbitRadius.md))
        }
    }

    private var hasChanges: Bool {
        text != memory.content.editableText || tags != memory.tags.map(\.name) || !pendingTag.isEmpty
    }

    private var pendingTag: String {
        newTag.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    }

    private func addTag() {
        let name = pendingTag
        newTag = ""
        guard !name.isEmpty, !tags.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) else { return }
        Haptics.play(.selection)
        tags.append(name)
        focusedField = .tag
    }

    private func save() {
        addTag()
        isSaving = true
        saveFailed = false
        Task {
            do {
                try await onSave(text, tags)
                Haptics.play(.success)
                dismiss()
            } catch {
                saveFailed = true
                Haptics.play(.failure)
            }
            isSaving = false
        }
    }

    private static func label(for kind: MemoryContentKind) -> String {
        switch kind {
        case .text:       "Note"
        case .voiceNote:  "Transcript"
        case .image:      "Caption"
        case .link:       "Title"
        case .screenshot: "Text"
        case .location:   "Place"
        }
    }

    private static func placeholder(for kind: MemoryContentKind) -> String {
        switch kind {
        case .text:       "What’s on your mind?"
        case .voiceNote:  "What was said"
        case .image:      "Add a caption"
        case .link:       "Add a title"
        case .screenshot: "Text in the screenshot"
        case .location:   "Name this place"
        }
    }
}

/// Removable tag chips that wrap onto new lines.
private struct FlowingTags: View {
    let tags: [String]
    let onRemove: @MainActor (String) -> Void

    var body: some View {
        if tags.isEmpty {
            Text("No tags yet.")
                .font(OrbitTypography.footnote)
                .foregroundStyle(OrbitColor.textTertiary)
        } else {
            WrappingLayout(spacing: OrbitSpacing.xs) {
                ForEach(tags, id: \.self) { tag in
                    Button {
                        onRemove(tag)
                    } label: {
                        HStack(spacing: OrbitSpacing.xxs) {
                            Text("#\(tag)")
                                .font(OrbitTypography.callout)
                            Image(systemName: "xmark")
                                .font(OrbitTypography.caption)
                                .accessibilityHidden(true)
                        }
                        .foregroundStyle(OrbitColor.textPrimary)
                        .padding(.horizontal, OrbitSpacing.sm)
                        .frame(minHeight: OrbitHitTarget.minimum)
                        .background(OrbitColor.surfaceMuted, in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove tag \(tag)")
                }
            }
        }
    }
}

/// Lays children out left-to-right, wrapping to a new row when the next
/// child doesn't fit.
private struct WrappingLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows.removeLast()
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows.append(row)
        }
        return rows
    }
}
