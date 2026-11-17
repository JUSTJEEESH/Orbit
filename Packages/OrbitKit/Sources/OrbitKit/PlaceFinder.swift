import CoreLocation
import Foundation
import MapKit
import UserNotifications

/// A place the user can pick for an arrival reminder.
public struct PlaceCandidate: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let name: String
    public let subtitle: String?
    public let latitude: Double
    public let longitude: Double

    public init(id: UUID = UUID(), name: String, subtitle: String?, latitude: Double, longitude: Double) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// Finds coordinates for place reminders: where the user is now, or an
/// Apple Maps search. Only ever asks for "While Using" location access —
/// arrival alerts are delivered by iOS itself (`UNLocationNotificationTrigger`),
/// so Orbit never tracks location in the background.
@MainActor
public final class PlaceFinder {
    public enum Failure: Error, Sendable {
        case denied
        case unavailable
    }

    private static let resultLimit = 8

    public init() {}

    /// Whether Orbit may use location (and therefore arrival alerts).
    public var isAuthorized: Bool {
        switch CLLocationManager().authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return true
        default: return false
        }
    }

    /// The user's location now. Prompts for "While Using" access the first
    /// time.
    public func currentCoordinate() async throws -> (latitude: Double, longitude: Double) {
        // The session requests authorization and keeps updates flowing
        // only while it's held.
        let session = CLServiceSession(authorization: .whenInUse)
        defer { session.invalidate() }
        for try await update in CLLocationUpdate.liveUpdates() {
            if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
                throw Failure.denied
            }
            if let location = update.location {
                return (location.coordinate.latitude, location.coordinate.longitude)
            }
        }
        throw Failure.unavailable
    }

    /// Makes sure arrival alerts can fire, asking once if undecided.
    public func ensureAuthorization() async -> Bool {
        switch CLLocationManager().authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        case .denied, .restricted:
            return false
        default:
            do {
                _ = try await currentCoordinate()
                return true
            } catch {
                return false
            }
        }
    }

    /// Whether the user turned Orbit's notifications off. Arrival alerts
    /// are notifications, so a place reminder can't ring while this is
    /// true. Undecided is not "off": saving asks.
    public func notificationsAreOff() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }

    /// The street address at a point ("412 Oak St"), so the user can see
    /// the pin is where they meant. Nil when Maps doesn't know or is
    /// offline; the picker just shows nothing then.
    public func address(latitude: Double, longitude: Double) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        guard let request = MKReverseGeocodingRequest(location: location),
              let item = try? await request.mapItems.first else { return nil }
        return item.address?.shortAddress ?? item.name
    }

    /// Apple Maps search limited to `region` (the part of the map the user
    /// is looking at). Without the limit, a personal name like "Mom's"
    /// matches a "Moms Rd" hundreds of miles away.
    public func search(_ query: String, within region: MKCoordinateRegion) async throws -> [PlaceCandidate] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]
        request.region = region
        request.regionPriority = .required
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.prefix(Self.resultLimit).map { item in
            PlaceCandidate(
                name: item.name ?? query,
                subtitle: item.address?.shortAddress,
                latitude: item.location.coordinate.latitude,
                longitude: item.location.coordinate.longitude
            )
        }
    }
}
