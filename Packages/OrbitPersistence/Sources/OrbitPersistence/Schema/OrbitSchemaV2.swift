import Foundation
import SwiftData

/// Version 2.0.0 of the Orbit persistence schema (Orbit 2.0).
///
/// Changes from V1 are strictly additive so every 1.x store upgrades with a
/// lightweight migration — no row is rewritten, renamed or dropped:
/// - `MemoryEntity.deletedAt: Date?` — powers Recently Deleted.
/// - `MemoryEntity.transcriptSegmentsJSON: Data?` — voice-note word timings.
/// - `MemoryTaskEntity.promisedTo: String?` — the Promise Ledger.
///
/// The models listed here are the live, top-level classes. When a V3 is
/// needed, freeze copies of these models inside this enum first (exactly as
/// `OrbitSchemaV1` freezes the 1.x models), then point V3 at the live ones.
public enum OrbitSchemaV2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            MemoryEntity.self,
            TagEntity.self,
            MediaAssetEntity.self,
            MemoryTaskEntity.self,
            AIInsightEntity.self,
        ]
    }
}

/// The schema the app runs on today. Everything that opens a container goes
/// through `ModelContainerFactory`, which reads this, so bumping the schema is
/// a one-line change here plus a stage in `OrbitMigrationPlan`.
public typealias OrbitCurrentSchema = OrbitSchemaV2
