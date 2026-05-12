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
                                    .font(.system(size: 11, weight: .regular))
                                Text(dueLabel(due))
                                    .font(OrbitTypography.footnote)
                            }
                            .foregroundStyle(dueColor(due))
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

    private var completeButton: some View {
        Button {
            Haptics.play(.selection)
            onToggle()
        } label: {
            ZStack {
                Circle()
                    .stroke(
                        task.isCompleted ? orbitTheme.primary : OrbitColor.separator,
                        lineWidth: 1.5
                    )
                    .frame(width: 22, height: 22)
                if task.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(orbitTheme.primary)
                }
            }
            .padding(.top, 2)
        }
        .buttonStyle(.plain)
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

    private var accessibilityLabel: String {
        var parts: [String] = [task.title]
        if task.isCompleted { parts.append("Completed.") }
        if let due = task.dueDate {
            parts.append("Due \(dueLabel(due)).")
        }
        return parts.joined(separator: " ")
    }
}
