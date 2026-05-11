import Foundation

/// The top-level tab destinations. Capture is intentionally NOT a tab — it
/// lives behind the floating action button so it's always reachable without
/// stealing chrome.
enum AppTab: Hashable, CaseIterable {
    case home
    case timeline
    case search

    var systemImage: String {
        switch self {
        case .home:     return "circle.hexagongrid"
        case .timeline: return "clock"
        case .search:   return "magnifyingglass"
        }
    }

    var title: String {
        switch self {
        case .home:     return "Home"
        case .timeline: return "Timeline"
        case .search:   return "Search"
        }
    }
}

/// Modal destinations layered above the tab shell. Strongly typed routes
/// instead of free-form sheet bindings.
enum AppModal: Hashable, Identifiable {
    case capture
    case settings
    case paywall

    var id: Self { self }
}
