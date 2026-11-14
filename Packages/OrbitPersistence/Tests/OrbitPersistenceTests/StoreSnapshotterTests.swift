import Foundation
import Testing
@testable import OrbitPersistence

@Suite("Store snapshots", .serialized)
struct StoreSnapshotterTests {

    private func makeSandbox() throws -> (store: URL, backups: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("orbit-snapshot-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return (root.appendingPathComponent("orbit.sqlite"), root.appendingPathComponent("Backups", isDirectory: true))
    }

    private func writeStore(at store: URL, contents: String) throws {
        try Data("db-\(contents)".utf8).write(to: store)
        try Data("wal-\(contents)".utf8).write(to: URL(fileURLWithPath: store.path + "-wal"))
        try Data("shm-\(contents)".utf8).write(to: URL(fileURLWithPath: store.path + "-shm"))
    }

    @Test func freshInstallTakesNoSnapshot() throws {
        let sandbox = try makeSandbox()
        let result = StoreSnapshotter.snapshotIfNeeded(
            storeURL: sandbox.store, label: "before-schema-2.0.0", backupsDirectory: sandbox.backups
        )
        #expect(result == nil)
        #expect(!FileManager.default.fileExists(atPath: sandbox.backups.appendingPathComponent("before-schema-2.0.0").path))
    }

    @Test func copiesDatabaseAndWriteAheadLog() throws {
        let sandbox = try makeSandbox()
        try writeStore(at: sandbox.store, contents: "v1")

        let snapshot = try #require(StoreSnapshotter.snapshotIfNeeded(
            storeURL: sandbox.store, label: "before-schema-2.0.0", backupsDirectory: sandbox.backups
        ))

        #expect(try String(contentsOf: snapshot.appendingPathComponent("orbit.sqlite"), encoding: .utf8) == "db-v1")
        #expect(try String(contentsOf: snapshot.appendingPathComponent("orbit.sqlite-wal"), encoding: .utf8) == "wal-v1")
        #expect(try String(contentsOf: snapshot.appendingPathComponent("orbit.sqlite-shm"), encoding: .utf8) == "shm-v1")
        // The original is untouched.
        #expect(try String(contentsOf: sandbox.store, encoding: .utf8) == "db-v1")

        let listed = StoreSnapshotter.snapshots(in: sandbox.backups)
        #expect(listed.count == 1)
        #expect(listed.first?.manifest.label == "before-schema-2.0.0")
        #expect(listed.first?.manifest.files["orbit.sqlite"] == 5)
    }

    /// The snapshot must keep the *pre-upgrade* bytes: later launches see
    /// the existing snapshot and never overwrite it with migrated data.
    @Test func snapshotIsTakenOnlyOncePerLabel() throws {
        let sandbox = try makeSandbox()
        try writeStore(at: sandbox.store, contents: "v1")
        StoreSnapshotter.snapshotIfNeeded(storeURL: sandbox.store, label: "before-schema-2.0.0", backupsDirectory: sandbox.backups)

        try writeStore(at: sandbox.store, contents: "v2")
        let snapshot = try #require(StoreSnapshotter.snapshotIfNeeded(
            storeURL: sandbox.store, label: "before-schema-2.0.0", backupsDirectory: sandbox.backups
        ))
        #expect(try String(contentsOf: snapshot.appendingPathComponent("orbit.sqlite"), encoding: .utf8) == "db-v1")
    }

    @Test func keepsOnlyNewestSnapshots() throws {
        let sandbox = try makeSandbox()
        try writeStore(at: sandbox.store, contents: "x")
        let labels = (1...5).map { "before-schema-\($0).0.0" }
        for (index, label) in labels.enumerated() {
            StoreSnapshotter.snapshotIfNeeded(
                storeURL: sandbox.store, label: label, backupsDirectory: sandbox.backups,
                now: Date(timeIntervalSince1970: TimeInterval(1_000 * (index + 1)))
            )
        }
        let remaining = StoreSnapshotter.snapshots(in: sandbox.backups).map(\.manifest.label)
        #expect(remaining == Array(labels.suffix(StoreSnapshotter.retainedSnapshots).reversed()))
    }
}
