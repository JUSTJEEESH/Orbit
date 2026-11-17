import Foundation

/// What brings a task back to mind besides a clock: arriving somewhere, or
/// being with someone. Research on ADHD and prospective memory shows event
/// cues work far better than time cues ("at Mom's", not "at 6 pm").
public enum TaskCue: Sendable, Hashable {
    case place(PlaceCue)
    /// Matched against calendar attendees and the people in new memories.
    case person(String)

    public var place: PlaceCue? {
        if case .place(let place) = self { return place }
        return nil
    }

    public var placeName: String? { place?.name }

    public var personName: String? {
        if case .person(let name) = self { return name }
        return nil
    }
}

/// A named spot with a radius, for an arrival alert.
public struct PlaceCue: Sendable, Hashable {
    public var name: String
    public var latitude: Double
    public var longitude: Double
    /// Meters. Large enough to fire reliably on arrival, small enough not
    /// to fire from the next street.
    public var radius: Double

    public static let defaultRadius: Double = 150

    public init(name: String, latitude: Double, longitude: Double, radius: Double = PlaceCue.defaultRadius) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
    }
}
