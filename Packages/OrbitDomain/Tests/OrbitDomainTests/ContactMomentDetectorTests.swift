import Testing
@testable import OrbitDomain

@Suite("Contact moments")
struct ContactMomentDetectorTests {
    @Test(arguments: [
        ("Called Dad about the roof", "Dad"),
        ("had dinner with Sam and Priya", "Sam"),
        ("Caught up with my mom on the porch", "mom"),
        ("Finally FaceTimed Alex", "Alex"),
        ("met up with Jordan at the park", "Jordan"),
        ("Saw Pamela at church", "Pamela"),
    ])
    func recognizesTimeTogether(text: String, name: String) {
        #expect(ContactMomentDetector.isContact(with: name, in: text))
    }

    @Test(arguments: [
        ("Dad's birthday is in May", "Dad"),
        ("Sam recommended this book", "Sam"),
        ("Need to call Alex tomorrow", "Alex"),
        ("Samantha came over", "Sam"),
    ])
    func ignoresMereMentions(text: String, name: String) {
        #expect(!ContactMomentDetector.isContact(with: name, in: text))
    }
}
