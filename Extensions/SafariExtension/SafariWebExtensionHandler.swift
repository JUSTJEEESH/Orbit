import Foundation
import SafariServices
import os

/// Native bridge for the Orbit Safari Web Extension.
///
/// The JS side (`background.js`) sends a single message shape:
///
///     { kind: "clip", url, title, selection?, capturedAt }
///
/// We write that shape verbatim — minus the trailing keys — to a JSON
/// envelope in the App Group's `Inbox/` directory. The host app picks it
/// up on next foreground via `CaptureInboxService` and turns it into a
/// `.link` (or `.text` if a selection was sent without a URL) memory,
/// which then flows through the normal enrichment pipeline.
final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    private static let appGroupIdentifier = "group.com.orbit.app"
    private static let logger = Logger(subsystem: "com.orbit.app.safari", category: "extension")

    func beginRequest(with context: NSExtensionContext) {
        guard let item = context.inputItems.first as? NSExtensionItem,
              let message = item.userInfo?[SFExtensionMessageKey]
        else {
            context.completeRequest(returningItems: nil)
            return
        }

        let envelope = Self.normalize(message: message)

        let written = Self.writeToInbox(envelope: envelope)

        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: ["ok": written]]
        context.completeRequest(returningItems: [response])
    }

    // MARK: - Inbox

    /// Coerces whatever shape the JS sent into a strict, host-friendly
    /// envelope. Anything we don't recognize is dropped — the host should
    /// never have to validate user-controlled fields.
    private static func normalize(message: Any) -> [String: Any] {
        guard let dict = message as? [String: Any] else {
            return ["kind": "text", "selection": String(describing: message)]
        }
        var out: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "source": "safari"
        ]
        if let url = dict["url"] as? String, !url.isEmpty {
            out["kind"] = "link"
            out["url"] = url
            if let title = dict["title"] as? String { out["title"] = title }
            if let selection = dict["selection"] as? String, !selection.isEmpty {
                out["selection"] = selection
            }
        } else if let selection = dict["selection"] as? String, !selection.isEmpty {
            out["kind"] = "text"
            out["selection"] = selection
        } else if let title = dict["title"] as? String, !title.isEmpty {
            out["kind"] = "text"
            out["selection"] = title
        } else {
            out["kind"] = "text"
            out["selection"] = ""
        }
        return out
    }

    private static func writeToInbox(envelope: [String: Any]) -> Bool {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            logger.error("Safari clip dropped: App Group container unavailable.")
            return false
        }
        let inbox = container
            .appendingPathComponent("Orbit", isDirectory: true)
            .appendingPathComponent("Inbox", isDirectory: true)
        let id = (envelope["id"] as? String) ?? UUID().uuidString
        let url = inbox.appendingPathComponent("\(id).json")

        do {
            try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            logger.error("Safari clip write failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }
}
