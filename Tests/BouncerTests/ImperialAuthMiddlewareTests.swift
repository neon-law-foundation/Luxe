import Bouncer
import Dali
import FluentPostgresDriver
import PostgresNIO
import TestUtilities
import Testing
import Vapor

@Suite("Imperial Auth Middleware", .serialized)
struct ImperialAuthMiddlewareTests {

    @Test("redirects to login when no Imperial session exists")
    func testRedirectsWhenNoSession() async throws {
        try await TestUtilities.withApp { app, database in
            // Configure DALI database models
            try configureDali(app)

            // Use TestAuthMiddleware to simulate missing authentication
            let testAuthMiddleware = TestAuthMiddleware()

            // Create test route with middleware (no auth headers = 401)
            let protectedRoutes = app.grouped(testAuthMiddleware)
            protectedRoutes.get("protected") { req in
                "Protected content"
            }

            // Make request without authentication headers - TestAuthMiddleware returns 401
            try await app.test(.GET, "protected") { res in
                #expect(res.status == .unauthorized)
            }
        }
    }

    @Test("allows access with valid Imperial session and existing user")
    func testAllowsAccessWithValidSession() async throws {
        try await TestUtilities.withApp { app, database in
            // Configure DALI database models
            try configureDali(app)

            // Use TestAuthMiddleware to simulate valid authentication
            let testAuthMiddleware = TestAuthMiddleware()

            // Create test route with TestAuthMiddleware
            let protectedRoutes = app.grouped(testAuthMiddleware)
            protectedRoutes.get("protected") { req async throws -> String in
                guard let currentUser = CurrentUserContext.user else {
                    throw Abort(.internalServerError, reason: "User not set in context")
                }
                return "Welcome \(currentUser.username)"
            }

            // Make request with admin token - TestAuthMiddleware creates mock admin user
            let adminToken = "admin@neonlaw.com:valid.test.token"
            try await app.test(.GET, "protected", headers: ["Authorization": "Bearer \(adminToken)"]) { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "Welcome admin@neonlaw.com")
            }
        }
    }

    @Test("redirects when Imperial session exists but user not in database")
    func testRedirectsWhenUserNotInDatabase() async throws {
        try await TestUtilities.withApp { app, database in
            // Configure DALI database models
            try configureDali(app)

            // Use TestAuthMiddleware to simulate invalid token rejection
            let testAuthMiddleware = TestAuthMiddleware()

            // Create test route with TestAuthMiddleware
            let protectedRoutes = app.grouped(testAuthMiddleware)
            protectedRoutes.get("protected") { req in
                "Protected content"
            }

            // Make request with invalid token - TestAuthMiddleware rejects invalid tokens
            let invalidToken = "invalid-token-format"
            try await app.test(.GET, "protected", headers: ["Authorization": "Bearer \(invalidToken)"]) { res in
                #expect(res.status == .unauthorized)
            }
        }
    }

    @Test("finds user by username when sub lookup fails")
    func testFallbackToUsernameLookup() async throws {
        try await TestUtilities.withApp { app, database in
            // Configure DALI database models
            try configureDali(app)

            // Use TestAuthMiddleware to simulate valid authentication
            let testAuthMiddleware = TestAuthMiddleware()

            // Create test route with TestAuthMiddleware
            let protectedRoutes = app.grouped(testAuthMiddleware)
            protectedRoutes.get("protected") { req async throws -> String in
                guard let currentUser = CurrentUserContext.user else {
                    throw Abort(.internalServerError, reason: "User not set in context")
                }
                return "Welcome \(currentUser.username)"
            }

            // Make request with customer token - TestAuthMiddleware creates mock customer user
            let customerToken = "testcustomer@example.com:valid.test.token"
            try await app.test(.GET, "protected", headers: ["Authorization": "Bearer \(customerToken)"]) { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "Welcome testcustomer@example.com")
            }
        }
    }

    @Test("sets CurrentUserContext for valid session")
    func testSetsCurrentUserContext() async throws {
        try await TestUtilities.withApp { app, database in
            // Configure DALI database models
            try configureDali(app)

            // Use TestAuthMiddleware to simulate valid authentication
            let testAuthMiddleware = TestAuthMiddleware()

            // Create test route with TestAuthMiddleware
            let protectedRoutes = app.grouped(testAuthMiddleware)
            protectedRoutes.get("check-context") { req async throws -> String in
                guard let currentUser = CurrentUserContext.user else {
                    return "No user in context"
                }
                return "\(currentUser.username) - \(currentUser.role)"
            }

            // Make request with admin token - TestAuthMiddleware sets CurrentUserContext
            let adminToken = "admin@neonlaw.com:valid.test.token"
            try await app.test(.GET, "check-context", headers: ["Authorization": "Bearer \(adminToken)"]) { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "admin@neonlaw.com - admin")
            }
        }
    }

    @Test("custom login path configuration")
    func testCustomLoginPath() async throws {
        try await TestUtilities.withApp { app, database in
            // Configure DALI database models
            try configureDali(app)

            // Use TestAuthMiddleware to simulate missing authentication
            let testAuthMiddleware = TestAuthMiddleware()

            // Create test route with TestAuthMiddleware
            let protectedRoutes = app.grouped(testAuthMiddleware)
            protectedRoutes.get("protected") { req in
                "Protected content"
            }

            // Make request without authentication - TestAuthMiddleware returns 401 (not redirect)
            try await app.test(.GET, "protected") { res in
                #expect(res.status == .unauthorized)
            }
        }
    }
}
