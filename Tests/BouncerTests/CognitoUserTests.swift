import Dali
import Foundation
import Testing
import Vapor

@testable import Bouncer

@Suite("CognitoUser Tests")
struct CognitoUserTests {

    @Test("Should create CognitoUser with all fields")
    func testCognitoUserCreation() async throws {
        let cognitoSub = "test-cognito-sub-123"
        let cognitoGroups = ["admin", "staff"]
        let username = "testuser@example.com"
        let email = "testuser@example.com"
        let name = "Test User"
        let albHeaders = ["x-amzn-oidc-data": "token123", "x-amzn-oidc-identity": "user123"]
        let createdAt = Date()

        let cognitoUser = CognitoUser(
            cognitoSub: cognitoSub,
            cognitoGroups: cognitoGroups,
            username: username,
            email: email,
            name: name,
            albHeaders: albHeaders,
            createdAt: createdAt
        )

        #expect(cognitoUser.cognitoSub == cognitoSub)
        #expect(cognitoUser.cognitoGroups == cognitoGroups)
        #expect(cognitoUser.username == username)
        #expect(cognitoUser.email == email)
        #expect(cognitoUser.name == name)
        #expect(cognitoUser.albHeaders == albHeaders)
        #expect(cognitoUser.createdAt == createdAt)
    }

    @Test("Should create CognitoUser with minimal fields")
    func testCognitoUserCreationMinimal() async throws {
        let cognitoSub = "minimal-sub-456"
        let cognitoGroups: [String] = []
        let username = "minimal@example.com"
        let email = "minimal@example.com"

        let cognitoUser = CognitoUser(
            cognitoSub: cognitoSub,
            cognitoGroups: cognitoGroups,
            username: username,
            email: email
        )

        #expect(cognitoUser.cognitoSub == cognitoSub)
        #expect(cognitoUser.cognitoGroups.isEmpty)
        #expect(cognitoUser.username == username)
        #expect(cognitoUser.email == email)
        #expect(cognitoUser.name == nil)
        #expect(cognitoUser.albHeaders.isEmpty)
        // createdAt should be approximately now
        #expect(abs(cognitoUser.createdAt.timeIntervalSinceNow) < 1.0)
    }

    @Test("Should validate CognitoUser successfully with valid data")
    func testValidationSuccess() async throws {
        let cognitoUser = CognitoUser(
            cognitoSub: "valid-sub-789",
            cognitoGroups: ["customer"],
            username: "validuser@example.com",
            email: "validuser@example.com",
            name: "Valid User"
        )

        try cognitoUser.validate()
        // Test passes if no exception is thrown
        #expect(Bool(true))
    }

    @Test("Should fail validation with empty cognito sub")
    func testValidationFailsEmptyCognitoSub() async throws {
        let cognitoUser = CognitoUser(
            cognitoSub: "",
            cognitoGroups: ["customer"],
            username: "test@example.com",
            email: "test@example.com"
        )

        #expect(throws: ValidationError.self) {
            try cognitoUser.validate()
        }
    }

    @Test("Should fail validation with empty username")
    func testValidationFailsEmptyUsername() async throws {
        let cognitoUser = CognitoUser(
            cognitoSub: "valid-sub",
            cognitoGroups: ["customer"],
            username: "",
            email: "test@example.com"
        )

        #expect(throws: ValidationError.self) {
            try cognitoUser.validate()
        }
    }

    @Test("Should fail validation with short username")
    func testValidationFailsShortUsername() async throws {
        let cognitoUser = CognitoUser(
            cognitoSub: "valid-sub",
            cognitoGroups: ["customer"],
            username: "ab",  // Only 2 characters
            email: "test@example.com"
        )

        #expect(throws: ValidationError.self) {
            try cognitoUser.validate()
        }
    }

    @Test("Should fail validation with empty email")
    func testValidationFailsEmptyEmail() async throws {
        let cognitoUser = CognitoUser(
            cognitoSub: "valid-sub",
            cognitoGroups: ["customer"],
            username: "testuser",
            email: ""
        )

        #expect(throws: ValidationError.self) {
            try cognitoUser.validate()
        }
    }

    @Test("Should fail validation with invalid email format")
    func testValidationFailsInvalidEmail() async throws {
        let cognitoUser = CognitoUser(
            cognitoSub: "valid-sub",
            cognitoGroups: ["customer"],
            username: "testuser",
            email: "invalid-email-format"
        )

        #expect(throws: ValidationError.self) {
            try cognitoUser.validate()
        }
    }

    @Test("Should determine admin role from cognito groups")
    func testUserRoleAdmin() async throws {
        let cognitoUser = CognitoUser(
            cognitoSub: "admin-sub",
            cognitoGroups: ["admin"],
            username: "admin@example.com",
            email: "admin@example.com"
        )

        #expect(cognitoUser.userRole == .admin)
        #expect(cognitoUser.isAdmin == true)
        #expect(cognitoUser.isStaff == true)  // Admin includes staff privileges
    }

    @Test("Should determine staff role from cognito groups")
    func testUserRoleStaff() async throws {
        let cognitoUser = CognitoUser(
            cognitoSub: "staff-sub",
            cognitoGroups: ["staff"],
            username: "staff@example.com",
            email: "staff@example.com"
        )

        #expect(cognitoUser.userRole == .staff)
        #expect(cognitoUser.isAdmin == false)
        #expect(cognitoUser.isStaff == true)
    }

    @Test("Should determine customer role from empty groups")
    func testUserRoleCustomer() async throws {
        let cognitoUser = CognitoUser(
            cognitoSub: "customer-sub",
            cognitoGroups: [],
            username: "customer@example.com",
            email: "customer@example.com"
        )

        #expect(cognitoUser.userRole == .customer)
        #expect(cognitoUser.isAdmin == false)
        #expect(cognitoUser.isStaff == false)
    }

    @Test("Should determine customer role from unknown groups")
    func testUserRoleCustomerUnknownGroups() async throws {
        let cognitoUser = CognitoUser(
            cognitoSub: "unknown-sub",
            cognitoGroups: ["unknown", "random"],
            username: "unknown@example.com",
            email: "unknown@example.com"
        )

        #expect(cognitoUser.userRole == .customer)
        #expect(cognitoUser.isAdmin == false)
        #expect(cognitoUser.isStaff == false)
    }

    @Test("Should prioritize admin role when multiple groups present")
    func testUserRolePriorityAdmin() async throws {
        let cognitoUser = CognitoUser(
            cognitoSub: "multi-role-sub",
            cognitoGroups: ["customer", "staff", "admin", "other"],
            username: "multirole@example.com",
            email: "multirole@example.com"
        )

        #expect(cognitoUser.userRole == .admin)
        #expect(cognitoUser.isAdmin == true)
        #expect(cognitoUser.isStaff == true)
    }

    @Test("Should prioritize staff role when staff and customer groups present")
    func testUserRolePriorityStaff() async throws {
        let cognitoUser = CognitoUser(
            cognitoSub: "staff-customer-sub",
            cognitoGroups: ["customer", "staff", "other"],
            username: "staffcustomer@example.com",
            email: "staffcustomer@example.com"
        )

        #expect(cognitoUser.userRole == .staff)
        #expect(cognitoUser.isAdmin == false)
        #expect(cognitoUser.isStaff == true)
    }

    @Test("Should return correct applicable roles for admin")
    func testApplicableRolesAdmin() async throws {
        let cognitoUser = CognitoUser(
            cognitoSub: "admin-roles-sub",
            cognitoGroups: ["admin"],
            username: "adminroles@example.com",
            email: "adminroles@example.com"
        )

        let applicableRoles = cognitoUser.applicableRoles
        #expect(applicableRoles.contains(.admin))
        #expect(applicableRoles.contains(.staff))
        #expect(applicableRoles.contains(.customer))
        #expect(applicableRoles.count == 3)
    }

    @Test("Should return correct applicable roles for staff")
    func testApplicableRolesStaff() async throws {
        let cognitoUser = CognitoUser(
            cognitoSub: "staff-roles-sub",
            cognitoGroups: ["staff"],
            username: "staffroles@example.com",
            email: "staffroles@example.com"
        )

        let applicableRoles = cognitoUser.applicableRoles
        #expect(!applicableRoles.contains(.admin))
        #expect(applicableRoles.contains(.staff))
        #expect(applicableRoles.contains(.customer))
        #expect(applicableRoles.count == 2)
    }

    @Test("Should return correct applicable roles for customer")
    func testApplicableRolesCustomer() async throws {
        let cognitoUser = CognitoUser(
            cognitoSub: "customer-roles-sub",
            cognitoGroups: [],
            username: "customerroles@example.com",
            email: "customerroles@example.com"
        )

        let applicableRoles = cognitoUser.applicableRoles
        #expect(!applicableRoles.contains(.admin))
        #expect(!applicableRoles.contains(.staff))
        #expect(applicableRoles.contains(.customer))
        #expect(applicableRoles.count == 1)
    }

    @Test("Should provide sanitized logging description")
    func testLoggingDescription() async throws {
        let cognitoUser = CognitoUser(
            cognitoSub: "logging-sub",
            cognitoGroups: ["admin", "staff"],
            username: "logging@example.com",
            email: "logging@example.com",
            name: "Logging User",
            albHeaders: ["sensitive-header": "sensitive-value"]
        )

        let loggingDesc = cognitoUser.loggingDescription

        #expect(loggingDesc["cognito_sub"] as? String == "logging-sub")
        #expect((loggingDesc["cognito_groups"] as? [String])?.contains("admin") == true)
        #expect(loggingDesc["username"] as? String == "logging@example.com")
        #expect(loggingDesc["email"] as? String == "logging@example.com")
        #expect(loggingDesc["name"] as? String == "Logging User")
        #expect(loggingDesc["user_role"] as? String == "admin")
        #expect(loggingDesc["created_at"] != nil)

        // Sensitive ALB headers should not be in logging description
        #expect(!loggingDesc.keys.contains("albHeaders"))
        #expect(!loggingDesc.keys.contains("sensitive-header"))
    }

    @Test("Should provide ALB header names without values")
    func testALBHeaderNames() async throws {
        let albHeaders = [
            "x-amzn-oidc-data": "sensitive-token",
            "x-amzn-oidc-identity": "user-identity",
            "x-forwarded-for": "ip-address",
        ]

        let cognitoUser = CognitoUser(
            cognitoSub: "header-test-sub",
            cognitoGroups: ["customer"],
            username: "headertest@example.com",
            email: "headertest@example.com",
            albHeaders: albHeaders
        )

        let headerNames = cognitoUser.albHeaderNames

        #expect(headerNames.count == 3)
        #expect(headerNames.contains("x-amzn-oidc-data"))
        #expect(headerNames.contains("x-amzn-oidc-identity"))
        #expect(headerNames.contains("x-forwarded-for"))
        #expect(headerNames.sorted() == headerNames)  // Should be sorted

        // Should not contain values, only keys
        #expect(!headerNames.contains("sensitive-token"))
        #expect(!headerNames.contains("user-identity"))
    }

    @Test("Should handle nil name in logging description")
    func testLoggingDescriptionWithNilName() async throws {
        let cognitoUser = CognitoUser(
            cognitoSub: "nil-name-sub",
            cognitoGroups: ["customer"],
            username: "nilname@example.com",
            email: "nilname@example.com",
            name: nil
        )

        let loggingDesc = cognitoUser.loggingDescription
        #expect(loggingDesc["name"] as? String == "nil")
    }

    @Test("Should be encodable and decodable as JSON")
    func testCodableConformance() async throws {
        let originalUser = CognitoUser(
            cognitoSub: "codable-sub",
            cognitoGroups: ["staff", "test"],
            username: "codable@example.com",
            email: "codable@example.com",
            name: "Codable User",
            albHeaders: ["header1": "value1"]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(originalUser)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedUser = try decoder.decode(CognitoUser.self, from: jsonData)

        #expect(decodedUser.cognitoSub == originalUser.cognitoSub)
        #expect(decodedUser.cognitoGroups == originalUser.cognitoGroups)
        #expect(decodedUser.username == originalUser.username)
        #expect(decodedUser.email == originalUser.email)
        #expect(decodedUser.name == originalUser.name)
        #expect(decodedUser.albHeaders == originalUser.albHeaders)
        #expect(abs(decodedUser.createdAt.timeIntervalSince(originalUser.createdAt)) < 1.0)
    }
}
