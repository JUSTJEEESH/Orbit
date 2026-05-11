import Foundation

/// An injectable wall clock. Lets tests drive deterministic time without
/// stubbing global `Date()`.
public protocol OrbitClock: Sendable {
    func now() -> Date
}

public struct SystemClock: OrbitClock {
    public init() {}
    public func now() -> Date { Date() }
}

/// Test fixture. Not thread-safe by design — drive from a single test thread.
public final class FixedClock: OrbitClock, @unchecked Sendable {
    private var current: Date
    public init(_ date: Date) { self.current = date }
    public func now() -> Date { current }
    public func advance(by interval: TimeInterval) { current.addTimeInterval(interval) }
    public func set(_ date: Date) { current = date }
}
