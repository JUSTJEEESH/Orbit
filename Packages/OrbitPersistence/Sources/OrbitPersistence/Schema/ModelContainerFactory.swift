import Foundation
import SwiftData

/// Produces `ModelContainer` instances tuned for one of three runtime modes.
///
/// CloudKit mode is opt-in because it requires the iCloud container to be
/// provisioned in App Store Connect. Until then the app runs on a local
/// on-disk store with the schema future-proofed for sync.
public enum ModelContainerFactory {
    public enum Mode: Sendable, Equatable {
        case inMemory
        case onDisk
        case cloudKit(containerIdentifier: String)
    }

    public static func makeContainer(mode: Mode = .onDisk) throws -> ModelContainer {
        let schema = Schema(versionedSchema: OrbitSchemaV1.self)
        let configuration: ModelConfiguration

        switch mode {
        case .inMemory:
            configuration = ModelConfiguration(
                "orbit-inmemory",
                schema: schema,
                isStoredInMemoryOnly: true,
                allowsSave: true,
                cloudKitDatabase: .none
            )
        case .onDisk:
            configuration = ModelConfiguration(
                "orbit-local",
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .none
            )
        case .cloudKit(let identifier):
            configuration = ModelConfiguration(
                "orbit",
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .private(identifier)
            )
        }

        return try ModelContainer(
            for: schema,
            migrationPlan: OrbitMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
