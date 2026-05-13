import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit
import OrbitMemoryDetailFeature

public struct SearchView: View {
    @State private var model: SearchViewModel
    @FocusState private var fieldFocus: Bool
    @Namespace private var heroNamespace

    private let makeDetailViewModel: @MainActor (UUID) -> MemoryDetailViewModel

    public init(
        viewModel: SearchViewModel,
        makeDetailViewModel: @escaping @MainActor (UUID) -> MemoryDetailViewModel
    ) {
        self._model = State(initialValue: viewModel)
        self.makeDetailViewModel = makeDetailViewModel
    }

    public var body: some View {
        OrbitScreen {
            VStack(alignment: .leading, spacing: OrbitSpacing.md) {
                OrbitTextField(
                    "Ask anything",
                    text: Binding(
                        get: { model.query },
                        set: { newValue in
                            model.query = newValue
                            model.queryDidChange()
                        }
                    ),
                    systemImage: "magnifyingglass",
                    focused: $fieldFocus
                )
                .submitLabel(.search)
                .onSubmit { fieldFocus = false }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            fieldFocus = false
                        }
                        .foregroundStyle(OrbitColor.textPrimary)
                    }
                }

                scopeChips

                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, OrbitSpacing.md)
            .padding(.bottom, 96)
        }
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { fieldFocus = false }
        )
        .navigationDestination(for: MemoryDetailRoute.self) { route in
            MemoryDetailView(
                viewModel: makeDetailViewModel(route.memoryID),
                onDeleted: {}
            )
            .navigationTransition(.zoom(sourceID: route.memoryID, in: heroNamespace))
        }
    }

    private var scopeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: OrbitSpacing.xs) {
                ForEach(SearchViewModel.Scope.allCases, id: \.self) { scope in
                    Button {
                        Haptics.play(.selection)
                        model.scope = scope
                        model.scopeDidChange()
                    } label: {
                        OrbitChip(scope.title, isSelected: model.scope == scope)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle:
            suggestions
        case .searching:
            searchingState
        case .empty:
            emptyState
        case .results:
            resultList
        case .failed(let message):
            errorState(message)
        }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Try")
            FlowSuggestions(
                queries: [
                    "Restaurants in Roatan",
                    "Drone business idea",
                    "From Pamela last month",
                    "Voice notes about travel",
                    "Passport renewal",
                ],
                onTap: { suggestion in
                    Haptics.play(.tap)
                    model.query = suggestion
                    model.queryDidChange()
                }
            )
        }
        .padding(.top, OrbitSpacing.lg)
    }

    private var searchingState: some View {
        HStack(spacing: OrbitSpacing.sm) {
            ProgressView()
            Text("Searching…")
                .font(OrbitTypography.callout)
                .foregroundStyle(OrbitColor.textSecondary)
        }
        .padding(.top, OrbitSpacing.lg)
    }

    private var emptyState: some View {
        OrbitEmptyState(
            systemImage: "magnifyingglass",
            title: "No matches yet",
            message: "Try different words, or capture this thought as a new memory."
        )
        .padding(.top, OrbitSpacing.xxl)
    }

    private func errorState(_ message: String) -> some View {
        OrbitErrorState(
            title: "Search failed",
            message: message
        )
        .padding(.top, OrbitSpacing.xxl)
    }

    private var resultList: some View {
        ScrollView {
            LazyVStack(spacing: OrbitSpacing.sm) {
                ForEach(model.results) { result in
                    NavigationLink(value: MemoryDetailRoute(memoryID: result.memory.id)) {
                        SearchResultRow(result: result)
                    }
                    .buttonStyle(OrbitBloomButtonStyle(
                        tint: OrbitCategoryPalette.tint(for: result.memory.ai.category)
                    ))
                    .matchedTransitionSource(id: result.memory.id, in: heroNamespace)
                    .simultaneousGesture(TapGesture().onEnded {
                        Haptics.play(.selection)
                        fieldFocus = false
                    })
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
    }
}

private struct FlowSuggestions: View {
    let queries: [String]
    let onTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.xs) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: OrbitSpacing.xs) {
                    ForEach(row, id: \.self) { suggestion in
                        Button {
                            onTap(suggestion)
                        } label: {
                            OrbitChip(suggestion)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// Cheap two-column layout. SwiftUI Layout-protocol flow can come later
    /// if the suggestion set grows.
    private var rows: [[String]] {
        stride(from: 0, to: queries.count, by: 2).map { start in
            Array(queries[start..<min(start + 2, queries.count)])
        }
    }
}

private struct SearchResultRow: View {
    let result: SearchMemoriesUseCase.Result

    var body: some View {
        OrbitCard(elevation: .resting) {
            VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                OrbitEyebrow(
                    label: eyebrowLabel,
                    suffix: timestamp,
                    tint: OrbitCategoryPalette.tint(for: result.memory.ai.category)
                )

                HStack(alignment: .top, spacing: OrbitSpacing.sm) {
                    Image(systemName: kindIcon)
                        .scaledFont(size: 14, weight: .regular)
                        .foregroundStyle(OrbitColor.textTertiary)
                        .padding(.top, 3)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
                        Text(headline)
                            .font(OrbitTypography.body)
                            .foregroundStyle(OrbitColor.textPrimary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                        if let snippet = result.highlight, snippet != headline {
                            Text(snippet)
                                .font(OrbitTypography.footnote)
                                .foregroundStyle(OrbitColor.textSecondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(eyebrowLabel). \(headline). \(timestamp)")
        .accessibilityHint("Double-tap to open.")
    }

    private var eyebrowLabel: String {
        if let category = result.memory.ai.category?.trimmingCharacters(in: .whitespacesAndNewlines),
           !category.isEmpty {
            return category
        }
        return kindLabel
    }

    private var headline: String {
        if let summary = result.memory.ai.summary, !summary.isEmpty { return summary }
        switch result.memory.content {
        case .text(let s):                                   return s
        case .voiceNote(let transcript, _):                  return transcript ?? "Voice note"
        case .image(let caption):                            return caption ?? "Photo"
        case .link(_, let title, let summary):               return summary ?? title ?? "Link"
        case .screenshot(let ocr):                           return ocr ?? "Screenshot"
        case .location(let name, _, _):                      return name ?? "Location"
        }
    }

    private var kindLabel: String {
        switch result.memory.content {
        case .text:        return "Note"
        case .voiceNote:   return "Voice"
        case .image:       return "Photo"
        case .link:        return "Link"
        case .screenshot:  return "Screenshot"
        case .location:    return "Place"
        }
    }

    private var kindIcon: String {
        switch result.memory.content {
        case .text:        return "text.alignleft"
        case .voiceNote:   return "waveform"
        case .image:       return "photo"
        case .link:        return "link"
        case .screenshot:  return "rectangle.on.rectangle"
        case .location:    return "mappin"
        }
    }

    private var timestamp: String {
        result.memory.createdAt.formatted(.relative(presentation: .named))
    }
}
