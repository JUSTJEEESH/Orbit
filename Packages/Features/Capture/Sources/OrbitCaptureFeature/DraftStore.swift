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
        // We deliberately reference `UserDefaults.standard` inside each
        // closure rather than capturing it: `UserDefaults` isn't Sendable
        // and these closures must be, but the `.standard` accessor is
        // documented thread-safe.
        let key = "orbit.capture.textDraft"
        return DraftStore(
            loadTextDraft: { UserDefaults.standard.string(forKey: key) },
            saveTextDraft: { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    UserDefaults.standard.removeObject(forKey: key)
                } else {
                    UserDefaults.standard.set(value, forKey: key)
                }
            },
            clearTextDraft: { UserDefaults.standard.removeObject(forKey: key) }
        )
    }()

    public static let noop = DraftStore(
        loadTextDraft: { nil },
        saveTextDraft: { _ in },
        clearTextDraft: {}
    )
}
