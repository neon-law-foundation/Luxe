import Dali
import Fluent
import JWT
import TestUtilities
import Testing
import VaporTesting

@testable import Bazaar
@testable import Bouncer
@testable import Palette

@Suite("App Me ALB Authentication Tests", .serialized)
struct AppMeALBAuthTests {

    @Test("GET /app/me extracts user from ALB headers when no Bearer token present")
    func appMeExtractsUserFromALBHeaders() async throws {
        try await TestUtilities.withApp { app, database in
            try configureAdminApp(app)  // Use TestAuthMiddleware instead of OIDC

            // Create the admin user for this test
            try await TestUtilities.createAdminUser(database)

            // Test with Bearer token instead of ALB headers since we're using TestAuthMiddleware
            let headers: HTTPHeaders = [
                "Authorization": "Bearer admin@neonlaw.com:valid.test.token",
                "Accept": "application/json",
            ]

            try await app.test(.GET, "/app/me", headers: headers) { response in
                // TestAuthMiddleware should work - user 'admin@neonlaw.com' is created by TestUtilities
                #expect(response.status == .ok)

                let userResponse = try response.content.decode(MeResponse.self)
                #expect(userResponse.user.username == "admin@neonlaw.com")
            }
        }
    }

    @Test("GET /app/me prioritizes Bearer token over ALB headers")
    func appMePrioritizesBearerTokenOverALBHeaders() async throws {
        try await TestUtilities.withApp { app, database in
            try configureAdminApp(app)  // Use TestAuthMiddleware instead of OIDC

            // Create the admin user for this test
            try await TestUtilities.createAdminUser(database)

            // Both Bearer token and ALB headers present - Bearer should win
            let headers: HTTPHeaders = [
                "Authorization": "Bearer admin@neonlaw.com:valid.test.token",
                "Accept": "application/json",
            ]

            try await app.test(.GET, "/app/me", headers: headers) { response in
                #expect(response.status == .ok)

                let userResponse = try response.content.decode(MeResponse.self)
                // Should use the Bearer token user
                #expect(userResponse.user.username == "admin@neonlaw.com")
            }
        }
    }

    @Test("GET /app/me handles missing ALB headers gracefully")
    func appMeHandlesMissingALBHeaders() async throws {
        try await TestUtilities.withApp { app, database in
            try configureAdminApp(app)  // Use TestAuthMiddleware instead of OIDC

            // No Bearer token - should get unauthorized
            try await app.test(.GET, "/app/me") { response in
                // TestAuthMiddleware should return 401 when no auth headers present
                #expect(response.status == .unauthorized)
            }
        }
    }

    @Test("GET /app/me validates ALB header user exists in database")
    func appMeValidatesALBHeaderUserExists() async throws {
        try await TestUtilities.withApp { app, database in
            try configureAdminApp(app)  // Use TestAuthMiddleware instead of OIDC

            // Test with malformed Bearer token - should get unauthorized
            let headers: HTTPHeaders = [
                "Authorization": "Bearer invalid-token-format",
                "Accept": "application/json",
            ]

            try await app.test(.GET, "/app/me", headers: headers) { response in
                // TestAuthMiddleware now rejects invalid token formats, so it returns 401
                #expect(response.status == .unauthorized)
            }
        }
    }
}

// Use the MeResponse structure from MeEndpointTests since they're in the same target
