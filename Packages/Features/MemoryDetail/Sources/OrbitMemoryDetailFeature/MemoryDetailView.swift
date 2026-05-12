import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit
import OrbitMedia
import OrbitShareFeature

public struct MemoryDetailView: View {
    @State private var model: MemoryDetailViewModel
    @State private var voicePlayer = VoicePlayer()
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
        if let memory = model.memory {
            ToolbarItem(placement: .topBarTrailing) {
                OrbitShareCardButton(previewTitle: "Memory") {
                    MemoryShareCard(memory: memory)
                }
            }
        }
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
            OrbitEmptyState(
                systemImage: "questionmark.circle",
                title: "Memory not found",
                message: "It may have been deleted from another device, or never finished syncing."
            )
            .padding(.top, OrbitSpacing.xxxl)
        case .failed(let message):
            OrbitErrorState(
                title: "Couldn't load memory",
                message: message,
                onRetry: { Task { await model.load() } }
            )
            .padding(.top, OrbitSpacing.xxxl)
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
        VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
            OrbitEyebrow(
                label: eyebrowLabel(memory),
                suffix: kindLabel(memory),
                tint: OrbitCategoryPalette.tint(for: memory.ai.category),
                size: .prominent
            )
            Text(memory.createdAt.formatted(date: .complete, time: .shortened))
                .font(OrbitTypography.title2)
                .foregroundStyle(OrbitColor.textPrimary)
        }
    }

    private func eyebrowLabel(_ memory: Memory) -> String {
        if let category = memory.ai.category?.trimmingCharacters(in: .whitespacesAndNewlines),
           !category.isEmpty {
            return category
        }
        return kindLabel(memory)
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
                VStack(alignment: .leading, spacing: OrbitSpacing.md) {
                    voicePlaybackBar(duration: duration)
                    Text(transcript.flatMap { $0.isEmpty ? nil : $0 } ?? "No transcript yet")
                        .font(OrbitTypography.body)
                        .foregroundStyle(transcript?.isEmpty == false
                            ? OrbitColor.textPrimary
                            : OrbitColor.textSecondary)
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
                        .scaledFont(size: 32)
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

    /// The voice card's transport: play / pause icon, scrubbing progress
    /// bar, and current-time / total-duration readout. Disabled with a
    /// quiet message when the source audio file isn't available (the
    /// memory was captured via the share extension, deleted from disk,
    /// or AppGroup hasn't resolved yet).
    private func voicePlaybackBar(duration: TimeInterval) -> some View {
        let url = model.voiceFileURL
        let isPlaying = voicePlayer.state.isPlaying
        let resolvedDuration: TimeInterval = {
            switch voicePlayer.state {
            case .playing(_, let total), .paused(_, let total): return total
            case .idle: return duration
            }
        }()
        let currentTime: TimeInterval = {
            switch voicePlayer.state {
            case .playing(let current, _), .paused(let current, _): return current
            case .idle: return 0
            }
        }()

        return HStack(spacing: OrbitSpacing.md) {
            Button {
                guard let url else { return }
                if isPlaying {
                    voicePlayer.pause()
                } else {
                    Haptics.play(.tap)
                    voicePlayer.play(url: url)
                }
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .scaledFont(size: 18, weight: .semibold)
                    .foregroundStyle(OrbitColor.textInverted)
                    .frame(width: 44, height: 44)
                    .background(OrbitColor.textPrimary, in: .circle)
            }
            .buttonStyle(.plain)
            .disabled(url == nil)
            .opacity(url == nil ? 0.4 : 1)
            .accessibilityLabel(isPlaying ? "Pause" : "Play")

            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: voicePlayer.state.progress)
                    .progressViewStyle(.linear)
                    .tint(OrbitColor.textPrimary)
                HStack {
                    Text(Self.formatDuration(currentTime))
                        .font(OrbitTypography.monoNumeric)
                        .foregroundStyle(OrbitColor.textSecondary)
                    Spacer()
                    Text(Self.formatDuration(resolvedDuration))
                        .font(OrbitTypography.monoNumeric)
                        .foregroundStyle(OrbitColor.textTertiary)
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

            // Category lives in the editorial eyebrow at the top of the
            // screen; here we surface just the actionable signals.
            HStack(spacing: OrbitSpacing.xs) {
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
