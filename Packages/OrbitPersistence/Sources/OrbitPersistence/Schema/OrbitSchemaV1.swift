import Foundation
import SwiftData

/// Version 1.0.0 of the Orbit persistence schema. Every breaking change to
/// any `@Model` class lives in a new `OrbitSchemaVx` enum alongside a stage
/// in `OrbitMigrationPlan`.
public enum OrbitSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)

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
