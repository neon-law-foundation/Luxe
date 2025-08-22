import Fluent
import FluentPostgresDriver
import Logging
import PostgresNIO
import TestUtilities
import Testing
import Vapor

@testable import Dali
@testable import Palette

@Suite("Admin User Service Tests", .serialized)
struct AdminUserServiceTests {

    @Test("AdminUserService can create person and user successfully")
    func adminUserServiceCanCreatePersonAndUser() async throws {
        try await TestUtilities.withApp { app, database in

            let service = AdminUserService(database: database)

            let email = "service_test_\(UniqueCodeGenerator.generateISOCode(prefix: "SERVICE"))@example.com"
            let input = AdminUserService.CreatePersonAndUserInput(
                name: "Test Service User \(UniqueCodeGenerator.generateISOCode(prefix: "TEST"))",
                email: email,
                username: email,  // Username must match email due to foreign key constraint
                role: .staff
            )

            let result = try await service.createPersonAndUser(input)

            // Verify the result contains valid IDs and timestamp
            #expect(!result.personId.uuidString.isEmpty)
            #expect(!result.userId.uuidString.isEmpty)
            #expect(result.createdAt.timeIntervalSince1970 > 0)

            // Verify the person and user were actually created
            let retrieved = try await service.getPersonWithUser(personId: result.personId)
            #expect(retrieved != nil)

            if let (person, user) = retrieved {
                #expect(person.name == input.name)
                #expect(person.email == input.email.lowercased())
                #expect(user.username == input.username.lowercased())
                #expect(user.role == input.role)
                #expect(user.$person.id == result.personId)
            }
        }
    }

    @Test("AdminUserService validates input parameters")
    func adminUserServiceValidatesInputParameters() async throws {
        try await TestUtilities.withApp { app, database in

            let service = AdminUserService(database: database)

            // Test empty name
            let emptyNameInput = AdminUserService.CreatePersonAndUserInput(
                name: "",
                email: "test@example.com",
                username: "testuser",
                role: .customer
            )

            do {
                let _ = try await service.createPersonAndUser(emptyNameInput)
                #expect(Bool(false), "Should reject empty name")
            } catch let error as ValidationError {
                #expect(error.message.contains("Name cannot be empty"))
            }

            // Test empty email
            let emptyEmailInput = AdminUserService.CreatePersonAndUserInput(
                name: "Test User",
                email: "",
                username: "testuser",
                role: .customer
            )

            do {
                let _ = try await service.createPersonAndUser(emptyEmailInput)
                #expect(Bool(false), "Should reject empty email")
            } catch let error as ValidationError {
                #expect(error.message.contains("Email cannot be empty"))
            }

            // Test empty username
            let emptyUsernameInput = AdminUserService.CreatePersonAndUserInput(
                name: "Test User",
                email: "test@example.com",
                username: "",
                role: .customer
            )

            do {
                let _ = try await service.createPersonAndUser(emptyUsernameInput)
                #expect(Bool(false), "Should reject empty username")
            } catch let error as ValidationError {
                #expect(error.message.contains("Username cannot be empty"))
            }

            // Test invalid email format
            let invalidEmailInput = AdminUserService.CreatePersonAndUserInput(
                name: "Test User",
                email: "invalid-email",
                username: "testuser",
                role: .customer
            )

            do {
                let _ = try await service.createPersonAndUser(invalidEmailInput)
                #expect(Bool(false), "Should reject invalid email format")
            } catch let error as ValidationError {
                #expect(error.message.contains("Invalid email format"))
            }

            // Test short username
            let shortUsernameInput = AdminUserService.CreatePersonAndUserInput(
                name: "Test User",
                email: "test@example.com",
                username: "ab",
                role: .customer
            )

            do {
                let _ = try await service.createPersonAndUser(shortUsernameInput)
                #expect(Bool(false), "Should reject short username")
            } catch let error as ValidationError {
                #expect(error.message.contains("Username must be at least 3 characters long"))
            }
        }
    }

    @Test("AdminUserService can check username availability")
    func adminUserServiceCanCheckUsernameAvailability() async throws {
        try await TestUtilities.withApp { app, database in

            let service = AdminUserService(database: database)

            let username = "availability_test_\(UniqueCodeGenerator.generateISOCode(prefix: "AVAIL"))@example.com"

            // Username should be available initially
            let isAvailableBefore = try await service.isUsernameAvailable(username)
            #expect(isAvailableBefore == true)

            // Create a user with this username
            let input = AdminUserService.CreatePersonAndUserInput(
                name: "Test User",
                email: username,  // Email must match username due to foreign key constraint
                username: username,
                role: .customer
            )

            let _ = try await service.createPersonAndUser(input)

            // Username should not be available after creation
            let isAvailableAfter = try await service.isUsernameAvailable(username)
            #expect(isAvailableAfter == false)

            // Case insensitive check
            let isAvailableUppercase = try await service.isUsernameAvailable(username.uppercased())
            #expect(isAvailableUppercase == false)
        }
    }

    @Test("AdminUserService can check email availability")
    func adminUserServiceCanCheckEmailAvailability() async throws {
        try await TestUtilities.withApp { app, database in

            let service = AdminUserService(database: database)

            let email = "email_availability_test_\(UniqueCodeGenerator.generateISOCode(prefix: "EMAIL"))@example.com"

            // Email should be available initially
            let isAvailableBefore = try await service.isEmailAvailable(email)
            #expect(isAvailableBefore == true)

            // Create a user with this email
            let input = AdminUserService.CreatePersonAndUserInput(
                name: "Test User",
                email: email,
                username: email,  // Username must match email due to foreign key constraint
                role: .customer
            )

            let _ = try await service.createPersonAndUser(input)

            // Email should not be available after creation
            let isAvailableAfter = try await service.isEmailAvailable(email)
            #expect(isAvailableAfter == false)

            // Case insensitive check
            let isAvailableUppercase = try await service.isEmailAvailable(email.uppercased())
            #expect(isAvailableUppercase == false)
        }
    }

    @Test("AdminUserService can update user role")
    func adminUserServiceCanUpdateUserRole() async throws {
        try await TestUtilities.withApp { app, database in

            let service = AdminUserService(database: database)

            // Create a user
            let email = "role_update_\(UniqueCodeGenerator.generateISOCode(prefix: "ROLE"))@example.com"
            let input = AdminUserService.CreatePersonAndUserInput(
                name: "Role Update Test User",
                email: email,
                username: email,  // Username must match email due to foreign key constraint
                role: .customer
            )

            let result = try await service.createPersonAndUser(input)

            // Verify initial role
            if let (_, user) = try await service.getPersonWithUser(personId: result.personId) {
                #expect(user.role == .customer)

                // Update role to staff
                let updatedUser: User
                do {
                    updatedUser = try await service.updateUserRole(userId: user.id!, newRole: .staff)
                } catch {
                    print("Update role error: \(String(reflecting: error))")
                    throw error
                }
                #expect(updatedUser.role == .staff)

                // Verify role was updated in database
                if let (_, userAfterUpdate) = try await service.getPersonWithUser(personId: result.personId) {
                    #expect(userAfterUpdate.role == .staff)
                }
            }
        }
    }

    @Test("AdminUserService can list people with users")
    func adminUserServiceCanListPeopleWithUsers() async throws {
        try await TestUtilities.withApp { app, database in

            let service = AdminUserService(database: database)

            // Create multiple users
            let baseEmail = "list_test_\(UniqueCodeGenerator.generateISOCode(prefix: "LIST"))"
            let email1 = "\(baseEmail)_1@example.com"
            let email2 = "\(baseEmail)_2@example.com"
            let email3 = "\(baseEmail)_3@example.com"
            let users = [
                AdminUserService.CreatePersonAndUserInput(
                    name: "List Test User 1",
                    email: email1,
                    username: email1,  // Username must match email due to foreign key constraint
                    role: .customer
                ),
                AdminUserService.CreatePersonAndUserInput(
                    name: "List Test User 2",
                    email: email2,
                    username: email2,  // Username must match email due to foreign key constraint
                    role: .staff
                ),
                AdminUserService.CreatePersonAndUserInput(
                    name: "List Test User 3",
                    email: email3,
                    username: email3,  // Username must match email due to foreign key constraint
                    role: .admin
                ),
            ]

            // Create all users
            var createdUserIds: [UUID] = []
            for userInput in users {
                let result = try await service.createPersonAndUser(userInput)
                createdUserIds.append(result.userId)
            }

            // List users with pagination
            let listed = try await service.listPeopleWithUsers(limit: 10, offset: 0)

            // Should have at least the users we just created
            #expect(listed.count >= 3)

            // Check that our created users are in the list
            let listedUserIds = listed.map { $0.user.id! }
            for createdUserId in createdUserIds {
                #expect(listedUserIds.contains(createdUserId))
            }

            // Verify the data integrity of listed users
            for (person, user) in listed {
                if createdUserIds.contains(user.id!) {
                    #expect(user.$person.id == person.id)
                    #expect(!person.name.isEmpty)
                    #expect(!person.email.isEmpty)
                    #expect(!user.username.isEmpty)
                    #expect(UserRole.allCases.contains(user.role))
                }
            }
        }
    }

    @Test("AdminUserService input validation handles whitespace correctly")
    func adminUserServiceInputValidationHandlesWhitespaceCorrectly() async throws {
        try await TestUtilities.withApp { app, database in

            let service = AdminUserService(database: database)

            // Input with whitespace
            let emailWithSpaces =
                "  WHITESPACE_TEST_\(UniqueCodeGenerator.generateISOCode(prefix: "WHITESPACE"))@EXAMPLE.COM  "
            let input = AdminUserService.CreatePersonAndUserInput(
                name: "  Test User With Spaces  ",
                email: emailWithSpaces,
                // Username must match email (both will be trimmed and lowercased by the function)
                username: emailWithSpaces,
                role: .customer
            )

            let result: AdminUserService.CreatePersonAndUserResult
            do {
                result = try await service.createPersonAndUser(input)
            } catch {
                print("Whitespace test error: \(String(reflecting: error))")
                throw error
            }

            // Verify the person and user were created with trimmed/normalized data
            if let (person, user) = try await service.getPersonWithUser(personId: result.personId) {
                #expect(person.name == input.name.trimmingCharacters(in: .whitespacesAndNewlines))
                #expect(person.email == input.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
                #expect(user.username == input.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
            }
        }
    }

    @Test("AdminUserService can get user with person by user ID")
    func adminUserServiceCanGetUserWithPerson() async throws {
        try await TestUtilities.withApp { app, database in

            let service = AdminUserService(database: database)

            // Create a user
            let email = "getuser_test_\(UniqueCodeGenerator.generateISOCode(prefix: "GETUSER"))@example.com"
            let input = AdminUserService.CreatePersonAndUserInput(
                name: "Get User Test User",
                email: email,
                username: email,  // Username must match email due to foreign key constraint
                role: .staff
            )

            let result = try await service.createPersonAndUser(input)

            // Get the user with person loaded
            let userWithPerson = try await service.getUserWithPerson(userId: result.userId)

            // Verify the user was found and person is loaded
            #expect(userWithPerson != nil)

            if let user = userWithPerson {
                #expect(user.id == result.userId)
                #expect(user.username == email.lowercased())
                #expect(user.role == .staff)

                // Verify person relationship is loaded
                #expect(user.$person.id == result.personId)
                #expect(user.person?.name == input.name)
                #expect(user.person?.email == input.email.lowercased())
            }

            // Test with non-existent user ID
            let nonExistentUserId = UUID()
            let notFound = try await service.getUserWithPerson(userId: nonExistentUserId)
            #expect(notFound == nil)
        }
    }

    @Test("AdminUserService can get user for deletion with protection")
    func adminUserServiceCanGetUserForDeletion() async throws {
        try await TestUtilities.withApp { app, database in

            let service = AdminUserService(database: database)

            // Create a regular user
            let email = "deleteuser_test_\(UniqueCodeGenerator.generateISOCode(prefix: "DELETE"))@example.com"
            let input = AdminUserService.CreatePersonAndUserInput(
                name: "Delete User Test User",
                email: email,
                username: email,  // Username must match email due to foreign key constraint
                role: .customer
            )

            let result = try await service.createPersonAndUser(input)

            // Get the user for deletion (should work for regular users)
            let userForDeletion = try await service.getUserForDeletion(userId: result.userId)

            // Verify the user was found and person is loaded
            #expect(userForDeletion != nil)

            if let user = userForDeletion {
                #expect(user.id == result.userId)
                #expect(user.username == email.lowercased())
                #expect(user.role == .customer)
                #expect(user.person?.name == input.name)
                #expect(user.person?.email == input.email.lowercased())
            }

            // Test with non-existent user ID
            let nonExistentUserId = UUID()
            let notFoundUser = try await service.getUserForDeletion(userId: nonExistentUserId)
            #expect(notFoundUser == nil)
        }
    }

    @Test("AdminUserService can delete user with protection checks")
    func adminUserServiceCanDeleteUser() async throws {
        try await TestUtilities.withApp { app, database in

            let service = AdminUserService(database: database)

            // Create a regular user
            let email = "deleteuser_service_\(UniqueCodeGenerator.generateISOCode(prefix: "DELSERVICE"))@example.com"
            let input = AdminUserService.CreatePersonAndUserInput(
                name: "Delete Service Test User",
                email: email,
                username: email,  // Username must match email due to foreign key constraint
                role: .customer
            )

            let result = try await service.createPersonAndUser(input)

            // Verify user exists before deletion
            let userBeforeDeletion = try await service.getUserWithPerson(userId: result.userId)
            #expect(userBeforeDeletion != nil)

            // Delete the user
            try await service.deleteUser(userId: result.userId)

            // Verify user no longer exists after deletion
            let userAfterDeletion = try await service.getUserWithPerson(userId: result.userId)
            #expect(userAfterDeletion == nil)

            // Test deletion of non-existent user (should throw ValidationError)
            let nonExistentUserId = UUID()
            do {
                try await service.deleteUser(userId: nonExistentUserId)
                #expect(Bool(false), "Should throw ValidationError for non-existent user")
            } catch let error as ValidationError {
                #expect(error.message.contains("User not found"))
            }
        }
    }

}
