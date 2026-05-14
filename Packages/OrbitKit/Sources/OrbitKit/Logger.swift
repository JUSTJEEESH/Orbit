import Foundation
import OSLog

/// Structured logging facade over `OSLog`. Use a category per subsystem so logs
/// stay grep-able in Console.app and via `log stream --predicate`.
///
/// ```swift
/// private let log = OrbitLog.capture
/// log.info("captured memory id=\(id)")
/// ```
public enum OrbitLog {
    private static let subsystem = "com.joshgreen.orbit"

    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let capture = Logger(subsystem: subsystem, category: "capture")
    public static let persistence = Logger(subsystem: subsystem, category: "persistence")
    public static let ai = Logger(subsystem: subsystem, category: "ai")
    public static let search = Logger(subsystem: subsystem, category: "search")
    public static let sync = Logger(subsystem: subsystem, category: "sync")
    public static let ui = Logger(subsystem: subsystem, category: "ui")

    /// Use with `OSSignposter` for Instruments-driven performance measurement.
    public static let signposter = OSSignposter(subsystem: subsystem, category: "signpost")
}
