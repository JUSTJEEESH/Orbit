import SwiftUI
import SwiftData
import OrbitKit
import OrbitDomain
import OrbitPersistence
import OrbitMedia
import OrbitAI

/// The composition root. Holds long-lived services (repositories, clocks,
/// media services, AI) and pre-constructed use cases ready to be invoked by
/// features. Always read via `@Environment(AppEnvironment.self)` — feature
/// code must never construct one for itself.
@MainActor
@Observable
final class AppEnvironment {
    let appConfig: AppConfig
    let clock: any OrbitClock

    let memories: any MemoryRepository
    let tasks: any TaskRepository
    let insights: any InsightRepository

    let mediaStorage: MediaStorage
    let speechTranscriber: SpeechTranscriber
    let linkFetcher: LinkPreviewFetcher

    let ai: any AIService
    let ocr: OCRService

    let captureMemory: CaptureMemoryUseCase
    let listMemories: ListMemoriesUseCase
    let updateMemory: UpdateMemoryUseCase
    let deleteMemory: DeleteMemoryUseCase
    let linkTask: LinkTaskToMemoryUseCase
    let toggleTask: ToggleTaskUseCase
    let enrichMemory: EnrichMemoryUseCase

    /// Bumped whenever the memory collection changes. Feature views observe
    /// it via `.task(id: env.memoryListVersion)` to refetch lazily — until
    /// repositories expose a live-query API in a later phase.
    var memoryListVersion: Int = 0

    func memoriesDidChange() {
        memoryListVersion &+= 1
    }

    /// Fire-and-forget enrichment of a freshly captured memory. The task
    /// re-bumps the list version when done so the timeline picks up the
    /// completed AI metadata.
    func scheduleEnrichment(for memoryID: UUID) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.enrichMemory(memoryID: memoryID)
            self.memoriesDidChange()
        }
    }

    init(
        appConfig: AppConfig,
        clock: any OrbitClock,
        memories: any MemoryRepository,
        tasks: any TaskRepository,
        insights: any InsightRepository,
        mediaStorage: MediaStorage,
        speechTranscriber: SpeechTranscriber,
        linkFetcher: LinkPreviewFetcher,
        ai: any AIService,
        ocr: OCRService
    ) {
        self.appConfig = appConfig
        self.clock = clock
        self.memories = memories
        self.tasks = tasks
        self.insights = insights
        self.mediaStorage = mediaStorage
        self.speechTranscriber = speechTranscriber
        self.linkFetcher = linkFetcher
        self.ai = ai
        self.ocr = ocr

        self.captureMemory = CaptureMemoryUseCase(repository: memories, clock: clock)
        self.listMemories = ListMemoriesUseCase(repository: memories)
        self.updateMemory = UpdateMemoryUseCase(repository: memories, clock: clock)
        self.deleteMemory = DeleteMemoryUseCase(repository: memories)
        self.linkTask = LinkTaskToMemoryUseCase(memories: memories, tasks: tasks, clock: clock)
        self.toggleTask = ToggleTaskUseCase(repository: tasks, clock: clock)
        self.enrichMemory = EnrichMemoryUseCase(ai: ai, memories: memories, clock: clock)
    }
}

extension AppEnvironment {
    /// Production environment: SwiftData on local storage + Foundation Models
    /// adapter as primary AI with a cloud stub fallback that currently throws
    /// (real cloud proxy lands in a later phase).
    static func makeProduction(appConfig: AppConfig) throws -> AppEnvironment {
        let container = try ModelContainerFactory.makeContainer(mode: .onDisk)
        let storage = try MediaStorage()
        let ai = AIServicePipeline([
            FoundationModelsAdapter(),
            CloudAIService(),
        ])
        return AppEnvironment(
            appConfig: appConfig,
            clock: SystemClock(),
            memories: SwiftDataMemoryRepository(modelContainer: container),
            tasks: SwiftDataTaskRepository(modelContainer: container),
            insights: SwiftDataInsightRepository(modelContainer: container),
            mediaStorage: storage,
            speechTranscriber: SpeechTranscriber(),
            linkFetcher: LinkPreviewFetcher(),
            ai: ai,
            ocr: OCRService()
        )
    }

    static func makePreview(seed: [Memory] = []) -> AppEnvironment {
        let storage = try! MediaStorage(
            root: FileManager.default.temporaryDirectory
                .appendingPathComponent("orbit-preview-\(UUID().uuidString)", isDirectory: true)
        )
        return AppEnvironment(
            appConfig: AppConfig(
                bundleIdentifier: "com.orbit.app",
                displayName: "Orbit",
                marketingVersion: "0.1.0",
                buildNumber: "1",
                environment: .debug,
                appGroupIdentifier: "group.com.orbit.app",
                cloudKitContainerIdentifier: "iCloud.com.orbit.app"
            ),
            clock: SystemClock(),
            memories: InMemoryMemoryRepository(seed: seed),
            tasks: InMemoryTaskRepository(),
            insights: InMemoryInsightRepository(),
            mediaStorage: storage,
            speechTranscriber: SpeechTranscriber(),
            linkFetcher: LinkPreviewFetcher(),
            ai: MockAIService(),
            ocr: OCRService()
        )
    }
}
