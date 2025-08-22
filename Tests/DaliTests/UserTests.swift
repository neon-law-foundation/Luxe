import Dali
import Fluent
import FluentPostgresDriver
import TestUtilities
import Testing
import Vapor

@testable import Dali
@testable import Palette

@Suite("User Tests", .serialized)
struct UserTests {

    @Test("User can be created with valid data")
    func userCanBeCreatedWithValidData() async throws {
        try await TestUtilities.withApp { app, database in
            let uniqueId = UniqueCodeGenerator.generateISOCode(prefix: "user")
            let email = "test.user.\(uniqueId)@example.com"
            let name = "Test User \(uniqueId)"

            // Create test user with person
            let (personId, userId) = try await TestUtilities.createTestUserWithPerson(
                database,
                name: name,
                email: email,
                role: .staff
            )

            // Verify person was created
            let personResult = try await (database as! PostgresDatabase).sql()
                .raw("SELECT id, name, email FROM directory.people WHERE id = \(bind: personId)")
                .first()

            #expect(personResult != nil)
            if let person = personResult {
                let personName = try person.decode(column: "name", as: String.self)
                let personEmail = try person.decode(column: "email", as: String.self)
                #expect(personName == name)
                #expect(personEmail == email)
            }

            // Verify user was created
            let userResult = try await (database as! PostgresDatabase).sql()
                .raw("SELECT id, username, person_id, role FROM auth.users WHERE id = \(bind: userId)")
                .first()

            #expect(userResult != nil)
            if let user = userResult {
                let username = try user.decode(column: "username", as: String.self)
                let userPersonId = try user.decode(column: "person_id", as: UUID.self)
                let role = try user.decode(column: "role", as: String.self)
                #expect(username == email)
                #expect(userPersonId == personId)
                #expect(role == "staff")
            }
        }
    }

    @Test("User creation handles duplicate email gracefully")
    func userCreationHandlesDuplicateEmailGracefully() async throws {
        try await TestUtilities.withApp { app, database in
            let uniqueId = UniqueCodeGenerator.generateISOCode(prefix: "duplicate")
            let email = "duplicate.user.\(uniqueId)@example.com"
            let name = "Duplicate User \(uniqueId)"

            // Create first user
            let (personId1, userId1) = try await TestUtilities.createTestUserWithPerson(
                database,
                name: name,
                email: email,
                role: .staff
            )

            // Create second user with same email (should update existing)
            let (personId2, userId2) = try await TestUtilities.createTestUserWithPerson(
                database,
                name: "Updated Name",
                email: email,
                role: .admin
            )

            // Should be the same person and user IDs
            #expect(personId1 == personId2)
            #expect(userId1 == userId2)

            // Verify the person was updated
            let personResult = try await (database as! PostgresDatabase).sql()
                .raw("SELECT name FROM directory.people WHERE id = \(bind: personId1)")
                .first()

            #expect(personResult != nil)
            if let person = personResult {
                let personName = try person.decode(column: "name", as: String.self)
                #expect(personName == "Updated Name")
            }

            // Verify the user role was updated
            let userResult = try await (database as! PostgresDatabase).sql()
                .raw("SELECT role FROM auth.users WHERE id = \(bind: userId1)")
                .first()

            #expect(userResult != nil)
            if let user = userResult {
                let role = try user.decode(column: "role", as: String.self)
                #expect(role == "admin")
            }
        }
    }

    @Test("Admin user can be created")
    func adminUserCanBeCreated() async throws {
        try await TestUtilities.withApp { app, database in
            let uniqueId = UniqueCodeGenerator.generateISOCode(prefix: "admin")
            let email = "admin.user.\(uniqueId)@example.com"
            let name = "Admin User \(uniqueId)"

            // Create admin user
            let (_, userId) = try await TestUtilities.createTestUserWithPerson(
                database,
                name: name,
                email: email,
                role: .admin
            )

            // Verify user has admin role
            let userResult = try await (database as! PostgresDatabase).sql()
                .raw("SELECT role FROM auth.users WHERE id = \(bind: userId)")
                .first()

            #expect(userResult != nil)
            if let user = userResult {
                let role = try user.decode(column: "role", as: String.self)
                #expect(role == "admin")
            }
        }
    }

    @Test("Person can be created without user")
    func personCanBeCreatedWithoutUser() async throws {
        try await TestUtilities.withApp { app, database in
            let uniqueId = UniqueCodeGenerator.generateISOCode(prefix: "person")
            let email = "person.only.\(uniqueId)@example.com"
            let name = "Person Only \(uniqueId)"

            // Create person without user
            let personId = try await TestUtilities.createTestPerson(
                database,
                name: name,
                email: email
            )

            // Verify person was created
            let personResult = try await (database as! PostgresDatabase).sql()
                .raw("SELECT id, name, email FROM directory.people WHERE id = \(bind: personId)")
                .first()

            #expect(personResult != nil)
            if let person = personResult {
                let personName = try person.decode(column: "name", as: String.self)
                let personEmail = try person.decode(column: "email", as: String.self)
                #expect(personName == name)
                #expect(personEmail == email)
            }

            // Verify no user was created
            let userResult = try await (database as! PostgresDatabase).sql()
                .raw("SELECT COUNT(*) as count FROM auth.users WHERE username = \(bind: email)")
                .first()

            #expect(userResult != nil)
            if let user = userResult {
                let count = try user.decode(column: "count", as: Int.self)
                #expect(count == 0)
            }
        }
    }
}
