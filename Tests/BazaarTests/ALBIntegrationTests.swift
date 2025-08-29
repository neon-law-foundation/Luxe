import Dali
import TestUtilities
import Testing
import Vapor

@testable import Bazaar
@testable import Bouncer

@Suite("ALB Integration Tests", .serialized)
struct ALBIntegrationTests {

    /// Configures a test application with actual ALBHeaderAuthenticator for integration testing
    func configureALBApp(_ app: Application) async throws -> RoutesBuilder {
        // Configure essential middleware
        app.middleware.use(ErrorMiddleware.default(environment: app.environment))

        // Configure DALI models and database
        try configureDali(app)

        // Create OIDC configuration for testing
        let testConfig = OIDCConfiguration(
            issuer: "https://cognito-idp.us-west-2.amazonaws.com/us-west-2_TestPool",
            clientId: "test-client",
            audienceId: "test-audience"
        )

        // Create ALBHeaderAuthenticator (not mock - real authenticator)
        let albAuthenticator = ALBHeaderAuthenticator(configuration: testConfig)

        // Create SmartAuthMiddleware with real ALB authenticator
        let smartAuth = SmartAuthMiddleware(authenticator: albAuthenticator)

        // Public routes (no middleware)
        app.get { req in "public home" }
        app.get("health") { req in "public health" }
        app.get("pricing") { req in "public pricing" }
        app.get("about") { req in "public about" }

        // Protected routes with SmartAuthMiddleware
        let protected = app.grouped(smartAuth)

        // App routes - require authentication
        protected.get("app") { req in
            guard let user = req.auth.get(User.self) else {
                throw Abort(.unauthorized)
            }
            return "app home - user: \(user.username)"
        }

        protected.get("app", "me") { req in
            guard let user = req.auth.get(User.self) else {
                throw Abort(.unauthorized)
            }
            return "app me - user: \(user.username), role: \(user.role.rawValue)"
        }

        protected.get("app", "dashboard") { req in
            guard let user = req.auth.get(User.self) else {
                throw Abort(.unauthorized)
            }
            return "app dashboard - user: \(user.username)"
        }

        // API routes - require authentication
        protected.get("api", "users") { req in
            guard let user = req.auth.get(User.self) else {
                throw Abort(.unauthorized)
            }
            return "api users - authenticated as: \(user.username)"
        }

        // Admin routes - require admin role
        protected.get("admin") { req in
            guard let user = req.auth.get(User.self) else {
                throw Abort(.unauthorized)
            }
            guard user.role == .admin else {
                throw Abort(.forbidden)
            }
            return "admin dashboard - admin: \(user.username)"
        }

        protected.get("admin", "users") { req in
            guard let user = req.auth.get(User.self) else {
                throw Abort(.unauthorized)
            }
            guard user.role == .admin else {
                throw Abort(.forbidden)
            }
            return "admin users - admin: \(user.username)"
        }

        return protected
    }

    @Test("Public routes should not require ALB headers")
    func publicRoutesWithoutALBHeaders() async throws {
        try await TestUtilities.withApp { app, database in
            _ = try await configureALBApp(app)

            let publicRoutes = ["/", "/health", "/pricing", "/about"]

            for route in publicRoutes {
                try await app.test(.GET, route) { response in
                    #expect(response.status == .ok, "Public route \(route) should be accessible without ALB headers")
                    #expect(response.body.string.hasPrefix("public"), "Should return public content")
                }
            }
        }
    }

    @Test(
        "Protected routes should require valid ALB headers",
        .disabled(
            if: ProcessInfo.processInfo.environment["CI"] != nil,
            "Disabled for CI due to database connection timeout issues"
        )
    )
    func protectedRoutesRequireALBHeaders() async throws {
        try await TestUtilities.withApp { app, database in
            _ = try await configureALBApp(app)

            // Create test user using app.db for visibility to handlers
            try await TestUtilities.createTestUser(
                app.db,  // Use app.db so handlers can see the user
                name: "Test User",
                email: "test@example.com",
                username: "test@example.com",
                role: "customer",
                sub: "test-cognito-sub"
            )

            let protectedRoutes = ["/app", "/app/me", "/app/dashboard", "/api/users"]

            // Without ALB headers should be unauthorized
            for route in protectedRoutes {
                try await app.test(.GET, route) { response in
                    #expect(response.status == .unauthorized, "Route \(route) should require authentication")
                }
            }

            // With valid ALB headers should work
            let validHeaders = TestUtilities.createMockALBHeaders(
                sub: "test-cognito-sub",
                email: "test@example.com",
                name: "Test User",
                groups: ["users"],
                username: "test@example.com"
            )

            for route in protectedRoutes {
                try await app.test(.GET, route, headers: validHeaders) { response in
                    #expect(response.status == .ok, "Route \(route) should work with valid ALB headers")
                    let body = response.body.string
                    #expect(body.contains("test@example.com"), "Response should contain authenticated user info")
                }
            }
        }
    }

    @Test(
        "Admin routes should require admin role in ALB headers",
        .disabled(
            if: ProcessInfo.processInfo.environment["CI"] != nil,
            "Disabled for CI due to database connection timeout issues"
        )
    )
    func adminRoutesRequireAdminRole() async throws {
        try await TestUtilities.withApp { app, database in
            _ = try await configureALBApp(app)

            // Create regular user with matching sub using app.db
            try await TestUtilities.createTestUser(
                app.db,  // Use app.db so handlers can see the user
                name: "Regular User",
                email: "user@example.com",
                username: "user@example.com",
                role: "customer",
                sub: "user-cognito-sub"
            )

            // Create admin user with matching sub using app.db
            try await TestUtilities.createTestUser(
                app.db,  // Use app.db so handlers can see the user
                name: "Admin User",
                email: "admin@neonlaw.com",
                username: "admin@neonlaw.com",
                role: "admin",
                sub: "admin-cognito-sub"
            )

            let adminRoutes = ["/admin", "/admin/users"]

            // Regular user with valid headers should get forbidden
            let userHeaders = TestUtilities.createMockALBHeaders(
                sub: "user-cognito-sub",
                email: "user@example.com",
                name: "Regular User",
                groups: ["users"],
                username: "user@example.com"
            )

            for route in adminRoutes {
                try await app.test(.GET, route, headers: userHeaders) { response in
                    #expect(response.status == .forbidden, "Admin route \(route) should deny regular users")
                }
            }

            // Admin user should have access
            let adminHeaders = TestUtilities.createMockALBAdminHeaders(
                sub: "admin-cognito-sub",
                email: "admin@neonlaw.com",
                name: "Admin User"
            )

            for route in adminRoutes {
                try await app.test(.GET, route, headers: adminHeaders) { response in
                    #expect(response.status == .ok, "Admin route \(route) should allow admin users")
                    let body = response.body.string
                    #expect(body.contains("admin@neonlaw.com"), "Response should contain admin user info")
                }
            }
        }
    }

    @Test(
        "Invalid ALB headers should be rejected",
        .disabled(
            if: ProcessInfo.processInfo.environment["CI"] != nil,
            "Disabled for CI due to database connection timeout issues"
        )
    )
    func invalidALBHeadersRejected() async throws {
        try await TestUtilities.withApp { app, database in
            _ = try await configureALBApp(app)

            let protectedRoute = "/app/me"

            // Test with malformed ALB headers
            let malformedHeaders = TestUtilities.createMalformedALBHeaders()

            try await app.test(.GET, protectedRoute, headers: malformedHeaders) { response in
                #expect(response.status == .unauthorized, "Malformed ALB headers should be rejected")
            }

            // Test with expired ALB headers
            let expiredHeaders = TestUtilities.createExpiredALBHeaders()

            try await app.test(.GET, protectedRoute, headers: expiredHeaders) { response in
                #expect(response.status == .unauthorized, "Expired ALB headers should be rejected")
            }
        }
    }

    @Test(
        "ALB headers with non-existent user should be rejected",
        .disabled(
            if: ProcessInfo.processInfo.environment["CI"] != nil,
            "Disabled for CI due to database connection timeout issues"
        )
    )
    func nonExistentUserRejected() async throws {
        try await TestUtilities.withApp { app, database in
            _ = try await configureALBApp(app)

            // Create headers for user that doesn't exist in database
            let nonExistentUserHeaders = TestUtilities.createMockALBHeaders(
                sub: "non-existent-sub",
                email: "nonexistent@example.com",
                name: "Non Existent User",
                groups: ["users"],
                username: "nonexistent@example.com"
            )

            try await app.test(.GET, "/app/me", headers: nonExistentUserHeaders) { response in
                #expect(response.status == .unauthorized, "Non-existent user should be rejected")
            }
        }
    }

    @Test(
        "ALB authentication should set correct user context",
        .disabled(
            if: ProcessInfo.processInfo.environment["CI"] != nil,
            "Disabled for CI due to database connection timeout issues"
        )
    )
    func albAuthenticationSetsUserContext() async throws {
        try await TestUtilities.withApp { app, database in
            _ = try await configureALBApp(app)

            // Create test user with matching sub using app's database
            _ = try await TestUtilities.createTestUser(
                app.db,  // Use app's database
                name: "Context Test User",
                email: "context@example.com",
                username: "context@example.com",
                role: "staff",
                sub: "context-cognito-sub"
            )

            let contextHeaders = TestUtilities.createMockALBHeaders(
                sub: "context-cognito-sub",
                email: "context@example.com",
                name: "Context Test User",
                groups: ["staff", "employees"],
                username: "context@example.com"
            )

            // Test authentication by verifying user context is set correctly
            try await app.test(.GET, "/app", headers: contextHeaders) { response in
                #expect(response.status == .ok)

                // /app route returns: "app home - user: \(user.username)"
                let responseBody = response.body.string
                #expect(
                    responseBody.contains("context@example.com"),
                    "Response should contain authenticated user's email"
                )
                #expect(responseBody.contains("app home - user:"), "Response should be from /app route")
            }
        }
    }
}
