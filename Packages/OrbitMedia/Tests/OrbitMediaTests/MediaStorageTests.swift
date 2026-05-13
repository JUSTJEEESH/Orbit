import Foundation
import Testing
@testable import OrbitMedia

@Suite("Media storage")
struct MediaStorageTests {

    private func makeStorage() throws -> (MediaStorage, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("orbit-tests-\(UUID().uuidString)", isDirectory: true)
        let storage = try MediaStorage(root: root)
        return (storage, root)
    }

    @Test func writesDataToDisk() async throws {
        let (storage, root) = try makeStorage()
        let payload = Data("hello".utf8)
        let file = try await storage.write(payload, kind: .audio)

        #expect(file.byteSize == Int64(payload.count))
        #expect(FileManager.default.fileExists(atPath: file.url.path))
        #expect(file.url.path.hasPrefix(root.path))

        try? FileManager.default.removeItem(at: root)
    }

    @Test func reservedURLIsStableAcrossFinalize() async throws {
        let (storage, root) = try makeStorage()
        let reserved = await storage.reserveURL(kind: .audio)
        try Data("audio bytes".utf8).write(to: reserved.url, options: .atomic)
        let finalized = try await storage.finalize(reserved)

        #expect(finalized.url == reserved.url)
        #expect(finalized.byteSize > 0)

        try? FileManager.default.removeItem(at: root)
    }

    @Test func deletesFiles() async throws {
        let (storage, root) = try makeStorage()
        let file = try await storage.write(Data("x".utf8), kind: .image)
        try await storage.delete(filename: file.filename)
        #expect(!FileManager.default.fileExists(atPath: file.url.path))

        try? FileManager.default.removeItem(at: root)
    }
}
