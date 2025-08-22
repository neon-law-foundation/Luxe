import Dali
import Fluent
import TestUtilities
import Testing
import Vapor

@Suite("Disclosure model", .serialized)
struct DisclosureTests {
    @Test("Create a new disclosure with required fields")
    func createDisclosure() async throws {
        try await TestUtilities.withApp { app, database in
            // Create test person
            let uniqueEmail = TestUtilities.randomUID(prefix: "test.disclosure") + "@example.com"
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

            // Create test project with unique codename
            let projectCodename = TestUtilities.randomUID(prefix: "PROJECT-DISCLOSURE-TEST")
            let project = Project(codename: projectCodename)
            try await project.create(on: app.db)

            // Create disclosure
            let disclosedAt = Date()
            let disclosure = Disclosure(
                credentialID: credential.id!,
                projectID: project.id!,
                disclosedAt: disclosedAt,
                endDisclosedAt: nil,
                active: true
            )
            try await disclosure.create(on: app.db)

            // Verify disclosure was created
            #expect(disclosure.id != nil)
            #expect(disclosure.disclosedAt == disclosedAt)
            #expect(disclosure.endDisclosedAt == nil)
            #expect(disclosure.active == true)
            #expect(disclosure.createdAt != nil)
            #expect(disclosure.updatedAt != nil)
        }
    }

    @Test("Create disclosure with end date")
    func createDisclosureWithEndDate() async throws {
        try await TestUtilities.withApp { app, database in
            // Create test data
            let uniqueEmail = TestUtilities.randomUID(prefix: "test.disclosure.end") + "@example.com"
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

            let projectCodename = TestUtilities.randomUID(prefix: "PROJECT-DISCLOSURE-END-TEST")
            let project = Project(codename: projectCodename)
            try await project.create(on: app.db)

            // Create disclosure with end date
            let disclosedAt = Date()
            let endDisclosedAt = Date(timeIntervalSinceNow: 86400)  // 1 day later
            let disclosure = Disclosure(
                credentialID: credential.id!,
                projectID: project.id!,
                disclosedAt: disclosedAt,
                endDisclosedAt: endDisclosedAt,
                active: false
            )
            try await disclosure.create(on: app.db)

            // Verify disclosure was created with end date
            #expect(disclosure.id != nil)
            #expect(disclosure.disclosedAt == disclosedAt)
            #expect(disclosure.endDisclosedAt == endDisclosedAt)
            #expect(disclosure.active == false)
        }
    }

    @Test("Load disclosure with relationships")
    func loadDisclosureWithRelationships() async throws {
        try await TestUtilities.withApp { app, database in
            // Create test data
            let uniqueEmail = TestUtilities.randomUID(prefix: "test.disclosure.rel") + "@example.com"
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

            let uniqueProjectCodename = TestUtilities.randomUID(prefix: "PROJECT-DISCLOSURE-REL-TEST")
            let project = Project(codename: uniqueProjectCodename)
            try await project.create(on: app.db)

            let disclosure = Disclosure(
                credentialID: credential.id!,
                projectID: project.id!,
                disclosedAt: Date(),
                endDisclosedAt: nil,
                active: true
            )
            try await disclosure.create(on: app.db)

            // Load disclosure with relationships
            let loadedDisclosure = try await Disclosure.query(on: app.db)
                .with(\.$credential) {
                    $0.with(\.$person)
                    $0.with(\.$jurisdiction)
                }
                .with(\.$project)
                .filter(\.$id == disclosure.id!)
                .first()

            #expect(loadedDisclosure != nil)
            #expect(loadedDisclosure?.credential.licenseNumber == uniqueLicenseNumber)
            #expect(loadedDisclosure?.credential.person.name == "Test Attorney")
            #expect(loadedDisclosure?.credential.jurisdiction.name == uniqueName)
            #expect(loadedDisclosure?.project.codename == uniqueProjectCodename)
        }
    }

    @Test("Find active disclosures for a project")
    func findActiveDisclosuresForProject() async throws {
        try await TestUtilities.withApp { app, database in
            // Create test data
            let uniqueEmail = TestUtilities.randomUID(prefix: "test.disclosure.active") + "@example.com"
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

            let uniqueProjectCodename = TestUtilities.randomUID(prefix: "PROJECT-DISCLOSURE-ACTIVE-TEST")
            let project = Project(codename: uniqueProjectCodename)
            try await project.create(on: app.db)

            // Create active disclosure
            let activeDisclosure = Disclosure(
                credentialID: credential.id!,
                projectID: project.id!,
                disclosedAt: Date(),
                endDisclosedAt: nil,
                active: true
            )
            try await activeDisclosure.create(on: app.db)

            // Create inactive disclosure
            let inactiveDisclosure = Disclosure(
                credentialID: credential.id!,
                projectID: project.id!,
                disclosedAt: Date(timeIntervalSinceNow: -86400),  // 1 day ago
                endDisclosedAt: Date(),
                active: false
            )
            try await inactiveDisclosure.create(on: app.db)

            // Find only active disclosures
            let activeDisclosures = try await Disclosure.query(on: app.db)
                .filter(\.$project.$id == project.id!)
                .filter(\.$active == true)
                .all()

            #expect(activeDisclosures.count == 1)
            #expect(activeDisclosures.first?.id == activeDisclosure.id)
        }
    }

    @Test("Update disclosure updates timestamp")
    func updateDisclosureTimestamp() async throws {
        try await TestUtilities.withApp { app, database in
            // Create test data
            let uniqueEmail = TestUtilities.randomUID(prefix: "test.disclosure.update") + "@example.com"
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

            let uniqueProjectCodename = TestUtilities.randomUID(prefix: "PROJECT-DISCLOSURE-UPDATE-TEST")
            let project = Project(codename: uniqueProjectCodename)
            try await project.create(on: app.db)

            let disclosure = Disclosure(
                credentialID: credential.id!,
                projectID: project.id!,
                disclosedAt: Date(),
                endDisclosedAt: nil,
                active: true
            )
            try await disclosure.create(on: app.db)

            let originalUpdatedAt = disclosure.updatedAt

            // Sleep briefly to ensure timestamp difference
            try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

            // Update disclosure
            disclosure.active = false
            disclosure.endDisclosedAt = Date()
            try await disclosure.save(on: app.db)

            #expect(disclosure.updatedAt != originalUpdatedAt)
            #expect(disclosure.active == false)
            #expect(disclosure.endDisclosedAt != nil)
        }
    }

    @Test("Find disclosures for a credential")
    func findDisclosuresForCredential() async throws {
        try await TestUtilities.withApp { app, database in
            // Create test data sequentially to avoid connection pool exhaustion
            let uniqueEmail = TestUtilities.randomUID(prefix: "test.disclosure.cred") + "@example.com"
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
            let uniqueProjectCodename = TestUtilities.randomUID(prefix: "PROJECT-DISCLOSURE-CRED-TEST")
            let project = Project(codename: uniqueProjectCodename)
            try await project.create(on: app.db)

            // Create two disclosures for the same project (still tests the credential query)
            let disclosure1 = Disclosure(
                credentialID: credential.id!,
                projectID: project.id!,
                disclosedAt: Date(),
                endDisclosedAt: nil,
                active: true
            )
            try await disclosure1.create(on: app.db)

            let disclosure2 = Disclosure(
                credentialID: credential.id!,
                projectID: project.id!,
                disclosedAt: Date(timeIntervalSinceNow: -3600),  // 1 hour ago
                endDisclosedAt: nil,
                active: true
            )
            try await disclosure2.create(on: app.db)

            // Find all disclosures for this credential
            let credentialDisclosures = try await Disclosure.query(on: app.db)
                .filter(\.$credential.$id == credential.id!)
                .all()

            #expect(credentialDisclosures.count == 2)
            let disclosureIDs = credentialDisclosures.map { $0.id }
            #expect(disclosureIDs.contains(disclosure1.id))
            #expect(disclosureIDs.contains(disclosure2.id))
        }
    }
}
