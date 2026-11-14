import Foundation
import OrbitKit
import OrbitDomain
import OrbitPersistence
import OrbitMedia

/// Background upkeep that repairs data left incomplete by Orbit 1.x — and by
/// any capture interrupted since (app killed mid-enrichment, extension saves
/// that never got enriched). Runs once per launch, after the first frame, and
/// never blocks the UI.
///
/// Everything here is repair-only: it adds missing transcripts, AI metadata
/// and rescued rows. It never deletes or overwrites anything the user wrote.
extension AppEnvironment {
    private enum MaintenanceKeys {
        static let rescueCompleted = "orbit.rescue.legacyStore.completed"
        /// Read by the What's New sheet: "We found N memories you saved with Siri."
        static let rescuedCount = "orbit.rescue.legacyStore.count"
        /// Voice memories whose audio we already tried to transcribe, so a
        /// silent or unreadable recording isn't retried on every launch.
        static let transcriptionAttempted = "orbit.maintenance.transcriptionAttempted"
    }

    /// How many memories 1.x's Siri intent had hidden that 2.0 recovered.
    var rescuedLegacyMemoryCount: Int {
        UserDefaults.standard.integer(forKey: MaintenanceKeys.rescuedCount)
    }

    /// Entry point, called from the root view's launch task.
    func runLaunchMaintenance() async {
        await rescueLegacyStoreIfNeeded()
        await completeUnfinishedMemories()
    }

    // MARK: - Legacy store rescue

    /// Copies memories 1.x saved into the per-app store (see
    /// `LegacyStoreRescue`) into the main library. Retries on the next launch
    /// if anything throws; marks itself complete only after a clean pass.
    private func rescueLegacyStoreIfNeeded() async {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: MaintenanceKeys.rescueCompleted) else { return }

        let legacyURL = ModelContainerFactory.localStoreURL()
        // No legacy file, or the main library *is* the per-app store because
        // the App Group is unavailable: nothing to rescue.
        guard FileManager.default.fileExists(atPath: legacyURL.path),
              ModelContainerFactory.appGroupStoreURL(for: appConfig.appGroupIdentifier) != nil
        else {
            defaults.set(true, forKey: MaintenanceKeys.rescueCompleted)
            return
        }

        do {
            let legacy = try ModelContainerFactory.makeContainer(mode: .storeURL(legacyURL))
            let outcome = try await LegacyStoreRescue.copyMissingRows(
                fromMemories: SwiftDataMemoryRepository(modelContainer: legacy),
                tasks: SwiftDataTaskRepository(modelContainer: legacy),
                intoMemories: memories,
                tasks: tasks
            )
            await copyLegacyMedia(outcome.mediaFilenames)
            defaults.set(outcome.rescuedMemoryIDs.count, forKey: MaintenanceKeys.rescuedCount)
            defaults.set(true, forKey: MaintenanceKeys.rescueCompleted)
            OrbitLog.persistence.notice("Legacy rescue: \(outcome.rescuedMemoryIDs.count, privacy: .public) memories, \(outcome.rescuedTaskIDs.count, privacy: .public) tasks.")

            guard !outcome.isEmpty else { return }
            memoriesDidChange()
            for id in outcome.rescuedMemoryIDs {
                if let memory = try? await memories.memory(with: id) {
                    await spotlight.index(memory)
                }
            }
        } catch {
            OrbitLog.persistence.error("Legacy rescue failed; will retry next launch: \(String(describing: error), privacy: .public)")
        }
    }

    /// When the App Group was unavailable, 1.x stored media in the app's own
    /// Documents folder. Copy any rescued files next to the main library's
    /// media so their memories can play / display them. Originals stay put.
    private func copyLegacyMedia(_ filenames: [String]) async {
        guard !filenames.isEmpty else { return }
        // Mirrors `MediaStorage`'s per-app fallback root. Computed rather
        // than constructing a `MediaStorage`, which would create the folder.
        let legacyRoot = URL.documentsDirectory.appendingPathComponent("Orbit/media", isDirectory: true)
        for filename in filenames {
            let source = legacyRoot.appendingPathComponent(filename)
            let destination = await mediaStorage.url(forFilename: filename)
            guard FileManager.default.fileExists(atPath: source.path),
                  !FileManager.default.fileExists(atPath: destination.path)
            else { continue }
            do {
                try FileManager.default.copyItem(at: source, to: destination)
            } catch {
                OrbitLog.persistence.error("Legacy media copy failed for \(filename, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
    }

    // MARK: - Unfinished memories

    /// Finishes memories that never completed their pipeline: anything still
    /// `pending` / `processing` (Share Extension and Siri saves, captures
    /// interrupted by the app being killed) and voice notes with audio but no
    /// transcript (1.x discarded Apple Watch transcripts). Sequential, so a
    /// large backlog doesn't swamp the on-device model.
    private func completeUnfinishedMemories() async {
        guard let all = try? await memories.list(filter: .allIncludingSealed) else { return }
        var attempted = Set(UserDefaults.standard.stringArray(forKey: MaintenanceKeys.transcriptionAttempted) ?? [])

        var touched = false
        for memory in all {
            if needsTranscript(memory), !attempted.contains(memory.id.uuidString) {
                attempted.insert(memory.id.uuidString)
                UserDefaults.standard.set(Array(attempted), forKey: MaintenanceKeys.transcriptionAttempted)
                await transcribeVoiceMemory(memory.id)
                await enrichMemory(memoryID: memory.id)
                touched = true
            } else if memory.ai.status == .pending || memory.ai.status == .processing {
                await enrichMemory(memoryID: memory.id)
                touched = true
            } else {
                continue
            }
            if let updated = try? await memories.memory(with: memory.id) {
                await spotlight.index(updated)
            }
        }
        if touched { memoriesDidChange() }
    }

    // MARK: - Voice memories

    /// Transcribes a newly captured voice memory, then enriches it. Used for
    /// Apple Watch captures, whose audio arrives without a transcript.
    func completeVoiceMemory(_ memoryID: UUID) async {
        await transcribeVoiceMemory(memoryID)
        scheduleEnrichment(for: memoryID)
    }

    private func needsTranscript(_ memory: Memory) -> Bool {
        guard case .voiceNote(let transcript, _) = memory.content else { return false }
        let isEmpty = (transcript ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return isEmpty && memory.media.contains { $0.kind == .audio }
    }

    /// Fills in a missing transcript from the memory's saved audio. Writes
    /// only if the transcript is still empty when transcription finishes, so
    /// it can never overwrite a transcript the user (or another pass) added.
    private func transcribeVoiceMemory(_ memoryID: UUID) async {
        guard let memory = try? await memories.memory(with: memoryID),
              needsTranscript(memory),
              let audio = memory.media.first(where: { $0.kind == .audio })
        else { return }

        let url = await mediaStorage.url(forFilename: audio.filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let text = try await speechTranscriber.transcribe(fileAt: url)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty,
                  var latest = try await memories.memory(with: memoryID),
                  needsTranscript(latest),
                  case .voiceNote(_, let duration) = latest.content
            else { return }
            latest.content = .voiceNote(transcript: text, duration: duration)
            _ = try await updateMemory(latest)
        } catch {
            OrbitLog.capture.error("Voice transcription failed for \(memoryID, privacy: .public): \(String(describing: error), privacy: .public)")
        }
    }
}
