import Foundation

/// Injectable wall clock. Use cases that timestamp values depend on this so
/// tests can drive deterministic time.
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
