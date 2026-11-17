import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit

/// Finds the briefing (a notification tap may arrive before the first
/// refresh) and presents it. The layout lives in `MeetingBriefingContent`
/// so it can be previewed without the environment.
struct MeetingBriefingView: View {
    let briefingID: String
    let onDismiss: @MainActor () -> Void

    @Environment(AppEnvironment.self) private var env
    @State private var briefing: MeetingBriefing?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if let briefing {
                    MeetingBriefingContent(briefing: briefing, now: Date(), onOpenMemory: open)
                } else if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    OrbitEmptyState(
                        systemImage: "calendar",
                        title: "This briefing has passed",
                        message: "The event moved or is over. Your memories are all still here."
                    )
                }
            }
            .background(OrbitColor.background)
            .navigationTitle("Before You Meet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDismiss() }
                }
            }
        }
        .task {
            briefing = await env.meetingBriefing(id: briefingID)
            isLoading = false
        }
    }

    private func open(_ memoryID: UUID) {
        onDismiss()
        env.pendingMemoryLink = memoryID
    }
}

/// Who you're meeting and what's worth remembering, in the order it's
/// useful walking in: what you owe them, what you meant to bring up, gift
/// ideas, then what you last noted. Plain sections; nothing generated, so
/// nothing invented.
struct MeetingBriefingContent: View {
    let briefing: MeetingBriefing
    let now: Date
    let onOpenMemory: @MainActor (UUID) -> Void

    @Environment(\.orbitTheme) private var orbitTheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OrbitSpacing.xxl) {
                header
                ForEach(briefing.people) { person in
                    personSection(person)
                }
            }
            .padding(.horizontal, OrbitSpacing.pageHorizontal)
            .padding(.vertical, OrbitSpacing.lg)
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
            Text(whenLabel)
                .font(OrbitTypography.footnote)
                .foregroundStyle(OrbitColor.textSecondary)
            Text(briefing.title)
                .font(OrbitTypography.largeTitle)
                .foregroundStyle(OrbitColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// "Today at 12:30 PM", "Friday at 9:00 AM", or just the day for an
    /// all-day event.
    private var whenLabel: String {
        let start = briefing.event.start
        let day = Calendar.current.isDateInToday(start) ? "Today" : start.formatted(.dateTime.weekday(.wide))
        guard !briefing.event.isAllDay else { return day }
        return "\(day) at \(start.formatted(date: .omitted, time: .shortened))"
    }

    // MARK: - Person

    private func personSection(_ person: PersonBrief) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.lg) {
            if briefing.people.count > 1 || person.lastContact != nil {
                VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
                    if briefing.people.count > 1 {
                        Text(person.name)
                            .font(OrbitTypography.title2)
                            .foregroundStyle(OrbitColor.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                    }
                    if let lastContact = person.lastContact {
                        Label(
                            "Last in touch \(TimeSince.phrase(from: lastContact, to: now))",
                            systemImage: "clock"
                        )
                        .font(OrbitTypography.callout)
                        .foregroundStyle(OrbitColor.textSecondary)
                    }
                }
            }
            if !person.openPromises.isEmpty {
                taskGroup("You promised", systemImage: "hand.raised", tasks: person.openPromises)
            }
            if !person.toBringUp.isEmpty {
                taskGroup("To bring up", systemImage: "text.bubble", tasks: person.toBringUp)
            }
            if !person.giftIdeas.isEmpty {
                memoryGroup("Gift ideas", memories: person.giftIdeas)
            }
            if !person.recentMoments.isEmpty {
                memoryGroup("What you noted", memories: person.recentMoments)
            }
        }
    }

    private func taskGroup(_ title: String, systemImage: String, tasks: [MemoryTask]) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader(title)
                .accessibilityAddTraits(.isHeader)
            OrbitCard(elevation: .resting) {
                VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                    ForEach(tasks) { task in
                        HStack(alignment: .firstTextBaseline, spacing: OrbitSpacing.sm) {
                            Image(systemName: systemImage)
                                .font(OrbitTypography.footnote)
                                .foregroundStyle(orbitTheme.primary)
                                .accessibilityHidden(true)
                            Text(task.title)
                                .font(OrbitTypography.body)
                                .foregroundStyle(OrbitColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private func memoryGroup(_ title: String, memories: [Memory]) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader(title)
                .accessibilityAddTraits(.isHeader)
            ForEach(memories) { memory in
                Button {
                    Haptics.play(.tap)
                    onOpenMemory(memory.id)
                } label: {
                    OrbitCard(elevation: .resting) {
                        VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
                            Text(TimeSince.phrase(from: memory.createdAt, to: now).capitalizingFirstLetter)
                                .font(OrbitTypography.caption)
                                .foregroundStyle(OrbitColor.textSecondary)
                            Text(ResurfacingPicker.previewText(for: memory))
                                .font(OrbitTypography.body)
                                .foregroundStyle(OrbitColor.textPrimary)
                                .lineLimit(4)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .buttonStyle(OrbitBloomButtonStyle(tint: orbitTheme.primary))
                .accessibilityHint("Opens this memory.")
            }
        }
    }
}

private extension String {
    var capitalizingFirstLetter: String {
        prefix(1).uppercased() + dropFirst()
    }
}

#Preview("Before you meet") {
    let now = Date()
    let kids = Memory(content: .text("Alex's kids are Mia (7) and Leo (4). Mia just started piano."),
                      createdAt: now.addingTimeInterval(-12 * 86_400), updatedAt: now)
    let gift = Memory(content: .text("Alex would love the new Murakami book"),
                      createdAt: now.addingTimeInterval(-30 * 86_400), updatedAt: now)
    MeetingBriefingContent(
        briefing: MeetingBriefing(
            event: CalendarEventSummary(id: "lunch", title: "Lunch with Alex", start: now.addingTimeInterval(1_800), attendeeNames: []),
            people: [PersonBrief(
                name: "Alex",
                key: "alex",
                lastContact: now.addingTimeInterval(-9 * 86_400),
                openPromises: [MemoryTask(title: "Send Alex the trip photos", createdAt: now, promisedTo: "Alex")],
                toBringUp: [MemoryTask(title: "Ask how the move went", createdAt: now, cue: .person("Alex"))],
                giftIdeas: [gift],
                recentMoments: [kids]
            )]
        ),
        now: now,
        onOpenMemory: { _ in }
    )
}
