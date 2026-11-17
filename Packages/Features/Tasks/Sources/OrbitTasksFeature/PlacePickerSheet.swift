import SwiftUI
import OrbitDesignSystem
import OrbitKit

/// "Where is Mom's?" — confirms the spot for an arrival reminder. "I'm
/// here now" is first (the most common case for personal places Maps
/// can't know); below it, Apple Maps results for what the user wrote.
struct PlacePickerSheet: View {
    /// The place as written ("Mom's", "Costco").
    let placeName: String
    let finder: PlaceFinder
    let onPick: @MainActor (PlaceCandidate) -> Void
    let onCancel: @MainActor () -> Void

    @State private var query: String
    @State private var results: [PlaceCandidate] = []
    @State private var isSearching = false
    @State private var isLocating = false
    @State private var message: String?

    init(placeName: String, finder: PlaceFinder, onPick: @escaping @MainActor (PlaceCandidate) -> Void, onCancel: @escaping @MainActor () -> Void) {
        self.placeName = placeName
        self.finder = finder
        self.onPick = onPick
        self.onCancel = onCancel
        self._query = State(initialValue: placeName)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        useCurrentLocation()
                    } label: {
                        HStack {
                            Label("I\u{2019}m here now", systemImage: "location.fill")
                                .font(OrbitTypography.bodyEmphasized)
                            Spacer()
                            if isLocating { ProgressView() }
                        }
                    }
                    .disabled(isLocating)
                } footer: {
                    Text("iPhone reminds you when you arrive. Orbit never tracks where you go.")
                }

                if let message {
                    Section {
                        Text(message)
                            .font(OrbitTypography.footnote)
                            .foregroundStyle(OrbitColor.textSecondary)
                    }
                }

                Section("Apple Maps") {
                    if isSearching {
                        ProgressView()
                    } else if results.isEmpty {
                        Text("No matches. Try a store name or an address.")
                            .font(OrbitTypography.footnote)
                            .foregroundStyle(OrbitColor.textSecondary)
                    }
                    ForEach(results) { candidate in
                        Button {
                            Haptics.play(.selection)
                            onPick(candidate)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(candidate.name)
                                    .font(OrbitTypography.body)
                                    .foregroundStyle(OrbitColor.textPrimary)
                                if let subtitle = candidate.subtitle {
                                    Text(subtitle)
                                        .font(OrbitTypography.footnote)
                                        .foregroundStyle(OrbitColor.textSecondary)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search Maps")
            .onSubmit(of: .search) { Task { await search() } }
            .navigationTitle("Where is \(placeName)?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
            .task { await search() }
        }
    }

    private func useCurrentLocation() {
        isLocating = true
        message = nil
        Task {
            defer { isLocating = false }
            do {
                let here = try await finder.currentCoordinate()
                Haptics.play(.success)
                onPick(PlaceCandidate(name: placeName, subtitle: nil, latitude: here.latitude, longitude: here.longitude))
            } catch PlaceFinder.Failure.denied {
                message = "Location is off for Orbit. Turn it on in Settings, or pick a Maps result below."
            } catch {
                message = "Couldn\u{2019}t find your location just now. Try again, or pick a Maps result."
            }
        }
    }

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        // Favor nearby results when location is already allowed; never
        // prompt just to search.
        var near: (latitude: Double, longitude: Double)?
        if finder.isAuthorized {
            near = try? await finder.currentCoordinate()
        }
        results = (try? await finder.search(trimmed, near: near)) ?? []
    }
}
