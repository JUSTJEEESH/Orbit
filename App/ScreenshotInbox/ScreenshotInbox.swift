import Foundation
import Observation
import os
import Photos
import OrbitKit
import OrbitDomain
import OrbitMedia
import OrbitAI

/// The Screenshot Inbox: Orbit reads your recent screenshots (only after you
/// turn it on), recognizes their text on device, and suggests what each one
/// is — an event, a receipt, a recipe, a note — so the "screenshot
/// graveyard" becomes memories you can find.
///
/// Nothing is saved without a tap, and nothing in your photo library is
/// changed. Dated screenshots (tickets, bookings) also get a reminder.
@MainActor
@Observable
final class ScreenshotInbox {
    struct Candidate: Identifiable, Equatable {
        let id: String
        let createdAt: Date
        let imageData: Data
        let text: String
        let suggestion: ScreenshotClassifier.Suggestion
    }

    private(set) var isEnabled: Bool
    private(set) var pending: [Candidate] = []
    private(set) var isScanning = false

    private enum Keys {
        static let enabledAt = "orbit.screenshotInbox.enabledAt"
        static let handled = "orbit.screenshotInbox.handledIDs"
    }

    /// How far back the very first scan looks, so turning the inbox on
    /// doesn't bury the user in years of screenshots.
    private static let initialLookback: TimeInterval = 7 * 24 * 60 * 60
    /// Screenshots considered per scan.
    private static let scanLimit = 24
    /// Long-edge size for stored screenshots and OCR.
    private static let storedPixelSize = 2_048
    /// How many handled IDs to remember (oldest dropped first).
    private static let handledMemory = 500

    private let storage: MediaStorage
    private let ocr: OCRService
    private let capture: CaptureMemoryUseCase
    private let tasks: any TaskRepository
    private let classifier = ScreenshotClassifier()
    /// Called after a screenshot becomes a memory (and its task, if any).
    var onSaved: (@MainActor (UUID, MemoryTask?) -> Void)?

    init(storage: MediaStorage, ocr: OCRService, capture: CaptureMemoryUseCase, tasks: any TaskRepository) {
        self.storage = storage
        self.ocr = ocr
        self.capture = capture
        self.tasks = tasks
        self.isEnabled = UserDefaults.standard.object(forKey: Keys.enabledAt) != nil
    }

    // MARK: - Enable

    /// Asks for Photos access and turns the inbox on.
    /// - Returns: whether it's on afterwards.
    @discardableResult
    func enable() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else { return false }
        UserDefaults.standard.set(Date(), forKey: Keys.enabledAt)
        isEnabled = true
        await scan()
        return true
    }

    func disable() {
        UserDefaults.standard.removeObject(forKey: Keys.enabledAt)
        isEnabled = false
        pending = []
    }

    // MARK: - Scan

    /// Looks for new screenshots and prepares suggestions for them.
    func scan() async {
        guard isEnabled, !isScanning,
              let enabledAt = UserDefaults.standard.object(forKey: Keys.enabledAt) as? Date
        else { return }
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return }

        isScanning = true
        defer { isScanning = false }

        let handled = Set(UserDefaults.standard.stringArray(forKey: Keys.handled) ?? [])
        let since = enabledAt.addingTimeInterval(-Self.initialLookback)
        var found: [Candidate] = []
        for asset in Self.recentScreenshots(limit: Self.scanLimit) {
            guard let created = asset.creationDate, created >= since,
                  !handled.contains(asset.localIdentifier),
                  !pending.contains(where: { $0.id == asset.localIdentifier }),
                  let raw = await Self.imageData(for: asset),
                  let jpeg = ImageDownsampler.jpegData(from: raw, maxPixelSize: Self.storedPixelSize)
            else { continue }
            let text = ((try? await ocr.extractText(from: jpeg)) ?? nil)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            // Screenshots with no readable text aren't worth suggesting.
            guard !text.isEmpty else {
                markHandled(asset.localIdentifier)
                continue
            }
            found.append(Candidate(
                id: asset.localIdentifier,
                createdAt: created,
                imageData: jpeg,
                text: text,
                suggestion: classifier.classify(text)
            ))
        }
        pending = (pending + found).sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Act

    /// Saves a screenshot as a memory. Dated ones also get a reminder task.
    func save(_ candidate: Candidate) async throws {
        let stored = try await storage.write(candidate.imageData, kind: .image)
        let asset = MediaAsset(kind: .image, filename: stored.filename, byteSize: stored.byteSize, createdAt: candidate.createdAt)
        let memory = try await capture(
            content: .screenshot(ocrText: candidate.text),
            tags: candidate.suggestion.tags.map { Tag(name: $0, origin: .ai) },
            media: [asset],
            createdAt: candidate.createdAt
        )
        var task: MemoryTask?
        if case .event(let date) = candidate.suggestion.kind {
            let reminder = MemoryTask(
                title: candidate.suggestion.title ?? "Screenshot reminder",
                dueDate: date,
                linkedMemoryID: memory.id,
                createdAt: Date()
            )
            try await tasks.save(reminder)
            task = reminder
        }
        markHandled(candidate.id)
        pending.removeAll { $0.id == candidate.id }
        onSaved?(memory.id, task)
    }

    /// Leaves a screenshot alone; it won't be suggested again.
    func skip(_ candidate: Candidate) {
        markHandled(candidate.id)
        pending.removeAll { $0.id == candidate.id }
    }

    private func markHandled(_ id: String) {
        var handled = UserDefaults.standard.stringArray(forKey: Keys.handled) ?? []
        handled.append(id)
        if handled.count > Self.handledMemory { handled.removeFirst(handled.count - Self.handledMemory) }
        UserDefaults.standard.set(handled, forKey: Keys.handled)
    }

    // MARK: - PhotoKit

    private static func recentScreenshots(limit: Int) -> [PHAsset] {
        let albums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumScreenshots, options: nil)
        guard let album = albums.firstObject else { return [] }
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = limit
        let result = PHAsset.fetchAssets(in: album, options: options)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    @MainActor
    private static func imageData(for asset: PHAsset) async -> Data? {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.version = .current
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }
}
