import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit

/// Single row in the open / completed lists. Tap the circle to toggle, tap
/// the body to open the edit sheet. Linked-memory snippet hangs below the
/// title in `textTertiary` so it reads as origin context, not the task
/// content itself.
struct TaskRowView: View {
    let task: MemoryTask
    let linkedMemory: Memory?
    let onToggle: @MainActor () -> Void
    let onTap: @MainActor () -> Void

    @Environment(\.orbitTheme) private var orbitTheme

    var body: some View {
        Button(action: onTap) {
            OrbitCard(elevation: .resting) {
                HStack(alignment: .top, spacing: OrbitSpacing.md) {
                    completeButton
                    VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
                        Text(task.title)
                            .font(OrbitTypography.body)
                            .foregroundStyle(task.isCompleted
                                             ? OrbitColor.textTertiary
                                             : OrbitColor.textPrimary)
                            .strikethrough(task.isCompleted, color: OrbitColor.textTertiary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let due = task.dueDate {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .scaledFont(size: 11, weight: .regular)
                                Text(dueLabel(due))
                                    .font(OrbitTypography.footnote)
                            }
                            .foregroundStyle(dueColor(due))
                        }

                        if let person = task.promisedTo {
                            Label("For \(person)", systemImage: "person.fill")
                                .font(OrbitTypography.footnote)
                                .foregroundStyle(orbitTheme.primary)
                        }

                        if let cueLabel {
                            Label(cueLabel.text, systemImage: cueLabel.symbol)
                                .font(OrbitTypography.footnote)
                                .foregroundStyle(orbitTheme.primary)
                        }

                        if let memory = linkedMemory {
                            Text("From: \(memorySnippet(memory))")
                                .font(OrbitTypography.caption)
                                .foregroundStyle(OrbitColor.textTertiary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .buttonStyle(OrbitBloomButtonStyle(tint: orbitTheme.primary))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAction(named: task.isCompleted ? "Mark incomplete" : "Mark complete", onToggle)
    }

    @ScaledMetric(relativeTo: .body) private var checkboxDiameter: CGFloat = 22
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The ring "pops" when a task is completed — one small, satisfying
    /// moment (Things 3, Tiimo) rather than a silent state flip.
    private var completeButton: some View {
        Button {
            onToggle()
        } label: {
            ZStack {
                Circle()
                    .stroke(
                        task.isCompleted ? orbitTheme.primary : OrbitColor.separator,
                        lineWidth: 1.5
                    )
                    .frame(width: checkboxDiameter, height: checkboxDiameter)
                    .keyframeAnimator(initialValue: 1.0, trigger: task.isCompleted) { ring, scale in
                        ring.scaleEffect(scale)
                    } keyframes: { _ in
                        // Pops only when completing, and never with Reduce Motion.
                        SpringKeyframe(task.isCompleted && !reduceMotion ? 1.18 : 1.0, duration: 0.14)
                        SpringKeyframe(1.0, duration: 0.28)
                    }
                if task.isCompleted {
                    Image(systemName: "checkmark")
                        .scaledFont(size: 11, weight: .bold)
                        .foregroundStyle(orbitTheme.primary)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(OrbitMotion.respectfully(OrbitMotion.snap, reduceMotion: reduceMotion), value: task.isCompleted)
            .padding(.top, 2)
            // The ring stays small; the tap target meets the 44-pt minimum.
            .frame(minWidth: OrbitHitTarget.minimum, minHeight: OrbitHitTarget.minimum, alignment: .top)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(trigger: task.isCompleted) { _, completed in
            completed ? .success : .selection
        }
        .accessibilityLabel(task.isCompleted ? "Mark incomplete" : "Mark complete")
    }

    private func dueLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date)      { return "Today" }
        if calendar.isDateInTomorrow(date)   { return "Tomorrow" }
        if calendar.isDateInYesterday(date)  { return "Yesterday (overdue)" }
        if date < Date()                     { return "\(date.formatted(date: .abbreviated, time: .omitted)) (overdue)" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func dueColor(_ date: Date) -> Color {
        if task.isCompleted { return OrbitColor.textTertiary }
        if date < Date() { return OrbitColor.warning }
        if Calendar.current.isDateInToday(date) { return OrbitColor.warning }
        return OrbitColor.textSecondary
    }

    private func memorySnippet(_ memory: Memory) -> String {
        if let summary = memory.ai.summary, !summary.isEmpty {
            return summary
        }
        switch memory.content {
        case .text(let s):                          return s
        case .voiceNote(let t, _):                  return t ?? "Voice note"
        case .image(let caption):                   return caption ?? "Photo"
        case .link(_, let title, let summary):      return summary ?? title ?? "Link"
        case .screenshot(let ocr):                  return ocr ?? "Screenshot"
        case .location(let name, _, _):             return name ?? "Place"
        }
    }

    /// "At Mom's" / "With Alex" for place and person reminders.
    private var cueLabel: (text: String, symbol: String)? {
        switch task.cue {
        case .place(let place): return ("At \(place.name)", "mappin.and.ellipse")
        case .person(let name): return ("With \(name)", "person.2")
        case nil:               return nil
        }
    }

    private var accessibilityLabel: String {
        var parts: [String] = [task.title]
        if let person = task.promisedTo { parts.append("Promised to \(person).") }
        if let cueLabel { parts.append("\(cueLabel.text).") }
        if task.isCompleted { parts.append("Completed.") }
        if let due = task.dueDate {
            parts.append("Due \(dueLabel(due)).")
        }
        return parts.joined(separator: " ")
    }
}
