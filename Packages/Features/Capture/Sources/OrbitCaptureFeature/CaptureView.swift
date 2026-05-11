import SwiftUI
import PhotosUI
import Foundation
import OrbitDesignSystem
import OrbitDomain
import OrbitMedia
import OrbitKit

public struct CaptureView: View {
    @State private var model: CaptureViewModel
    private let onCompleted: @MainActor (UUID) -> Void
    private let onCancel: @MainActor () -> Void

    @FocusState private var textFocus: Bool
    @State private var photoPickerItem: PhotosPickerItem?

    public init(
        viewModel: CaptureViewModel,
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
                VStack(spacing: OrbitSpacing.lg) {
                    CaptureTypeSwitcher(selection: $model.mode)
                        .padding(.top, OrbitSpacing.md)

                    activeMode

                    if let message = model.errorMessage {
                        Text(message)
                            .font(OrbitTypography.footnote)
                            .foregroundStyle(OrbitColor.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer()

                    OrbitButton(
                        model.isSaving ? "Saving…" : "Save memory",
                        systemImage: "checkmark",
                        style: .primary,
                        size: .large,
                        action: save
                    )
                    .disabled(!model.canSave)
                }
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
            .interactiveDismissDisabled(isRecording)
            .onAppear {
                if model.mode == .text { textFocus = true }
            }
            .onChange(of: photoPickerItem) { _, newItem in
                Task { await loadPhoto(newItem) }
            }
        }
    }

    private var isRecording: Bool {
        if case .recording = model.voiceState { return true }
        return false
    }

    @ViewBuilder
    private var activeMode: some View {
        switch model.mode {
        case .text:  textMode
        case .voice: voiceMode
        case .photo: photoMode
        case .link:  linkMode
        }
    }

    // MARK: - Text

    private var textMode: some View {
        OrbitTextField(
            "What's on your mind?",
            text: $model.textDraft,
            axis: .vertical
        )
        .focused($textFocus)
        .frame(minHeight: 220, alignment: .top)
    }

    // MARK: - Voice

    private var voiceMode: some View {
        VStack(spacing: OrbitSpacing.lg) {
            voiceWaveformPanel
            voiceTranscriptPreview
            voiceControls
        }
    }

    @ViewBuilder
    private var voiceWaveformPanel: some View {
        switch model.voiceState {
        case .idle:
            VoiceWaveformView(levels: [])
                .opacity(0.25)
        case .recording(_, let levels), .transcribing(_, _, let levels):
            VoiceWaveformView(levels: levels, color: OrbitColor.danger)
                .animation(OrbitMotion.snap, value: levels)
        case .recorded(_, _, _):
            VoiceWaveformView(levels: [])
                .opacity(0.25)
        }
    }

    @ViewBuilder
    private var voiceTranscriptPreview: some View {
        switch model.voiceState {
        case .idle:
            Text("Tap the mic to start recording. Up to 30 seconds works best.")
                .font(OrbitTypography.callout)
                .foregroundStyle(OrbitColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .recording(let elapsed, _):
            HStack(spacing: OrbitSpacing.sm) {
                RecordingIndicator(isActive: true)
                Text(Self.formatDuration(elapsed))
                    .font(OrbitTypography.monoNumeric)
                    .foregroundStyle(OrbitColor.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .transcribing(_, let duration, _):
            HStack(spacing: OrbitSpacing.sm) {
                ProgressView()
                Text("Transcribing \(Self.formatDuration(duration))…")
                    .font(OrbitTypography.callout)
                    .foregroundStyle(OrbitColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .recorded(_, let duration, let transcript):
            OrbitCard(elevation: .resting) {
                VStack(alignment: .leading, spacing: OrbitSpacing.xs) {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundStyle(OrbitColor.textSecondary)
                        Text(Self.formatDuration(duration))
                            .font(OrbitTypography.monoNumeric)
                            .foregroundStyle(OrbitColor.textSecondary)
                    }
                    Text(transcript?.isEmpty == false ? transcript! : "No transcript")
                        .font(OrbitTypography.body)
                        .foregroundStyle(OrbitColor.textPrimary)
                }
            }
        }
    }

    @ViewBuilder
    private var voiceControls: some View {
        switch model.voiceState {
        case .idle:
            OrbitButton("Start recording", systemImage: "mic.fill", style: .primary, size: .large) {
                Task { await model.startRecording() }
            }
        case .recording:
            OrbitButton("Stop", systemImage: "stop.fill", style: .destructive, size: .large) {
                Task { await model.stopRecording() }
            }
        case .transcribing:
            OrbitButton("Transcribing…", style: .secondary, size: .large) {}
                .disabled(true)
        case .recorded:
            HStack(spacing: OrbitSpacing.sm) {
                OrbitButton("Discard", style: .secondary) {
                    Task { await model.discardRecording() }
                }
                OrbitButton("Re-record", systemImage: "arrow.counterclockwise", style: .ghost) {
                    Task {
                        await model.discardRecording()
                        await model.startRecording()
                    }
                }
            }
        }
    }

    // MARK: - Photo

    private var photoMode: some View {
        VStack(spacing: OrbitSpacing.lg) {
            if let data = model.photoData, let preview = UIImage(data: data) {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: OrbitRadius.lg))
                OrbitTextField("Caption (optional)", text: $model.photoCaption)
                OrbitButton("Choose a different photo", systemImage: "photo", style: .ghost) {
                    photoPickerItem = nil
                    model.photoData = nil
                }
            } else {
                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    PhotoPlaceholder()
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self) {
            model.photoData = data
        }
    }

    // MARK: - Link

    private var linkMode: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitTextField("Paste a link", text: $model.linkText, systemImage: "link")
                .onSubmit { Task { await model.fetchLinkPreview() } }

            HStack(spacing: OrbitSpacing.sm) {
                OrbitButton("Paste from clipboard", systemImage: "doc.on.clipboard", style: .secondary) {
                    if let pasted = UIPasteboard.general.string {
                        model.linkText = pasted
                        Task { await model.fetchLinkPreview() }
                    }
                }
                OrbitButton(
                    model.linkPreviewLoading ? "Loading…" : "Fetch preview",
                    style: .ghost
                ) {
                    Task { await model.fetchLinkPreview() }
                }
                .disabled(model.linkPreviewLoading || model.linkText.isEmpty)
            }

            if let preview = model.linkPreview {
                OrbitCard {
                    VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
                        Text(preview.title ?? "Untitled link")
                            .font(OrbitTypography.bodyEmphasized)
                            .foregroundStyle(OrbitColor.textPrimary)
                        Text(model.linkText)
                            .font(OrbitTypography.footnote)
                            .foregroundStyle(OrbitColor.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    // MARK: - Save action

    private func save() {
        Task { @MainActor in
            if let memoryID = await model.save() {
                onCompleted(memoryID)
            }
        }
    }

    private static func formatDuration(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

/// Extracted into its own `View` so the `PhotosPicker` label closure doesn't
/// have to capture a computed property on the parent — that capture trips
/// strict-concurrency isolation under Swift 6.
private struct PhotoPlaceholder: View {
    var body: some View {
        VStack(spacing: OrbitSpacing.sm) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(OrbitColor.textSecondary)
            Text("Choose a photo")
                .font(OrbitTypography.bodyEmphasized)
                .foregroundStyle(OrbitColor.textPrimary)
            Text("Pick from your library. Camera arrives later.")
                .font(OrbitTypography.footnote)
                .foregroundStyle(OrbitColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, OrbitSpacing.xxxl)
        .background(OrbitColor.surfaceMuted, in: .rect(cornerRadius: OrbitRadius.lg))
    }
}
