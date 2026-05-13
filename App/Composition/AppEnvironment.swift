import SwiftUI
import SwiftData
import WidgetKit
import OrbitKit
import OrbitDomain
import OrbitPersistence
import OrbitMedia
import OrbitAI
import OrbitAccount
import OrbitStore

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
    let search: any SearchService
    let spotlight: SpotlightIndexer

    let account: AccountService
    let entitlements: EntitlementService
    let themeService: ThemeService
    let iconService: IconService
    let notifications: NotificationService
    let watchSession: WatchSessionService
    let captureInbox: CaptureInboxService
    let remindersSync: RemindersSyncService
    let calendarSync: CalendarSyncService
    let healthKit: HealthKitService
    let reviewPrompts: ReviewPromptService
    let proGates: ProGateService

    let captureMemory: CaptureMemoryUseCase
    let listMemories: ListMemoriesUseCase
    let updateMemory: UpdateMemoryUseCase
    let deleteMemory: DeleteMemoryUseCase
    let linkTask: LinkTaskToMemoryUseCase
    let toggleTask: ToggleTaskUseCase
    let enrichMemory: EnrichMemoryUseCase
    let searchMemories: SearchMemoriesUseCase
    let generateDailyRecap: GenerateDailyRecapUseCase
    let generateInsights: GenerateInsightsUseCase
    let listTasks: ListTasksUseCase
    let listTaskSuggestions: ListTaskSuggestionsUseCase
    let promoteHintToTask: PromoteHintToTaskUseCase
    let updateTask: UpdateTaskUseCase
    let deleteTask: DeleteTaskUseCase
    let askOrbit: AskOrbitUseCase
    let listOnThisDay: ListOnThisDayUseCase
    let generateYearInReview: GenerateYearInReviewUseCase
    let listReadingItems: ListReadingItemsUseCase
    let updateReadingItemStatus: UpdateReadingItemStatusUseCase
    let listHabits: ListHabitsUseCase
    let listReminderSuggestions: ListReminderSuggestionsUseCase
    let promoteReminderToTask: PromoteReminderToTaskUseCase
    let captureGratitude: CaptureGratitudeUseCase
    let loadGratitudeStatus: LoadGratitudeStatusUseCase

    /// Bumped whenever the memory collection changes. Feature views observe
    /// it via `.task(id: env.memoryListVersion)` to refetch lazily — until
    /// repositories expose a live-query API in a later phase.
    var memoryListVersion: Int = 0

    /// External entry points (deep links, AppIntents) write here; `RootView`
    /// observes it and presents the corresponding sheet.
    var requestedModal: AppModal?

    /// Mirrors the `orbit.onboarding.completed` UserDefaults flag. We hold
    /// it on the env so the delete-account flow can flip it back to false
    /// and the app re-presents onboarding on the next render without a
    /// relaunch.
    var onboardingComplete: Bool {
        didSet {
            UserDefaults.standard.set(onboardingComplete, forKey: Self.onboardingKey)
        }
    }

    private static let onboardingKey = "orbit.onboarding.completed"
    private static let yearInReviewLastSeenKey = "orbit.yearInReview.lastSeenYear"

    /// The most recent calendar year for which the user has dismissed
    /// the Year in Review surface. Drives the late-December Home banner
    /// so it doesn't re-show the same review on every launch.
    var yearInReviewLastSeenYear: Int? {
        get { UserDefaults.standard.object(forKey: Self.yearInReviewLastSeenKey) as? Int }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: Self.yearInReviewLastSeenKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.yearInReviewLastSeenKey)
            }
        }
    }

    /// Whether to surface the Year-in-Review banner on Home. True from
    /// Dec 15 through Jan 14, scoped to the year that's ending, and only
    /// when the user hasn't already dismissed that year's review.
    func shouldOfferYearInReview(at date: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day else { return false }
        let inWindow = (month == 12 && day >= 15) || (month == 1 && day <= 14)
        guard inWindow else { return false }
        let targetYear = month == 1 ? year - 1 : year
        return yearInReviewLastSeenYear != targetYear
    }

    /// Mark the most-recent target year as seen so the banner stops
    /// surfacing for that year.
    func markYearInReviewSeen(at date: Date = Date()) {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: date)
        guard let year = comps.year, let month = comps.month else { return }
        yearInReviewLastSeenYear = month == 1 ? year - 1 : year
    }

    func memoriesDidChange() {
        memoryListVersion &+= 1
        // Nudge the widget bundle so the Recent widget picks up new content
        // without waiting for its next scheduled refresh.
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Fire-and-forget enrichment + Spotlight indexing for a freshly captured
    /// memory. Re-bumps the list version when done so the timeline picks up
    /// the completed AI metadata.
    func scheduleEnrichment(for memoryID: UUID) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.enrichMemory(memoryID: memoryID)
            if let memory = try? await self.memories.memory(with: memoryID) {
                await self.spotlight.index(memory)
            }
            self.memoriesDidChange()
        }
    }

    /// Inspects a freshly-saved memory and, if it has a future `surfaceDate`,
    /// schedules a local notification for the moment it should resurface.
    /// Idempotent: re-scheduling replaces the pending request.
    func scheduleSealedDeliveryIfNeeded(for memoryID: UUID) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let memory = try? await self.memories.memory(with: memoryID),
                  let surfaceDate = memory.surfaceDate,
                  surfaceDate > Date()
            else { return }
            await self.notifications.scheduleSealedDelivery(
                memoryID: memory.id,
                surfaceDate: surfaceDate,
                isLetter: memory.isLetter,
                previewText: Self.previewText(for: memory)
            )
        }
    }

    private static func previewText(for memory: Memory) -> String? {
        switch memory.content {
        case .text(let s):                          return s
        case .voiceNote(let transcript, _):         return transcript
        case .image(let caption):                   return caption
        case .link(_, let title, let summary):      return summary ?? title
        case .screenshot(let ocr):                  return ocr
        case .location(let name, _, _):             return name
        }
    }

    /// Trigger sites call this instead of setting `requestedModal =
    /// .dailyRecap` directly. Free users hitting the weekly quota are
    /// routed to the soft paywall sheet instead of the recap — so the
    /// quota check lives in one place and every entry point (Home
    /// button, notification tap, AppIntents) inherits it.
    func requestRecap() {
        if proGates.canAccess(.dailyRecap) {
            proGates.recordUsage(.dailyRecap)
            requestedModal = .dailyRecap
        } else {
            requestedModal = .proGate(.dailyRecap)
        }
    }

    /// Deletes a memory and removes it from Spotlight. Use this from the UI
    /// instead of `deleteMemory` directly.
    func removeMemory(id: UUID) async throws {
        try await deleteMemory(id: id)
        await spotlight.deindex(memoryID: id)
        // Drop any pending sealed-delivery notification too — otherwise a
        // deleted time capsule would still chime on its surface date.
        notifications.cancelSealedDelivery(memoryID: id)
        memoriesDidChange()
    }

    /// Re-runs enrichment for every memory currently in the repository.
    /// Useful after changing the classification logic (e.g. shipping a
    /// new heuristic category inferrer) so existing rows pick up the new
    /// labels without the user having to delete + recapture.
    func reenrichAllMemories() async {
        // Re-enrich includes sealed memories so their AI metadata is ready
        // when they surface — otherwise a year-old time capsule would
        // arrive with stale categorization.
        let all = (try? await memories.list(filter: .allIncludingSealed)) ?? []
        for memory in all {
            await enrichMemory(memoryID: memory.id)
            if let updated = try? await memories.memory(with: memory.id) {
                await spotlight.index(updated)
            }
        }
        memoriesDidChange()
    }

    /// Wipes every memory, clears Spotlight, signs the user out, and resets
    /// onboarding so the next render starts from a clean slate. Used by the
    /// in-app account-deletion flow (Apple 5.1.1(v) requirement).
    func wipeAccountAndData() async throws {
        try await memories.deleteAll()
        await spotlight.deindexAll()
        account.signOut()
        onboardingComplete = false
        memoriesDidChange()
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
        ocr: OCRService,
        search: any SearchService,
        spotlight: SpotlightIndexer,
        account: AccountService,
        entitlements: EntitlementService,
        themeService: ThemeService = ThemeService(),
        iconService: IconService = IconService(),
        notifications: NotificationService = NotificationService(),
        watchSession: WatchSessionService? = nil
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
        self.search = search
        self.spotlight = spotlight
        self.account = account
        self.entitlements = entitlements
        self.themeService = themeService
        self.iconService = iconService
        self.notifications = notifications
        self.remindersSync = RemindersSyncService(tasks: tasks)
        self.calendarSync = CalendarSyncService(tasks: tasks)
        self.healthKit = HealthKitService()
        self.reviewPrompts = ReviewPromptService()
        self.proGates = ProGateService(entitlements: entitlements)

        self.onboardingComplete = UserDefaults.standard.bool(forKey: Self.onboardingKey)

        let signals = SignalExtractor()
        let captureMemoryUseCase = CaptureMemoryUseCase(
            repository: memories,
            clock: clock,
            signalExtractor: signals
        )
        self.captureMemory = captureMemoryUseCase
        self.watchSession = watchSession ?? WatchSessionService(
            mediaStorage: mediaStorage,
            captureMemory: captureMemoryUseCase,
            speechTranscriber: speechTranscriber
        )
        self.captureInbox = CaptureInboxService(
            appGroupIdentifier: appConfig.appGroupIdentifier,
            mediaStorage: mediaStorage,
            captureMemory: captureMemoryUseCase,
            clock: clock
        )
        self.listMemories = ListMemoriesUseCase(repository: memories)
        self.updateMemory = UpdateMemoryUseCase(repository: memories, clock: clock)
        self.deleteMemory = DeleteMemoryUseCase(repository: memories)
        self.linkTask = LinkTaskToMemoryUseCase(memories: memories, tasks: tasks, clock: clock)
        self.toggleTask = ToggleTaskUseCase(repository: tasks, clock: clock)
        self.enrichMemory = EnrichMemoryUseCase(
            ai: ai,
            memories: memories,
            clock: clock,
            signalExtractor: signals
        )
        self.searchMemories = SearchMemoriesUseCase(search: search, memories: memories)
        self.generateDailyRecap = GenerateDailyRecapUseCase(memories: memories, ai: ai, clock: clock)
        self.generateInsights = GenerateInsightsUseCase(
            memories: memories,
            generator: InsightsEngine(),
            dismissals: UserDefaultsInsightDismissalStore(),
            clock: clock
        )
        self.listTasks = ListTasksUseCase(repository: tasks)
        self.listTaskSuggestions = ListTaskSuggestionsUseCase(memories: memories, tasks: tasks)
        self.promoteHintToTask = PromoteHintToTaskUseCase(tasks: tasks, clock: clock)
        self.updateTask = UpdateTaskUseCase(tasks: tasks)
        self.deleteTask = DeleteTaskUseCase(tasks: tasks)
        self.askOrbit = AskOrbitUseCase(
            search: search,
            memories: memories,
            ai: ai,
            clock: clock
        )
        self.listOnThisDay = ListOnThisDayUseCase(memories: memories, clock: clock)
        self.generateYearInReview = GenerateYearInReviewUseCase(memories: memories, clock: clock)
        self.listReadingItems = ListReadingItemsUseCase(memories: memories)
        self.updateReadingItemStatus = UpdateReadingItemStatusUseCase(memories: memories, clock: clock)
        self.listHabits = ListHabitsUseCase(memories: memories, clock: clock)
        self.listReminderSuggestions = ListReminderSuggestionsUseCase(
            memories: memories,
            tasks: tasks,
            clock: clock
        )
        self.promoteReminderToTask = PromoteReminderToTaskUseCase(tasks: tasks, clock: clock)
        self.captureGratitude = CaptureGratitudeUseCase(captureMemory: captureMemoryUseCase)
        self.loadGratitudeStatus = LoadGratitudeStatusUseCase(memories: memories, clock: clock)

        // Notifications can't reach the modal binding directly (it lives on
        // env). Hand the service a closure that flips the binding when the
        // user taps the delivered recap notification. Must happen after every
        // stored property is initialized so `self` is fully formed.
        self.notifications.onOpenRecap = { [weak self] in
            self?.requestRecap()
        }

        // Same pattern for the watch session — the receiver needs to nudge
        // the timeline + schedule enrichment after each watch capture.
        self.watchSession.onCapture = { [weak self] memoryID in
            guard let self else { return }
            self.memoriesDidChange()
            self.scheduleEnrichment(for: memoryID)
        }

        // Lock-Screen camera + Safari Web Extension drop captures into
        // shared inboxes while Orbit is off-screen. Same downstream as a
        // watch capture: bump the timeline, run enrichment + Spotlight.
        self.captureInbox.onCapture = { [weak self] memoryID in
            guard let self else { return }
            self.memoriesDidChange()
            self.scheduleEnrichment(for: memoryID)
        }
    }
}

extension AppEnvironment {
    /// Production environment. SwiftData lives in the App Group container so
    /// the share extension and widgets see the same store. If the group
    /// entitlement isn't active the factory degrades to per-app storage.
    static func makeProduction(appConfig: AppConfig) throws -> AppEnvironment {
        let container = try ModelContainerFactory.makeContainer(
            mode: .appGroup(identifier: appConfig.appGroupIdentifier)
        )
        let storage = try MediaStorage.sharedAcrossExtensions(
            appGroupIdentifier: appConfig.appGroupIdentifier
        )
        let memoryRepo = SwiftDataMemoryRepository(modelContainer: container)
        let embeddings = EmbeddingService()
        let ai = AIServicePipeline([
            FoundationModelsAdapter(embeddings: embeddings),
            CloudAIService(),
        ])
        return AppEnvironment(
            appConfig: appConfig,
            clock: SystemClock(),
            memories: memoryRepo,
            tasks: SwiftDataTaskRepository(modelContainer: container),
            insights: SwiftDataInsightRepository(modelContainer: container),
            mediaStorage: storage,
            speechTranscriber: SpeechTranscriber(),
            linkFetcher: LinkPreviewFetcher(),
            ai: ai,
            ocr: OCRService(),
            search: LocalSearchService(memories: memoryRepo, embeddings: embeddings),
            spotlight: SpotlightIndexer(),
            account: AccountService(),
            entitlements: EntitlementService()
        )
    }

    static func makePreview(seed: [Memory] = []) -> AppEnvironment {
        // Two-step fallback so the preview environment never crashes
        // even if the temp directory is unusable (sandbox edge case).
        // If both paths fail, the app's bigger problems are external —
        // we still hand back an environment so logs can surface the
        // failure instead of crashing on launch.
        let tmpRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("orbit-preview-\(UUID().uuidString)", isDirectory: true)
        let storage: MediaStorage = {
            if let s = try? MediaStorage(root: tmpRoot) { return s }
            OrbitLog.persistence.fault("Preview MediaStorage tmp init failed; trying default documents path.")
            if let s = try? MediaStorage() { return s }
            // Final fallback — log loudly and continue with the tmp
            // path that we know createDirectory couldn't reach. Most
            // operations against it will fail gracefully through
            // FileManager error paths rather than crashing on launch.
            OrbitLog.persistence.fault("Preview MediaStorage default init also failed. Capture flows will surface errors.")
            // Final fallback: the system temp directory itself, which
            // is guaranteed to exist in the app sandbox. If even this
            // fails the sandbox is so broken the app can't run, so we
            // trap with a labeled message instead of an unlabeled
            // force-unwrap.
            guard let last = try? MediaStorage(root: FileManager.default.temporaryDirectory) else {
                preconditionFailure("MediaStorage cannot initialize against the app sandbox temp directory.")
            }
            return last
        }()
        let memoryRepo = InMemoryMemoryRepository(seed: seed)
        let embeddings = EmbeddingService()
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
            memories: memoryRepo,
            tasks: InMemoryTaskRepository(),
            insights: InMemoryInsightRepository(),
            mediaStorage: storage,
            speechTranscriber: SpeechTranscriber(),
            linkFetcher: LinkPreviewFetcher(),
            ai: MockAIService(),
            ocr: OCRService(),
            search: LocalSearchService(memories: memoryRepo, embeddings: embeddings),
            spotlight: SpotlightIndexer(),
            account: AccountService(),
            entitlements: EntitlementService()
        )
    }
}
