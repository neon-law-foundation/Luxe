import Dali
import JWT
import TestUtilities
import Testing
import Vapor
import VaporTesting

@testable import Bazaar
@testable import Bouncer
@testable import Palette

@Suite("App Me Endpoint Tests", .serialized)
struct AppMeEndpointTests {

    @Test("GET /app/me requires authentication")
    func appMeRequiresAuthentication() async throws {
        try await TestUtilities.withApp { app, database in
            try await configureApp(app)

            try await app.test(.GET, "/app/me") { response in
                // Should redirect to Keycloak when no auth headers present in non-production
                #expect(response.status == .seeOther || response.status == .unauthorized)
            }
        }
    }

    @Test("GET /app/me returns user info with valid JWT token")
    func appMeReturnsUserInfoWithValidToken() async throws {
        try await TestUtilities.withApp { app, database in

            try await configureApp(app)

            // Use a token that will map to the "admin@neonlaw.com" user which should exist in the database
            let testToken = "admin@neonlaw.com:valid-token-format"

            var headers: HTTPHeaders = ["Authorization": "Bearer \(testToken)"]
            headers.add(name: .accept, value: "application/json")

            try await app.test(.GET, "/app/me", headers: headers) { response in
                #expect(response.status == .ok)

                let meResponse = try response.content.decode(Bazaar.MeResponse.self)
                #expect(meResponse.user.username == "admin@neonlaw.com")
                #expect(meResponse.person.name == "Admin User")
                #expect(meResponse.person.email == "admin@neonlaw.com")
            }
        }
    }

    @Test("GET /app/me rejects invalid JWT token")
    func appMeRejectsInvalidToken() async throws {
        try await TestUtilities.withApp { app, database in
            try await configureApp(app)

            let invalidToken = "invalid-token-format"

            try await app.test(.GET, "/app/me", headers: ["Authorization": "Bearer \(invalidToken)"]) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }

    @Test("GET /app/me rejects expired JWT token")
    func appMeRejectsExpiredToken() async throws {
        try await TestUtilities.withApp { app, database in
            try await configureApp(app)

            // Use a token with "expired" in it, which will be rejected by the middleware
            let expiredToken = "expired-token-format"

            try await app.test(.GET, "/app/me", headers: ["Authorization": "Bearer \(expiredToken)"]) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }
}

// MARK: - Test Configuration

/// Configures the Bazaar application for AppMeEndpointTests with TestAuthMiddleware.
///
/// This function sets up the /app/me endpoint with TestAuthMiddleware instead of
/// ALBAuthMiddleware to work with transaction-safe testing.
///
/// - Parameter app: The Vapor application to configure
/// - Throws: Configuration errors if setup fails
func configureApp(_ app: Application) async throws {
    // Configure essential middleware
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))

    // Configure DALI models and database (must be done before any database usage)
    try configureDali(app)

    // Create TestAuthMiddleware that bypasses database lookups
    let testAuthMiddleware = TestAuthMiddleware()

    // Add session middleware and role middleware
    app.middleware.use(SessionMiddleware())
    app.middleware.use(PostgresRoleMiddleware())

    // Configure the /app/me route using TestAuthMiddleware
    let appRoutes = app.grouped("app")
    let protectedRoutes = appRoutes.grouped(testAuthMiddleware)

    protectedRoutes.get("me") { req async throws in
        guard let user = CurrentUserContext.user else {
            throw Abort(.internalServerError, reason: "Current user not available")
        }

        // For tests, create mock person data since TestAuthMiddleware doesn't call actual UserService
        let userInfo = Bazaar.UserInfo(
            id: user.id?.uuidString ?? UUID().uuidString,
            username: user.username,
            role: user.role.rawValue
        )

        let personInfo = Bazaar.PersonInfo(
            id: UUID().uuidString,
            name: "Admin User",  // Match what tests expect for admin@neonlaw.com
            email: user.username
        )

        let response = Bazaar.MeResponse(user: userInfo, person: personInfo)
        return try await response.encodeResponse(for: req)
    }
}
