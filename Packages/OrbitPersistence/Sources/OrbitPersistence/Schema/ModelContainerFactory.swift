import Foundation
import SwiftData

/// Produces `ModelContainer` instances tuned for one of four runtime modes.
///
/// App Group mode lets the main app, the Share Extension, and the Widget
/// bundle read/write the same SwiftData store. If the group container
/// isn't accessible (entitlement not provisioned, simulator misconfig)
/// the factory falls back to on-disk so the app still launches.
///
/// CloudKit mode requires an iCloud container provisioned in App Store
/// Connect; flip to it once that's wired up.
public enum ModelContainerFactory {
    public enum Mode: Sendable, Equatable {
        case inMemory
        case onDisk
        case appGroup(identifier: String)
        case cloudKit(containerIdentifier: String)
    }

    public static func makeContainer(mode: Mode = .onDisk) throws -> ModelContainer {
        let schema = Schema(versionedSchema: OrbitSchemaV1.self)
        let configuration = try makeConfiguration(mode: mode, schema: schema)
        return try ModelContainer(
            for: schema,
            migrationPlan: OrbitMigrationPlan.self,
            configurations: [configuration]
        )
    }

    private static func makeConfiguration(
        mode: Mode,
        schema: Schema
    ) throws -> ModelConfiguration {
        switch mode {
        case .inMemory:
            return ModelConfiguration(
                "orbit-inmemory",
                schema: schema,
                isStoredInMemoryOnly: true,
                allowsSave: true,
                cloudKitDatabase: .none
            )

        case .onDisk:
            return ModelConfiguration(
                "orbit-local",
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .none
            )

        case .appGroup(let identifier):
            guard let url = appGroupStoreURL(for: identifier) else {
                // The entitlement isn't active. Fall back to on-disk so the
                // main app still works; extensions will see an empty store
                // until the group container resolves.
                return ModelConfiguration(
                    "orbit-local",
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    allowsSave: true,
                    cloudKitDatabase: .none
                )
            }
            return ModelConfiguration(
                "orbit-shared",
                schema: schema,
                url: url,
                allowsSave: true,
                cloudKitDatabase: .none
            )

        case .cloudKit(let identifier):
            return ModelConfiguration(
                "orbit",
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .private(identifier)
            )
        }
    }

    /// Resolves the SwiftData store URL inside the App Group container.
    /// Returns `nil` if the group isn't accessible.
    public static func appGroupStoreURL(for identifier: String) -> URL? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        ) else { return nil }
        let directory = container.appendingPathComponent("Library/SwiftData", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("orbit.sqlite")
    }
}
