import Bouncer
import TestUtilities
import Testing
import Vapor
import VaporTesting

@testable import Bazaar

@Suite("Test Auth Middleware Tests", .serialized)
struct TestAuthMiddlewareTests {

    @Test("TestAuthMiddleware creates mock users for admin tokens")
    func testAuthMiddlewareCreatesAdminUsers() async throws {
        try await TestUtilities.withApp { app, database in
            try configureAppWithTestAuth(app)

            let adminToken = "admin@neonlaw.com:valid.test.token"

            try await app.test(.GET, "/admin/test", headers: ["Authorization": "Bearer \(adminToken)"]) { response in
                #expect(response.status == .ok)

                // Should return JSON with user info
                #expect(response.headers.contentType?.type == "application")
                #expect(response.headers.contentType?.subType == "json")

                let responseBody = response.body.string
                #expect(responseBody.contains("admin@neonlaw.com"))
                #expect(responseBody.contains("admin"))
                #expect(responseBody.contains("TestAuthMiddleware working!"))
            }
        }
    }

    @Test("TestAuthMiddleware rejects staff tokens from admin routes")
    func testAuthMiddlewareRejectsStaffFromAdmin() async throws {
        try await TestUtilities.withApp { app, database in
            try configureAppWithTestAuth(app)

            let staffToken = "teststaff@example.com:valid.test.token"

            try await app.test(.GET, "/admin/test", headers: ["Authorization": "Bearer \(staffToken)"]) { response in
                // Staff users should be forbidden from accessing admin routes
                #expect(response.status == .forbidden)
            }
        }
    }

    @Test("TestAuthMiddleware requires Bearer token")
    func testAuthMiddlewareRequiresBearerToken() async throws {
        try await TestUtilities.withApp { app, database in
            try configureAppWithTestAuth(app)

            try await app.test(.GET, "/admin/test") { response in
                #expect(response.status == .unauthorized)
            }
        }
    }
}
