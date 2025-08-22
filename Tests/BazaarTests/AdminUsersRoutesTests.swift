import Dali
import Fluent
import FluentPostgresDriver
import TestUtilities
import Testing
import Vapor

@Suite("Admin Users Service Tests", .serialized)
struct AdminUsersRoutesTests {

    @Test("AdminUserService can create person and user atomically")
    func adminServiceCanCreatePersonAndUser() async throws {
        try await TestUtilities.withApp { app, db in
            let userService = AdminUserService(database: db)

            let input = AdminUserService.CreatePersonAndUserInput(
                name: "Test User",
                email: "test.user@example.com",
                username: "test.user@example.com",
                role: .customer
            )

            let result = try await userService.createPersonAndUser(input)

            // Verify creation
            #expect(!result.personId.uuidString.isEmpty)
            #expect(!result.userId.uuidString.isEmpty)
            #expect(result.createdAt.timeIntervalSince1970 > 0)
        }
    }

    @Test("AdminUserService can list people with users")
    func adminServiceCanListPeopleWithUsers() async throws {
        try await TestUtilities.withApp { app, db in
            let userService = AdminUserService(database: db)

            // Create test users
            let input1 = AdminUserService.CreatePersonAndUserInput(
                name: "John Staff",
                email: "john.staff@example.com",
                username: "john.staff@example.com",
                role: .staff
            )

            let input2 = AdminUserService.CreatePersonAndUserInput(
                name: "Jane Admin",
                email: "jane.admin@example.com",
                username: "jane.admin@example.com",
                role: .admin
            )

            _ = try await userService.createPersonAndUser(input1)
            _ = try await userService.createPersonAndUser(input2)

            // Test listing people with users
            let peopleWithUsers = try await userService.listPeopleWithUsers()

            #expect(peopleWithUsers.count >= 2)

            let staffFound = peopleWithUsers.contains { $0.person.name == "John Staff" }
            let adminFound = peopleWithUsers.contains { $0.person.name == "Jane Admin" }

            #expect(staffFound)
            #expect(adminFound)
        }
    }

    @Test("AdminUserService can get person with user")
    func adminServiceCanGetPersonWithUser() async throws {
        try await TestUtilities.withApp { app, db in
            let userService = AdminUserService(database: db)

            // Use unique email to avoid conflicts
            let uniqueEmail = "test.person.\(UUID().uuidString.lowercased())@example.com"
            let input = AdminUserService.CreatePersonAndUserInput(
                name: "Test Person",
                email: uniqueEmail,
                username: uniqueEmail,
                role: .customer
            )

            let result = try await userService.createPersonAndUser(input)

            // Test getting person with user
            let retrieved = try await userService.getPersonWithUser(personId: result.personId)

            #expect(retrieved != nil)
            #expect(retrieved?.person.name == "Test Person")
            #expect(retrieved?.person.email == uniqueEmail)
            #expect(retrieved?.user.role == .customer)
        }
    }

    @Test("AdminUserService can update user role")
    func adminServiceCanUpdateUserRole() async throws {
        try await TestUtilities.withApp { app, db in
            let userService = AdminUserService(database: db)

            let input = AdminUserService.CreatePersonAndUserInput(
                name: "Role Test User",
                email: "role.test@example.com",
                username: "role.test@example.com",
                role: .customer
            )

            let result = try await userService.createPersonAndUser(input)

            // Update the role
            let updatedUser = try await userService.updateUserRole(
                userId: result.userId,
                newRole: .staff
            )

            // Verify update
            #expect(updatedUser.role == .staff)
            #expect(updatedUser.id == result.userId)
        }
    }

    @Test("AdminUserService validates input")
    func adminServiceValidatesInput() async throws {
        try await TestUtilities.withApp { app, db in
            let userService = AdminUserService(database: db)

            // Test that empty name throws validation error
            do {
                let input = AdminUserService.CreatePersonAndUserInput(
                    name: "",
                    email: "test@example.com",
                    username: "test@example.com",
                    role: .customer
                )

                _ = try await userService.createPersonAndUser(input)

                #expect(Bool(false), "Should have thrown validation error for empty name")
            } catch {
                #expect(error is ValidationError)
            }

            // Test that empty email throws validation error
            do {
                let input = AdminUserService.CreatePersonAndUserInput(
                    name: "Test User",
                    email: "",
                    username: "test@example.com",
                    role: .customer
                )

                _ = try await userService.createPersonAndUser(input)

                #expect(Bool(false), "Should have thrown validation error for empty email")
            } catch {
                #expect(error is ValidationError)
            }
        }
    }

    @Test("AdminUserService can check username availability")
    func adminServiceCanCheckUsernameAvailability() async throws {
        try await TestUtilities.withApp { app, db in
            let userService = AdminUserService(database: db)

            // Create a user
            let input = AdminUserService.CreatePersonAndUserInput(
                name: "Existing User",
                email: "existing@example.com",
                username: "existing@example.com",
                role: .customer
            )

            _ = try await userService.createPersonAndUser(input)

            // Test username availability
            let existingAvailable = try await userService.isUsernameAvailable("existing@example.com")
            let newAvailable = try await userService.isUsernameAvailable("new@example.com")

            #expect(existingAvailable == false)
            #expect(newAvailable == true)
        }
    }

    @Test("AdminUserService can check email availability")
    func adminServiceCanCheckEmailAvailability() async throws {
        try await TestUtilities.withApp { app, db in
            let userService = AdminUserService(database: db)

            // Create a user
            let input = AdminUserService.CreatePersonAndUserInput(
                name: "Email Test User",
                email: "emailtest@example.com",
                username: "emailtest@example.com",
                role: .customer
            )

            _ = try await userService.createPersonAndUser(input)

            // Test email availability
            let existingAvailable = try await userService.isEmailAvailable("emailtest@example.com")
            let newAvailable = try await userService.isEmailAvailable("newemail@example.com")

            #expect(existingAvailable == false)
            #expect(newAvailable == true)
        }
    }
}
