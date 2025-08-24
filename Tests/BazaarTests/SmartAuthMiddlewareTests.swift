import Dali
import TestUtilities
import Testing
import Vapor

@testable import Bazaar
@testable import Bouncer

@Suite("SmartAuthMiddleware Tests", .serialized)
struct SmartAuthMiddlewareTests {

    /// Mock ALB authenticator for testing SmartAuthMiddleware
    struct MockALBAuthenticator: ALBAuthenticatorProtocol {
        let configuration: OIDCConfiguration

        init(configuration: OIDCConfiguration) {
            self.configuration = configuration
        }

        func authenticate(request: Request) async throws {
            // Check for ALB authentication headers
            guard let identity = request.headers.first(name: "X-Amzn-Oidc-Identity") else {
                throw Abort(.unauthorized, reason: "Authentication required")
            }

            guard !identity.isEmpty else {
                throw Abort(.unauthorized, reason: "Invalid authentication")
            }

            // Create mock user based on identity
            let role: UserRole =
                if identity == "admin@neonlaw.com" {
                    .admin
                } else if identity.contains("staff") {
                    .staff
                } else {
                    .customer
                }

            let mockUser = User()
            mockUser.id = UUID()
            mockUser.username = identity
            mockUser.sub = identity
            mockUser.role = role

            request.auth.login(mockUser)
            request.logger.info("✅ Mock ALB auth created user: \(identity), role: \(role)")
        }
    }

    /// Creates a test application with SmartAuthMiddleware configured
    func configureApp(_ app: Application) async throws {
        // Configure essential middleware
        app.middleware.use(ErrorMiddleware.default(environment: app.environment))

        // Configure DALI models and database
        try configureDali(app)

        // Create mock OIDC configuration for testing
        let mockConfig = OIDCConfiguration(
            issuer: "http://localhost:9090/realms/luxe",
            clientId: "luxe-client",
            audienceId: "luxe-client"
        )

        // Create mock ALB authenticator
        let authenticator = MockALBAuthenticator(configuration: mockConfig)

        // Create SmartAuthMiddleware with default patterns
        let smartAuth = SmartAuthMiddleware(authenticator: authenticator)

        // Public routes (should not require authentication)
        app.get { req in "public root" }
        app.get("pricing") { req in "public pricing" }
        app.get("blog") { req in "public blog" }
        app.get("about") { req in "public about" }
        app.get("contact") { req in "public contact" }

        // Apply middleware to all routes
        let protectedRoutes = app.grouped(smartAuth)

        // Protected app routes (should require authentication)
        protectedRoutes.get("app") { req in "app root" }
        protectedRoutes.get("app", "me") { req in "app me" }
        protectedRoutes.get("app", "dashboard") { req in "app dashboard" }
        protectedRoutes.get("app", "settings") { req in "app settings" }

        // Protected API routes (should require authentication)
        protectedRoutes.get("api") { req in "api root" }
        protectedRoutes.get("api", "me") { req in "api me" }
        protectedRoutes.get("api", "users") { req in "api users" }
        protectedRoutes.get("api", "data") { req in "api data" }

        // Admin routes (should require admin role)
        protectedRoutes.get("admin") { req in "admin root" }
        protectedRoutes.get("admin", "users") { req in "admin users" }
        protectedRoutes.get("api", "admin", "settings") { req in "api admin settings" }

        // Staff routes (should require staff role)
        protectedRoutes.get("staff") { req in "staff root" }
        protectedRoutes.get("staff", "reports") { req in "staff reports" }
        protectedRoutes.get("api", "staff", "data") { req in "api staff data" }
        protectedRoutes.get("reports") { req in "reports root" }
    }

    @Test("Public routes should not require authentication")
    func publicRoutesDoNotRequireAuthentication() async throws {
        try await TestUtilities.withApp { app, database in
            try await configureApp(app)

            let publicRoutes = ["/", "/pricing", "/blog", "/about", "/contact"]

            for route in publicRoutes {
                try await app.test(.GET, route) { response in
                    #expect(response.status == .ok, "Route \(route) should be accessible without authentication")
                }
            }
        }
    }

    @Test("App routes should require authentication")
    func appRoutesRequireAuthentication() async throws {
        try await TestUtilities.withApp { app, database in
            try await configureApp(app)

            let appRoutes = ["/app", "/app/me", "/app/dashboard", "/app/settings"]

            // Without authentication, should get unauthorized
            for route in appRoutes {
                try await app.test(.GET, route) { response in
                    #expect(response.status == .unauthorized, "Route \(route) should require authentication")
                }
            }

            // With valid ALB headers, should work
            let validHeaders = TestUtilities.createMockALBHeaders(
                sub: "test-customer-sub",
                email: "test@example.com",
                name: "Test Customer",
                groups: ["users"]
            )

            for route in appRoutes {
                try await app.test(.GET, route, headers: validHeaders) { response in
                    #expect(response.status == .ok, "Route \(route) should work with valid authentication")
                }
            }
        }
    }

    @Test("API routes should require authentication")
    func apiRoutesRequireAuthentication() async throws {
        try await TestUtilities.withApp { app, database in
            try await configureApp(app)

            let apiRoutes = ["/api", "/api/me", "/api/users", "/api/data"]

            // Without authentication, should get unauthorized
            for route in apiRoutes {
                try await app.test(.GET, route) { response in
                    #expect(response.status == .unauthorized, "Route \(route) should require authentication")
                }
            }

            // With valid ALB headers, should work
            let validHeaders = TestUtilities.createMockALBHeaders(
                sub: "test-customer-sub",
                email: "test@example.com",
                name: "Test Customer",
                groups: ["users"]
            )

            for route in apiRoutes {
                try await app.test(.GET, route, headers: validHeaders) { response in
                    #expect(response.status == .ok, "Route \(route) should work with valid authentication")
                }
            }
        }
    }

    @Test("Admin routes should require admin role")
    func adminRoutesRequireAdminRole() async throws {
        try await TestUtilities.withApp { app, database in
            try await configureApp(app)

            let adminRoutes = ["/admin", "/admin/users", "/api/admin/settings"]

            // Regular user should get forbidden
            let userHeaders = TestUtilities.createMockALBCustomerHeaders(
                sub: "customer-user-sub",
                email: "user@example.com",
                name: "Regular User"
            )

            for route in adminRoutes {
                try await app.test(.GET, route, headers: userHeaders) { response in
                    #expect(response.status == .forbidden, "Route \(route) should deny access to non-admin users")
                }
            }

            // Admin user should have access
            let adminHeaders = TestUtilities.createMockALBAdminHeaders(
                sub: "admin-user-sub",
                email: "admin@neonlaw.com",
                name: "Admin User"
            )

            for route in adminRoutes {
                try await app.test(.GET, route, headers: adminHeaders) { response in
                    #expect(response.status == .ok, "Route \(route) should allow access to admin users")
                }
            }
        }
    }

    @Test("Staff routes should require staff role or higher")
    func staffRoutesRequireStaffRole() async throws {
        try await TestUtilities.withApp { app, database in
            try await configureApp(app)

            let staffRoutes = ["/staff", "/staff/reports", "/api/staff/data", "/reports"]

            // Regular user should get forbidden
            let userHeaders = TestUtilities.createMockALBCustomerHeaders(
                sub: "customer-user-sub",
                email: "user@example.com",
                name: "Regular User"
            )

            for route in staffRoutes {
                try await app.test(.GET, route, headers: userHeaders) { response in
                    #expect(response.status == .forbidden, "Route \(route) should deny access to regular users")
                }
            }

            // Staff user should have access
            let staffHeaders = TestUtilities.createMockALBStaffHeaders(
                sub: "staff-user-sub",
                email: "staff@example.com",
                name: "Staff User"
            )

            for route in staffRoutes {
                try await app.test(.GET, route, headers: staffHeaders) { response in
                    #expect(response.status == .ok, "Route \(route) should allow access to staff users")
                }
            }

            // Admin should also have access (higher role)
            let adminHeaders = TestUtilities.createMockALBAdminHeaders(
                sub: "admin-user-sub",
                email: "admin@neonlaw.com",
                name: "Admin User"
            )

            for route in staffRoutes {
                try await app.test(.GET, route, headers: adminHeaders) { response in
                    #expect(response.status == .ok, "Route \(route) should allow access to admin users")
                }
            }
        }
    }

    @Test("Custom admin patterns should work correctly")
    func customAdminPatternsWorkCorrectly() async throws {
        try await TestUtilities.withApp { app, database in
            // Configure essential middleware
            app.middleware.use(ErrorMiddleware.default(environment: app.environment))
            try configureDali(app)

            // Create SmartAuthMiddleware with custom admin patterns
            let mockConfig = OIDCConfiguration(
                issuer: "http://localhost:9090/realms/luxe",
                clientId: "luxe-client",
                audienceId: "luxe-client"
            )
            let authenticator = MockALBAuthenticator(configuration: mockConfig)
            let smartAuth = SmartAuthMiddleware(
                authenticator: authenticator,
                adminPatterns: ["/api/super-admin", "/management"],
                staffPatterns: ["/api/moderator"]
            )

            app.middleware.use(smartAuth)

            // Add test routes
            app.get("api", "super-admin") { req in "custom admin route" }
            app.get("management") { req in "management route" }
            app.get("api", "moderator") { req in "custom staff route" }

            // Regular user should be denied access to custom admin routes
            let userHeaders = HTTPHeaders([
                ("X-Amzn-Oidc-Identity", "user@example.com"),
                ("X-Amzn-Oidc-Accesstoken", "valid-token"),
            ])

            try await app.test(.GET, "/api/super-admin", headers: userHeaders) { response in
                #expect(response.status == .forbidden)
            }

            try await app.test(.GET, "/management", headers: userHeaders) { response in
                #expect(response.status == .forbidden)
            }

            // Admin should have access
            let adminHeaders = HTTPHeaders([
                ("X-Amzn-Oidc-Identity", "admin@neonlaw.com"),
                ("X-Amzn-Oidc-Accesstoken", "admin-token"),
            ])

            try await app.test(.GET, "/api/super-admin", headers: adminHeaders) { response in
                #expect(response.status == .ok)
            }

            try await app.test(.GET, "/management", headers: adminHeaders) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test("Invalid authentication should be rejected")
    func invalidAuthenticationShouldBeRejected() async throws {
        try await TestUtilities.withApp { app, database in
            try await configureApp(app)

            let protectedRoutes = ["/app/me", "/api/users"]

            // Missing headers
            for route in protectedRoutes {
                try await app.test(.GET, route) { response in
                    #expect(response.status == .unauthorized)
                }
            }

            // Invalid headers
            let invalidHeaders = HTTPHeaders([
                ("X-Amzn-Oidc-Identity", ""),  // Empty identity
                ("X-Amzn-Oidc-Accesstoken", "invalid-token"),
            ])

            for route in protectedRoutes {
                try await app.test(.GET, route, headers: invalidHeaders) { response in
                    #expect(response.status == .unauthorized)
                }
            }
        }
    }

    @Test("Middleware should set current user context correctly")
    func middlewareShouldSetCurrentUserContext() async throws {
        try await TestUtilities.withApp { app, database in
            // Configure essential middleware
            app.middleware.use(ErrorMiddleware.default(environment: app.environment))
            try configureDali(app)

            // Create mock OIDC configuration and authenticator
            let mockConfig = OIDCConfiguration(
                issuer: "http://localhost:9090/realms/luxe",
                clientId: "luxe-client",
                audienceId: "luxe-client"
            )
            let authenticator = MockALBAuthenticator(configuration: mockConfig)
            let smartAuth = SmartAuthMiddleware(authenticator: authenticator)

            // Add a route that returns current user info - group it with middleware
            let protectedRoutes = app.grouped(smartAuth)
            protectedRoutes.get("app", "current-user") { req -> String in
                req.logger.info("🔍 Checking current user context...")

                // Try both CurrentUserContext and request.auth
                if let contextUser = CurrentUserContext.user {
                    req.logger.info("✅ User context found: \(contextUser.username)")
                    return "User: \(contextUser.username), Role: \(contextUser.role)"
                } else if let authUser = req.auth.get(User.self) {
                    req.logger.info("✅ User auth found: \(authUser.username)")
                    return "User: \(authUser.username), Role: \(authUser.role)"
                } else {
                    req.logger.error("❌ No user context or auth found")
                    throw Abort(.internalServerError, reason: "User context not set")
                }
            }

            let headers = HTTPHeaders([
                ("X-Amzn-Oidc-Identity", "test@example.com"),
                ("X-Amzn-Oidc-Accesstoken", "valid-token"),
            ])

            try await app.test(.GET, "/app/current-user", headers: headers) { response in
                #expect(response.status == .ok)
                let body = response.body.string
                #expect(body.contains("test@example.com"))
            }
        }
    }

    @Test("Edge cases in path matching should work correctly")
    func edgeCasesInPathMatching() async throws {
        try await TestUtilities.withApp { app, database in
            // Configure essential middleware
            app.middleware.use(ErrorMiddleware.default(environment: app.environment))
            try configureDali(app)

            // Create mock OIDC configuration and authenticator
            let mockConfig = OIDCConfiguration(
                issuer: "http://localhost:9090/realms/luxe",
                clientId: "luxe-client",
                audienceId: "luxe-client"
            )
            let authenticator = MockALBAuthenticator(configuration: mockConfig)
            let smartAuth = SmartAuthMiddleware(authenticator: authenticator)

            // Add edge case routes - these should be public (no SmartAuth middleware)
            app.get("application") { req in "application route" }  // Should not match /app prefix
            app.get("apps") { req in "apps route" }  // Should not match /app prefix
            app.get("apikey") { req in "apikey route" }  // Should not match /api prefix
            app.get("apis") { req in "apis route" }  // Should not match /api prefix

            // Add protected routes through middleware
            let protectedRoutes = app.grouped(smartAuth)
            protectedRoutes.get("app") { req in "app root" }
            protectedRoutes.get("api") { req in "api root" }

            // These should be public (no authentication required)
            let edgeCaseRoutes = ["/application", "/apps", "/apikey", "/apis"]

            for route in edgeCaseRoutes {
                try await app.test(.GET, route) { response in
                    #expect(response.status == .ok, "Route \(route) should be public")
                }
            }
        }
    }
}
