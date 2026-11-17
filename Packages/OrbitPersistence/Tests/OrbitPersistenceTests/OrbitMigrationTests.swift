import Foundation
import Testing
import SwiftData
@testable import OrbitPersistence
import OrbitDomain

/// Guards the single most important promise of every Orbit update: nothing a
/// user saved in an earlier version is lost.
///
/// Each test writes a genuine on-disk store with a *historical* schema (the
/// frozen `OrbitSchemaV1` models, exactly what 1.x shipped), closes it, then
/// reopens the same file through `ModelContainerFactory` — the code path the
/// app uses at launch — and checks every field of every row.
extension StoreBackedTests {
    @Suite("Schema migration", .serialized)
    struct OrbitMigrationTests {

        // MARK: - Fixture

        /// Fixed values so assertions compare exact data, not "something exists".
        private enum Fixture {
            static let created = Date(timeIntervalSince1970: 1_750_000_000)
            static let updated = Date(timeIntervalSince1970: 1_750_000_500)
            static let sealedUntil = Date(timeIntervalSince1970: 4_000_000_000)
            static let due = Date(timeIntervalSince1970: 1_760_000_000)

            static let textID = UUID()
            static let voiceID = UUID()
            static let photoID = UUID()
            static let linkID = UUID()
            static let screenshotID = UUID()
            static let placeID = UUID()
            static let letterID = UUID()
            static let mediaID = UUID()
            static let tagID = UUID()
            static let taskID = UUID()
            static let hintID = UUID()
            static let insightID = UUID()

            static let signals = Data("{\"taskHints\":[]}".utf8)
            static let embedding: [Float] = [0.25, -0.5, 0.75]
        }

        private func makeStoreURL() throws -> URL {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("orbit-migration-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory.appendingPathComponent("orbit.sqlite")
        }

        /// Writes a 1.x store containing one of every kind of row Orbit 1.x could
        /// create, with every optional field populated.
        private func writeV1Store(at url: URL) throws {
            let schema = Schema(versionedSchema: OrbitSchemaV1.self)
            let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)

            let tag = OrbitSchemaV1.TagEntity(id: Fixture.tagID, name: "travel", origin: "ai")
            context.insert(tag)

            let text = OrbitSchemaV1.MemoryEntity(id: Fixture.textID)
            text.contentKind = "text"
            text.textContent = "Renew passport before the July trip"
            text.createdAt = Fixture.created
            text.updatedAt = Fixture.updated
            text.linkedTaskIDs = [Fixture.taskID]
            text.embedding = Fixture.embedding
            text.aiStatus = "complete"
            text.aiSummary = "Passport renewal before July."
            text.aiCategory = "travel"
            text.aiPriority = 2
            text.aiExtractedDates = [Fixture.due]
            text.aiExtractedPeople = ["Pamela"]
            text.aiExtractedLocations = ["Guatemala"]
            text.signalsJSON = Fixture.signals
            text.tags = [tag]
            context.insert(text)

            let voice = OrbitSchemaV1.MemoryEntity(id: Fixture.voiceID)
            voice.contentKind = "voiceNote"
            voice.voiceTranscript = "Found a tiny bookshop on Calle 8"
            voice.voiceDuration = 42.5
            voice.createdAt = Fixture.created
            let audio = OrbitSchemaV1.MediaAssetEntity(
                id: Fixture.mediaID, kind: "audio", filename: "\(Fixture.mediaID).wav",
                byteSize: 1_234_567, createdAt: Fixture.created
            )
            context.insert(audio)
            voice.media = [audio]
            voice.tags = [tag]
            context.insert(voice)

            let photo = OrbitSchemaV1.MemoryEntity(id: Fixture.photoID)
            photo.contentKind = "image"
            photo.imageCaption = "Sunset over the lake"
            context.insert(photo)

            let link = OrbitSchemaV1.MemoryEntity(id: Fixture.linkID)
            link.contentKind = "link"
            link.linkURLString = "https://example.com/ramen"
            link.linkTitle = "Best ramen in town"
            link.linkSummary = "A list of ramen spots."
            context.insert(link)

            let screenshot = OrbitSchemaV1.MemoryEntity(id: Fixture.screenshotID)
            screenshot.contentKind = "screenshot"
            screenshot.screenshotOCRText = "Flight AA123 departs 9:40"
            context.insert(screenshot)

            let place = OrbitSchemaV1.MemoryEntity(id: Fixture.placeID)
            place.contentKind = "location"
            place.locationName = "Roatán"
            place.latitude = 16.32
            place.longitude = -86.53
            context.insert(place)

            let letter = OrbitSchemaV1.MemoryEntity(id: Fixture.letterID)
            letter.contentKind = "text"
            letter.textContent = "Dear future me"
            letter.isLetter = true
            letter.surfaceDate = Fixture.sealedUntil
            context.insert(letter)

            let task = OrbitSchemaV1.MemoryTaskEntity(id: Fixture.taskID, title: "Renew passport", createdAt: Fixture.created)
            task.notes = "Bring two photos"
            task.isCompleted = true
            task.dueDate = Fixture.due
            task.priority = 3
            task.linkedMemoryID = Fixture.textID
            task.sourceHintID = Fixture.hintID
            task.remindersIdentifier = "reminder-123"
            task.calendarEventIdentifier = "event-456"
            task.completedAt = Fixture.updated
            context.insert(task)

            let insight = OrbitSchemaV1.AIInsightEntity(
                id: Fixture.insightID, kind: "pattern", headline: "You mention sourdough a lot", generatedAt: Fixture.created
            )
            insight.detail = "5 times this month"
            insight.relatedMemoryIDs = [Fixture.textID, Fixture.voiceID]
            insight.seenAt = Fixture.updated
            context.insert(insight)

            try context.save()
        }

        // MARK: - Tests

        @Test func everyV1RowSurvivesUpgrade() throws {
            let url = try makeStoreURL()
            try writeV1Store(at: url)

            let container = try ModelContainerFactory.makeContainer(mode: .storeURL(url))
            let context = ModelContext(container)

            #expect(try context.fetchCount(FetchDescriptor<MemoryEntity>()) == 7)
            #expect(try context.fetchCount(FetchDescriptor<MemoryTaskEntity>()) == 1)
            #expect(try context.fetchCount(FetchDescriptor<AIInsightEntity>()) == 1)
            #expect(try context.fetchCount(FetchDescriptor<TagEntity>()) == 1)
            #expect(try context.fetchCount(FetchDescriptor<MediaAssetEntity>()) == 1)
        }

        @Test func memoryFieldsArePreservedExactly() throws {
            let url = try makeStoreURL()
            try writeV1Store(at: url)
            let context = ModelContext(try ModelContainerFactory.makeContainer(mode: .storeURL(url)))

            let text = try #require(try fetchMemory(Fixture.textID, in: context))
            #expect(text.contentKind == "text")
            #expect(text.textContent == "Renew passport before the July trip")
            #expect(text.createdAt == Fixture.created)
            #expect(text.updatedAt == Fixture.updated)
            #expect(text.linkedTaskIDs == [Fixture.taskID])
            #expect(text.embedding == Fixture.embedding)
            #expect(text.aiStatus == "complete")
            #expect(text.aiSummary == "Passport renewal before July.")
            #expect(text.aiCategory == "travel")
            #expect(text.aiPriority == 2)
            #expect(text.aiExtractedDates == [Fixture.due])
            #expect(text.aiExtractedPeople == ["Pamela"])
            #expect(text.aiExtractedLocations == ["Guatemala"])
            #expect(text.signalsJSON == Fixture.signals)
            #expect(text.tags?.map(\.name) == ["travel"])
            // The V2 field arrives empty: nothing migrates as "deleted".
            #expect(text.deletedAt == nil)
            #expect(text.transcriptSegmentsJSON == nil)

            let voice = try #require(try fetchMemory(Fixture.voiceID, in: context))
            #expect(voice.voiceTranscript == "Found a tiny bookshop on Calle 8")
            #expect(voice.voiceDuration == 42.5)
            let audio = try #require(voice.media?.first)
            #expect(audio.id == Fixture.mediaID)
            #expect(audio.kind == "audio")
            #expect(audio.filename == "\(Fixture.mediaID).wav")
            #expect(audio.byteSize == 1_234_567)

            #expect(try fetchMemory(Fixture.photoID, in: context)?.imageCaption == "Sunset over the lake")

            let link = try #require(try fetchMemory(Fixture.linkID, in: context))
            #expect(link.linkURLString == "https://example.com/ramen")
            #expect(link.linkTitle == "Best ramen in town")
            #expect(link.linkSummary == "A list of ramen spots.")

            #expect(try fetchMemory(Fixture.screenshotID, in: context)?.screenshotOCRText == "Flight AA123 departs 9:40")

            let place = try #require(try fetchMemory(Fixture.placeID, in: context))
            #expect(place.locationName == "Roatán")
            #expect(place.latitude == 16.32)
            #expect(place.longitude == -86.53)

            let letter = try #require(try fetchMemory(Fixture.letterID, in: context))
            #expect(letter.isLetter)
            #expect(letter.surfaceDate == Fixture.sealedUntil)
        }

        @Test func tasksAndInsightsArePreservedExactly() throws {
            let url = try makeStoreURL()
            try writeV1Store(at: url)
            let context = ModelContext(try ModelContainerFactory.makeContainer(mode: .storeURL(url)))

            let task = try #require(try context.fetch(FetchDescriptor<MemoryTaskEntity>()).first)
            #expect(task.id == Fixture.taskID)
            #expect(task.title == "Renew passport")
            #expect(task.notes == "Bring two photos")
            #expect(task.isCompleted)
            #expect(task.dueDate == Fixture.due)
            #expect(task.priority == 3)
            #expect(task.linkedMemoryID == Fixture.textID)
            #expect(task.sourceHintID == Fixture.hintID)
            #expect(task.remindersIdentifier == "reminder-123")
            #expect(task.calendarEventIdentifier == "event-456")
            #expect(task.createdAt == Fixture.created)
            #expect(task.completedAt == Fixture.updated)
            #expect(task.promisedTo == nil)

            let insight = try #require(try context.fetch(FetchDescriptor<AIInsightEntity>()).first)
            #expect(insight.id == Fixture.insightID)
            #expect(insight.kind == "pattern")
            #expect(insight.headline == "You mention sourdough a lot")
            #expect(insight.detail == "5 times this month")
            #expect(insight.relatedMemoryIDs == [Fixture.textID, Fixture.voiceID])
            #expect(insight.generatedAt == Fixture.created)
            #expect(insight.seenAt == Fixture.updated)
        }

        @Test func tagIsSharedNotDuplicated() throws {
            let url = try makeStoreURL()
            try writeV1Store(at: url)
            let context = ModelContext(try ModelContainerFactory.makeContainer(mode: .storeURL(url)))

            let tags = try context.fetch(FetchDescriptor<TagEntity>())
            #expect(tags.count == 1)
            #expect(tags.first?.id == Fixture.tagID)
            #expect(tags.first?.origin == "ai")
            #expect(Set(tags.first?.memories?.map(\.id) ?? []) == [Fixture.textID, Fixture.voiceID])
        }

        /// The domain layer reads upgraded rows through the same repository the
        /// app uses — sealed letters stay hidden, everything else is listed.
        @Test func repositoryReadsUpgradedStore() async throws {
            let url = try makeStoreURL()
            try writeV1Store(at: url)
            let repo = SwiftDataMemoryRepository(
                modelContainer: try ModelContainerFactory.makeContainer(mode: .storeURL(url))
            )

            #expect(try await repo.list(filter: .allIncludingSealed).count == 7)
            #expect(try await repo.list(filter: .all).count == 6)

            let voice = try #require(try await repo.memory(with: Fixture.voiceID))
            #expect(voice.content == .voiceNote(transcript: "Found a tiny bookshop on Calle 8", duration: 42.5))
            #expect(voice.media.first?.filename == "\(Fixture.mediaID).wav")
        }

        /// A second launch must reopen the upgraded store without re-migrating
        /// or losing anything — and new writes must persist alongside old rows.
        @Test func upgradedStoreReopensAndAcceptsWrites() async throws {
            let url = try makeStoreURL()
            try writeV1Store(at: url)

            do {
                let repo = SwiftDataMemoryRepository(
                    modelContainer: try ModelContainerFactory.makeContainer(mode: .storeURL(url))
                )
                try await repo.save(Memory(content: .text("Written by 2.0"), createdAt: .now, updatedAt: .now))
            }

            let repo = SwiftDataMemoryRepository(
                modelContainer: try ModelContainerFactory.makeContainer(mode: .storeURL(url))
            )
            let all = try await repo.list(filter: .allIncludingSealed)
            #expect(all.count == 8)
            #expect(all.contains { $0.content == .text("Written by 2.0") })
            #expect(all.contains { $0.id == Fixture.letterID })
        }

        // MARK: - Helpers

        private func fetchMemory(_ id: UUID, in context: ModelContext) throws -> MemoryEntity? {
            var descriptor = FetchDescriptor<MemoryEntity>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first
        }
    }
}
