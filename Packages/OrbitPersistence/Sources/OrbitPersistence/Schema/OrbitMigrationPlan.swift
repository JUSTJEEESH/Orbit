import Foundation
import SwiftData

/// Migration plan composing every schema version. New versions append both to
/// `schemas` and to `stages`. Phase 1 ships v1 only, so there are no stages
/// yet — the plan exists so future migrations stay deterministic.
public enum OrbitMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [OrbitSchemaV1.self]
    }

    public static var stages: [MigrationStage] {
        []
    }
}
