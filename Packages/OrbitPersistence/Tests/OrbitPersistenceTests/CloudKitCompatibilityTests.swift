import Foundation
import Testing
import SwiftData
@testable import OrbitPersistence

/// iCloud mirroring (NSPersistentCloudKitContainer under SwiftData) refuses
/// or silently stops syncing a schema that breaks CloudKit's rules. These
/// checks make a future model change fail in CI instead of in users' hands.
@Suite("CloudKit compatibility")
struct CloudKitCompatibilityTests {
    private let schema = Schema(versionedSchema: OrbitCurrentSchema.self)

    @Test func everyAttributeIsOptionalOrDefaulted() {
        for entity in schema.entities {
            for attribute in entity.attributes {
                #expect(
                    attribute.isOptional || attribute.defaultValue != nil,
                    "\(entity.name).\(attribute.name) needs a default value or must be optional for iCloud sync"
                )
            }
        }
    }

    @Test func noAttributeIsUnique() {
        for entity in schema.entities {
            for attribute in entity.attributes {
                #expect(
                    !attribute.options.contains(.unique),
                    "\(entity.name).\(attribute.name) is unique, which CloudKit doesn't support"
                )
            }
        }
    }

    @Test func everyRelationshipIsOptional() {
        for entity in schema.entities {
            for relationship in entity.relationships {
                #expect(
                    relationship.isOptional,
                    "\(entity.name).\(relationship.name) must be optional for iCloud sync"
                )
            }
        }
    }
}
