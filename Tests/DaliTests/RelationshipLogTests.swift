import Dali
import Fluent
import TestUtilities
import Testing
import Vapor

@Suite("RelationshipLog model", .serialized)
struct RelationshipLogTests {
    @Test("Create a new relationship log with required fields")
    func createRelationshipLog() async throws {
        try await TestUtilities.withApp { app, database in
            // Create test person
            let uniqueEmail = TestUtilities.randomUID(prefix: "test.relationshiplog") + "@example.com"
            let person = Person(name: "Test Attorney", email: uniqueEmail)
            try await person.create(on: app.db)

            // Create test jurisdiction
            let uniqueCode = TestUtilities.randomCode(prefix: "TS")
            let uniqueName = TestUtilities.randomUID(prefix: "TestState")
            let jurisdiction = LegalJurisdiction(name: uniqueName, code: uniqueCode)
            try await jurisdiction.create(on: app.db)

            // Create test credential
            let uniqueLicenseNumber = TestUtilities.randomCode(prefix: "TEST")
            let credential = Credential(
                personID: person.id!,
                jurisdictionID: jurisdiction.id!,
                licenseNumber: uniqueLicenseNumber
            )
            try await credential.create(on: app.db)

            // Create test project
            let project = Project(codename: "PROJECT-RELATIONSHIPLOG-TEST")
            try await project.create(on: app.db)

            // Create relationship log
            let relationshipLog = RelationshipLog(
                projectID: project.id!,
                credentialID: credential.id!,
                body: "Test relationship log body content",
                relationships: RelationshipsData()
            )
            try await relationshipLog.create(on: app.db)

            // Verify relationship log was created
            #expect(relationshipLog.id != nil)
            #expect(relationshipLog.body == "Test relationship log body content")
            #expect(relationshipLog.relationships.rawValue.isEmpty)
            #expect(relationshipLog.createdAt != nil)
            #expect(relationshipLog.updatedAt != nil)
        }
    }

    @Test("Create relationship log with relationships data")
    func createRelationshipLogWithRelationships() async throws {
        try await TestUtilities.withApp { app, database in
            // Create test data
            let uniqueEmail = TestUtilities.randomUID(prefix: "test.relationshiplog.rel") + "@example.com"
            let person = Person(name: "Test Attorney", email: uniqueEmail)
            try await person.create(on: app.db)

            let uniqueCode = TestUtilities.randomCode(prefix: "TS")
            let uniqueName = TestUtilities.randomUID(prefix: "TestState")
            let jurisdiction = LegalJurisdiction(name: uniqueName, code: uniqueCode)
            try await jurisdiction.create(on: app.db)

            let uniqueLicenseNumber = TestUtilities.randomCode(prefix: "TEST")
            let credential = Credential(
                personID: person.id!,
                jurisdictionID: jurisdiction.id!,
                licenseNumber: uniqueLicenseNumber
            )
            try await credential.create(on: app.db)

            let project = Project(codename: "PROJECT-RELATIONSHIPLOG-REL-TEST")
            try await project.create(on: app.db)

            // Create relationship log with relationships data
            let relationshipsData: [String: Any] = [
                "entities": ["Entity1", "Entity2"],
                "people": ["Person1", "Person2"],
                "metadata": [
                    "category": "legal",
                    "priority": "high",
                ],
            ]
            let relationshipLog = RelationshipLog(
                projectID: project.id!,
                credentialID: credential.id!,
                body: "Complex relationship log with metadata",
                relationships: RelationshipsData(rawValue: relationshipsData)
            )
            try await relationshipLog.create(on: app.db)

            // Verify relationship log was created with relationships
            #expect(relationshipLog.id != nil)
            #expect(relationshipLog.body == "Complex relationship log with metadata")
            #expect(!relationshipLog.relationships.rawValue.isEmpty)
            #expect(relationshipLog.relationships.rawValue["entities"] != nil)
            #expect(relationshipLog.relationships.rawValue["people"] != nil)
            #expect(relationshipLog.relationships.rawValue["metadata"] != nil)
        }
    }

    @Test("Load relationship log with relationships")
    func loadRelationshipLogWithRelationships() async throws {
        try await TestUtilities.withApp { app, database in
            // Create test data
            let uniqueEmail = TestUtilities.randomUID(prefix: "test.relationshiplog.load") + "@example.com"
            let person = Person(name: "Test Attorney", email: uniqueEmail)
            try await person.create(on: app.db)

            let uniqueCode = TestUtilities.randomCode(prefix: "TS")
            let uniqueName = TestUtilities.randomUID(prefix: "TestState")
            let jurisdiction = LegalJurisdiction(name: uniqueName, code: uniqueCode)
            try await jurisdiction.create(on: app.db)

            let uniqueLicenseNumber = TestUtilities.randomCode(prefix: "TEST")
            let credential = Credential(
                personID: person.id!,
                jurisdictionID: jurisdiction.id!,
                licenseNumber: uniqueLicenseNumber
            )
            try await credential.create(on: app.db)

            let project = Project(codename: "PROJECT-RELATIONSHIPLOG-LOAD-TEST")
            try await project.create(on: app.db)

            let relationshipLog = RelationshipLog(
                projectID: project.id!,
                credentialID: credential.id!,
                body: "Test relationship log for loading",
                relationships: RelationshipsData()
            )
            try await relationshipLog.create(on: app.db)

            // Load relationship log with relationships
            let loadedRelationshipLog = try await RelationshipLog.query(on: app.db)
                .with(\.$project)
                .with(\.$credential) {
                    $0.with(\.$person)
                    $0.with(\.$jurisdiction)
                }
                .filter(\.$id == relationshipLog.id!)
                .first()

            #expect(loadedRelationshipLog != nil)
            #expect(loadedRelationshipLog?.body == "Test relationship log for loading")
            #expect(loadedRelationshipLog?.project.codename == "PROJECT-RELATIONSHIPLOG-LOAD-TEST")
            #expect(loadedRelationshipLog?.credential.licenseNumber == uniqueLicenseNumber)
            #expect(loadedRelationshipLog?.credential.person.name == "Test Attorney")
            #expect(loadedRelationshipLog?.credential.jurisdiction.name == uniqueName)
        }
    }

    @Test("Find relationship logs for a project")
    func findRelationshipLogsForProject() async throws {
        try await TestUtilities.withApp { app, database in
            // Create test data sequentially to avoid connection pool exhaustion
            let uniqueEmail = TestUtilities.randomUID(prefix: "test.relationshiplog.project") + "@example.com"
            let person = Person(name: "Test Attorney", email: uniqueEmail)
            try await person.create(on: app.db)

            let uniqueCode = TestUtilities.randomCode(prefix: "TS")
            let uniqueName = TestUtilities.randomUID(prefix: "TestState")
            let jurisdiction = LegalJurisdiction(name: uniqueName, code: uniqueCode)
            try await jurisdiction.create(on: app.db)

            let uniqueLicenseNumber = TestUtilities.randomCode(prefix: "TEST")
            let credential = Credential(
                personID: person.id!,
                jurisdictionID: jurisdiction.id!,
                licenseNumber: uniqueLicenseNumber
            )
            try await credential.create(on: app.db)

            // Use only one project to reduce database operations while still testing the query
            let project = Project(codename: "PROJECT-RELATIONSHIPLOG-PROJECT-TEST")
            try await project.create(on: app.db)

            // Create two relationship logs for the same project (still tests the project query)
            let relationshipLog1 = RelationshipLog(
                projectID: project.id!,
                credentialID: credential.id!,
                body: "First relationship log for project",
                relationships: RelationshipsData()
            )
            try await relationshipLog1.create(on: app.db)

            let relationshipLog2 = RelationshipLog(
                projectID: project.id!,
                credentialID: credential.id!,
                body: "Second relationship log for project",
                relationships: RelationshipsData()
            )
            try await relationshipLog2.create(on: app.db)

            // Find relationship logs for the project
            let projectLogs = try await RelationshipLog.query(on: app.db)
                .filter(\.$project.$id == project.id!)
                .all()

            #expect(projectLogs.count == 2)
            let projectLogIDs = projectLogs.map { $0.id }
            #expect(projectLogIDs.contains(relationshipLog1.id))
            #expect(projectLogIDs.contains(relationshipLog2.id))
        }
    }

    @Test("Find relationship logs for a credential")
    func findRelationshipLogsForCredential() async throws {
        try await TestUtilities.withApp { app, database in
            // Create test data sequentially to avoid connection pool exhaustion
            let uniqueEmail = TestUtilities.randomUID(prefix: "test.relationshiplog.cred") + "@example.com"
            let person = Person(name: "Test Attorney", email: uniqueEmail)
            try await person.create(on: app.db)

            let uniqueCode = TestUtilities.randomCode(prefix: "TS")
            let uniqueName = TestUtilities.randomUID(prefix: "TestState")
            let jurisdiction = LegalJurisdiction(name: uniqueName, code: uniqueCode)
            try await jurisdiction.create(on: app.db)

            // Use only one credential to reduce database operations while still testing the query
            let uniqueLicenseNumber = TestUtilities.randomCode(prefix: "TEST")
            let credential = Credential(
                personID: person.id!,
                jurisdictionID: jurisdiction.id!,
                licenseNumber: uniqueLicenseNumber
            )
            try await credential.create(on: app.db)

            let project = Project(codename: "PROJECT-RELATIONSHIPLOG-CRED-TEST")
            try await project.create(on: app.db)

            // Create two relationship logs for the same credential (still tests the credential query)
            let relationshipLog1 = RelationshipLog(
                projectID: project.id!,
                credentialID: credential.id!,
                body: "First relationship log for credential",
                relationships: RelationshipsData()
            )
            try await relationshipLog1.create(on: app.db)

            let relationshipLog2 = RelationshipLog(
                projectID: project.id!,
                credentialID: credential.id!,
                body: "Second relationship log for credential",
                relationships: RelationshipsData()
            )
            try await relationshipLog2.create(on: app.db)

            // Find relationship logs for the credential
            let credentialLogs = try await RelationshipLog.query(on: app.db)
                .filter(\.$credential.$id == credential.id!)
                .all()

            #expect(credentialLogs.count == 2)
            let credentialLogIDs = credentialLogs.map { $0.id }
            #expect(credentialLogIDs.contains(relationshipLog1.id))
            #expect(credentialLogIDs.contains(relationshipLog2.id))
        }
    }

    @Test("Update relationship log updates timestamp")
    func updateRelationshipLogTimestamp() async throws {
        try await TestUtilities.withApp { app, database in
            // Create test data
            let uniqueEmail = TestUtilities.randomUID(prefix: "test.relationshiplog.update") + "@example.com"
            let person = Person(name: "Test Attorney", email: uniqueEmail)
            try await person.create(on: app.db)

            let uniqueCode = TestUtilities.randomCode(prefix: "TS")
            let uniqueName = TestUtilities.randomUID(prefix: "TestState")
            let jurisdiction = LegalJurisdiction(name: uniqueName, code: uniqueCode)
            try await jurisdiction.create(on: app.db)

            let uniqueLicenseNumber = TestUtilities.randomCode(prefix: "TEST")
            let credential = Credential(
                personID: person.id!,
                jurisdictionID: jurisdiction.id!,
                licenseNumber: uniqueLicenseNumber
            )
            try await credential.create(on: app.db)

            let project = Project(codename: "PROJECT-RELATIONSHIPLOG-UPDATE-TEST")
            try await project.create(on: app.db)

            let relationshipLog = RelationshipLog(
                projectID: project.id!,
                credentialID: credential.id!,
                body: "Original body",
                relationships: RelationshipsData()
            )
            try await relationshipLog.create(on: app.db)

            let originalUpdatedAt = relationshipLog.updatedAt

            // Sleep briefly to ensure timestamp difference
            try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

            // Update relationship log
            relationshipLog.body = "Updated body"
            relationshipLog.relationships = RelationshipsData(rawValue: ["updated": true])
            try await relationshipLog.save(on: app.db)

            #expect(relationshipLog.updatedAt != originalUpdatedAt)
            #expect(relationshipLog.body == "Updated body")
            #expect(relationshipLog.relationships.rawValue["updated"] as? Bool == true)
        }
    }
}
