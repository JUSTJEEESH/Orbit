import Foundation
import Observation
import OrbitDomain
import OrbitKit

@MainActor
@Observable
public final class YearInReviewViewModel {
    public enum State: Equatable {
        case loading
        case loaded(YearInReview)
        case empty(year: Int)
        case failed(String)
    }

    public private(set) var state: State = .loading

    private let generate: GenerateYearInReviewUseCase
    private let yearOverride: Int?

    public init(generate: GenerateYearInReviewUseCase, year: Int? = nil) {
        self.generate = generate
        self.yearOverride = year
    }

    public func load() async {
        state = .loading
        do {
            let review = try await generate(for: yearOverride)
            if review.isEmpty {
                state = .empty(year: review.year)
            } else {
                state = .loaded(review)
            }
        } catch {
            OrbitLog.app.error("Year in Review load failed: \(String(describing: error), privacy: .public)")
            state = .failed("Couldn't load your year in review. Try again in a moment.")
        }
    }
}
