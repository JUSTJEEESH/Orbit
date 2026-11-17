import Foundation
import os
import SwiftData

private let log = Logger(subsystem: "com.joshgreen.orbit", category: "persistence")

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
/// iCloud sync is opt-in: `.appGroup` with a `cloudKitContainer` mirrors
/// the same store file to the user's private CloudKit database. Turning it
/// on never moves or deletes local rows — SwiftData uploads what's there.
/// Only the main app passes a container; extensions keep opening the store
/// local-only, and their writes are uploaded by the app afterwards.
public enum ModelContainerFactory {
    public enum Mode: Sendable, Equatable {
        case inMemory
        case onDisk
        case appGroup(identifier: String, cloudKitContainer: String? = nil)
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
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: OrbitMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            return try openWithInferredMigration(schema: schema, configuration: configuration, planError: error)
        }
    }

    /// Second attempt for a store whose schema matches no version in the
    /// migration plan.
    ///
    /// A migration plan only recognizes stores whose model hash equals one
    /// of its listed versions. A store written by an unreleased 2.0 build
    /// (TestFlight or a developer's device, before later optional fields
    /// were added) matches none of them, so the plan refuses it with
    /// `unknownDataStoreSchema`. SQLite stores carry a copy of the model
    /// that wrote them, so opening without the plan lets Core Data infer a
    /// lightweight migration from that copy. Every 2.0 change is an added
    /// optional attribute, which lightweight migration fills with nil.
    ///
    /// This never deletes or recreates the store: if Core Data can't infer
    /// a safe migration it throws, and the caller shows the recovery
    /// screen with the original file untouched (and already snapshotted).
    private static func openWithInferredMigration(
        schema: Schema,
        configuration: ModelConfiguration,
        planError: any Error
    ) throws -> ModelContainer {
        log.error("Migration plan couldn't open the store: \(String(describing: planError), privacy: .public). Trying inferred migration.")
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            log.notice("Store opened with inferred lightweight migration.")
            return container
        } catch {
            log.error("Inferred migration failed too: \(String(describing: error), privacy: .public)")
            // Report the plan's error: it describes why the normal path
            // failed, which is what support needs to see.
            throw planError
        }
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

        case .appGroup(let identifier, let cloudKitContainer):
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
                cloudKitDatabase: cloudKitContainer.map { .private($0) } ?? .none
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
        guard case .appGroup(let identifier, _) = mode,
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
