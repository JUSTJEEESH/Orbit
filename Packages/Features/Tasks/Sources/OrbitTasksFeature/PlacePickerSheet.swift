import CoreLocation
import MapKit
import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit

/// How close counts as "arrived".
enum ReminderRadius: Double, CaseIterable, Identifiable {
    case small = 100
    case medium = 200
    case large = 500

    var id: Double { rawValue }

    var label: String {
        switch self {
        case .small:  return "Small"
        case .medium: return "Medium"
        case .large:  return "Large"
        }
    }

    /// "100 m" or "330 ft", in the user's units.
    var distanceLabel: String {
        Measurement(value: rawValue, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }
}

/// "Where is Mom's?" — the user moves the map under a fixed center pin
/// (the Apple Maps "drop a pin" feel), sees the exact circle that will
/// trigger the reminder, and can search Maps within the visible area to
/// jump somewhere. Starts at the user's location, since personal places
/// ("Mom's") are ones Maps can't know.
struct PlacePickerSheet: View {
    let placeName: String
    let finder: PlaceFinder
    let onPick: @MainActor (PlaceCandidate, ReminderRadius) -> Void
    let onCancel: @MainActor () -> Void

    @State private var name: String
    /// The latest camera move asked for (saved place, locate, search
    /// result). The map applies each request once.
    @State private var cameraRequest: PlaceMapCameraRequest?
    /// Changing an existing place opens on it; otherwise the map centers on
    /// the user once, after location access is settled.
    private let startsAtExistingPlace: Bool
    /// Debug harness only (CI smoke test): moves the camera on a timer to
    /// exercise the same path as a user dragging the map.
    private let harnessMovesCamera: Bool
    @State private var center: CLLocationCoordinate2D?
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var radius: ReminderRadius = .medium
    @State private var query = ""
    @State private var results: [PlaceCandidate] = []
    @State private var isSearching = false
    @State private var locationMessage: String?
    @State private var notificationsAreOff = false
    /// Where the user is, once known: tells them when they're already
    /// inside the circle (an arrival alert only rings on the way in).
    @State private var userCoordinate: CLLocationCoordinate2D?
    /// The street address under the pin, so they can see it's right.
    @State private var pinAddress: String?
    @State private var isFindingAddress = false
    @State private var addressLookup: Task<Void, Never>?
    /// The pin lifts while the map moves and settles when it stops.
    @State private var isMapMoving = false
    @Environment(\.orbitTheme) private var orbitTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far a search result zooms in.
    private static let resultSpanMeters: CLLocationDistance = 800
    private static let pinSize: CGFloat = 36
    /// How high the pin lifts while the map moves.
    private static let pinLift: CGFloat = 10
    private static let pinShadowSize: CGFloat = 8
    private static let pinShadowOpacity = 0.25
    /// Waits for the map to rest before looking up the address, so a
    /// drag doesn't fire a lookup per frame.
    private static let addressLookupDelay: Duration = .milliseconds(350)

    /// - Parameter current: the place being changed, so the map opens on
    ///   it (with its area) instead of on the user's location.
    init(
        placeName: String,
        current: PlaceCue? = nil,
        finder: PlaceFinder,
        onPick: @escaping @MainActor (PlaceCandidate, ReminderRadius) -> Void,
        onCancel: @escaping @MainActor () -> Void,
        harnessMovesCamera: Bool = false
    ) {
        self.harnessMovesCamera = harnessMovesCamera
        self.placeName = placeName
        self.finder = finder
        self.onPick = onPick
        self.onCancel = onCancel
        self._name = State(initialValue: placeName)
        self.startsAtExistingPlace = current != nil
        if let current {
            let coordinate = CLLocationCoordinate2D(latitude: current.latitude, longitude: current.longitude)
            self._cameraRequest = State(initialValue: PlaceMapCameraRequest(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                spanMeters: Self.resultSpanMeters,
                animated: false
            ))
            self._center = State(initialValue: coordinate)
            self._radius = State(initialValue: ReminderRadius(rawValue: current.radius) ?? .medium)
        }
    }

    // A plain stack with no navigation bar and no MapKit controls. Inside
    // a sheet's NavigationStack, iOS 26 hands the map "bar layout guides"
    // for the navigation bar and its floating controls; with the map
    // sized by a stack, those guides demanded more height than the map
    // had, and layout never settled (an earlier version also fought
    // `.searchable` over the bottom edge). A custom header and our own
    // locate button leave the map nothing to make room for.
    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar
            map
                .overlay(alignment: .top) { searchResults }
                .overlay(alignment: .bottomTrailing) { locateButton }
            controls
        }
        .background(OrbitColor.surfaceElevated)
        .task {
            notificationsAreOff = await finder.notificationsAreOff()
            // Arrival alerts need location anyway; asking here also lets
            // the map open on where the user is.
            let allowed = await finder.ensureAuthorization()
            guard allowed else {
                locationMessage = "Location is off for Orbit, so iPhone can\u{2019}t remind you on arrival. You can turn it on in Settings."
                return
            }
            if startsAtExistingPlace {
                // Still learn where the user is, for the "you're inside
                // the circle" note, without moving the map.
                if let here = try? await finder.currentCoordinate() {
                    userCoordinate = CLLocationCoordinate2D(latitude: here.latitude, longitude: here.longitude)
                }
            } else {
                await centerOnUser(animated: false)
            }
            if harnessMovesCamera {
                await runHarnessCameraMoves()
            }
        }
    }

    private var header: some View {
        ZStack {
            Text(placeName.isEmpty ? "Choose a Place" : "Where is \(placeName)?")
                .font(OrbitTypography.bodyEmphasized)
                .foregroundStyle(OrbitColor.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, OrbitSpacing.xxxl * 2)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button("Cancel") { onCancel() }
                    .font(OrbitTypography.body)
                    .frame(minHeight: OrbitHitTarget.minimum)
                Spacer()
            }
        }
        .padding(.horizontal, OrbitSpacing.md)
        .padding(.top, OrbitSpacing.sm)
    }

    private var locateButton: some View {
        Button {
            Haptics.play(.selection)
            Task { await centerOnUser(animated: true) }
        } label: {
            Image(systemName: "location.fill")
                .font(OrbitTypography.bodyEmphasized)
                .foregroundStyle(orbitTheme.primary)
                .frame(width: OrbitHitTarget.minimum, height: OrbitHitTarget.minimum)
                .background(OrbitColor.surfaceElevated, in: .circle)
                .orbitShadow(.lifted)
        }
        .buttonStyle(.plain)
        .padding(OrbitSpacing.md)
        .accessibilityLabel("Center on my location")
    }

    private func centerOnUser(animated: Bool) async {
        guard let here = try? await finder.currentCoordinate() else { return }
        userCoordinate = CLLocationCoordinate2D(latitude: here.latitude, longitude: here.longitude)
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: here.latitude, longitude: here.longitude),
            latitudinalMeters: Self.resultSpanMeters,
            longitudinalMeters: Self.resultSpanMeters
        )
        cameraRequest = PlaceMapCameraRequest(
            latitude: region.center.latitude,
            longitude: region.center.longitude,
            spanMeters: Self.resultSpanMeters,
            animated: animated
        )
    }

    /// Small hops around the starting point, like a user nudging the map.
    private func runHarnessCameraMoves() async {
        let offsets: [(Double, Double)] = [(0.002, 0), (0, 0.002), (-0.002, -0.002), (0.004, 0.001)]
        for (latitudeOffset, longitudeOffset) in offsets {
            try? await Task.sleep(for: .seconds(1.5))
            guard let center else { continue }
            cameraRequest = PlaceMapCameraRequest(
                latitude: center.latitude + latitudeOffset,
                longitude: center.longitude + longitudeOffset,
                spanMeters: Self.resultSpanMeters,
                animated: true
            )
        }
    }

    // MARK: - Map

    private var map: some View {
        PlaceMapView(
            cameraRequest: cameraRequest,
            radius: radius.rawValue,
            accent: orbitTheme.primary,
            onMoveStart: {
                // The old address no longer describes where the pin is.
                addressLookup?.cancel()
                pinAddress = nil
                withAnimation(OrbitMotion.respectfully(OrbitMotion.snap, reduceMotion: reduceMotion)) { isMapMoving = true }
            },
            onCenterChange: { newCenter, region in
                center = newCenter
                visibleRegion = region
                withAnimation(OrbitMotion.respectfully(OrbitMotion.snap, reduceMotion: reduceMotion)) { isMapMoving = false }
                lookUpAddress(at: newCenter)
            }
        )
        .overlay {
            // Fixed pin: the map moves under it. The tip sits on the
            // center; it lifts while the map moves, over a small shadow
            // marking the exact spot, and sets down when the map rests.
            ZStack {
                Ellipse()
                    .fill(OrbitColor.textPrimary.opacity(Self.pinShadowOpacity))
                    .frame(width: Self.pinShadowSize, height: Self.pinShadowSize / 2)
                Image(systemName: "mappin")
                    .font(.system(size: Self.pinSize, weight: .semibold))
                    .foregroundStyle(orbitTheme.primary)
                    .offset(y: -Self.pinSize / 2 - (isMapMoving ? Self.pinLift : 0))
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Map. Move it to put the pin on the place.")
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: OrbitSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(OrbitColor.textSecondary)
                .accessibilityHidden(true)
            TextField("Search nearby in Maps", text: $query)
                .font(OrbitTypography.body)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .onSubmit { Task { await search() } }
            if !query.isEmpty {
                Button {
                    query = ""
                    results = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(OrbitColor.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, OrbitSpacing.md)
        .padding(.vertical, OrbitSpacing.sm)
        .background(OrbitColor.surfaceMuted, in: .capsule)
        .padding(.horizontal, OrbitSpacing.md)
        .padding(.vertical, OrbitSpacing.sm)
    }

    @ViewBuilder
    private var searchResults: some View {
        if isSearching || !results.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                if isSearching {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(OrbitSpacing.md)
                }
                ForEach(results) { candidate in
                    Button {
                        select(candidate)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(candidate.name)
                                .font(OrbitTypography.body)
                                .foregroundStyle(OrbitColor.textPrimary)
                            Text(detail(for: candidate))
                                .font(OrbitTypography.footnote)
                                .foregroundStyle(OrbitColor.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, OrbitSpacing.md)
                        .padding(.vertical, OrbitSpacing.sm)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    if candidate.id != results.last?.id {
                        Divider().padding(.leading, OrbitSpacing.md)
                    }
                }
            }
            .background(OrbitColor.surfaceElevated, in: .rect(cornerRadius: OrbitRadius.lg))
            .orbitShadow(.lifted)
            .padding(OrbitSpacing.md)
        }
    }

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let visibleRegion else { return }
        isSearching = true
        defer { isSearching = false }
        results = (try? await finder.search(trimmed, within: visibleRegion)) ?? []
    }

    private func select(_ candidate: PlaceCandidate) {
        Haptics.play(.selection)
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            name = candidate.name
        }
        cameraRequest = PlaceMapCameraRequest(
            latitude: candidate.latitude,
            longitude: candidate.longitude,
            spanMeters: Self.resultSpanMeters,
            animated: true
        )
        results = []
        query = ""
    }

    /// "1.2 mi · 123 Main St"
    private func detail(for candidate: PlaceCandidate) -> String {
        var parts: [String] = []
        if let center {
            let meters = CLLocation(latitude: center.latitude, longitude: center.longitude)
                .distance(from: CLLocation(latitude: candidate.latitude, longitude: candidate.longitude))
            parts.append(Measurement(value: meters, unit: UnitLength.meters)
                .formatted(.measurement(width: .abbreviated, usage: .road)))
        }
        if let subtitle = candidate.subtitle { parts.append(subtitle) }
        return parts.joined(separator: " \u{00B7} ")
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            ForEach(warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.circle")
                    .font(OrbitTypography.footnote)
                    .foregroundStyle(OrbitColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            pinAddressRow
            TextField("Name, like Mom\u{2019}s house", text: $name)
                .font(OrbitTypography.bodyEmphasized)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
            VStack(alignment: .leading, spacing: OrbitSpacing.xs) {
                Text("Remind me within")
                    .font(OrbitTypography.footnote)
                    .foregroundStyle(OrbitColor.textSecondary)
                // Distances only: "Medium · 200 m" truncated in three
                // segments on smaller iPhones.
                Picker("Remind me within", selection: $radius) {
                    ForEach(ReminderRadius.allCases) { option in
                        Text(option.distanceLabel)
                            .accessibilityLabel("\(option.label), \(option.distanceLabel)")
                            .tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .sensoryFeedback(.selection, trigger: radius)
            }
            OrbitButton("Remind Me Here", style: .primary) {
                confirm()
            }
            .disabled(center == nil || name.trimmingCharacters(in: .whitespaces).isEmpty)
            Text("iPhone reminds you when you arrive inside the circle. Orbit never tracks where you go.")
                .font(OrbitTypography.caption)
                .foregroundStyle(OrbitColor.textSecondary)
        }
        .padding(OrbitSpacing.lg)
        .background(OrbitColor.surfaceElevated)
    }

    @ViewBuilder
    private var pinAddressRow: some View {
        HStack(spacing: OrbitSpacing.xs) {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(orbitTheme.primary)
                .accessibilityHidden(true)
            if let pinAddress {
                Text(pinAddress)
                    .foregroundStyle(OrbitColor.textPrimary)
            } else {
                Text(pinStatus)
                    .foregroundStyle(OrbitColor.textSecondary)
            }
        }
        .font(OrbitTypography.footnote)
        .lineLimit(1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(pinAddress.map { "Pin is at \($0)" } ?? pinStatus)
    }

    /// What the address row says before (or without) an address.
    private var pinStatus: String {
        if isFindingAddress || isMapMoving { return "Finding the address\u{2026}" }
        // Maps had no street address here (a park, a field): the pin
        // still works, like a dropped pin in Maps.
        return center == nil ? "Move the map to put the pin on the place" : "Dropped pin"
    }

    /// Things that would stop the reminder ringing, or delay it, said
    /// before saving rather than discovered later.
    private var warnings: [String] {
        var lines: [String] = []
        if let locationMessage { lines.append(locationMessage) }
        if notificationsAreOff {
            lines.append("Notifications are off for Orbit, so this reminder can\u{2019}t ring. You can turn them on in Settings.")
        }
        if let userCoordinate, let center,
           CLLocation(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude)
               .distance(from: CLLocation(latitude: center.latitude, longitude: center.longitude)) <= radius.rawValue {
            lines.append("You\u{2019}re inside this circle now, so the first reminder comes the next time you arrive.")
        }
        return lines
    }

    private func lookUpAddress(at coordinate: CLLocationCoordinate2D) {
        addressLookup?.cancel()
        pinAddress = nil
        isFindingAddress = true
        addressLookup = Task {
            try? await Task.sleep(for: Self.addressLookupDelay)
            guard !Task.isCancelled else { return }
            let address = await finder.address(latitude: coordinate.latitude, longitude: coordinate.longitude)
            guard !Task.isCancelled else { return }
            pinAddress = address
            isFindingAddress = false
        }
    }

    private func confirm() {
        guard let center else { return }
        Haptics.play(.success)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        onPick(
            PlaceCandidate(name: trimmed, subtitle: pinAddress, latitude: center.latitude, longitude: center.longitude),
            radius
        )
    }
}
