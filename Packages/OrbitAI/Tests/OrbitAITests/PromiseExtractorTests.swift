import Foundation
import Testing
import OrbitDomain
@testable import OrbitAI

@Suite("Promise extraction")
struct PromiseExtractorTests {
    @Test func toldSomeoneIdDoSomething() {
        let promises = PromiseExtractor.extract(from: "Great dinner. I told Sam I'd send the photos.")
        #expect(promises.count == 1)
        #expect(promises.first?.person == "Sam")
        #expect(promises.first?.item == "send the photos")
    }

    @Test func promisedARelation() {
        let promises = PromiseExtractor.extract(from: "I promised my mom to call her back tomorrow at 6pm")
        #expect(promises.first?.person == "Mom")
        #expect(promises.first?.item == "call her back")
        #expect(promises.first?.dueDate != nil)
    }

    @Test func oweSomeone() {
        #expect(PromiseExtractor.extract(from: "I owe Alex a coffee").first?.item == "a coffee")
    }

    @Test func willSendSomeone() {
        let promise = PromiseExtractor.extract(from: "I'll send Priya the slides").first
        #expect(promise?.person == "Priya")
        #expect(promise?.item == "send the slides")
    }

    @Test func ordinaryTextHasNoPromises() {
        #expect(PromiseExtractor.extract(from: "Walked by the lake. The light was beautiful.").isEmpty)
    }
}
