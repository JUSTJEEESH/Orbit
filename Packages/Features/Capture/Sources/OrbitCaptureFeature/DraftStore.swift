import Foundation

/// Lightweight persistence for in-progress capture drafts. Strings only —
/// audio drafts hold real bytes and live in `MediaStorage`, photos are
/// memory-only until saved.
public struct DraftStore: Sendable {
    public var loadTextDraft: @Sendable () -> String?
    public var saveTextDraft: @Sendable (String) -> Void
    public var clearTextDraft: @Sendable () -> Void

    public init(
        loadTextDraft: @escaping @Sendable () -> String?,
        saveTextDraft: @escaping @Sendable (String) -> Void,
        clearTextDraft: @escaping @Sendable () -> Void
    ) {
        self.loadTextDraft = loadTextDraft
        self.saveTextDraft = saveTextDraft
        self.clearTextDraft = clearTextDraft
    }

    public static let userDefaults: DraftStore = {
        let key = "orbit.capture.textDraft"
        let defaults = UserDefaults.standard
        return DraftStore(
            loadTextDraft: { defaults.string(forKey: key) },
            saveTextDraft: { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    defaults.removeObject(forKey: key)
                } else {
                    defaults.set(value, forKey: key)
                }
            },
            clearTextDraft: { defaults.removeObject(forKey: key) }
        )
    }()

    public static let noop = DraftStore(
        loadTextDraft: { nil },
        saveTextDraft: { _ in },
        clearTextDraft: {}
    )
}
