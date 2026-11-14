import Testing

/// Parent suite for every test that opens a real SwiftData store.
///
/// The migration and rescue tests create containers with the frozen
/// `OrbitSchemaV1` models while other tests use the live models, which share
/// entity names. Apple's versioned-schema pattern relies on that, but
/// SwiftData's model registry isn't safe to exercise from parallel tests, so
/// `.serialized` here (inherited by every nested suite) runs them one at a
/// time.
@Suite(.serialized)
enum StoreBackedTests {}
