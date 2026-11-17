import Foundation

/// Compiled regular expressions, built once and reused. The on-device
/// parsers (places, cues, contact moments) run over every memory on each
/// load; compiling their patterns per memory cost thousands of
/// compilations per screen. `NSRegularExpression` is immutable and safe to
/// share across threads once built.
enum RegexCache {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var storage: [String: NSRegularExpression] = [:]

    static func regex(_ pattern: String, options: NSRegularExpression.Options = []) -> NSRegularExpression? {
        let key = "\(options.rawValue)|\(pattern)"
        lock.lock()
        defer { lock.unlock() }
        if let cached = storage[key] { return cached }
        guard let compiled = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        storage[key] = compiled
        return compiled
    }
}
