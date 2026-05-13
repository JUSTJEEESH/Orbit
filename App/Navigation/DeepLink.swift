import Foundation

/// Typed parser for the `orbit://` URL scheme.
///
/// Supported routes:
/// - `orbit://capture` → opens the capture sheet
/// - `orbit://search?q=text` → opens the search tab with a prefilled query
enum DeepLink: Equatable {
    case capture
    case search(query: String)

    init?(url: URL) {
        guard url.scheme == "orbit" else { return nil }

        switch url.host {
        case "capture":
            self = .capture
        case "search":
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let q = components?.queryItems?.first(where: { $0.name == "q" })?.value ?? ""
            self = .search(query: q)
        default:
            return nil
        }
    }
}
