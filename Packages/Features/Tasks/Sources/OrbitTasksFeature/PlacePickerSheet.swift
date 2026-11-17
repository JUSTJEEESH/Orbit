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
    @State private var position: MapCameraPosition = .automatic
    /// Changing an existing place opens on it; otherwise the map centers on
    /// the user once, after location access is settled.
    private let startsAtExistingPlace: Bool
    @State private var center: CLLocationCoordinate2D?
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var radius: ReminderRadius = .medium
    @State private var query = ""
    @State private var results: [PlaceCandidate] = []
    @State private var isSearching = false
    @State private var locationMessage: String?
    @Environment(\.orbitTheme) private var orbitTheme

    /// How far a search result zooms in.
    private static let resultSpanMeters: CLLocationDistance = 800
    private static let pinSize: CGFloat = 36

    /// - Parameter current: the place being changed, so the map opens on
    ///   it (with its area) instead of on the user's location.
    init(
        placeName: String,
        current: PlaceCue? = nil,
        finder: PlaceFinder,
        onPick: @escaping @MainActor (PlaceCandidate, ReminderRadius) -> Void,
        onCancel: @escaping @MainActor () -> Void
    ) {
        self.placeName = placeName
        self.finder = finder
        self.onPick = onPick
        self.onCancel = onCancel
        self._name = State(initialValue: placeName)
        self.startsAtExistingPlace = current != nil
        if let current {
            let coordinate = CLLocationCoordinate2D(latitude: current.latitude, longitude: current.longitude)
            self._position = State(initialValue: .region(MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: Self.resultSpanMeters,
                longitudinalMeters: Self.resultSpanMeters
            )))
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
            // Arrival alerts need location anyway; asking here also lets
            // the map open on where the user is.
            let allowed = await finder.ensureAuthorization()
            guard allowed else {
                locationMessage = "Location is off for Orbit, so iPhone can\u{2019}t remind you on arrival. You can turn it on in Settings."
                return
            }
            if !startsAtExistingPlace {
                await centerOnUser(animated: false)
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
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: here.latitude, longitude: here.longitude),
            latitudinalMeters: Self.resultSpanMeters,
            longitudinalMeters: Self.resultSpanMeters
        )
        if animated {
            withAnimation(OrbitMotion.smooth) { position = .region(region) }
        } else {
            position = .region(region)
        }
    }

    // MARK: - Map

    private var map: some View {
        Map(position: $position) {
            UserAnnotation()
            if let center {
                MapCircle(center: center, radius: radius.rawValue)
                    .foregroundStyle(orbitTheme.primary.opacity(0.15))
                    .stroke(orbitTheme.primary, lineWidth: 2)
            }
        }
        // `.onEnd`, not `.continuous`: writing state on every camera frame
        // re-renders the sheet, which nudges the map's layout, which moves
        // the camera again — a layout feedback loop that froze the sheet.
        // The pin is a fixed overlay, so it tracks the finger regardless;
        // only the circle and the confirmed spot wait for the drag to end.
        .onMapCameraChange(frequency: .onEnd) { context in
            let region = context.region
            if let visibleRegion, Self.isNegligibleChange(from: visibleRegion, to: region) { return }
            center = region.center
            visibleRegion = region
        }
        .overlay {
            // Fixed pin: the map moves under it. The tip sits on the center.
            Image(systemName: "mappin")
                .font(.system(size: Self.pinSize, weight: .semibold))
                .foregroundStyle(orbitTheme.primary)
                .offset(y: -Self.pinSize / 2)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .accessibilityLabel("Map. Move it to put the pin on the place.")
    }

    /// Camera moves smaller than this (degrees, about a meter) are layout
    /// jitter, not the user moving the map.
    private static let negligibleDegrees = 0.000_01

    private static func isNegligibleChange(from old: MKCoordinateRegion, to new: MKCoordinateRegion) -> Bool {
        abs(old.center.latitude - new.center.latitude) < negligibleDegrees
            && abs(old.center.longitude - new.center.longitude) < negligibleDegrees
            && abs(old.span.latitudeDelta - new.span.latitudeDelta) < negligibleDegrees
            && abs(old.span.longitudeDelta - new.span.longitudeDelta) < negligibleDegrees
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
        let coordinate = CLLocationCoordinate2D(latitude: candidate.latitude, longitude: candidate.longitude)
        withAnimation(OrbitMotion.smooth) {
            position = .region(MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: Self.resultSpanMeters,
                longitudinalMeters: Self.resultSpanMeters
            ))
        }
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
            if let locationMessage {
                Text(locationMessage)
                    .font(OrbitTypography.footnote)
                    .foregroundStyle(OrbitColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            TextField("Name, like Mom\u{2019}s house", text: $name)
                .font(OrbitTypography.bodyEmphasized)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
            Picker("Reminder area", selection: $radius) {
                ForEach(ReminderRadius.allCases) { option in
                    Text("\(option.label) \u{00B7} \(option.distanceLabel)").tag(option)
                }
            }
            .pickerStyle(.segmented)
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

    private func confirm() {
        guard let center else { return }
        Haptics.play(.success)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        onPick(
            PlaceCandidate(name: trimmed, subtitle: nil, latitude: center.latitude, longitude: center.longitude),
            radius
        )
    }
}
