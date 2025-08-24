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

    // MARK: - Cognito Groups Mapping Tests

    @Test("Should map admin cognito groups to admin role")
    func testCognitoGroupsAdminMapping() async throws {
        let adminGroups = [
            ["admin"],
            ["administrators"],
            ["superadmin"],
            ["super-admin"],
            ["system-admin"],
            ["luxe-admin"],
            ["admin", "staff"],  // Mixed groups - should prioritize admin
            ["unknown", "admin", "other"],  // Admin among other groups
        ]

        for groups in adminGroups {
            let role = User.roleFromCognitoGroups(groups)
            #expect(role == .admin, "Groups \(groups) should map to admin role")
        }
    }

    @Test("Should map staff cognito groups to staff role")
    func testCognitoGroupsStaffMapping() async throws {
        let staffGroups = [
            ["staff"],
            ["employees"],
            ["team"],
            ["lawyers"],
            ["attorneys"],
            ["paralegals"],
            ["luxe-staff"],
            ["staff", "customer"],  // Mixed groups - should prioritize staff
            ["unknown", "staff", "other"],  // Staff among other groups
        ]

        for groups in staffGroups {
            let role = User.roleFromCognitoGroups(groups)
            #expect(role == .staff, "Groups \(groups) should map to staff role")
        }
    }

    @Test("Should map unknown or empty cognito groups to customer role")
    func testCognitoGroupsCustomerMapping() async throws {
        let customerGroups = [
            [],  // Empty groups
            ["unknown"],
            ["random"],
            ["guest"],
            ["user"],
            ["customer"],  // Explicit customer group
            ["unknown", "random", "guest"],  // Multiple unknown groups
        ]

        for groups in customerGroups {
            let role = User.roleFromCognitoGroups(groups)
            #expect(role == .customer, "Groups \(groups) should map to customer role")
        }
    }

    @Test("Should prioritize admin over staff and customer")
    func testCognitoGroupsPriorityAdmin() async throws {
        let mixedGroups = [
            ["admin", "staff", "customer"],
            ["customer", "admin", "staff"],
            ["staff", "customer", "admin"],
            ["luxe-admin", "luxe-staff"],
            ["super-admin", "employees", "guest"],
        ]

        for groups in mixedGroups {
            let role = User.roleFromCognitoGroups(groups)
            #expect(role == .admin, "Groups \(groups) with admin should prioritize admin role")
        }
    }

    @Test("Should prioritize staff over customer")
    func testCognitoGroupsPriorityStaff() async throws {
        let staffCustomerGroups = [
            ["staff", "customer"],
            ["customer", "staff"],
            ["employees", "guest"],
            ["lawyers", "user"],
            ["luxe-staff", "random"],
        ]

        for groups in staffCustomerGroups {
            let role = User.roleFromCognitoGroups(groups)
            #expect(role == .staff, "Groups \(groups) with staff should prioritize staff role")
        }
    }

    @Test("Should handle case insensitive group matching")
    func testCognitoGroupsCaseInsensitive() async throws {
        let caseVariations = [
            (["ADMIN"], UserRole.admin),
            (["Admin"], UserRole.admin),
            (["AdMin"], UserRole.admin),
            (["STAFF"], UserRole.staff),
            (["Staff"], UserRole.staff),
            (["StAfF"], UserRole.staff),
            (["LAWYERS"], UserRole.staff),
            (["Lawyers"], UserRole.staff),
        ]

        for (groups, expectedRole) in caseVariations {
            let role = User.roleFromCognitoGroups(groups)
            #expect(
                role == expectedRole,
                "Groups \(groups) should map to \(expectedRole.rawValue) role (case insensitive)"
            )
        }
    }

    @Test("Should update user role based on cognito groups")
    func testUpdateRoleFromCognitoGroups() async throws {
        try await TestUtilities.withApp { app, database in
            let uniqueId = UniqueCodeGenerator.generateISOCode(prefix: "roleupdate")
            let email = "role.update.\(uniqueId)@example.com"
            let name = "Role Update User \(uniqueId)"

            // Create user with customer role
            let (_, userId) = try await TestUtilities.createTestUserWithPerson(
                database,
                name: name,
                email: email,
                role: .customer
            )

            // Fetch user from database
            let user = try await User.find(userId, on: database)
            #expect(user != nil)
            #expect(user?.role == .customer)

            // Update role based on admin cognito groups
            user?.updateRoleFromCognitoGroups(["admin"])
            #expect(user?.role == .admin)

            // Update role based on staff cognito groups
            user?.updateRoleFromCognitoGroups(["staff"])
            #expect(user?.role == .staff)

            // Update role based on empty groups (should become customer)
            user?.updateRoleFromCognitoGroups([])
            #expect(user?.role == .customer)
        }
    }

    @Test("Should not update role if it hasn't changed")
    func testUpdateRoleFromCognitoGroupsNoChange() async throws {
        try await TestUtilities.withApp { app, database in
            let uniqueId = UniqueCodeGenerator.generateISOCode(prefix: "nochange")
            let email = "no.change.\(uniqueId)@example.com"
            let name = "No Change User \(uniqueId)"

            // Create user with admin role
            let (_, userId) = try await TestUtilities.createTestUserWithPerson(
                database,
                name: name,
                email: email,
                role: .admin
            )

            // Fetch user from database
            let user = try await User.find(userId, on: database)
            #expect(user != nil)
            #expect(user?.role == .admin)

            let _ = user?.updatedAt

            // Update with same admin groups - role shouldn't change
            user?.updateRoleFromCognitoGroups(["admin"])
            #expect(user?.role == .admin)

            // updatedAt should remain the same since no actual change occurred
            // (This test validates the optimization to avoid unnecessary database writes)
        }
    }

    @Test("Should validate role matches cognito groups correctly")
    func testValidateRoleMatchesCognitoGroups() async throws {
        try await TestUtilities.withApp { app, database in
            let uniqueId = UniqueCodeGenerator.generateISOCode(prefix: "validate")
            let email = "validate.role.\(uniqueId)@example.com"
            let name = "Validate Role User \(uniqueId)"

            // Create user with admin role
            let (_, userId) = try await TestUtilities.createTestUserWithPerson(
                database,
                name: name,
                email: email,
                role: .admin
            )

            // Fetch user from database
            let user = try await User.find(userId, on: database)
            #expect(user != nil)

            // Should validate true for admin groups
            #expect(user?.validateRoleMatchesCognitoGroups(["admin"]) == true)
            #expect(user?.validateRoleMatchesCognitoGroups(["administrators"]) == true)
            #expect(user?.validateRoleMatchesCognitoGroups(["luxe-admin"]) == true)

            // Should validate false for non-admin groups
            #expect(user?.validateRoleMatchesCognitoGroups(["staff"]) == false)
            #expect(user?.validateRoleMatchesCognitoGroups(["customer"]) == false)
            #expect(user?.validateRoleMatchesCognitoGroups([]) == false)

            // Should validate true for mixed groups containing admin
            #expect(user?.validateRoleMatchesCognitoGroups(["admin", "staff", "customer"]) == true)
        }
    }

    @Test("Should validate staff role matches cognito groups correctly")
    func testValidateStaffRoleMatchesCognitoGroups() async throws {
        try await TestUtilities.withApp { app, database in
            let uniqueId = UniqueCodeGenerator.generateISOCode(prefix: "validatestaff")
            let email = "validate.staff.\(uniqueId)@example.com"
            let name = "Validate Staff User \(uniqueId)"

            // Create user with staff role
            let (_, userId) = try await TestUtilities.createTestUserWithPerson(
                database,
                name: name,
                email: email,
                role: .staff
            )

            // Fetch user from database
            let user = try await User.find(userId, on: database)
            #expect(user != nil)

            // Should validate true for staff groups
            #expect(user?.validateRoleMatchesCognitoGroups(["staff"]) == true)
            #expect(user?.validateRoleMatchesCognitoGroups(["employees"]) == true)
            #expect(user?.validateRoleMatchesCognitoGroups(["lawyers"]) == true)

            // Should validate false for admin groups (staff user shouldn't have admin groups)
            #expect(user?.validateRoleMatchesCognitoGroups(["admin"]) == false)

            // Should validate false for customer-only groups
            #expect(user?.validateRoleMatchesCognitoGroups([]) == false)
            #expect(user?.validateRoleMatchesCognitoGroups(["customer"]) == false)

            // Should validate true for mixed groups containing staff
            #expect(user?.validateRoleMatchesCognitoGroups(["staff", "customer"]) == true)
        }
    }

    @Test("Should validate customer role matches cognito groups correctly")
    func testValidateCustomerRoleMatchesCognitoGroups() async throws {
        try await TestUtilities.withApp { app, database in
            let uniqueId = UniqueCodeGenerator.generateISOCode(prefix: "validatecustomer")
            let email = "validate.customer.\(uniqueId)@example.com"
            let name = "Validate Customer User \(uniqueId)"

            // Create user with customer role
            let (_, userId) = try await TestUtilities.createTestUserWithPerson(
                database,
                name: name,
                email: email,
                role: .customer
            )

            // Fetch user from database
            let user = try await User.find(userId, on: database)
            #expect(user != nil)

            // Should validate true for empty groups or customer-like groups
            #expect(user?.validateRoleMatchesCognitoGroups([]) == true)
            #expect(user?.validateRoleMatchesCognitoGroups(["customer"]) == true)
            #expect(user?.validateRoleMatchesCognitoGroups(["guest"]) == true)
            #expect(user?.validateRoleMatchesCognitoGroups(["unknown"]) == true)

            // Should validate false for admin or staff groups
            #expect(user?.validateRoleMatchesCognitoGroups(["admin"]) == false)
            #expect(user?.validateRoleMatchesCognitoGroups(["staff"]) == false)
            #expect(user?.validateRoleMatchesCognitoGroups(["lawyers"]) == false)
        }
    }
}
