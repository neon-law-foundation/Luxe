import Dali
import Fluent
import FluentPostgresDriver
import Foundation
import TestUtilities
import Testing
import Vapor

@testable import Bouncer

@Suite("CognitoUserService Tests", .serialized)
struct CognitoUserServiceTests {

    @Test("Should create CognitoData with all fields")
    func testCognitoDataCreation() async throws {
        let cognitoSub = "test-cognito-sub-123"
        let cognitoGroups = ["admin", "staff"]
        let username = "testuser@example.com"
        let email = "testuser@example.com"
        let name = "Test User"
        let albHeaders = ["x-amzn-oidc-data": "token123", "x-amzn-oidc-identity": "user123"]

        let cognitoData = CognitoUserService.CognitoData(
            cognitoSub: cognitoSub,
            cognitoGroups: cognitoGroups,
            username: username,
            email: email,
            name: name,
            albHeaders: albHeaders
        )

        #expect(cognitoData.cognitoSub == cognitoSub)
        #expect(cognitoData.cognitoGroups == cognitoGroups)
        #expect(cognitoData.username == username)
        #expect(cognitoData.email == email)
        #expect(cognitoData.name == name)
        #expect(cognitoData.albHeaders == albHeaders)
    }

    @Test("Should create CognitoData with minimal fields")
    func testCognitoDataCreationMinimal() async throws {
        let cognitoSub = "minimal-sub-456"
        let cognitoGroups: [String] = []
        let username = "minimal@example.com"
        let email = "minimal@example.com"

        let cognitoData = CognitoUserService.CognitoData(
            cognitoSub: cognitoSub,
            cognitoGroups: cognitoGroups,
            username: username,
            email: email
        )

        #expect(cognitoData.cognitoSub == cognitoSub)
        #expect(cognitoData.cognitoGroups == cognitoGroups)
        #expect(cognitoData.username == username)
        #expect(cognitoData.email == email)
        #expect(cognitoData.name == nil)
        #expect(cognitoData.albHeaders.isEmpty)
    }

    @Test("Should determine admin role from Cognito groups")
    func testAdminRoleMapping() async throws {
        let cognitoData = CognitoUserService.CognitoData(
            cognitoSub: "admin-user-sub",
            cognitoGroups: ["admin", "users"],
            username: "admin@example.com",
            email: "admin@example.com"
        )

        #expect(cognitoData.userRole == .admin)
    }

    @Test("Should determine staff role from Cognito groups")
    func testStaffRoleMapping() async throws {
        let cognitoData = CognitoUserService.CognitoData(
            cognitoSub: "staff-user-sub",
            cognitoGroups: ["staff", "lawyers"],
            username: "lawyer@example.com",
            email: "lawyer@example.com"
        )

        #expect(cognitoData.userRole == .staff)
    }

    @Test("Should default to customer role for unknown groups")
    func testCustomerRoleMapping() async throws {
        let cognitoData = CognitoUserService.CognitoData(
            cognitoSub: "customer-user-sub",
            cognitoGroups: ["unknown-group", "random-group"],
            username: "customer@example.com",
            email: "customer@example.com"
        )

        #expect(cognitoData.userRole == .customer)
    }

    @Test("Should validate valid CognitoData")
    func testValidCognitoDataValidation() async throws {
        let cognitoData = CognitoUserService.CognitoData(
            cognitoSub: "valid-sub-789",
            cognitoGroups: ["users"],
            username: "valid@example.com",
            email: "valid@example.com"
        )

        #expect(throws: Never.self) {
            try cognitoData.validate()
        }
    }

    @Test("Should throw error for empty Cognito sub")
    func testInvalidCognitoSubValidation() async throws {
        let cognitoData = CognitoUserService.CognitoData(
            cognitoSub: "",
            cognitoGroups: ["users"],
            username: "test@example.com",
            email: "test@example.com"
        )

        #expect(throws: Bouncer.ValidationError.self) {
            try cognitoData.validate()
        }
    }

    @Test("Should throw error for empty username")
    func testInvalidUsernameValidation() async throws {
        let cognitoData = CognitoUserService.CognitoData(
            cognitoSub: "valid-sub",
            cognitoGroups: ["users"],
            username: "",
            email: "test@example.com"
        )

        #expect(throws: Bouncer.ValidationError.self) {
            try cognitoData.validate()
        }
    }

    @Test("Should throw error for short username")
    func testShortUsernameValidation() async throws {
        let cognitoData = CognitoUserService.CognitoData(
            cognitoSub: "valid-sub",
            cognitoGroups: ["users"],
            username: "ab",
            email: "ab@example.com"
        )

        #expect(throws: Bouncer.ValidationError.self) {
            try cognitoData.validate()
        }
    }

    @Test("Should throw error for invalid email")
    func testInvalidEmailValidation() async throws {
        let cognitoData = CognitoUserService.CognitoData(
            cognitoSub: "valid-sub",
            cognitoGroups: ["users"],
            username: "test@example.com",
            email: "invalid-email"
        )

        #expect(throws: Bouncer.ValidationError.self) {
            try cognitoData.validate()
        }
    }

    // Note: Database integration tests will be added in Phase 2 when implementing the authenticator
    // For now we focus on the core data validation and role mapping functionality

    @Test("Should validate user role matches Cognito groups")
    func testValidateUserRole() async throws {
        let user = User(
            username: "validate@example.com",
            sub: "validate-sub",
            role: .admin
        )

        let isValid = CognitoUserService.validateUserRole(
            user: user,
            cognitoGroups: ["admin", "staff"]
        )

        #expect(isValid == true)

        let isInvalid = CognitoUserService.validateUserRole(
            user: user,
            cognitoGroups: ["customer"]
        )

        #expect(isInvalid == false)
    }

    @Test("Should create audit log data")
    func testCreateAuditLogData() async throws {
        let user = User(
            username: "audit@example.com",
            sub: "audit-sub",
            role: .staff
        )

        let logData = user.createAuditLogData(
            cognitoGroups: ["staff", "lawyers"],
            requestPath: "/admin/dashboard",
            albHeaderCount: 5
        )

        #expect(logData["cognito_sub"] as? String == "audit-sub")
        #expect(logData["username"] as? String == "audit@example.com")
        #expect(logData["role"] as? String == "staff")
        #expect(logData["request_path"] as? String == "/admin/dashboard")
        #expect(logData["alb_headers_count"] as? Int == 5)

        let cognitoGroups = logData["cognito_groups"] as? [String]
        #expect(cognitoGroups?.contains("staff") == true)
        #expect(cognitoGroups?.contains("lawyers") == true)
    }

    @Test("Should check appropriate Cognito access")
    func testHasAppropriateCognitoAccess() async throws {
        let adminUser = User(
            username: "admin@example.com",
            sub: "admin-sub",
            role: .admin
        )

        // Admin user should have access to all group levels
        #expect(adminUser.hasAppropriateCognitoAccess(["admin"]) == true)
        #expect(adminUser.hasAppropriateCognitoAccess(["staff"]) == true)
        #expect(adminUser.hasAppropriateCognitoAccess(["customer"]) == true)

        let staffUser = User(
            username: "staff@example.com",
            sub: "staff-sub",
            role: .staff
        )

        // Staff user should not have access to admin groups
        #expect(staffUser.hasAppropriateCognitoAccess(["admin"]) == false)
        #expect(staffUser.hasAppropriateCognitoAccess(["staff"]) == true)
        #expect(staffUser.hasAppropriateCognitoAccess(["customer"]) == true)
    }
}
