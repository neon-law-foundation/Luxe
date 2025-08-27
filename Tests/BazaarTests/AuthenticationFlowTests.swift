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

            // Use header-based auth for testing
            let mockHeaders = MockALBHeaders.adminUser()
            let headers = mockHeaders.httpHeaders

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

    @Test("Logout route redirects to Keycloak logout")
    func logoutRouteRedirectsToKeycloak() async throws {
        try await TestUtilities.withApp { app, database in
            try configureAuthFlowApp(app)

            // Use ALB headers for authentication
            let mockHeaders = MockALBHeaders.adminUser()
            let headers = mockHeaders.httpHeaders

            try await app.test(.GET, "/auth/logout", headers: headers) { response in
                #expect(response.status == .seeOther)

                // Should redirect to Keycloak logout endpoint
                let location = response.headers.first(name: "location")
                #expect(location != nil)
                #expect(location?.contains("protocol/openid-connect/logout") == true)
                #expect(location?.contains("post_logout_redirect_uri=http://localhost:8080/") == true)
                #expect(location?.contains("client_id=luxe-client") == true)
            }
        }
    }

    @Test("Logout redirects authenticated users to Keycloak")
    func logoutRedirectsAuthenticatedUsersToKeycloak() async throws {
        try await TestUtilities.withApp { app, database in
            try configureAuthFlowApp(app)

            // Use ALB headers for authentication
            let mockHeaders = MockALBHeaders.adminUser()
            let headers = mockHeaders.httpHeaders

            try await app.test(.GET, "/auth/logout", headers: headers) { response in
                #expect(response.status == .seeOther)

                // Should redirect to Keycloak logout
                let location = response.headers.first(name: "location")
                #expect(location != nil)
                #expect(location?.contains("protocol/openid-connect/logout") == true)
            }
        }
    }

    @Test("ALB headers work across requests")
    func albHeadersWorkAcrossRequests() async throws {
        try await TestUtilities.withApp { app, database in
            try configureAuthFlowApp(app)

            // Use ALB headers for authentication
            let mockHeaders = MockALBHeaders.adminUser()
            let headers = mockHeaders.httpHeaders

            // First request should work
            try await app.test(.GET, "/", headers: headers) { response in
                #expect(response.status == .ok)
                let html = response.body.string
                #expect(html.contains("Welcome, admin@neonlaw.com"))
            }

            // Second request should also work with same headers
            try await app.test(.GET, "/pricing", headers: headers) { response in
                #expect(response.status == .ok)
                let html = response.body.string
                #expect(html.contains("Welcome, admin@neonlaw.com"))
            }
        }
    }

    @Test("Invalid ALB headers are treated as not authenticated")
    func invalidALBHeadersAreTreatedAsNotAuthenticated() async throws {
        try await TestUtilities.withApp { app, database in
            try configureAuthFlowApp(app)

            // Make request with malformed ALB headers
            let malformedHeaders = TestUtilities.createMalformedALBHeaders()

            try await app.test(.GET, "/app/me", headers: malformedHeaders) { response in
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

    app.middleware.use(PostgresRoleMiddleware())

    // Create custom ALB-aware test auth middleware
    let albTestMiddleware = ALBTestAuthMiddleware()

    // Home route - shows login/logout based on authentication status
    let homeRoute = app.grouped(albTestMiddleware)
    homeRoute.get { req in
        HTMLResponse {
            HomePage(currentUser: CurrentUserContext.user)
        }
    }

    // Pricing route - shows user info when authenticated
    let pricingRoute = app.grouped(albTestMiddleware)
    pricingRoute.get("pricing") { req in
        HTMLResponse {
            PricingPage(currentUser: CurrentUserContext.user)
        }
    }

    // Protected /app/me route - requires authentication
    let appRoutes = app.grouped("app")
    let protectedAppRoutes = appRoutes.grouped(albTestMiddleware)
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

    // Logout route - redirects to Keycloak logout
    app.get("auth", "logout") { req -> Response in
        // Get OIDC configuration and build logout URL
        let oidcConfig = OIDCConfiguration.create(from: req.application.environment)
        let logoutURL = AuthService.buildLogoutURL(oidcConfig: oidcConfig)

        // Redirect to Keycloak logout (no session handling needed)
        return req.redirect(to: logoutURL)
    }
}

/// Test authentication middleware that handles ALB headers and Bearer tokens.
///
/// This middleware is designed specifically for AuthenticationFlow tests that need to test
/// ALB header-based authentication behavior in a transaction-safe environment.
struct ALBTestAuthMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // First check for Bearer token
        if let authorization = request.headers.bearerAuthorization {
            let mockUser = try createMockUserFromToken(authorization.token, logger: request.logger)
            return try await CurrentUserContext.$user.withValue(mockUser) {
                try await next.respond(to: request)
            }
        }

        // Check for ALB OIDC headers
        if let oidcData = request.headers.first(name: "x-amzn-oidc-data") {
            let mockUser = try createMockUserFromALBHeaders(
                oidcData: oidcData,
                request: request,
                logger: request.logger
            )
            return try await CurrentUserContext.$user.withValue(mockUser) {
                try await next.respond(to: request)
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

        logger.info("✅ ALBTestAuth created mock user from token - username: \(username), role: \(role)")
        return mockUser
    }

    private func createMockUserFromALBHeaders(oidcData: String, request: Request, logger: Logger) throws -> User {
        // Check for obviously malformed headers
        if oidcData == "invalid-base64-data" {
            throw Abort(.unauthorized, reason: "Malformed OIDC data")
        }

        // Extract email from ALB headers or use identity header
        let username = request.headers.first(name: "x-amzn-oidc-identity") ?? "test@example.com"

        // Check for malformed identity
        if username == "malformed-identity" {
            throw Abort(.unauthorized, reason: "Malformed identity header")
        }

        // Determine role based on email/groups
        let role: UserRole = username.contains("admin@neonlaw.com") ? .admin : .customer

        // Create mock User object
        let mockUser = User()
        mockUser.id = UUID()
        mockUser.username = username
        mockUser.sub = username
        mockUser.role = role

        logger.info("✅ ALBTestAuth created mock user from ALB headers - username: \(username), role: \(role)")
        return mockUser
    }
}
