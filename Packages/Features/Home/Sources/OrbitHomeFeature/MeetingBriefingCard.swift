import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit

/// What Home needs for the "Before you meet" card.
public struct HomeMeetingBriefing {
    public let briefing: MeetingBriefing
    public let onOpen: @MainActor () -> Void

    public init(briefing: MeetingBriefing, onOpen: @escaping @MainActor () -> Void) {
        self.briefing = briefing
        self.onOpen = onOpen
    }
}

/// A quiet card in the hours before a meeting with someone you've noted:
/// who, when, and a one-line summary. Tapping opens the full briefing.
struct MeetingBriefingCard: View {
    let model: HomeMeetingBriefing
    let accent: Color

    private var briefing: MeetingBriefing { model.briefing }

    var body: some View {
        Button {
            Haptics.play(.tap)
            model.onOpen()
        } label: {
            OrbitCard(elevation: .lifted) {
                HStack(alignment: .center, spacing: OrbitSpacing.md) {
                    VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
                        Text(eyebrow)
                            .font(OrbitTypography.footnote)
                            .foregroundStyle(accent)
                        Text(briefing.title)
                            .font(OrbitTypography.title3)
                            .foregroundStyle(OrbitColor.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text(briefing.summary)
                            .font(OrbitTypography.callout)
                            .foregroundStyle(OrbitColor.textSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textTertiary)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(OrbitBloomButtonStyle(tint: accent))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens your briefing.")
    }

    /// "Before you meet · 12:30 PM", or "Before you meet · Today".
    private var eyebrow: String {
        let when = briefing.event.isAllDay
            ? "Today"
            : briefing.event.start.formatted(date: .omitted, time: .shortened)
        return "Before you meet \u{00B7} \(when)"
    }
}

#Preview("Before you meet") {
    MeetingBriefingCard(
        model: HomeMeetingBriefing(
            briefing: MeetingBriefing(
                event: CalendarEventSummary(id: "lunch", title: "Lunch with Alex", start: Date().addingTimeInterval(5_400), attendeeNames: []),
                people: [PersonBrief(
                    name: "Alex", key: "alex", lastContact: nil,
                    openPromises: [MemoryTask(title: "Send the photos", createdAt: Date(), promisedTo: "Alex")],
                    toBringUp: [], giftIdeas: [], recentMoments: []
                )]
            ),
            onOpen: {}
        ),
        accent: .blue
    )
    .padding()
}
