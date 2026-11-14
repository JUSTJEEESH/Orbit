import Foundation
import SwiftData

/// Produces `ModelContainer` instances tuned for one of the runtime modes.
///
/// Every container is opened with `OrbitCurrentSchema` plus
/// `OrbitMigrationPlan`, so a store written by any earlier Orbit version is
/// upgraded in place, stage by stage, the first time it is opened.
///
/// App Group mode lets the main app, the Share Extension, the Widget bundle
/// and App Intents read/write the same SwiftData store. If the group
/// container isn't accessible (entitlement not provisioned, simulator
/// misconfig) the factory falls back to on-disk so the app still launches.
///
/// CloudKit mode requires an iCloud container provisioned in App Store
/// Connect; flip to it once that's wired up.
public enum ModelContainerFactory {
    public enum Mode: Sendable, Equatable {
        case inMemory
        case onDisk
        case appGroup(identifier: String)
        case cloudKit(containerIdentifier: String)
        /// A store at an explicit file URL. Used by migration tests and by
        /// the legacy-store rescue, which must open a specific file.
        case storeURL(URL)
    }

    /// Configuration name of the per-app store used by `.onDisk` (and by the
    /// App Group fallback). Orbit 1.x's Siri intent wrote here by mistake,
    /// which is why `LegacyStoreRescue` knows its location.
    public static let localStoreName = "orbit-local"

    public static func makeContainer(mode: Mode = .onDisk) throws -> ModelContainer {
        snapshotBeforeOpening(mode: mode)
        let schema = Schema(versionedSchema: OrbitCurrentSchema.self)
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
            return localConfiguration(schema: schema)

        case .appGroup(let identifier):
            guard let url = appGroupStoreURL(for: identifier) else {
                // The entitlement isn't active. Fall back to on-disk so the
                // main app still works; extensions will see an empty store
                // until the group container resolves.
                return localConfiguration(schema: schema)
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

        case .storeURL(let url):
            return ModelConfiguration(
                "orbit-file",
                schema: schema,
                url: url,
                allowsSave: true,
                cloudKitDatabase: .none
            )
        }
    }

    private static func localConfiguration(schema: Schema) -> ModelConfiguration {
        ModelConfiguration(
            localStoreName,
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .none
        )
    }

    /// Label of the snapshot taken before the current schema first opens a
    /// store, e.g. `before-schema-2.0.0`.
    public static var currentSnapshotLabel: String {
        let version = OrbitCurrentSchema.versionIdentifier
        return "before-schema-\(version.major).\(version.minor).\(version.patch)"
    }

    /// `App Group/Library/Backups` — where pre-upgrade snapshots live.
    public static func backupsDirectory(for appGroupIdentifier: String) -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent("Library/Backups", isDirectory: true)
    }

    /// The App Group store is the one holding real user data, so it gets a
    /// snapshot before the current schema first touches it. (The `.onDisk`
    /// store only ever held 1.x Siri captures; `LegacyStoreRescue` copies
    /// those rows out without modifying that file's contents beyond the
    /// lightweight upgrade, and keeps the file.)
    private static func snapshotBeforeOpening(mode: Mode) {
        guard case .appGroup(let identifier) = mode,
              let storeURL = appGroupStoreURL(for: identifier),
              let backups = backupsDirectory(for: identifier)
        else { return }
        StoreSnapshotter.snapshotIfNeeded(
            storeURL: storeURL,
            label: currentSnapshotLabel,
            backupsDirectory: backups
        )
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

    /// Where SwiftData keeps the `.onDisk` store: a named configuration
    /// without an explicit URL lands in Application Support as
    /// `<name>.store`. Only used to *find* an existing file — never to
    /// create one.
    public static func localStoreURL() -> URL {
        URL.applicationSupportDirectory.appendingPathComponent("\(localStoreName).store")
    }
}
