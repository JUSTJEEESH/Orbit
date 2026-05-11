import SwiftUI
import SwiftData
import OrbitKit
import OrbitDomain
import OrbitPersistence

/// The composition root. Holds long-lived services (repositories, clocks) and
/// pre-constructed use cases ready to be invoked by features. Always read via
/// `@Environment(AppEnvironment.self)` — feature code must never construct
/// one for itself.
@MainActor
@Observable
final class AppEnvironment {
    let appConfig: AppConfig
    let clock: any OrbitClock

    let memories: any MemoryRepository
    let tasks: any TaskRepository
    let insights: any InsightRepository

    let captureMemory: CaptureMemoryUseCase
    let listMemories: ListMemoriesUseCase
    let updateMemory: UpdateMemoryUseCase
    let deleteMemory: DeleteMemoryUseCase
    let linkTask: LinkTaskToMemoryUseCase
    let toggleTask: ToggleTaskUseCase

    /// Bumped whenever the memory collection changes. Feature views observe
    /// it via `.task(id: env.memoryListVersion)` to refetch lazily — until
    /// repositories expose a live-query API in a later phase.
    var memoryListVersion: Int = 0

    func memoriesDidChange() {
        memoryListVersion &+= 1
    }

    init(
        appConfig: AppConfig,
        clock: any OrbitClock,
        memories: any MemoryRepository,
        tasks: any TaskRepository,
        insights: any InsightRepository
    ) {
        self.appConfig = appConfig
        self.clock = clock
        self.memories = memories
        self.tasks = tasks
        self.insights = insights

        self.captureMemory = CaptureMemoryUseCase(repository: memories, clock: clock)
        self.listMemories = ListMemoriesUseCase(repository: memories)
        self.updateMemory = UpdateMemoryUseCase(repository: memories, clock: clock)
        self.deleteMemory = DeleteMemoryUseCase(repository: memories)
        self.linkTask = LinkTaskToMemoryUseCase(memories: memories, tasks: tasks, clock: clock)
        self.toggleTask = ToggleTaskUseCase(repository: tasks, clock: clock)
    }
}

extension AppEnvironment {
    /// Production environment backed by SwiftData on local storage. CloudKit
    /// mirroring is wired up but disabled until the iCloud container is
    /// provisioned in App Store Connect — flip `.onDisk` to
    /// `.cloudKit(containerIdentifier:)` when ready.
    static func makeProduction(appConfig: AppConfig) throws -> AppEnvironment {
        let container = try ModelContainerFactory.makeContainer(mode: .onDisk)
        return AppEnvironment(
            appConfig: appConfig,
            clock: SystemClock(),
            memories: SwiftDataMemoryRepository(modelContainer: container),
            tasks: SwiftDataTaskRepository(modelContainer: container),
            insights: SwiftDataInsightRepository(modelContainer: container)
        )
    }

    /// Environment backed by in-memory fakes. Use for SwiftUI previews and
    /// crash recovery scenarios where persistence init fails.
    static func makePreview(seed: [Memory] = []) -> AppEnvironment {
        AppEnvironment(
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
            insights: InMemoryInsightRepository()
        )
    }
}
