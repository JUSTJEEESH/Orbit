import Foundation

/// Tracks which memory IDs the user has dismissed from suggestion
/// surfaces (Home's "Worth revisiting" feed and Memory Detail's
/// "Connected memories" strip). Lets the engine filter them out of the
/// candidate pool so the user doesn't keep seeing what they explicitly
/// said no to.
///
/// Dismissals are time-bounded by the implementation — a memory the
/// user dismissed 90+ days ago is fair game to surface again, on the
/// theory that the user's interests shift over time and a permanent
/// blacklist is too punitive. Implementations decide the exact
/// duration.
public protocol SuggestionDismissalStore: Sendable {
    /// Returns true when `memoryID` was dismissed within the
    /// implementation's active-dismissal window.
    func isDismissed(_ memoryID: UUID, at date: Date) -> Bool
    /// Marks a memory as dismissed at the given timestamp. Idempotent:
    /// dismissing an already-dismissed memory just refreshes the
    /// timestamp (effectively extending the dismissal window).
    func dismiss(_ memoryID: UUID, at date: Date)
    /// Returns every memory ID currently within its dismissal window
    /// at the given date. Used by the engine to filter the candidate
    /// pool in one pass.
    func dismissedIDs(at date: Date) -> Set<UUID>
    /// Clears every dismissal. Called from the account-wipe flow so a
    /// re-onboarded user starts with a clean slate.
    func clearAll()
}
