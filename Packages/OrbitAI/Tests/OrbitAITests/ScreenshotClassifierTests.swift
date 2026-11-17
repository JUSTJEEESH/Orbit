import Foundation
import Testing
@testable import OrbitAI

@Suite("Screenshot classifier")
struct ScreenshotClassifierTests {
    private let now = Date(timeIntervalSince1970: 1_790_000_000) // Sep 2026

    @Test func ticketWithFutureDateIsAnEvent() {
        let text = "Boarding Pass\nFlight AA 123\nDecember 3, 2026 9:40 AM\nGate B12"
        guard case .event(let date) = ScreenshotClassifier().classify(text, now: now).kind else {
            Issue.record("Expected an event")
            return
        }
        #expect(date > now)
    }

    @Test func receiptIsDetected() {
        let text = "Corner Cafe\nLatte 4.50\nSubtotal 4.50\nTotal 4.95"
        #expect(ScreenshotClassifier().classify(text, now: now).kind == .receipt)
    }

    @Test func recipeIsDetected() {
        let text = "Banana bread\nIngredients\n2 cups flour\n1 tsp baking soda\nPreheat oven to 350"
        let suggestion = ScreenshotClassifier().classify(text, now: now)
        #expect(suggestion.kind == .recipe)
        #expect(suggestion.title == "Banana bread")
    }

    @Test func otherTextIsANote() {
        #expect(ScreenshotClassifier().classify("Remember: the wifi password is in the drawer", now: now).kind == .note)
    }
}
