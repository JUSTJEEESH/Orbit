import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit
import os

/// Loads the week and presents it. Thin on purpose: the layout lives in
/// `WeeklyReviewContent` so it can be previewed without the environment.
struct WeeklyReviewView: View {
    let onDismiss: @MainActor () -> Void

    @Environment(AppEnvironment.self) private var env
    @State private var review: WeeklyReview?
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Group {
                if let review {
                    WeeklyReviewContent(review: review, onOpenMemory: open)
                } else if failed {
                    OrbitEmptyState(
                        systemImage: "calendar",
                        title: "Couldn\u{2019}t load your week",
                        message: "Your memories are fine. Try again in a moment."
                    )
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(OrbitColor.background)
            .navigationTitle("Your Week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDismiss() }
                }
            }
        }
        .task {
            do {
                review = try await env.generateWeeklyReview()
            } catch {
                OrbitLog.app.error("Weekly review failed: \(String(describing: error), privacy: .public)")
                failed = true
            }
        }
    }

    private func open(_ memoryID: UUID) {
        onDismiss()
        env.pendingMemoryLink = memoryID
    }
}

/// The week, top to bottom: what's open, who was on your mind, the best
/// moments, one memory worth revisiting. Plain sections, no scores, no
/// charts: a review to read, not a dashboard to check.
struct WeeklyReviewContent: View {
    let review: WeeklyReview
    let onOpenMemory: @MainActor (UUID) -> Void

    @Environment(\.orbitTheme) private var orbitTheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OrbitSpacing.xxl) {
                header
                if review.isEmpty {
                    OrbitEmptyState(
                        systemImage: "leaf",
                        title: "A quiet week",
                        message: "Nothing captured and nothing waiting. That\u{2019}s allowed."
                    )
                } else {
                    if !review.openPromises.isEmpty || !review.openTasks.isEmpty { openSection }
                    if !review.people.isEmpty { peopleSection }
                    if !review.bestMoments.isEmpty { momentsSection }
                    if let revisit = review.revisit { revisitSection(revisit) }
                }
            }
            .padding(.horizontal, OrbitSpacing.pageHorizontal)
            .padding(.vertical, OrbitSpacing.lg)
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
            Text(review.interval.start.formatted(.dateTime.month(.abbreviated).day())
                 + " \u{2013} "
                 + review.interval.end.formatted(.dateTime.month(.abbreviated).day()))
                .font(OrbitTypography.footnote)
                .foregroundStyle(OrbitColor.textSecondary)
            Text(review.memoryCount == 1 ? "1 memory this week" : "\(review.memoryCount) memories this week")
                .font(OrbitTypography.largeTitle)
                .foregroundStyle(OrbitColor.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Still open

    private var openSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Still open", subtitle: "Carry these into next week, or let them go")
                .accessibilityAddTraits(.isHeader)
            OrbitCard(elevation: .resting) {
                VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                    ForEach(review.openPromises + review.openTasks) { task in
                        HStack(alignment: .firstTextBaseline, spacing: OrbitSpacing.sm) {
                            Image(systemName: task.promisedTo == nil ? "circle" : "hand.raised")
                                .font(OrbitTypography.footnote)
                                .foregroundStyle(orbitTheme.primary)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                    .font(OrbitTypography.body)
                                    .foregroundStyle(OrbitColor.textPrimary)
                                if let person = task.promisedTo {
                                    Text("For \(person)")
                                        .font(OrbitTypography.footnote)
                                        .foregroundStyle(OrbitColor.textSecondary)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    // MARK: - People

    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("On your mind")
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: OrbitSpacing.xs) {
                ForEach(review.people) { person in
                    HStack {
                        Label(person.name, systemImage: "person")
                            .font(OrbitTypography.body)
                            .foregroundStyle(OrbitColor.textPrimary)
                        Spacer()
                        Text(person.memoryCount == 1 ? "1 memory" : "\(person.memoryCount) memories")
                            .font(OrbitTypography.footnote)
                            .foregroundStyle(OrbitColor.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    // MARK: - Moments

    private var momentsSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Best moments")
                .accessibilityAddTraits(.isHeader)
            ForEach(review.bestMoments) { memory in
                memoryButton(memory, eyebrow: memory.createdAt.formatted(.dateTime.weekday(.wide)))
            }
        }
    }

    private func revisitSection(_ memory: Memory) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Worth revisiting")
                .accessibilityAddTraits(.isHeader)
            memoryButton(memory, eyebrow: memory.createdAt.formatted(date: .abbreviated, time: .omitted))
        }
    }

    private func memoryButton(_ memory: Memory, eyebrow: String) -> some View {
        Button {
            Haptics.play(.tap)
            onOpenMemory(memory.id)
        } label: {
            OrbitCard(elevation: .resting) {
                VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
                    Text(eyebrow)
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

#Preview("Your week") {
    let now = Date()
    let lunch = Memory(content: .text("Lunch with Sam at the taco place. He got the new job!"),
                       createdAt: now.addingTimeInterval(-86_400), updatedAt: now)
    WeeklyReviewContent(
        review: WeeklyReview(
            interval: DateInterval(start: now.addingTimeInterval(-7 * 86_400), end: now),
            memoryCount: 12,
            openPromises: [MemoryTask(title: "Send the photos", createdAt: now, promisedTo: "Sam")],
            openTasks: [MemoryTask(title: "Fix the gate", createdAt: now)],
            people: [MentionedEntity(kind: .person, name: "Sam", key: "sam", memoryCount: 4, lastMentioned: now)],
            bestMoments: [lunch],
            revisit: nil
        ),
        onOpenMemory: { _ in }
    )
}
