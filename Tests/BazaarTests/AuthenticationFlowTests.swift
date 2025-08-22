import Dali
import TestUtilities
import Testing
import Vapor
import VaporElementary
import VaporTesting

@testable import Bazaar
@testable import Bouncer

@Suite("Authentication Flow Tests", .serialized)
struct AuthenticationFlowTests {

    @Test("Navigation shows login button when not authenticated")
    func navigationShowsLoginWhenNotAuthenticated() async throws {
        try await TestUtilities.withApp { app, database in
            try configureAuthFlowApp(app)

            try await app.test(.GET, "/") { response in
                #expect(response.status == .ok)

                let html = response.body.string
                #expect(html.contains("Log In"))
                #expect(!html.contains("Log Out"))
                #expect(!html.contains("Welcome,"))
            }
        }
    }

    @Test("Navigation shows logout button when authenticated")
    func navigationShowsLogoutWhenAuthenticated() async throws {
        try await TestUtilities.withApp { app, database in

            try configureAuthFlowApp(app)

            // Create a session to simulate logged in user
            let sessionId = "test-session-id"
            let testToken = "admin@neonlaw.com:valid-token"
            app.storage[SessionStorageKey.self] = [sessionId: testToken]

            // Make request with session cookie
            let headers = HTTPHeaders([("Cookie", "luxe-session=\(sessionId)")])

            try await app.test(.GET, "/", headers: headers) { response in
                #expect(response.status == .ok)

                let html = response.body.string
                #expect(html.contains("Welcome, admin@neonlaw.com"))
                #expect(html.contains("Log Out"))
                #expect(!html.contains("Log In"))
            }
        }
    }

    @Test("Protected route redirects to Keycloak when not authenticated")
    func protectedRouteRedirectsToKeycloakWhenNotAuthenticated() async throws {
        try await TestUtilities.withApp { app, database in
            try configureAuthFlowApp(app)

            try await app.test(.GET, "/app/me") { response in
                #expect(response.status == .seeOther)

                let location = response.headers.first(name: "location")
                #expect(location != nil)
                #expect(location == "/login?redirect=/app/me")
            }
        }
    }

    @Test("Logout route clears session and redirects to Keycloak logout")
    func logoutRouteClearsSessionAndRedirectsToKeycloak() async throws {
        try await TestUtilities.withApp { app, database in
            try configureAuthFlowApp(app)

            // Create a session first
            let sessionId = "test-session-id"
            let testToken = "admin@neonlaw.com:valid-token"
            app.storage[SessionStorageKey.self] = [sessionId: testToken]

            // Make logout request with session cookie
            let headers = HTTPHeaders([("Cookie", "luxe-session=\(sessionId)")])

            try await app.test(.GET, "/auth/logout", headers: headers) { response in
                #expect(response.status == .seeOther)

                // Should redirect to Keycloak logout endpoint
                let location = response.headers.first(name: "location")
                #expect(location != nil)
                #expect(location?.contains("protocol/openid-connect/logout") == true)
                #expect(location?.contains("post_logout_redirect_uri=http://localhost:8080/") == true)
                #expect(location?.contains("client_id=luxe-client") == true)

                // Should clear the session cookie
                let setCookie = response.headers.first(name: "set-cookie")
                #expect(setCookie != nil)
                #expect(setCookie?.contains("luxe-session=") == true)
                #expect(setCookie?.contains("Expires=") == true)
            }
        }
    }

    @Test("Logout clears server-side session storage")
    func logoutClearsServerSideSession() async throws {
        try await TestUtilities.withApp { app, database in
            try configureAuthFlowApp(app)

            // Create a session
            let sessionId = "test-session-id-123"
            let testToken = "admin@neonlaw.com:valid-token"
            app.storage[SessionStorageKey.self] = [sessionId: testToken]

            // Verify session exists
            #expect(app.storage[SessionStorageKey.self]?[sessionId] == testToken)

            // Make logout request with session cookie
            let headers = HTTPHeaders([("Cookie", "luxe-session=\(sessionId)")])

            try await app.test(.GET, "/auth/logout", headers: headers) { response in
                #expect(response.status == .seeOther)

                // Should redirect to Keycloak logout (not directly home anymore)
                let location = response.headers.first(name: "location")
                #expect(location != nil)
                #expect(location?.contains("protocol/openid-connect/logout") == true)
            }

            // Verify session is cleared from server storage
            #expect(app.storage[SessionStorageKey.self]?[sessionId] == nil)
        }
    }

    @Test("Session persists across requests")
    func sessionPersistsAcrossRequests() async throws {
        try await TestUtilities.withApp { app, database in
            try configureAuthFlowApp(app)

            // Create a session
            let sessionId = "test-session-id"
            let testToken = "admin@neonlaw.com:valid-token"
            app.storage[SessionStorageKey.self] = [sessionId: testToken]

            let headers = HTTPHeaders([("Cookie", "luxe-session=\(sessionId)")])

            // First request should work
            try await app.test(.GET, "/", headers: headers) { response in
                #expect(response.status == .ok)
                let html = response.body.string
                #expect(html.contains("Welcome, admin@neonlaw.com"))
            }

            // Second request should still work
            try await app.test(.GET, "/pricing", headers: headers) { response in
                #expect(response.status == .ok)
                let html = response.body.string
                #expect(html.contains("Welcome, admin@neonlaw.com"))
            }
        }
    }

    @Test("Invalid session is treated as not authenticated")
    func invalidSessionIsTreatedAsNotAuthenticated() async throws {
        try await TestUtilities.withApp { app, database in
            try configureAuthFlowApp(app)

            // Make request with invalid session cookie
            let headers = HTTPHeaders([("Cookie", "luxe-session=invalid-session-id")])

            try await app.test(.GET, "/app/me", headers: headers) { response in
                #expect(response.status == .seeOther || response.status == .unauthorized)
            }
        }
    }
}

// MARK: - Test Configuration

/// Configures the Bazaar application for AuthenticationFlowTests with proper authentication routes.
///
/// This function sets up the main application routes that the authentication flow tests depend on,
/// including home page, pricing, logout, and protected /app/me routes with proper authentication.
///
/// - Parameter app: The Vapor application to configure
/// - Throws: Configuration errors if setup fails
func configureAuthFlowApp(_ app: Application) throws {
    // Configure essential middleware
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))

    // Configure DALI models and database (must be done before any database usage)
    try configureDali(app)

    // Initialize session storage
    app.storage[SessionStorageKey.self] = [:]

    // Add session middleware
    app.middleware.use(SessionMiddleware())
    app.middleware.use(PostgresRoleMiddleware())

    // Create custom session-aware test auth middleware
    let sessionTestMiddleware = SessionTestAuthMiddleware()

    // Home route - shows login/logout based on authentication status
    let homeRoute = app.grouped(sessionTestMiddleware)
    homeRoute.get { req in
        HTMLResponse {
            HomePage(currentUser: CurrentUserContext.user)
        }
    }

    // Pricing route - shows user info when authenticated
    let pricingRoute = app.grouped(sessionTestMiddleware)
    pricingRoute.get("pricing") { req in
        HTMLResponse {
            PricingPage(currentUser: CurrentUserContext.user)
        }
    }

    // Protected /app/me route - requires authentication
    let appRoutes = app.grouped("app")
    let protectedAppRoutes = appRoutes.grouped(sessionTestMiddleware)
    protectedAppRoutes.get("me") { req async throws in
        guard let user = CurrentUserContext.user else {
            // No user means not authenticated - redirect to login
            return req.redirect(to: "/login?redirect=/app/me")
        }

        let userInfo = Bazaar.UserInfo(
            id: user.id?.uuidString ?? UUID().uuidString,
            username: user.username,
            role: user.role.rawValue
        )

        let personInfo = Bazaar.PersonInfo(
            id: UUID().uuidString,
            name: "Admin User",
            email: user.username
        )

        let response = Bazaar.MeResponse(user: userInfo, person: personInfo)
        return try await response.encodeResponse(for: req)
    }

    // Logout route - clears session and redirects
    app.get("auth", "logout") { req -> Response in
        // Clear the session from server storage
        if let sessionId = req.cookies["luxe-session"]?.string {
            if var sessions = req.application.storage[SessionStorageKey.self] {
                AuthService.clearSession(sessionId: sessionId, from: &sessions)
                req.application.storage[SessionStorageKey.self] = sessions
            }
        }

        // Get OIDC configuration and build logout URL
        let oidcConfig = OIDCConfiguration.create(from: req.application.environment)
        let logoutURL = AuthService.buildLogoutURL(oidcConfig: oidcConfig)

        // Clear the session cookie and redirect
        let response = req.redirect(to: logoutURL)
        response.cookies["luxe-session"] = AuthService.createLogoutCookie()
        return response
    }
}

/// Test authentication middleware that handles both session cookies and Bearer tokens.
///
/// This middleware is designed specifically for AuthenticationFlow tests that need to test
/// session-based authentication behavior in a transaction-safe environment.
struct SessionTestAuthMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // First check for Bearer token (like TestAuthMiddleware)
        if let authorization = request.headers.bearerAuthorization {
            let mockUser = try createMockUserFromToken(authorization.token, logger: request.logger)
            return try await CurrentUserContext.$user.withValue(mockUser) {
                try await next.respond(to: request)
            }
        }

        // Then check for session cookie
        if let sessionId = request.cookies["luxe-session"]?.string {
            if let sessionToken = request.application.storage[SessionStorageKey.self]?[sessionId] {
                let mockUser = try createMockUserFromToken(sessionToken, logger: request.logger)
                return try await CurrentUserContext.$user.withValue(mockUser) {
                    try await next.respond(to: request)
                }
            }
        }

        // No authentication found - continue without user context
        return try await next.respond(to: request)
    }

    private func createMockUserFromToken(_ token: String, logger: Logger) throws -> User {
        let username: String
        let role: UserRole

        if token.hasPrefix("admin@neonlaw.com:") || token == "admin@neonlaw.com:valid-token" {
            username = "admin@neonlaw.com"
            role = .admin
        } else if token.hasPrefix("teststaff@example.com:") {
            username = "teststaff@example.com"
            role = .staff
        } else {
            username = "test-user-123"
            role = .customer
        }

        // Create mock User object
        let mockUser = User()
        mockUser.id = UUID()
        mockUser.username = username
        mockUser.sub = username
        mockUser.role = role

        logger.info("✅ SessionTestAuth created mock user - username: \(username), role: \(role)")
        return mockUser
    }
}
