import MapKit
import SwiftUI

#if DEBUG
/// Debug-only reproduction of the SwiftUI `Map` picker that froze on
/// device (commit 2c36409): `.automatic` camera, a `MapCircle` that follows
/// the camera center via `onMapCameraChange`, and a user annotation. CI runs
/// it with `-OrbitPlacePickerHarnessLegacy` and expects the smoke test to
/// flag it, which proves the smoke test can see this class of hang. Delete
/// once the new picker has shipped.
struct LegacyMapPickerRepro: View {
    @State private var position: MapCameraPosition = .automatic
    @State private var center: CLLocationCoordinate2D?
    private static let radius: CLLocationDistance = 200

    var body: some View {
        VStack(spacing: 0) {
            Text("Legacy repro")
            Map(position: $position) {
                UserAnnotation()
                if let center {
                    MapCircle(center: center, radius: Self.radius)
                        .foregroundStyle(.blue.opacity(0.15))
                }
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                center = context.region.center
            }
            Text("Controls")
        }
    }
}
#endif
