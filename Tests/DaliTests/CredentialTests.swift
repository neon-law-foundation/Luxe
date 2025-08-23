import Fluent
import FluentPostgresDriver
import Foundation
import Logging
import PostgresNIO
import TestUtilities
import Testing
import Vapor

@testable import Dali
@testable import Palette

@Suite("Credential Model Tests", .serialized)
struct CredentialTests {

    @Test("Credential model should create and save correctly", .disabled("CI connection timeout issues"))
    func credentialModelCreatesCorrectly() async throws {
        try await TestUtilities.withApp { app, database in
            do {
                // Create test person with unique email
                let uniqueEmail = TestUtilities.randomUID(prefix: "test.credential") + "@example.com"
                let person = Person(name: "Test Person", email: uniqueEmail)
                try await person.create(on: app.db)

                // Create test jurisdiction with unique name and code
                let uniqueCode = TestUtilities.randomCode(prefix: "TS")
                let uniqueName = TestUtilities.randomUID(prefix: "TestState")
                let jurisdiction = LegalJurisdiction(name: uniqueName, code: uniqueCode)
                try await jurisdiction.create(on: app.db)

                // Create credential with unique license number
                let uniqueLicenseNumber = TestUtilities.randomCode(prefix: "TEST")
                let credential = Credential(
                    personID: person.id!,
                    jurisdictionID: jurisdiction.id!,
                    licenseNumber: uniqueLicenseNumber
                )
                try await credential.create(on: app.db)

                // Verify credential was created
                #expect(credential.id != nil)
                #expect(credential.licenseNumber == uniqueLicenseNumber)
                #expect(credential.createdAt != nil)
                #expect(credential.updatedAt != nil)

                // Test relationships
                let savedCredential = try await Credential.query(on: app.db)
                    .with(\.$person)
                    .with(\.$jurisdiction)
                    .filter(\.$id == credential.id!)
                    .first()

                #expect(savedCredential != nil)
                #expect(savedCredential?.person.name == "Test Person")
                #expect(savedCredential?.jurisdiction.name == uniqueName)
            }
        }
    }

    @Test("Credential should enforce unique constraint", .disabled("CI connection timeout issues"))
    func credentialEnforcesUniqueConstraint() async throws {
        try await TestUtilities.withApp { app, database in
            // Create test person and jurisdiction with unique identifiers
            let uniqueEmail = TestUtilities.randomUID(prefix: "test.unique") + "@example.com"
            let person = Person(name: "Test Person", email: uniqueEmail)
            try await person.create(on: app.db)

            let uniqueCode = TestUtilities.randomCode(prefix: "TS")
            let uniqueName = TestUtilities.randomUID(prefix: "TestState")
            let jurisdiction = LegalJurisdiction(name: uniqueName, code: uniqueCode)
            try await jurisdiction.create(on: app.db)

            // Create first credential with unique license number
            let uniqueLicenseNumber = TestUtilities.randomCode(prefix: "UNIQUE")
            let credential1 = Credential(
                personID: person.id!,
                jurisdictionID: jurisdiction.id!,
                licenseNumber: uniqueLicenseNumber
            )
            try await credential1.create(on: app.db)

            // Try to create duplicate credential (should fail)
            let credential2 = Credential(
                personID: person.id!,
                jurisdictionID: jurisdiction.id!,
                licenseNumber: uniqueLicenseNumber
            )

            do {
                try await credential2.create(on: app.db)
                #expect(Bool(false), "Should have thrown an error for duplicate credential")
            } catch {
                // Expected to fail due to unique constraint
                let errorString = String(reflecting: error)
                #expect(errorString.contains("unique constraint") || errorString.contains("duplicate key"))
            }
        }
    }
}
