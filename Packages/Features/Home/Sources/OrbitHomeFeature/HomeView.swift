import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit
import OrbitMemoryDetailFeature

public struct HomeView: View {
    private let listMemories: ListMemoriesUseCase
    private let generateInsights: GenerateInsightsUseCase
    private let listOnThisDay: ListOnThisDayUseCase
    private let refreshToken: Int
    private let clock: any OrbitClock
    private let makeDetailViewModel: @MainActor (UUID) -> MemoryDetailViewModel
    private let onPresentRecap: @MainActor () -> Void
    private let onPresentPatterns: @MainActor () -> Void
    private let onPresentAskOrbit: @MainActor () -> Void
    private let onPresentLetter: @MainActor () -> Void

    @State private var memories: [Memory] = []
    @State private var loadState: LoadState = .idle
    @State private var primaryInsight: SmartInsight?
    @State private var onThisDay: OnThisDayContent?
    @State private var showOnThisDay: Bool = false
    @Namespace private var heroNamespace
    @Environment(\.orbitTheme) private var orbitTheme

    private var themeAccent: Color { orbitTheme.primary }

    private enum LoadState: Equatable { case idle, loading, loaded, failed(String) }

    public init(
        listMemories: ListMemoriesUseCase,
        generateInsights: GenerateInsightsUseCase,
        listOnThisDay: ListOnThisDayUseCase,
        refreshToken: Int = 0,
        clock: any OrbitClock = SystemClock(),
        makeDetailViewModel: @escaping @MainActor (UUID) -> MemoryDetailViewModel,
        onPresentRecap: @escaping @MainActor () -> Void,
        onPresentPatterns: @escaping @MainActor () -> Void,
        onPresentAskOrbit: @escaping @MainActor () -> Void,
        onPresentLetter: @escaping @MainActor () -> Void
    ) {
        self.listMemories = listMemories
        self.generateInsights = generateInsights
        self.listOnThisDay = listOnThisDay
        self.refreshToken = refreshToken
        self.clock = clock
        self.makeDetailViewModel = makeDetailViewModel
        self.onPresentRecap = onPresentRecap
        self.onPresentPatterns = onPresentPatterns
        self.onPresentAskOrbit = onPresentAskOrbit
        self.onPresentLetter = onPresentLetter
    }

    public var body: some View {
        OrbitScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: OrbitSpacing.xxl) {
                    greeting
                    VStack(spacing: OrbitSpacing.sm) {
                        askOrbitPill
                        letterPill
                    }
                    content
                    Spacer(minLength: 96)
                }
                .padding(.top, OrbitSpacing.lg)
            }
            .scrollIndicators(.hidden)
            .refreshable { await reload() }
        }
        .navigationDestination(for: MemoryDetailRoute.self) { route in
            MemoryDetailView(
                viewModel: makeDetailViewModel(route.memoryID),
                onDeleted: {}
            )
            .navigationTransition(.zoom(sourceID: route.memoryID, in: heroNamespace))
        }
        .sheet(isPresented: $showOnThisDay) {
            if let onThisDay {
                OnThisDayView(
                    content: onThisDay,
                    makeDetailViewModel: makeDetailViewModel,
                    onDismiss: { showOnThisDay = false }
                )
                .presentationDetents([.large])
            }
        }
        .task(id: refreshToken) { await reload() }
    }

    // MARK: - Greeting

    private var greeting: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
            Text(timeOfDayLabel)
                .font(OrbitTypography.footnote)
                .foregroundStyle(OrbitColor.textSecondary)
            Text(headline)
                .font(OrbitTypography.largeTitle)
                .foregroundStyle(OrbitColor.textPrimary)
        }
    }

    private var timeOfDayLabel: String {
        let hour = Calendar.current.component(.hour, from: clock.now())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default:      return "Hello"
        }
    }

    private var headline: String {
        memories.isEmpty
            ? "Your second brain"
            : "\(memories.count) \(memories.count == 1 ? "memory" : "memories"), all in one place"
    }

    // MARK: - Content switch

    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .idle:
            emptyState
        case .loading, .loaded:
            if memories.isEmpty {
                emptyState
            } else {
                loadedContent
            }
        case .failed(let message):
            errorState(message)
        }
    }

    // MARK: - Letter pill

    /// Discrete entry point to the Letter-to-Future-Me capture flow. Sits
    /// just below Ask Orbit because both are "compose a thought" surfaces;
    /// quieter visual treatment so it doesn't compete for tap weight.
    private var letterPill: some View {
        Button {
            Haptics.play(.tap)
            onPresentLetter()
        } label: {
            HStack(spacing: OrbitSpacing.sm) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(OrbitColor.textSecondary)
                Text("Write a letter to future you")
                    .font(OrbitTypography.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(OrbitColor.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(OrbitColor.textTertiary)
            }
            .padding(.horizontal, OrbitSpacing.md)
            .padding(.vertical, OrbitSpacing.xs)
            .background(OrbitColor.surfaceMuted, in: .capsule)
            .overlay(
                Capsule()
                    .stroke(OrbitColor.separator, lineWidth: 0.5)
            )
        }
        .buttonStyle(OrbitBloomButtonStyle(tint: themeAccent))
        .accessibilityLabel("Write a letter to future you")
        .accessibilityHint("Open a private letter you'll receive on a date you choose.")
    }

    // MARK: - Ask Orbit pill

    /// Persistent entry point to chat with your memories. Sits above the
    /// Today section so it's the first interactive surface after the
    /// greeting — premium product, premium discovery.
    private var askOrbitPill: some View {
        Button {
            Haptics.play(.tap)
            onPresentAskOrbit()
        } label: {
            HStack(spacing: OrbitSpacing.sm) {
                Image(systemName: "sparkle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(themeAccent)
                Text("Ask Orbit anything")
                    .font(OrbitTypography.body)
                    .foregroundStyle(OrbitColor.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(OrbitColor.textTertiary)
            }
            .padding(.horizontal, OrbitSpacing.md)
            .padding(.vertical, OrbitSpacing.sm)
            .background(themeAccent.opacity(0.10), in: .capsule)
            .overlay(
                Capsule()
                    .stroke(themeAccent.opacity(0.18), lineWidth: 0.5)
            )
        }
        .buttonStyle(OrbitBloomButtonStyle(tint: themeAccent))
        .accessibilityLabel("Ask Orbit anything")
        .accessibilityHint("Opens a conversation with your memories.")
    }

    private var loadedContent: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.xxl) {
            todaySection
            if let onThisDay, !onThisDay.isEmpty {
                onThisDayCard(onThisDay)
            }
            if shouldShowRecapInvite {
                recapCard
            }
            if let primaryInsight {
                insightCard(primaryInsight)
            }
            recentSection
        }
    }

    // MARK: - On This Day

    /// Editorial nostalgia card. Shows the years-ago count in serif as the
    /// hero, with a snippet from the oldest matching memory. Tap opens the
    /// chronological sheet across every past year that has a memory.
    private func onThisDayCard(_ content: OnThisDayContent) -> some View {
        let themeColor = themeAccent
        let yearsAgo = content.yearsAgoForFeatured() ?? 0
        let featured = content.featured
        return Button {
            Haptics.play(.tap)
            showOnThisDay = true
        } label: {
            OrbitCard(elevation: .resting) {
                VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                    OrbitEyebrow(
                        label: "On This Day",
                        suffix: content.today.formatted(.dateTime.month(.abbreviated).day()),
                        tint: themeColor
                    )
                    Text(yearsAgo == 1 ? "1 year ago today" : "\(yearsAgo) years ago today")
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .foregroundStyle(OrbitColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let featured {
                        Text(headlineText(for: featured))
                            .font(OrbitTypography.callout)
                            .foregroundStyle(OrbitColor.textSecondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: 6) {
                        Text(subtitle(for: content))
                            .font(OrbitTypography.footnote)
                            .foregroundStyle(OrbitColor.textTertiary)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(OrbitColor.textTertiary)
                    }
                    .padding(.top, OrbitSpacing.xxs)
                }
            }
        }
        .buttonStyle(OrbitBloomButtonStyle(tint: themeAccent))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("On This Day. \(yearsAgo) years ago today. \(featured.map { headlineText(for: $0) } ?? "").")
        .accessibilityHint("Double-tap to revisit past years on this date.")
    }

    private func subtitle(for content: OnThisDayContent) -> String {
        let count = content.totalCount
        let years = content.memoriesByYear.count
        let memoryWord = count == 1 ? "memory" : "memories"
        let yearWord = years == 1 ? "year" : "years"
        return "\(count) \(memoryWord) across \(years) \(yearWord)"
    }

    /// Single rotating insight surface on Home. We deliberately show one at a
    /// time so the surface stays calm; the full set lives in the Patterns
    /// sheet, presented when the user taps through.
    private func insightCard(_ insight: SmartInsight) -> some View {
        let themeColor = themeAccent
        return Button {
            Haptics.play(.tap)
            onPresentPatterns()
        } label: {
            OrbitCard(elevation: .resting) {
                VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                    OrbitEyebrow(
                        label: insight.kind.label,
                        suffix: "patterns",
                        tint: themeColor
                    )
                    HStack(alignment: .firstTextBaseline, spacing: OrbitSpacing.xs) {
                        Text(insight.headline)
                            .font(.system(size: 22, weight: .semibold, design: .serif))
                            .foregroundStyle(OrbitColor.textPrimary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(OrbitColor.textTertiary)
                    }
                    Text(insight.body)
                        .font(OrbitTypography.callout)
                        .foregroundStyle(OrbitColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .buttonStyle(OrbitBloomButtonStyle(tint: themeAccent))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(insight.kind.label). \(insight.headline). \(insight.body)")
        .accessibilityHint("Double-tap to open patterns.")
    }

    /// We only invite the user into the recap experience once the day has
    /// produced something worth reflecting on. Below the threshold a single
    /// memory feels lonely as a 'day in review.'
    private var shouldShowRecapInvite: Bool {
        memoriesFromToday.count >= 2
    }

    private var recapCard: some View {
        // Reading the theme inside the computed property keeps the
        // recap eyebrow + bloom in sync with the user's chosen accent.
        let themeColor = themeAccent
        return Button {
            Haptics.play(.tap)
            onPresentRecap()
        } label: {
            OrbitCard(elevation: .lifted) {
                VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                    OrbitEyebrow(
                        label: "Daily Recap",
                        suffix: "today",
                        tint: themeColor
                    )
                    Text("See your day reflected back")
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .foregroundStyle(OrbitColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Orbit reads your captures and writes a calm, two-sentence summary of the day.")
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Text("Open recap")
                            .font(OrbitTypography.bodyEmphasized)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(OrbitColor.textPrimary)
                    .padding(.top, OrbitSpacing.xxs)
                }
            }
        }
        .buttonStyle(OrbitBloomButtonStyle(tint: themeAccent))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Daily Recap. See your day reflected back.")
        .accessibilityHint("Double-tap to open today's recap.")
    }

    // MARK: - Today

    private var todaySection: some View {
        let todays = memoriesFromToday
        return VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader(
                "Today",
                subtitle: todays.isEmpty
                    ? "Nothing captured yet today"
                    : "\(todays.count) \(todays.count == 1 ? "capture" : "captures")"
            )

            if todays.isEmpty {
                OrbitCard {
                    VStack(alignment: .leading, spacing: OrbitSpacing.xs) {
                        Text("A blank canvas")
                            .font(OrbitTypography.bodyEmphasized)
                            .foregroundStyle(OrbitColor.textPrimary)
                        Text("Capture something the moment it crosses your mind. Orbit handles the rest.")
                            .font(OrbitTypography.callout)
                            .foregroundStyle(OrbitColor.textSecondary)
                    }
                }
            } else {
                OrbitCard {
                    todaySummary(todays)
                }
            }
        }
    }

    private func todaySummary(_ todays: [Memory]) -> some View {
        let kinds = Dictionary(grouping: todays) { $0.content.kind }
        let categories = todays.compactMap(\.ai.category).filter { !$0.isEmpty }
        return VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
            HStack(spacing: OrbitSpacing.xs) {
                ForEach(MemoryContentKind.allCases, id: \.self) { kind in
                    if let count = kinds[kind]?.count, count > 0 {
                        OrbitChip("\(count) \(label(for: kind))", systemImage: icon(for: kind))
                    }
                }
            }
            if !categories.isEmpty {
                Divider().background(OrbitColor.separator)
                HStack(spacing: OrbitSpacing.xs) {
                    ForEach(Array(Set(categories)).sorted(), id: \.self) { category in
                        OrbitChip(category, style: .accent)
                    }
                }
            }
        }
    }

    // MARK: - Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Recent")
                .accessibilityAddTraits(.isHeader)
            ForEach(memories.prefix(3)) { memory in
                NavigationLink(value: MemoryDetailRoute(memoryID: memory.id)) {
                    OrbitCard(elevation: .resting) {
                        VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                            OrbitEyebrow(
                                label: eyebrowLabel(for: memory),
                                suffix: memory.createdAt.formatted(.relative(presentation: .named)),
                                tint: OrbitCategoryPalette.tint(for: memory.ai.category)
                            )
                            HStack(alignment: .top, spacing: OrbitSpacing.sm) {
                                Image(systemName: icon(for: memory.content.kind))
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(OrbitColor.textTertiary)
                                    .padding(.top, 3)
                                    .accessibilityHidden(true)
                                Text(headlineText(for: memory))
                                    .font(OrbitTypography.body)
                                    .foregroundStyle(OrbitColor.textPrimary)
                                    .lineLimit(3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .buttonStyle(OrbitBloomButtonStyle(
                    tint: OrbitCategoryPalette.tint(for: memory.ai.category)
                ))
                .matchedTransitionSource(id: memory.id, in: heroNamespace)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(eyebrowLabel(for: memory)). \(headlineText(for: memory)). \(memory.createdAt.formatted(.relative(presentation: .named)))")
                .accessibilityHint("Double-tap to open.")
            }
        }
    }

    private func eyebrowLabel(for memory: Memory) -> String {
        if let category = memory.ai.category?.trimmingCharacters(in: .whitespacesAndNewlines),
           !category.isEmpty {
            return category
        }
        return label(for: memory.content.kind)
    }

    // MARK: - Empty / error

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            Text("A calm place to land")
                .font(OrbitTypography.title2)
                .foregroundStyle(OrbitColor.textPrimary)
            Text("Tap the circle below to add your first thought. Orbit organizes the rest — quietly.")
                .font(OrbitTypography.body)
                .foregroundStyle(OrbitColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: OrbitSpacing.xs) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 14, weight: .semibold))
                Text("Capture")
                    .font(OrbitTypography.caption)
            }
            .foregroundStyle(OrbitColor.textTertiary)
            .padding(.top, OrbitSpacing.sm)
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
            Text("Couldn't load home")
                .font(OrbitTypography.title3)
            Text(message)
                .font(OrbitTypography.footnote)
                .foregroundStyle(OrbitColor.textSecondary)
        }
    }

    // MARK: - Helpers

    private var memoriesFromToday: [Memory] {
        let calendar = Calendar.current
        let today = clock.now()
        return memories.filter { calendar.isDate($0.createdAt, inSameDayAs: today) }
    }

    private func headlineText(for memory: Memory) -> String {
        if let summary = memory.ai.summary, !summary.isEmpty { return summary }
        switch memory.content {
        case .text(let s):                                   return s
        case .voiceNote(let transcript, _):                  return transcript ?? "Voice note"
        case .image(let caption):                            return caption ?? "Photo"
        case .link(_, let title, let summary):               return summary ?? title ?? "Link"
        case .screenshot(let ocr):                           return ocr ?? "Screenshot"
        case .location(let name, _, _):                      return name ?? "Location"
        }
    }

    private func label(for kind: MemoryContentKind) -> String {
        switch kind {
        case .text:        return "note"
        case .voiceNote:   return "voice"
        case .image:       return "photo"
        case .link:        return "link"
        case .screenshot:  return "screenshot"
        case .location:    return "place"
        }
    }

    private func icon(for kind: MemoryContentKind) -> String {
        switch kind {
        case .text:        return "text.alignleft"
        case .voiceNote:   return "waveform"
        case .image:       return "photo"
        case .link:        return "link"
        case .screenshot:  return "rectangle.on.rectangle"
        case .location:    return "mappin"
        }
    }

    private func reload() async {
        loadState = .loading
        do {
            memories = try await listMemories()
            loadState = .loaded
        } catch {
            loadState = .failed(String(describing: error))
        }
        // Insights + On This Day run in parallel with the list; failures
        // are silent because their absence is the natural fallback.
        await reloadInsights()
        await reloadOnThisDay()
    }

    private func reloadOnThisDay() async {
        onThisDay = try? await listOnThisDay()
    }

    private func reloadInsights() async {
        do {
            let all = try await generateInsights()
            primaryInsight = preferred(from: all)
        } catch {
            primaryInsight = nil
        }
    }

    /// Picks the highest-priority insight to surface on Home. Order is
    /// deliberate: an entity feels more personal than a category, which
    /// feels more personal than a pace number.
    private func preferred(from insights: [SmartInsight]) -> SmartInsight? {
        let priority: [SmartInsight.Kind] = [.topEntity, .trendingCategory, .weeklyVolume, .dayOfWeek]
        for kind in priority {
            if let match = insights.first(where: { $0.kind == kind }) {
                return match
            }
        }
        return insights.first
    }
}

// Preview removed — HomeView now requires a MemoryDetailViewModel factory
// which depends on MediaStorage, which would pull OrbitMedia into the
// Home feature package just for the preview. Reinstate when we have a
// TestSupport package that vends an ephemeral environment.
