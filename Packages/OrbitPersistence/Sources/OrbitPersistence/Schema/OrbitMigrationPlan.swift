import Foundation
import SwiftData

/// Migration plan composing every schema version. New versions append both to
/// `schemas` and to `stages`, oldest first.
///
/// Every stage so far is lightweight: each version only adds optional or
/// defaulted properties, so SwiftData can upgrade the store in place without
/// touching existing values. `OrbitMigrationTests` builds a real store with
/// each historical schema and asserts every field survives the upgrade —
/// add a case there whenever a stage is added here.
public enum OrbitMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [OrbitSchemaV1.self, OrbitSchemaV2.self]
    }

    public static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    /// 1.x → 2.0: adds `MemoryEntity.deletedAt` (nil for every existing row).
    /// Computed rather than a stored `let`: `MigrationStage` isn't `Sendable`,
    /// so a stored static would trip Swift 6 strict concurrency.
    static var migrateV1toV2: MigrationStage {
        .lightweight(fromVersion: OrbitSchemaV1.self, toVersion: OrbitSchemaV2.self)
    }
}
