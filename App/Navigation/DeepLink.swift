import Foundation

/// Typed parser for the `orbit://` URL scheme.
///
/// Supported routes:
/// - `orbit://capture` → opens the capture sheet
/// - `orbit://search?q=text` → opens the search tab with a prefilled query
/// - `orbit://memory/<uuid>` → opens Memory Detail for that memory, pushed
///                              onto the Timeline tab's NavigationStack
/// - `orbit://year-in-review` → opens Year in Review (App Store in-app event)
/// - `orbit://record` → opens capture already recording a voice note
///                      (Control Center, Lock Screen, Action Button, widgets)
enum DeepLink: Equatable {
    case capture
    case recordVoice
    case search(query: String)
    case memory(id: UUID)
    case yearInReview

    init?(url: URL) {
        guard url.scheme == "orbit" else { return nil }

        switch url.host {
        case "capture":
            self = .capture
        case "record":
            self = .recordVoice
        case "search":
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let q = components?.queryItems?.first(where: { $0.name == "q" })?.value ?? ""
            self = .search(query: q)
        case "year-in-review":
            self = .yearInReview
        case "memory":
            // Path looks like "/<uuid>"; drop the leading slash before parsing.
            let raw = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard let id = UUID(uuidString: raw) else { return nil }
            self = .memory(id: id)
        default:
            return nil
        }
    }
}
