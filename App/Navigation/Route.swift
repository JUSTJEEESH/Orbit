import Foundation

/// The top-level tab destinations. Capture is intentionally NOT a tab — it
/// lives behind the floating action button so it's always reachable without
/// stealing chrome.
enum AppTab: Hashable, CaseIterable {
    case home
    case timeline
    case tasks
    case search

    var systemImage: String {
        switch self {
        case .home:     return "circle.hexagongrid"
        case .timeline: return "clock"
        case .tasks:    return "checklist"
        case .search:   return "magnifyingglass"
        }
    }

    var title: String {
        switch self {
        case .home:     return "Home"
        case .timeline: return "Timeline"
        case .tasks:    return "Tasks"
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
    case dailyRecap
    case patterns
    case askOrbit
    case letter

    var id: Self { self }
}
