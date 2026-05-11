import Foundation
import OSLog

/// Thin wrapper around `OSSignposter` for measuring critical paths with
/// Instruments. Spans show up in the Points of Interest instrument when
/// profiling.
///
/// Example:
/// ```swift
/// try await OrbitSignpost.measure("Memory enrichment") {
///     try await enrichMemory(memoryID: id)
/// }
/// ```
public enum OrbitSignpost {

    /// Wraps an async throwing closure in a signpost interval.
    public static func measure<T>(
        _ name: StaticString,
        _ work: () async throws -> T
    ) async rethrows -> T {
        let signposter = OrbitLog.signposter
        let state = signposter.beginInterval(name)
        defer { signposter.endInterval(name, state) }
        return try await work()
    }

    /// Wraps a sync throwing closure in a signpost interval.
    public static func measureSync<T>(
        _ name: StaticString,
        _ work: () throws -> T
    ) rethrows -> T {
        let signposter = OrbitLog.signposter
        let state = signposter.beginInterval(name)
        defer { signposter.endInterval(name, state) }
        return try work()
    }
}
