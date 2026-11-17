import MapKit
import SwiftUI
import UIKit

/// A camera move the user asked for (locate me, a search result, the saved
/// place). Each request has its own ID so the same spot can be requested
/// twice, and re-renders never re-apply an old request.
struct PlaceMapCameraRequest: Equatable {
    let id = UUID()
    let latitude: Double
    let longitude: Double
    let spanMeters: CLLocationDistance
    let animated: Bool
}

/// The map behind the place picker, built on `MKMapView`.
///
/// Why UIKit here: SwiftUI's `Map` keeps its camera and our state in a
/// two-way binding. Inside a sheet on iOS 26 that produced three different
/// hangs (an observation feedback loop, bar-layout constraint fights, and
/// an automatic-camera refit loop between the reminder circle and the
/// camera). This wrapper is strictly one-way in each direction:
/// - the map reports where the user stopped (`onCenterChange`), deferred
///   so it never mutates SwiftUI state during a view update;
/// - SwiftUI moves the map only for an explicit `cameraRequest`, applied
///   once per request ID.
/// Nothing the map reports can cause it to move, so there is no loop.
struct PlaceMapView: UIViewRepresentable {
    let cameraRequest: PlaceMapCameraRequest?
    let radius: CLLocationDistance
    let accent: Color
    /// Center and visible region after the user (or a request) moves the map.
    let onCenterChange: @MainActor (CLLocationCoordinate2D, MKCoordinateRegion) -> Void

    private enum Style {
        static let fillOpacity: CGFloat = 0.15
        static let lineWidth: CGFloat = 2
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.showsCompass = false
        map.pointOfInterestFilter = .includingAll
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onCenterChange = onCenterChange
        coordinator.accent = UIColor(accent)

        if let cameraRequest, cameraRequest.id != coordinator.appliedRequestID {
            coordinator.appliedRequestID = cameraRequest.id
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: cameraRequest.latitude, longitude: cameraRequest.longitude),
                latitudinalMeters: cameraRequest.spanMeters,
                longitudinalMeters: cameraRequest.spanMeters
            )
            map.setRegion(region, animated: cameraRequest.animated)
        }
        if coordinator.radius != radius {
            coordinator.radius = radius
            coordinator.redrawCircle(on: map)
        }
    }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency MKMapViewDelegate {
        var onCenterChange: (@MainActor (CLLocationCoordinate2D, MKCoordinateRegion) -> Void)?
        var appliedRequestID: UUID?
        var radius: CLLocationDistance = 0
        var accent: UIColor = .tintColor
        private var circle: MKCircle?

        /// The circle always sits where the pin is: the map's center.
        func redrawCircle(on map: MKMapView) {
            if let circle { map.removeOverlay(circle) }
            guard radius > 0 else { circle = nil; return }
            let next = MKCircle(center: map.centerCoordinate, radius: radius)
            map.addOverlay(next)
            circle = next
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            redrawCircle(on: mapView)
            let center = mapView.centerCoordinate
            let span = mapView.region.span
            let latitude = center.latitude, longitude = center.longitude
            let latitudeDelta = span.latitudeDelta, longitudeDelta = span.longitudeDelta
            // Deferred: this callback can fire inside `updateUIView`
            // (`setRegion`), and SwiftUI state must not change mid-update.
            Task { @MainActor [weak self] in
                let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                let region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
                )
                self?.onCenterChange?(coordinate, region)
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            guard let circle = overlay as? MKCircle else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKCircleRenderer(circle: circle)
            renderer.fillColor = accent.withAlphaComponent(Style.fillOpacity)
            renderer.strokeColor = accent
            renderer.lineWidth = Style.lineWidth
            return renderer
        }
    }
}
