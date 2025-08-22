import Bouncer
import Dali
import Fluent
import FluentPostgresDriver
import TestUtilities
import Testing
import Vapor
import VaporTesting

@testable import Bouncer

@Suite("Bouncer Authentication Tests", .serialized)
struct BouncerTests {

    @Test("Bouncer allows admin@neonlaw.com user to authenticate")
    func bouncerAllowsAdminAuthentication() async throws {
        try await TestUtilities.withApp { app, database in
            try configureApp(app)

            let adminToken = "admin@neonlaw.com:valid.test.token"

            try await app.test(.GET, "/app/me", headers: ["Authorization": "Bearer \(adminToken)"]) { response in
                #expect(response.status == .ok)

                let responseBody = try response.content.decode([String: String].self)
                #expect(responseBody["user_id"] != nil)
                #expect(responseBody["username"] == "admin@neonlaw.com")
            }
        }
    }

    @Test("Bouncer handles invalid token")
    func bouncerHandlesInvalidToken() async throws {
        try await TestUtilities.withApp { app, database in
            try configureApp(app)

            let invalidToken = "invalid"

            try await app.test(.GET, "/app/me", headers: ["Authorization": "Bearer \(invalidToken)"]) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }

    @Test("Bouncer handles missing authorization header")
    func bouncerHandlesMissingAuthorizationHeader() async throws {
        try await TestUtilities.withApp { app, database in
            try configureApp(app)

            try await app.test(.GET, "/app/me") { response in
                #expect(response.status == .unauthorized)
            }
        }
    }

    @Test("AdminAuthMiddleware allows admin users")
    func adminAuthMiddlewareAllowsAdminUsers() async throws {
        try await TestUtilities.withApp { app, database in
            try configureAdminApp(app)

            let adminToken = "admin@neonlaw.com:valid.test.token"

            try await app.test(.GET, "/admin/test", headers: ["Authorization": "Bearer \(adminToken)"]) { response in
                #expect(response.status == .ok)

                let responseBody = try response.content.decode([String: String].self)
                #expect(responseBody["message"] == "Admin access granted")
                #expect(responseBody["user_role"] == "admin")
            }
        }
    }

    @Test("AdminAuthMiddleware rejects non-admin users")
    func adminAuthMiddlewareRejectsNonAdminUsers() async throws {
        try await TestUtilities.withApp { app, database in
            try configureAdminApp(app)

            // Create a test staff user token
            let staffToken = "teststaff@example.com:valid.test.token"

            try await app.test(.GET, "/admin/test", headers: ["Authorization": "Bearer \(staffToken)"]) { response in
                #expect(response.status == .forbidden)
            }
        }
    }

    @Test("AdminAuthMiddleware rejects unauthenticated requests")
    func adminAuthMiddlewareRejectsUnauthenticatedRequests() async throws {
        try await TestUtilities.withApp { app, database in
            try configureAdminApp(app)

            try await app.test(.GET, "/admin/test") { response in
                #expect(response.status == .unauthorized)
            }
        }
    }

    func configureApp(_ app: Application) throws {
        // Configure DALI database models
        try configureDali(app)

        // Use TestAuthMiddleware for transaction-safe testing
        let testAuthMiddleware = TestAuthMiddleware()

        let protected = app.grouped(testAuthMiddleware)
        protected.get("app", "me") { req async throws -> [String: String] in
            guard let user = CurrentUserContext.user else {
                throw Abort(.internalServerError, reason: "Current user not available")
            }
            return [
                "user_id": user.id?.uuidString ?? "",
                "username": user.username,
            ]
        }
    }

    func configureAdminApp(_ app: Application) throws {
        // Configure DALI database models
        try configureDali(app)

        // Use TestAuthMiddleware for transaction-safe testing
        let testAuthMiddleware = TestAuthMiddleware()

        let adminRoutes = app.grouped("admin")
            .grouped(testAuthMiddleware)
            .grouped(AdminAuthMiddleware())

        adminRoutes.get("test") { req async throws -> [String: String] in
            guard let user = CurrentUserContext.user else {
                throw Abort(.internalServerError, reason: "Current user not available")
            }
            return [
                "message": "Admin access granted",
                "user_role": user.role.rawValue,
                "username": user.username,
            ]
        }
    }

}
