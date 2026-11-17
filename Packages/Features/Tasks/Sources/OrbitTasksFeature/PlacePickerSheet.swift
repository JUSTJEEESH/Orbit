import CoreLocation
import MapKit
import SwiftUI
import OrbitDesignSystem
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
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
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

    init(
        placeName: String,
        finder: PlaceFinder,
        onPick: @escaping @MainActor (PlaceCandidate, ReminderRadius) -> Void,
        onCancel: @escaping @MainActor () -> Void
    ) {
        self.placeName = placeName
        self.finder = finder
        self.onPick = onPick
        self.onCancel = onCancel
        self._name = State(initialValue: placeName)
    }

    var body: some View {
        NavigationStack {
            map
                .safeAreaInset(edge: .bottom) { controls }
                .overlay(alignment: .top) { searchResults }
                .searchable(text: $query, prompt: "Search nearby in Maps")
                .onSubmit(of: .search) { Task { await search() } }
                .onChange(of: query) { _, newValue in
                    if newValue.isEmpty { results = [] }
                }
                .navigationTitle("Where is \(placeName)?")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { onCancel() }
                    }
                }
                .task {
                    // Arrival alerts need location anyway; asking here also
                    // lets the map open on where the user is.
                    let allowed = await finder.ensureAuthorization()
                    if !allowed {
                        locationMessage = "Location is off for Orbit, so iPhone can\u{2019}t remind you on arrival. You can turn it on in Settings."
                    }
                }
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
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .onMapCameraChange(frequency: .continuous) { context in
            center = context.region.center
            visibleRegion = context.region
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
        .accessibilityLabel("Map. Move it to put the pin on \(placeName).")
    }

    // MARK: - Search

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
            TextField("Name", text: $name)
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
