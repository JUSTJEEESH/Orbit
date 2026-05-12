import Foundation
import Observation
import OrbitDomain

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
            state = .failed(String(describing: error))
        }
    }
}
