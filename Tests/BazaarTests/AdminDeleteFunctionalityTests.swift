import Bouncer
import Dali
import Fluent
import FluentPostgresDriver
import TestUtilities
import Testing
import Vapor
import VaporTesting

@testable import Bazaar

@Suite("Admin Delete Functionality Tests", .serialized)
struct AdminDeleteFunctionalityTests {

    @Test("AdminPeopleService can handle person deletion workflow")
    func adminPeopleServiceCanHandlePersonDeletionWorkflow() async throws {
        try await TestUtilities.withApp { app, db in
            let adminService = AdminPeopleService(database: db)

            // Create test person using the service instead of raw SQL
            let uniqueEmail = "delete-test-\(UUID().uuidString.lowercased())@example.com"
            let createdPerson = try await adminService.createPerson(
                name: "Test Delete Person",
                email: uniqueEmail
            )

            let personId = try createdPerson.requireID()

            // Verify person exists before deletion
            let existingPerson = try await adminService.getPerson(personId: personId)
            #expect(existingPerson != nil)
            #expect(existingPerson?.name == "Test Delete Person")
            #expect(existingPerson?.email == uniqueEmail)

            // Test the deletion functionality (core business logic)
            try await adminService.deletePerson(personId: personId)

            // Verify person was deleted
            let deletedPerson = try await adminService.getPerson(personId: personId)
            #expect(deletedPerson == nil)
        }
    }

    @Test("AdminPeopleService cannot delete admin@neonlaw.com")
    func adminPeopleServiceCannotDeleteSystemAdmin() async throws {
        try await TestUtilities.withApp { app, db in
            let adminService = AdminPeopleService(database: db)

            // Try to get the existing admin@neonlaw.com person, or create if not exists
            let postgresDb = db as! PostgresDatabase

            // First ensure the person exists (create via raw SQL to avoid duplicates)
            try await postgresDb.sql().raw(
                """
                INSERT INTO directory.people (name, email)
                VALUES ('Admin User', 'admin@neonlaw.com')
                ON CONFLICT (email) DO NOTHING
                """
            ).run()

            // Get the person ID
            let personResult = try await postgresDb.sql().raw(
                "SELECT id FROM directory.people WHERE email = 'admin@neonlaw.com'"
            ).first()

            guard let personId = try personResult?.decode(column: "id", as: UUID.self) else {
                throw TestError.databaseOperationFailed("Failed to find admin@neonlaw.com person")
            }

            // Verify person exists
            let existingPerson = try await adminService.getPerson(personId: personId)
            #expect(existingPerson != nil)
            #expect(existingPerson?.email == "admin@neonlaw.com")

            // Attempt to delete the system admin should fail
            do {
                try await adminService.deletePerson(personId: personId)
                #expect(Bool(false), "Expected deletion to fail for system admin")
            } catch {
                // Verify the error message contains the expected text
                let errorMessage = "\(error)"
                #expect(errorMessage.contains("Cannot delete the system administrator account"))
            }

            // Verify person still exists after failed deletion attempt
            let stillExistingPerson = try await adminService.getPerson(personId: personId)
            #expect(stillExistingPerson != nil)
            #expect(stillExistingPerson?.email == "admin@neonlaw.com")
        }
    }

    @Test("Delete buttons are present in admin list pages")
    func deleteButtonsArePresentInAdminListPages() async throws {
        try await TestUtilities.withWebApp { app in
            try configureAdminApp(app)

            // TestAuthMiddleware handles authentication - no need to create database users

            try await runAdminDeleteSeedsWithApp(app.db)

            // Create a test user for the users list using raw SQL (visible to HTTP handlers)
            let testEmail = "test-user-\(UUID().uuidString.lowercased())@example.com"
            let (_, _) = try await createTestPersonAndUserWithApp(
                app.db,
                name: "Test User Person",
                email: testEmail,
                role: .staff
            )

            let adminToken = "admin@neonlaw.com:valid.test.token"

            // Test people list page has delete buttons
            try await app.test(.GET, "/admin/people", headers: ["Authorization": "Bearer \(adminToken)"]) { response in
                #expect(response.status == .ok)
                let html = response.body.string
                #expect(html.contains("Delete"))
                #expect(html.contains("/delete"))
            }

            // Test users list page has delete buttons
            try await app.test(.GET, "/admin/users", headers: ["Authorization": "Bearer \(adminToken)"]) { response in
                #expect(response.status == .ok)
                let html = response.body.string
                #expect(html.contains("Delete"))
                #expect(html.contains("/delete"))
            }
        }
    }

    @Test("Person with linked user can be deleted with cascading delete")
    func personWithLinkedUserCanBeDeletedWithCascadingDelete() async throws {
        try await TestUtilities.withWebApp { app in
            try configureAdminApp(app)

            // TestAuthMiddleware handles authentication - no need to create database users

            try await runAdminDeleteSeedsWithApp(app.db)

            // Create test person with linked user using raw SQL (visible to HTTP handlers)
            let uniqueEmail = "cascade-test-\(UUID().uuidString.lowercased())@example.com"
            let (personId, userId) = try await createTestPersonAndUserWithApp(
                app.db,
                name: "Cascade Test Person",
                email: uniqueEmail,
                role: .staff
            )

            let adminToken = "admin@neonlaw.com:valid.test.token"

            // Verify both person and user exist before deletion
            let existingPerson = try await Person.find(personId, on: app.db)
            let existingUser = try await User.find(userId, on: app.db)
            #expect(existingPerson != nil)
            #expect(existingUser != nil)

            // Test DELETE endpoint for person (should cascade delete user)
            do {
                try await app.test(
                    .DELETE,
                    "/admin/people/\(personId)",
                    headers: ["Authorization": "Bearer \(adminToken)"]
                ) { response in
                    #expect(response.status == .seeOther)  // Redirect
                    #expect(response.headers.first(name: .location) == "/admin/people")
                }
            } catch {
                print("Error in DELETE request: \(String(reflecting: error))")
                throw error
            }

            // Verify person was deleted
            let deletedPerson = try await Person.find(personId, on: app.db)
            #expect(deletedPerson == nil)

            // Verify linked user was also deleted
            let deletedUser = try await User.find(userId, on: app.db)
            #expect(deletedUser == nil)

        }
    }

    @Test("Delete button on person confirmation page works correctly")
    func deleteButtonOnPersonConfirmationPageWorksCorrectly() async throws {
        try await TestUtilities.withWebApp { app in
            try configureAdminApp(app)

            // TestAuthMiddleware handles authentication - no need to create database users

            try await runAdminDeleteSeedsWithApp(app.db)

            // Create test person using raw SQL (visible to HTTP handlers)
            let uniqueEmail = "delete-button-test-\(UUID().uuidString.lowercased())@example.com"
            let personId = try await createTestPersonWithApp(
                app.db,
                name: "Delete Button Test Person",
                email: uniqueEmail
            )

            let adminToken = "admin@neonlaw.com:valid.test.token"

            // First, verify the delete confirmation page loads
            try await app.test(
                .GET,
                "/admin/people/\(personId)/delete",
                headers: ["Authorization": "Bearer \(adminToken)"]
            ) { response in
                #expect(response.status == .ok)
                let html = try response.body.string
                #expect(html.contains("Delete Person"))
                #expect(html.contains("Delete Button Test Person"))
                #expect(html.contains("delete-button-test"))

                // Check for the form with hidden _method field
                #expect(html.contains("_method"))
                #expect(html.contains("DELETE"))
                #expect(html.contains("Yes, Delete Person"))
            }

            // Test the DELETE via form submission (POST with _method=DELETE)
            try await app.test(
                .POST,
                "/admin/people/\(personId)",
                headers: [
                    "Authorization": "Bearer \(adminToken)",
                    "Content-Type": "application/x-www-form-urlencoded",
                ],
                body: ByteBuffer(string: "_method=DELETE")
            ) { response in
                #expect(response.status == .seeOther)  // Redirect
                #expect(response.headers.first(name: .location) == "/admin/people")
            }

            // Verify person was deleted
            let deletedPerson = try await Person.find(personId, on: app.db)
            #expect(deletedPerson == nil)

        }
    }

    @Test("User deletion works correctly and redirects properly")
    func userDeletionWorksCorrectlyAndRedirectsProperly() async throws {
        try await TestUtilities.withWebApp { app in
            try configureAdminApp(app)

            // TestAuthMiddleware handles authentication - no need to create database users

            try await runAdminDeleteSeedsWithApp(app.db)

            // Create test person and user using raw SQL (visible to HTTP handlers)
            let uniqueEmail = "user-delete-test-\(UUID().uuidString.lowercased())@example.com"
            let (personId, userId) = try await createTestPersonAndUserWithApp(
                app.db,
                name: "User Delete Test Person",
                email: uniqueEmail,
                role: .staff
            )

            let adminToken = "admin@neonlaw.com:valid.test.token"

            // Verify user exists
            let existingUser = try await User.find(userId, on: app.db)
            #expect(existingUser != nil)

            // Test DELETE endpoint for user
            try await app.test(.DELETE, "/admin/users/\(userId)", headers: ["Authorization": "Bearer \(adminToken)"]) {
                response in
                #expect(response.status == .seeOther)  // Redirect
                #expect(response.headers.first(name: .location) == "/admin/users")
            }

            // Verify user was deleted
            let deletedUser = try await User.find(userId, on: app.db)
            #expect(deletedUser == nil)

            // Verify person still exists (user deletion should not cascade to person)
            let remainingPerson = try await Person.find(personId, on: app.db)
            #expect(remainingPerson != nil)

        }
    }

    @Test("Delete button on user confirmation page works correctly")
    func deleteButtonOnUserConfirmationPageWorksCorrectly() async throws {
        try await TestUtilities.withWebApp { app in
            try configureAdminApp(app)

            // TestAuthMiddleware handles authentication - no need to create database users

            try await runAdminDeleteSeedsWithApp(app.db)

            // Create test person and user using raw SQL (visible to HTTP handlers)
            let uniqueEmail = "user-delete-button-test-\(UUID().uuidString.lowercased())@example.com"
            let (personId, userId) = try await createTestPersonAndUserWithApp(
                app.db,
                name: "User Delete Button Test Person",
                email: uniqueEmail,
                role: .staff
            )

            let adminToken = "admin@neonlaw.com:valid.test.token"

            // First, verify the delete confirmation page loads
            try await app.test(
                .GET,
                "/admin/users/\(userId)/delete",
                headers: ["Authorization": "Bearer \(adminToken)"]
            ) { response in
                #expect(response.status == .ok)
                let html = try response.body.string
                #expect(html.contains("Delete User"))
                #expect(html.contains("User Delete Button Test Person"))
                #expect(html.contains("user-delete-button-test"))

                // Check for the form with hidden _method field
                #expect(html.contains("_method"))
                #expect(html.contains("DELETE"))
                #expect(html.contains("Yes, Delete User"))
            }

            // Test the DELETE via form submission (POST with _method=DELETE)
            try await app.test(
                .POST,
                "/admin/users/\(userId)",
                headers: [
                    "Authorization": "Bearer \(adminToken)",
                    "Content-Type": "application/x-www-form-urlencoded",
                ],
                body: ByteBuffer(string: "_method=DELETE")
            ) { response in
                #expect(response.status == .seeOther)  // Redirect
                #expect(response.headers.first(name: .location) == "/admin/users")
            }

            // Verify user was deleted
            let deletedUser = try await User.find(userId, on: app.db)
            #expect(deletedUser == nil)

            // Verify person still exists
            let remainingPerson = try await Person.find(personId, on: app.db)
            #expect(remainingPerson != nil)

        }
    }

    @Test("Cannot delete admin@neonlaw.com person record")
    func cannotDeleteAdminPersonRecord() async throws {
        try await TestUtilities.withApp { app, db in
            try configureAdminApp(app)

            // TestAuthMiddleware handles authentication - no need to create database users

            try await runAdminDeleteSeeds(db)

            // Find the admin@neonlaw.com person
            guard
                let adminPerson = try await Person.query(on: db)
                    .filter(\.$email == "admin@neonlaw.com")
                    .first()
            else {
                throw ValidationError("admin@neonlaw.com person not found in db")
            }

            let personId = try adminPerson.requireID()
            let adminToken = "admin@neonlaw.com:valid.test.token"

            // Test DELETE endpoint should fail
            try await app.test(.DELETE, "/admin/people/\(personId)", headers: ["Authorization": "Bearer \(adminToken)"])
            { response in
                #expect(response.status == .forbidden)
                let html = try response.body.string
                #expect(html.contains("Cannot delete the system administrator account"))
            }

            // Test form-based DELETE should also fail
            try await app.test(
                .POST,
                "/admin/people/\(personId)",
                headers: [
                    "Authorization": "Bearer \(adminToken)",
                    "Content-Type": "application/x-www-form-urlencoded",
                ],
                body: ByteBuffer(string: "_method=DELETE")
            ) { response in
                #expect(response.status == .forbidden)
                let html = try response.body.string
                #expect(html.contains("Cannot delete the system administrator account"))
            }

            // Verify admin@neonlaw.com person still exists
            let stillExistsPerson = try await Person.find(personId, on: db)
            #expect(stillExistsPerson != nil)

        }
    }

    @Test("Cannot delete admin@neonlaw.com user record")
    func cannotDeleteAdminUserRecord() async throws {
        try await TestUtilities.withApp { app, db in
            try configureAdminApp(app)

            // TestAuthMiddleware handles authentication - no need to create database users

            try await runAdminDeleteSeeds(db)

            // Find the admin@neonlaw.com user
            guard
                let adminUser = try await User.query(on: db)
                    .filter(\.$username == "admin@neonlaw.com")
                    .first()
            else {
                throw ValidationError("admin@neonlaw.com user not found in db")
            }

            let userId = try adminUser.requireID()
            let adminToken = "admin@neonlaw.com:valid.test.token"

            // Test DELETE endpoint should fail
            try await app.test(.DELETE, "/admin/users/\(userId)", headers: ["Authorization": "Bearer \(adminToken)"]) {
                response in
                #expect(response.status == .forbidden)
                let html = try response.body.string
                #expect(html.contains("Cannot delete the system administrator account"))
            }

            // Test form-based DELETE should also fail
            try await app.test(
                .POST,
                "/admin/users/\(userId)",
                headers: [
                    "Authorization": "Bearer \(adminToken)",
                    "Content-Type": "application/x-www-form-urlencoded",
                ],
                body: ByteBuffer(string: "_method=DELETE")
            ) { response in
                #expect(response.status == .forbidden)
                let html = try response.body.string
                #expect(html.contains("Cannot delete the system administrator account"))
            }

            // Verify admin@neonlaw.com user still exists
            let stillExistsUser = try await User.find(userId, on: db)
            #expect(stillExistsUser != nil)

        }
    }

    @Test("Cannot access delete confirmation page for admin@neonlaw.com person")
    func cannotAccessDeleteConfirmationPageForAdminPerson() async throws {
        try await TestUtilities.withApp { app, db in
            try configureAdminApp(app)

            // TestAuthMiddleware handles authentication - no need to create database users

            try await runAdminDeleteSeeds(db)

            // Find the admin@neonlaw.com person
            guard
                let adminPerson = try await Person.query(on: db)
                    .filter(\.$email == "admin@neonlaw.com")
                    .first()
            else {
                throw ValidationError("admin@neonlaw.com person not found in db")
            }

            let personId = try adminPerson.requireID()
            let adminToken = "admin@neonlaw.com:valid.test.token"

            // Test GET delete confirmation page should fail
            try await app.test(
                .GET,
                "/admin/people/\(personId)/delete",
                headers: ["Authorization": "Bearer \(adminToken)"]
            ) { response in
                #expect(response.status == .forbidden)
                let html = try response.body.string
                #expect(html.contains("Cannot delete the system administrator account"))
            }

        }
    }

    @Test("Cannot access delete confirmation page for admin@neonlaw.com user")
    func cannotAccessDeleteConfirmationPageForAdminUser() async throws {
        try await TestUtilities.withApp { app, db in
            try configureAdminApp(app)

            // TestAuthMiddleware handles authentication - no need to create database users

            try await runAdminDeleteSeeds(db)

            // Find the admin@neonlaw.com user
            guard
                let adminUser = try await User.query(on: db)
                    .filter(\.$username == "admin@neonlaw.com")
                    .first()
            else {
                throw ValidationError("admin@neonlaw.com user not found in db")
            }

            let userId = try adminUser.requireID()
            let adminToken = "admin@neonlaw.com:valid.test.token"

            // Test GET delete confirmation page should fail
            try await app.test(
                .GET,
                "/admin/users/\(userId)/delete",
                headers: ["Authorization": "Bearer \(adminToken)"]
            ) { response in
                #expect(response.status == .forbidden)
                let html = try response.body.string
                #expect(html.contains("Cannot delete the system administrator account"))
            }

        }
    }
}

// MARK: - Helper Functions

private func runAdminDeleteSeeds(_ database: Database) async throws {
    let postgresConnection = database as! PostgresDatabase

    // Insert basic test data to ensure admin pages work
    let uniqueTestId = UUID().uuidString.lowercased()

    // Set admin context and disable RLS for tests
    try await postgresConnection.sql()
        .raw("SET app.current_user_role = 'admin'")
        .run()
    try await postgresConnection.sql()
        .raw("SET row_security = off")
        .run()

    // Insert people first
    try await postgresConnection.sql().raw(
        """
        INSERT INTO directory.people (name, email) VALUES
        ('Admin User', 'admin@neonlaw.com'),
        ('Test Admin Person', 'admin-test-\(unsafeRaw: uniqueTestId)@example.com'),
        ('Sample Person', 'sample-\(unsafeRaw: uniqueTestId)@example.com')
        ON CONFLICT (email) DO NOTHING
        """
    ).run()

    // Create the admin@neonlaw.com user - ensure person exists first
    let personExists = try await postgresConnection.sql().raw(
        "SELECT id FROM directory.people WHERE email = 'admin@neonlaw.com'"
    ).first()

    if personExists != nil {
        try await postgresConnection.sql().raw(
            """
            INSERT INTO auth.users (username, role, person_id, created_at, updated_at)
            SELECT 'admin@neonlaw.com', 'admin'::auth.user_role, p.id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
            FROM directory.people p
            WHERE p.email = 'admin@neonlaw.com'
            ON CONFLICT (username) DO NOTHING
            """
        ).run()
    }

    try await postgresConnection.sql().raw(
        """
        INSERT INTO legal.jurisdictions (name, code) VALUES
        ('Test Jurisdiction', 'TEST-\(unsafeRaw: uniqueTestId)'),
        ('Sample Jurisdiction', 'SAMPLE-\(unsafeRaw: uniqueTestId)')
        ON CONFLICT (code) DO NOTHING
        """
    ).run()
}

private func createTestPerson(
    _ database: Database,
    name: String,
    email: String
) async throws -> UUID {
    let postgres = database as! PostgresDatabase

    let result = try await postgres.sql().raw(
        """
        INSERT INTO directory.people (name, email)
        VALUES (\(bind: name), \(bind: email))
        ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name
        RETURNING id
        """
    ).first()

    guard let result = result else {
        throw Abort(.internalServerError, reason: "Failed to create person")
    }

    return try result.decode(column: "id", as: UUID.self)
}

private func createTestPersonAndUser(
    _ database: Database,
    name: String,
    email: String,
    role: UserRole
) async throws -> (personId: UUID, userId: UUID) {
    let postgres = database as! PostgresDatabase

    // Create person first
    let personId = try await createTestPerson(database, name: name, email: email)

    // Create user with person_id foreign key
    let userResult = try await postgres.sql().raw(
        """
        INSERT INTO auth.users (username, role, person_id, created_at, updated_at)
        VALUES (\(bind: email), \(bind: role.rawValue)::auth.user_role, \(bind: personId), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ON CONFLICT (username) DO UPDATE SET role = EXCLUDED.role
        RETURNING id
        """
    ).first()

    guard let userResult = userResult else {
        throw Abort(.internalServerError, reason: "Failed to create user")
    }

    let userId = try userResult.decode(column: "id", as: UUID.self)
    return (personId: personId, userId: userId)
}

// MARK: - WithWebApp Helper Functions

private func runAdminDeleteSeedsWithApp(_ database: Database) async throws {
    let postgres = database as! PostgresDatabase
    let uniqueTestId = String(UUID().uuidString.prefix(8))

    // Create seeded person data
    try await postgres.sql().raw(
        """
        INSERT INTO directory.people (name, email) VALUES
        ('Admin Test Person', 'admin-test-\(unsafeRaw: uniqueTestId)@example.com'),
        ('Staff Test Person', 'staff-test-\(unsafeRaw: uniqueTestId)@example.com')
        ON CONFLICT (email) DO NOTHING
        """
    ).run()

    // Create admin@neonlaw.com person if not exists
    try await postgres.sql().raw(
        """
        INSERT INTO directory.people (name, email)
        VALUES ('Admin User', 'admin@neonlaw.com')
        ON CONFLICT (email) DO NOTHING
        """
    ).run()

    // Create corresponding user records
    try await postgres.sql().raw(
        """
        INSERT INTO auth.users (username, role, person_id, created_at, updated_at)
        SELECT 'admin@neonlaw.com', 'admin'::auth.user_role, p.id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        FROM directory.people p
        WHERE p.email = 'admin@neonlaw.com'
        ON CONFLICT (username) DO NOTHING
        """
    ).run()

    try await postgres.sql().raw(
        """
        INSERT INTO legal.jurisdictions (name, code) VALUES
        ('Test Jurisdiction', 'TEST-\(unsafeRaw: uniqueTestId)'),
        ('Sample Jurisdiction', 'SAMPLE-\(unsafeRaw: uniqueTestId)')
        ON CONFLICT (code) DO NOTHING
        """
    ).run()
}

private func createTestPersonWithApp(
    _ database: Database,
    name: String,
    email: String
) async throws -> UUID {
    let postgres = database as! PostgresDatabase

    let result = try await postgres.sql().raw(
        """
        INSERT INTO directory.people (name, email)
        VALUES (\(bind: name), \(bind: email))
        ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name
        RETURNING id
        """
    ).first()

    guard let result = result else {
        throw Abort(.internalServerError, reason: "Failed to create person")
    }

    return try result.decode(column: "id", as: UUID.self)
}

private func createTestPersonAndUserWithApp(
    _ database: Database,
    name: String,
    email: String,
    role: UserRole
) async throws -> (personId: UUID, userId: UUID) {
    let postgres = database as! PostgresDatabase

    // Create person first
    let personId = try await createTestPersonWithApp(database, name: name, email: email)

    // Create user with person_id foreign key
    let userResult = try await postgres.sql().raw(
        """
        INSERT INTO auth.users (username, role, person_id, created_at, updated_at)
        VALUES (\(bind: email), \(bind: role.rawValue)::auth.user_role, \(bind: personId), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ON CONFLICT (username) DO UPDATE SET role = EXCLUDED.role
        RETURNING id
        """
    ).first()

    guard let userResult = userResult else {
        throw Abort(.internalServerError, reason: "Failed to create user")
    }

    let userId = try userResult.decode(column: "id", as: UUID.self)
    return (personId: personId, userId: userId)
}
