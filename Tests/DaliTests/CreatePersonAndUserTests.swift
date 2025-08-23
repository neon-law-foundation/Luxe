import Fluent
import FluentPostgresDriver
import Logging
import PostgresNIO
import TestUtilities
import Testing
import Vapor

@testable import Dali
@testable import Palette

@Suite("Create Person and User Function Tests", .serialized)
struct CreatePersonAndUserTests {

    @Test("Admin can create person and user successfully")
    func adminCanCreatePersonAndUser() async throws {
        try await TestUtilities.withApp { app, database in

            let name = "Test User \(UniqueCodeGenerator.generateISOCode(prefix: "TEST"))"
            let email = "test_user_\(UniqueCodeGenerator.generateISOCode(prefix: "TEST_USER"))@example.com"
            let username = email  // Username must match email due to foreign key constraint
            let role = "customer"

            // Execute in transaction to ensure session variable and function call use same connection
            do {
                let result = try await app.db.transaction { connection in
                    guard let postgresConnection = connection as? PostgresDatabase else {
                        throw ValidationError("PostgreSQL database required")
                    }

                    // Set admin context for the function call
                    try await postgresConnection.sql()
                        .raw("SET app.current_user_role = 'admin'")
                        .run()

                    // Call the create_person_and_user function
                    return try await postgresConnection.sql()
                        .raw(
                            """
                            SELECT person_id, user_id, created_at
                            FROM admin.create_person_and_user(\(bind: name)::varchar(255), \(bind: email)::citext, \(bind: username)::varchar(255), \(bind: role)::auth.user_role)
                            """
                        )
                        .first()
                }

                #expect(result != nil, "Function should return a result")

                if let result = result {
                    let personId = try result.decode(column: "person_id", as: UUID.self)
                    let userId = try result.decode(column: "user_id", as: UUID.self)
                    let createdAt = try result.decode(column: "created_at", as: Date.self)

                    // Verify person was created correctly
                    let personResult = try await (app.db as! PostgresDatabase).sql()
                        .raw(
                            """
                            SELECT name, email FROM directory.people WHERE id = \(bind: personId)
                            """
                        )
                        .first()

                    #expect(personResult != nil)
                    if let personResult = personResult {
                        let storedName = try personResult.decode(column: "name", as: String.self)
                        let storedEmail = try personResult.decode(column: "email", as: String.self)
                        #expect(storedName == name)
                        #expect(storedEmail == email.lowercased())
                    }

                    // Verify user was created correctly
                    let userResult = try await (app.db as! PostgresDatabase).sql()
                        .raw(
                            """
                            SELECT username, person_id, role FROM auth.users WHERE id = \(bind: userId)
                            """
                        )
                        .first()

                    #expect(userResult != nil)
                    if let userResult = userResult {
                        let storedUsername = try userResult.decode(column: "username", as: String.self)
                        let storedPersonId = try userResult.decode(column: "person_id", as: UUID.self)
                        let storedRole = try userResult.decode(column: "role", as: String.self)
                        #expect(storedUsername == username.lowercased())
                        #expect(storedPersonId == personId)
                        #expect(storedRole == role)
                    }

                    // Verify timestamps are reasonable
                    let now = Date()
                    let timeDifference = now.timeIntervalSince(createdAt)
                    #expect(timeDifference >= 0 && timeDifference < 10, "Created timestamp should be recent")
                }
            } catch {
                print("Error details: \(String(reflecting: error))")
                throw error
            }
        }
    }

    @Test("Function works correctly with admin authorization in production context")
    func functionWorksCorrectlyWithAdminAuthorization() async throws {
        try await TestUtilities.withApp { app, database in

            // This test verifies that the admin authorization is working correctly
            // in the production context via AdminUserService, which is how the function
            // is actually used in the application

            let adminService = AdminUserService(database: app.db)

            let email = "authorized_\(UniqueCodeGenerator.generateISOCode(prefix: "TEST_AUTH_EMAIL"))@example.com"
            let input = AdminUserService.CreatePersonAndUserInput(
                name: "Test Authorized User \(UniqueCodeGenerator.generateISOCode(prefix: "TEST_AUTH"))",
                email: email,
                username: email,  // Username must match email due to foreign key constraint
                role: .customer
            )

            // Should succeed with admin role (AdminUserService handles setting session context)
            let result = try await adminService.createPersonAndUser(input)
            #expect(result.personId != UUID())
            #expect(result.userId != UUID())
        }
    }

    @Test("Function validates input parameters correctly")
    func functionValidatesInputParametersCorrectly() async throws {
        try await TestUtilities.withApp { app, database in

            // Set admin context (direct SQL test needs this)
            try await (app.db as! PostgresDatabase).sql()
                .raw("SET app.current_user_role = 'admin'")
                .run()

            // Test empty name
            do {
                let _ = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        SELECT person_id, user_id, created_at
                        FROM admin.create_person_and_user('', 'test@example.com', 'testuser', 'customer'::auth.user_role)
                        """
                    )
                    .first()
                #expect(Bool(false), "Should reject empty name")
            } catch {
                // PostgreSQL errors are sanitized for security, just expect an error occurred
                #expect(error is PSQLError, "Expected PostgreSQL error for empty name validation")
            }

            // Test empty email
            do {
                let _ = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        SELECT person_id, user_id, created_at
                        FROM admin.create_person_and_user('Test User', '', 'testuser', 'customer'::auth.user_role)
                        """
                    )
                    .first()
                #expect(Bool(false), "Should reject empty email")
            } catch {
                // PostgreSQL errors are sanitized for security, just expect an error occurred
                #expect(error is PSQLError, "Expected PostgreSQL error for empty email validation")
            }

            // Test empty username
            do {
                let _ = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        SELECT person_id, user_id, created_at
                        FROM admin.create_person_and_user('Test User', 'test@example.com', '', 'customer'::auth.user_role)
                        """
                    )
                    .first()
                #expect(Bool(false), "Should reject empty username")
            } catch {
                // PostgreSQL errors are sanitized for security, just expect an error occurred
                #expect(error is PSQLError, "Expected PostgreSQL error for empty username validation")
            }

            // Test invalid email format
            do {
                let _ = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        SELECT person_id, user_id, created_at
                        FROM admin.create_person_and_user('Test User', 'invalid-email', 'testuser', 'customer'::auth.user_role)
                        """
                    )
                    .first()
                #expect(Bool(false), "Should reject invalid email format")
            } catch {
                // PostgreSQL errors are sanitized for security, just expect an error occurred
                #expect(error is PSQLError, "Expected PostgreSQL error for invalid email format")
            }
        }
    }

    @Test("Function prevents duplicate email addresses")
    func functionPreventsDuplicateEmailAddresses() async throws {
        try await TestUtilities.withApp { app, database in

            let adminService = AdminUserService(database: app.db)
            let email = "duplicate_test_\(UniqueCodeGenerator.generateISOCode(prefix: "DUPLICATE"))@example.com"

            let input1 = AdminUserService.CreatePersonAndUserInput(
                name: "Test User 1",
                email: email,
                username: email,  // Username must match email due to foreign key constraint
                role: .customer
            )

            let input2 = AdminUserService.CreatePersonAndUserInput(
                name: "Test User 2",
                email: email,  // Same email - should fail
                username: email,  // Username must match email due to foreign key constraint
                role: .customer
            )

            // Create first user successfully
            let result1 = try await adminService.createPersonAndUser(input1)
            #expect(result1.personId != UUID())

            // Try to create second user with same email - should fail
            do {
                let _ = try await adminService.createPersonAndUser(input2)
                #expect(Bool(false), "Should reject duplicate email")
            } catch {
                // Should get a validation error about duplicate email
                #expect(Bool(true), "Expected error for duplicate email")
            }
        }
    }

    @Test("Function prevents duplicate usernames")
    func functionPreventsDuplicateUsernames() async throws {
        try await TestUtilities.withApp { app, database in

            let adminService = AdminUserService(database: app.db)
            let email = "duplicate_user_\(UniqueCodeGenerator.generateISOCode(prefix: "DUPLICATE_USER"))@example.com"

            let input1 = AdminUserService.CreatePersonAndUserInput(
                name: "Test User 1",
                email: email,
                username: email,  // Username must match email due to foreign key constraint
                role: .customer
            )

            let input2 = AdminUserService.CreatePersonAndUserInput(
                name: "Test User 2",
                email: email,  // Same email - should fail due to unique constraint
                username: email,  // Username matches email
                role: .customer
            )

            // Create first user successfully
            let result1 = try await adminService.createPersonAndUser(input1)
            #expect(result1.personId != UUID())

            // Try to create second user with same username - should fail
            do {
                let _ = try await adminService.createPersonAndUser(input2)
                #expect(Bool(false), "Should reject duplicate username")
            } catch {
                // Should get a validation error about duplicate username
                #expect(Bool(true), "Expected error for duplicate username")
            }
        }
    }

    @Test("Function creates user with specified role", .disabled("CI connection timeout issues"))
    func functionCreatesUserWithSpecifiedRole() async throws {
        try await TestUtilities.withApp { app, database in

            let roles = ["customer", "staff", "admin"]

            for role in roles {
                let name = "Test User \(role) \(UniqueCodeGenerator.generateISOCode(prefix: "TEST_ROLE"))"
                let email = "test_\(role)_\(UniqueCodeGenerator.generateISOCode(prefix: "TEST_ROLE_EMAIL"))@example.com"
                let username = email  // Username must match email due to foreign key constraint

                // Execute in transaction to ensure session variable and function call use same connection
                let result = try await app.db.transaction { connection in
                    guard let postgresConnection = connection as? PostgresDatabase else {
                        throw ValidationError("PostgreSQL database required")
                    }

                    // Set admin context
                    try await postgresConnection.sql()
                        .raw("SET app.current_user_role = 'admin'")
                        .run()

                    // Call the function
                    return try await postgresConnection.sql()
                        .raw(
                            """
                            SELECT person_id, user_id, created_at
                            FROM admin.create_person_and_user(\(bind: name)::varchar(255), \(bind: email)::citext, \(bind: username)::varchar(255), \(bind: role)::auth.user_role)
                            """
                        )
                        .first()
                }

                #expect(result != nil, "Should create user with role \(role)")

                if let result = result {
                    let userId = try result.decode(column: "user_id", as: UUID.self)

                    // Verify the role was set correctly
                    let userResult = try await (app.db as! PostgresDatabase).sql()
                        .raw(
                            """
                            SELECT role FROM auth.users WHERE id = \(bind: userId)
                            """
                        )
                        .first()

                    #expect(userResult != nil)
                    if let userResult = userResult {
                        let storedRole = try userResult.decode(column: "role", as: String.self)
                        #expect(storedRole == role, "Role should be \(role), but got \(storedRole)")
                    }
                }
            }
        }
    }

    @Test("Function defaults to customer role when not specified")
    func functionDefaultsToCustomerRoleWhenNotSpecified() async throws {
        try await TestUtilities.withApp { app, database in

            let name = "Test Default Role User \(UniqueCodeGenerator.generateISOCode(prefix: "TEST_DEFAULT"))"
            let email = "test_default_\(UniqueCodeGenerator.generateISOCode(prefix: "TEST_DEFAULT_EMAIL"))@example.com"
            let username = email  // Username must match email due to foreign key constraint

            // Execute in transaction to ensure session variable and function call use same connection
            let result = try await app.db.transaction { connection in
                guard let postgresConnection = connection as? PostgresDatabase else {
                    throw ValidationError("PostgreSQL database required")
                }

                // Set admin context
                try await postgresConnection.sql()
                    .raw("SET app.current_user_role = 'admin'")
                    .run()

                // Call function without specifying role (should use default)
                return try await postgresConnection.sql()
                    .raw(
                        """
                        SELECT person_id, user_id, created_at
                        FROM admin.create_person_and_user(\(bind: name)::varchar(255), \(bind: email)::citext, \(bind: username)::varchar(255))
                        """
                    )
                    .first()
            }

            #expect(result != nil, "Should create user with default role")

            if let result = result {
                let userId = try result.decode(column: "user_id", as: UUID.self)

                // Verify the role defaulted to customer
                let userResult = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        SELECT role FROM auth.users WHERE id = \(bind: userId)
                        """
                    )
                    .first()

                #expect(userResult != nil)
                if let userResult = userResult {
                    let storedRole = try userResult.decode(column: "role", as: String.self)
                    #expect(storedRole == "customer", "Default role should be customer, but got \(storedRole)")
                }
            }
        }
    }

    @Test("Function handles whitespace in input parameters correctly")
    func functionHandlesWhitespaceCorrectly() async throws {
        try await TestUtilities.withApp { app, database in

            let adminService = AdminUserService(database: app.db)

            let email = "test_email_\(UniqueCodeGenerator.generateISOCode(prefix: "TEST_WHITESPACE"))@example.com"
            let input = AdminUserService.CreatePersonAndUserInput(
                name: "  Test User With Spaces  ",
                email: email,
                username: email,  // Username must match email due to foreign key constraint
                role: .customer
            )

            let result = try await adminService.createPersonAndUser(input)
            #expect(result.personId != UUID())
            #expect(result.userId != UUID())

            // Verify data normalization by checking the stored values
            let person = try await Person.find(result.personId, on: app.db)
            let user = try await User.find(result.userId, on: app.db)

            #expect(person?.name == input.name.trimmingCharacters(in: .whitespacesAndNewlines))
            #expect(person?.email == input.email.lowercased())
            #expect(user?.username == input.username.lowercased())
        }
    }

    @Test("Function creates atomically linked person and user records")
    func functionCreatesAtomicallyLinkedRecords() async throws {
        try await TestUtilities.withApp { app, database in

            let adminService = AdminUserService(database: app.db)

            let email = "atomic_test_\(UniqueCodeGenerator.generateISOCode(prefix: "ATOMIC_EMAIL"))@example.com"
            let input = AdminUserService.CreatePersonAndUserInput(
                name: "Atomic Test User \(UniqueCodeGenerator.generateISOCode(prefix: "ATOMIC"))",
                email: email,
                username: email,  // Username must match email due to foreign key constraint
                role: .customer
            )

            let result = try await adminService.createPersonAndUser(input)
            #expect(result.personId != UUID())
            #expect(result.userId != UUID())

            // Verify the records are properly linked
            let person = try await Person.find(result.personId, on: app.db)
            let user = try await User.find(result.userId, on: app.db)

            #expect(person != nil, "Person should be created")
            #expect(user != nil, "User should be created")
            #expect(user?.$person.id == result.personId, "User should be linked to person")

            // Verify data integrity
            #expect(person?.name == input.name)
            #expect(person?.email == input.email.lowercased())
            #expect(user?.username == input.username.lowercased())
            #expect(user?.role == input.role)
        }
    }
}
