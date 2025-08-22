import Fluent
import FluentPostgresDriver
import Logging
import PostgresNIO
import TestUtilities
import Testing
import Vapor

@testable import Dali
@testable import Palette

@Suite("User Service Tests", .serialized)
struct UserServiceTests {

    @Test("UserService can prepare user profile")
    func userServiceCanPrepareUserProfile() async throws {
        try await TestUtilities.withApp { app, database in
            let service = UserService(database: database)
            let adminService = AdminUserService(database: database)

            // Create test person and user using AdminUserService to handle RLS properly
            let email = "profile_user_\(UniqueCodeGenerator.generateISOCode(prefix: "PROFILE"))@example.com"
            let input = AdminUserService.CreatePersonAndUserInput(
                name: "Profile User \(UniqueCodeGenerator.generateISOCode(prefix: "PROFILE"))",
                email: email,
                username: email,
                role: .customer
            )

            let result = try await adminService.createPersonAndUser(input)

            // Get the created user with person relationship loaded
            guard
                let testUser = try await User.query(on: database)
                    .filter(\.$id == result.userId)
                    .with(\.$person)
                    .first()
            else {
                throw ValidationError("Failed to load created user")
            }

            // Test preparing user profile
            let (user, person) = try await service.prepareUserProfile(user: testUser)

            #expect(user.id == result.userId)
            #expect(person.id == result.personId)
            #expect(person.name == input.name)
            #expect(person.email == input.email.lowercased())
        }
    }

    @Test(
        "UserService throws error when person not available",
        .disabled("PSQLError - RLS policy issue with NULL person_id insert")
    )
    func userServiceThrowsErrorWhenPersonNotAvailable() async throws {
        try await TestUtilities.withApp { app, database in
            let service = UserService(database: database)

            // Create a user without a person relationship
            // We'll use raw SQL to bypass RLS and create an orphaned user for testing
            if let postgresDB = database as? PostgresDatabase {
                // Set admin role for the operation
                _ = try await postgresDB.sql()
                    .raw("SET app.current_user_role = 'admin'")
                    .run()

                // Create user without person_id
                let username = "no_person_\(UniqueCodeGenerator.generateISOCode(prefix: "NO"))@example.com"
                let userId = UUID()
                _ = try await postgresDB.sql()
                    .raw(
                        """
                            INSERT INTO auth.users (id, username, role, person_id)
                            VALUES (\(bind: userId), \(bind: username), 'customer', NULL)
                        """
                    )
                    .run()

                // Load the user
                guard let testUser = try await User.find(userId, on: database) else {
                    throw ValidationError("Failed to load test user")
                }

                // Test that preparing user profile throws error
                do {
                    _ = try await service.prepareUserProfile(user: testUser)
                    #expect(Bool(false), "Should throw ValidationError when person not available")
                } catch let error as ValidationError {
                    #expect(error.message.contains("Person record not available"))
                }
            }
        }
    }

    @Test("UserService can prepare user for API")
    func userServiceCanPrepareUserForAPI() async throws {
        try await TestUtilities.withApp { app, database in
            let service = UserService(database: database)
            let adminService = AdminUserService(database: database)

            // Create test person and user using AdminUserService
            let email = "api_user_\(UniqueCodeGenerator.generateISOCode(prefix: "API"))@example.com"
            let input = AdminUserService.CreatePersonAndUserInput(
                name: "API User \(UniqueCodeGenerator.generateISOCode(prefix: "API"))",
                email: email,
                username: email,
                role: .staff
            )

            let result = try await adminService.createPersonAndUser(input)

            // Get the created user (without person loaded initially)
            guard let testUser = try await User.find(result.userId, on: database) else {
                throw ValidationError("Failed to load created user")
            }

            // Test preparing user for API (should load person relationship)
            let preparedUser = try await service.prepareUserForAPI(user: testUser)

            #expect(preparedUser.id == result.userId)
            #expect(preparedUser.person?.name == input.name)
            #expect(preparedUser.person?.email == input.email.lowercased())
        }
    }

    @Test("UserService can get user with person by ID")
    func userServiceCanGetUserWithPersonById() async throws {
        try await TestUtilities.withApp { app, database in
            let service = UserService(database: database)
            let adminService = AdminUserService(database: database)

            // Create test person and user using AdminUserService
            let email = "get_user_\(UniqueCodeGenerator.generateISOCode(prefix: "GET"))@example.com"
            let input = AdminUserService.CreatePersonAndUserInput(
                name: "Get User \(UniqueCodeGenerator.generateISOCode(prefix: "GET"))",
                email: email,
                username: email,
                role: .admin
            )

            let result = try await adminService.createPersonAndUser(input)

            // Test getting user with person
            let retrievedUser = try await service.getUserWithPerson(userId: result.userId)

            #expect(retrievedUser != nil)
            #expect(retrievedUser?.id == result.userId)
            #expect(retrievedUser?.person?.name == input.name)
        }
    }

    @Test("UserService can get user by username")
    func userServiceCanGetUserByUsername() async throws {
        try await TestUtilities.withApp { app, database in
            let service = UserService(database: database)
            let adminService = AdminUserService(database: database)

            // Create test person and user using AdminUserService
            let uniqueEmail = "username_user_\(UniqueCodeGenerator.generateISOCode(prefix: "USERNAME"))@example.com"
            let input = AdminUserService.CreatePersonAndUserInput(
                name: "Username User \(UniqueCodeGenerator.generateISOCode(prefix: "USERNAME"))",
                email: uniqueEmail,
                username: uniqueEmail,
                role: .customer
            )

            _ = try await adminService.createPersonAndUser(input)

            // Test getting user by username
            let retrievedUser = try await service.getUserByUsername(username: uniqueEmail.lowercased())

            #expect(retrievedUser != nil)
            #expect(retrievedUser?.username == uniqueEmail.lowercased())
            #expect(retrievedUser?.person?.name == input.name)
        }
    }

    @Test("UserService can update user profile", .disabled("PSQLError - RLS policy issue with updates"))
    func userServiceCanUpdateUserProfile() async throws {
        try await TestUtilities.withApp { app, database in
            let service = UserService(database: database)
            let adminService = AdminUserService(database: database)

            // Create test person and user using AdminUserService
            let originalEmail = "update_user_\(UniqueCodeGenerator.generateISOCode(prefix: "UPDATE"))@example.com"
            let input = AdminUserService.CreatePersonAndUserInput(
                name: "Original Name \(UniqueCodeGenerator.generateISOCode(prefix: "ORIG"))",
                email: originalEmail,
                username: originalEmail,
                role: .customer
            )

            let result = try await adminService.createPersonAndUser(input)

            // Get the created user with person relationship loaded
            guard
                let testUser = try await User.query(on: database)
                    .filter(\.$id == result.userId)
                    .with(\.$person)
                    .first()
            else {
                throw ValidationError("Failed to load created user")
            }

            // Set admin role to allow updates (RLS policy requires admin)
            if let postgresDB = database as? PostgresDatabase {
                _ = try await postgresDB.sql()
                    .raw("SET app.current_user_role = 'admin'")
                    .run()
            }

            // Update user profile
            let newName = "Updated Name \(UniqueCodeGenerator.generateISOCode(prefix: "UPD"))"
            let newEmail = "updated_user_\(UniqueCodeGenerator.generateISOCode(prefix: "UPD"))@example.com"

            let updatedUser = try await service.updateUserProfile(
                user: testUser,
                name: newName,
                email: newEmail
            )

            #expect(updatedUser.person?.name == newName)
            #expect(updatedUser.person?.email == newEmail)

            // Verify changes were persisted
            let retrievedUser = try await service.getUserWithPerson(userId: result.userId)
            #expect(retrievedUser?.person?.name == newName)
            #expect(retrievedUser?.person?.email == newEmail)
        }
    }

    @Test("UserService handles non-existent user gracefully")
    func userServiceHandlesNonExistentUser() async throws {
        try await TestUtilities.withApp { app, database in
            let service = UserService(database: database)

            // Test with non-existent user ID
            let nonExistentId = UUID()
            let retrievedUser = try await service.getUserWithPerson(userId: nonExistentId)
            #expect(retrievedUser == nil)

            // Test with non-existent username
            let nonExistentUsername = "nonexistent_\(UniqueCodeGenerator.generateISOCode(prefix: "NONE"))@example.com"
            let retrievedByUsername = try await service.getUserByUsername(username: nonExistentUsername)
            #expect(retrievedByUsername == nil)
        }
    }

    @Test(
        "UserService validates profile update requirements",
        .disabled("PSQLError - RLS policy issue with NULL person_id insert")
    )
    func userServiceValidatesProfileUpdateRequirements() async throws {
        try await TestUtilities.withApp { app, database in
            let service = UserService(database: database)

            // Create a user without a person relationship using raw SQL
            if let postgresDB = database as? PostgresDatabase {
                // Set admin role for the operation
                _ = try await postgresDB.sql()
                    .raw("SET app.current_user_role = 'admin'")
                    .run()

                // Create user without person_id
                let username = "validation_\(UniqueCodeGenerator.generateISOCode(prefix: "VAL"))@example.com"
                let userId = UUID()
                _ = try await postgresDB.sql()
                    .raw(
                        """
                            INSERT INTO auth.users (id, username, role, person_id)
                            VALUES (\(bind: userId), \(bind: username), 'customer', NULL)
                        """
                    )
                    .run()

                // Load the user
                guard let testUser = try await User.find(userId, on: database) else {
                    throw ValidationError("Failed to load test user")
                }

                // Test updating profile without person relationship
                do {
                    _ = try await service.updateUserProfile(
                        user: testUser,
                        name: "New Name",
                        email: "new@example.com"
                    )
                    #expect(Bool(false), "Should throw ValidationError when person not available")
                } catch let error as ValidationError {
                    #expect(error.message.contains("Person record not available"))
                }
            }
        }
    }

    @Test("UserService trims whitespace in profile updates", .disabled("PSQLError - RLS policy issue with updates"))
    func userServiceTrimsWhitespaceInProfileUpdates() async throws {
        try await TestUtilities.withApp { app, database in
            let service = UserService(database: database)
            let adminService = AdminUserService(database: database)

            // Create test person and user using AdminUserService
            let email = "trim_user_\(UniqueCodeGenerator.generateISOCode(prefix: "TRIM"))@example.com"
            let input = AdminUserService.CreatePersonAndUserInput(
                name: "Trim User \(UniqueCodeGenerator.generateISOCode(prefix: "TRIM"))",
                email: email,
                username: email,
                role: .customer
            )

            let result = try await adminService.createPersonAndUser(input)

            // Get the created user with person relationship loaded
            guard
                let testUser = try await User.query(on: database)
                    .filter(\.$id == result.userId)
                    .with(\.$person)
                    .first()
            else {
                throw ValidationError("Failed to load created user")
            }

            // Set admin role to allow updates (RLS policy requires admin)
            if let postgresDB = database as? PostgresDatabase {
                _ = try await postgresDB.sql()
                    .raw("SET app.current_user_role = 'admin'")
                    .run()
            }

            // Update with whitespace-padded values
            let uniqueCode = UniqueCodeGenerator.generateISOCode(prefix: "TRIM")
            let nameWithWhitespace = "  Trimmed Name \(uniqueCode)  "
            let emailWithWhitespace = "  trimmed_\(uniqueCode)@example.com  "
            let expectedName = "Trimmed Name \(uniqueCode)"
            let expectedEmail = "trimmed_\(uniqueCode)@example.com"

            let updatedUser = try await service.updateUserProfile(
                user: testUser,
                name: nameWithWhitespace,
                email: emailWithWhitespace
            )

            #expect(updatedUser.person?.name == expectedName)
            #expect(updatedUser.person?.email == expectedEmail)
        }
    }
}
