import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit

public struct MemoryDetailView: View {
    @State private var model: MemoryDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    private let onDeleted: @MainActor () -> Void

    public init(
        viewModel: MemoryDetailViewModel,
        onDeleted: @escaping @MainActor () -> Void
    ) {
        self._model = State(initialValue: viewModel)
        self.onDeleted = onDeleted
    }

    public var body: some View {
        OrbitScreen {
            ScrollView {
                content
                    .padding(.top, OrbitSpacing.lg)
                    .padding(.bottom, OrbitSpacing.xxxl)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .confirmationDialog(
            "Delete this memory?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { @MainActor in
                    if await model.delete() {
                        Haptics.play(.success)
                        onDeleted()
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
        .task { await model.load() }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showDeleteConfirmation = true
                Haptics.play(.warning)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(OrbitColor.danger)
                    .accessibilityLabel("Delete memory")
            }
            .disabled(model.memory == nil)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .padding(.top, OrbitSpacing.xxxl)
                .frame(maxWidth: .infinity)
        case .missing:
            Text("Memory not found")
                .font(OrbitTypography.title3)
                .foregroundStyle(OrbitColor.textSecondary)
                .padding(.top, OrbitSpacing.xxxl)
        case .failed(let message):
            VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                Text("Couldn't load memory")
                    .font(OrbitTypography.title3)
                Text(message)
                    .font(OrbitTypography.footnote)
                    .foregroundStyle(OrbitColor.textSecondary)
            }
        case .loaded:
            if let memory = model.memory {
                loadedContent(memory)
            }
        }
    }

    private func loadedContent(_ memory: Memory) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.xl) {
            header(memory)
            primaryContent(memory)
            if hasAIMetadata(memory) {
                aiSection(memory)
            }
            if !memory.tags.isEmpty {
                tagsSection(memory)
            }
        }
    }

    // MARK: - Sections

    private func header(_ memory: Memory) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
            Text(kindLabel(memory))
                .font(OrbitTypography.caption)
                .textCase(.uppercase)
                .foregroundStyle(OrbitColor.textTertiary)
            Text(memory.createdAt.formatted(date: .complete, time: .shortened))
                .font(OrbitTypography.title2)
                .foregroundStyle(OrbitColor.textPrimary)
        }
    }

    @ViewBuilder
    private func primaryContent(_ memory: Memory) -> some View {
        switch memory.content {
        case .text(let value):
            OrbitCard {
                Text(value)
                    .font(OrbitTypography.body)
                    .foregroundStyle(OrbitColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .voiceNote(let transcript, let duration):
            OrbitCard {
                VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                    HStack(spacing: OrbitSpacing.xs) {
                        Image(systemName: "waveform")
                        Text(Self.formatDuration(duration))
                            .font(OrbitTypography.monoNumeric)
                    }
                    .foregroundStyle(OrbitColor.textSecondary)
                    Text(transcript?.isEmpty == false ? transcript! : "No transcript")
                        .font(OrbitTypography.body)
                        .foregroundStyle(OrbitColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        case .image(let caption):
            imageCard(systemFallback: "photo", caption: caption ?? "Photo")
        case .screenshot(let ocr):
            imageCard(systemFallback: "rectangle.on.rectangle", caption: ocr ?? "Screenshot")
        case .link(let url, let title, let summary):
            OrbitCard {
                VStack(alignment: .leading, spacing: OrbitSpacing.xs) {
                    Text(title ?? url.absoluteString)
                        .font(OrbitTypography.bodyEmphasized)
                        .foregroundStyle(OrbitColor.textPrimary)
                    if let summary {
                        Text(summary)
                            .font(OrbitTypography.callout)
                            .foregroundStyle(OrbitColor.textSecondary)
                    }
                    Link(destination: url) {
                        Text(url.absoluteString)
                            .font(OrbitTypography.footnote)
                            .foregroundStyle(OrbitColor.accent)
                            .lineLimit(1)
                    }
                }
            }
        case .location(let name, let latitude, let longitude):
            OrbitCard {
                VStack(alignment: .leading, spacing: OrbitSpacing.xs) {
                    HStack(spacing: OrbitSpacing.xs) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(OrbitColor.accent)
                        Text(name ?? "Location")
                            .font(OrbitTypography.bodyEmphasized)
                    }
                    Text(String(format: "%.4f, %.4f", latitude, longitude))
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textSecondary)
                }
            }
        }
    }

    /// Shared rendering for `.image` and `.screenshot` content. Renders the
    /// actual photo when the view model has loaded it, otherwise falls back
    /// to the system icon so the card never appears empty.
    private func imageCard(systemFallback: String, caption: String) -> some View {
        OrbitCard {
            VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                if let image = model.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(.rect(cornerRadius: OrbitRadius.md))
                } else {
                    Image(systemName: systemFallback)
                        .font(.system(size: 32))
                        .foregroundStyle(OrbitColor.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                }
                if !caption.isEmpty, caption != "Photo", caption != "Screenshot" {
                    Text(caption)
                        .font(OrbitTypography.body)
                        .foregroundStyle(OrbitColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func aiSection(_ memory: Memory) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Orbit understood")
            if let summary = memory.ai.summary, !summary.isEmpty {
                OrbitCard(elevation: .flat) {
                    Text(summary)
                        .font(OrbitTypography.body)
                        .foregroundStyle(OrbitColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: OrbitSpacing.xs) {
                if let category = memory.ai.category, !category.isEmpty {
                    OrbitChip(category, style: .accent)
                }
                priorityChip(memory.ai.priority)
                statusChip(memory.ai.status)
            }

            if !memory.ai.extractedPeople.isEmpty {
                metadataRow(label: "People", values: memory.ai.extractedPeople)
            }
            if !memory.ai.extractedLocations.isEmpty {
                metadataRow(label: "Places", values: memory.ai.extractedLocations)
            }
            if !memory.ai.extractedDates.isEmpty {
                metadataRow(label: "Dates", values: memory.ai.extractedDates.map {
                    $0.formatted(date: .abbreviated, time: .omitted)
                })
            }
        }
    }

    private func tagsSection(_ memory: Memory) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Tags")
            HStack(spacing: OrbitSpacing.xs) {
                ForEach(memory.tags) { tag in
                    OrbitChip(
                        tag.name,
                        systemImage: tag.origin == .ai ? "sparkles" : "tag",
                        style: tag.origin == .ai ? .accent : .neutral
                    )
                }
            }
        }
    }

    // MARK: - Bits

    private func metadataRow(label: String, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
            Text(label.uppercased())
                .font(OrbitTypography.caption)
                .foregroundStyle(OrbitColor.textTertiary)
            Text(values.joined(separator: ", "))
                .font(OrbitTypography.callout)
                .foregroundStyle(OrbitColor.textPrimary)
        }
    }

    private func priorityChip(_ priority: MemoryAIMetadata.Priority) -> OrbitChip {
        switch priority {
        case .urgent: return OrbitChip("Urgent", systemImage: "exclamationmark", style: .danger)
        case .high:   return OrbitChip("High", style: .warning)
        case .normal: return OrbitChip("Normal", style: .neutral)
        case .low:    return OrbitChip("Low", style: .neutral)
        }
    }

    private func statusChip(_ status: MemoryAIMetadata.ProcessingStatus) -> OrbitChip {
        switch status {
        case .pending:    return OrbitChip("Pending", style: .neutral)
        case .processing: return OrbitChip("Organizing", style: .neutral)
        case .complete:   return OrbitChip("Indexed", systemImage: "checkmark", style: .success)
        case .failed:     return OrbitChip("Retry needed", systemImage: "exclamationmark.triangle", style: .warning)
        }
    }

    private func hasAIMetadata(_ memory: Memory) -> Bool {
        memory.ai.summary?.isEmpty == false
        || memory.ai.category?.isEmpty == false
        || !memory.ai.extractedPeople.isEmpty
        || !memory.ai.extractedLocations.isEmpty
        || !memory.ai.extractedDates.isEmpty
    }

    private func kindLabel(_ memory: Memory) -> String {
        switch memory.content {
        case .text:        return "Note"
        case .voiceNote:   return "Voice note"
        case .image:       return "Photo"
        case .link:        return "Link"
        case .screenshot:  return "Screenshot"
        case .location:    return "Place"
        }
    }

    private static func formatDuration(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
