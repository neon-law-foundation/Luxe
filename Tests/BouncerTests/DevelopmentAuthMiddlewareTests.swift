import Bouncer
import Dali
import TestUtilities
import Testing
import Vapor
import VaporTesting

@Suite("Development Auth Middleware Tests", .serialized)
struct DevelopmentAuthMiddlewareTests {

    @Test("URL parameter auth switching - admin mode")
    func urlParameterAuthAdmin() async throws {
        try await TestUtilities.withApp { app, database in
            try await setupTestApp(app)

            try await app.test(.GET, "/app/me?auth=admin") { response in
                #expect(response.status == .ok)

                // Check debug headers
                #expect(response.headers.first(name: "x-dev-auth-processed") == "true")
                #expect(response.headers.first(name: "x-dev-auth-mode") == "admin")
                #expect(response.headers.first(name: "x-dev-auth-role") == "admin")

                // Verify user is authenticated as admin
                let body = response.body.string
                #expect(body.contains("admin@neonlaw.com") || body.contains("dev-admin@neonlaw.com"))
            }
        }
    }

    @Test("URL parameter auth switching - staff mode")
    func urlParameterAuthStaff() async throws {
        try await TestUtilities.withApp { app, database in
            try await setupTestApp(app)

            try await app.test(.GET, "/app/me?auth=staff") { response in
                #expect(response.status == .ok)

                // Check debug headers
                #expect(response.headers.first(name: "x-dev-auth-processed") == "true")
                #expect(response.headers.first(name: "x-dev-auth-mode") == "staff")
                #expect(response.headers.first(name: "x-dev-auth-role") == "staff")

                // Verify user is authenticated as staff
                let body = response.body.string
                #expect(body.contains("staff@neonlaw.com") || body.contains("dev-staff@neonlaw.com"))
            }
        }
    }

    @Test("URL parameter auth switching - customer mode")
    func urlParameterAuthCustomer() async throws {
        try await TestUtilities.withApp { app, database in
            try await setupTestApp(app)

            try await app.test(.GET, "/app/me?auth=customer") { response in
                #expect(response.status == .ok)

                // Check debug headers
                #expect(response.headers.first(name: "x-dev-auth-processed") == "true")
                #expect(response.headers.first(name: "x-dev-auth-mode") == "customer")
                #expect(response.headers.first(name: "x-dev-auth-role") == "customer")

                // Verify user is authenticated as customer
                let body = response.body.string
                #expect(body.contains("customer@example.com") || body.contains("dev-customer@example.com"))
            }
        }
    }

    @Test("URL parameter auth switching - none mode")
    func urlParameterAuthNone() async throws {
        try await TestUtilities.withApp { app, database in
            try await setupTestApp(app)

            try await app.test(.GET, "/app/me?auth=none") { response in
                // Should be unauthorized since /app/me requires auth
                #expect(response.status == .unauthorized)

                // Check debug headers
                #expect(response.headers.first(name: "x-dev-auth-processed") == "true")
                #expect(response.headers.first(name: "x-dev-auth-mode") == "none")
            }
        }
    }

    @Test("Route-based auto-detection - admin routes")
    func routeBasedAutoDetectionAdmin() async throws {
        try await TestUtilities.withApp { app, database in
            try await setupTestApp(app)

            // Add a test admin route
            app.get("admin", "test") { req -> String in
                guard let user = req.auth.get(User.self) else {
                    throw Abort(.unauthorized)
                }
                return "Admin route accessed by: \(user.username)"
            }

            try await app.test(.GET, "/admin/test") { response in
                // Admin routes should auto-detect admin auth
                #expect(response.status == .ok)

                let body = response.body.string
                #expect(body.contains("dev-admin@neonlaw.com"))
            }
        }
    }

    @Test("Route-based auto-detection - staff routes")
    func routeBasedAutoDetectionStaff() async throws {
        try await TestUtilities.withApp { app, database in
            try await setupTestApp(app)

            // Add a test staff route
            app.get("staff", "test") { req -> String in
                guard let user = req.auth.get(User.self) else {
                    throw Abort(.unauthorized)
                }
                return "Staff route accessed by: \(user.username)"
            }

            try await app.test(.GET, "/staff/test") { response in
                // Staff routes should auto-detect staff auth
                #expect(response.status == .ok)

                let body = response.body.string
                #expect(body.contains("dev-staff@neonlaw.com"))
            }
        }
    }

    @Test("Route-based auto-detection - customer routes")
    func routeBasedAutoDetectionCustomer() async throws {
        try await TestUtilities.withApp { app, database in
            try await setupTestApp(app)

            // Add a test API route
            app.get("api", "test") { req -> String in
                guard let user = req.auth.get(User.self) else {
                    throw Abort(.unauthorized)
                }
                return "API route accessed by: \(user.username)"
            }

            try await app.test(.GET, "/api/test") { response in
                // API routes should auto-detect customer auth
                #expect(response.status == .ok)

                let body = response.body.string
                #expect(body.contains("dev-customer@example.com"))
            }
        }
    }

    @Test("Public routes remain accessible without auth")
    func publicRoutesAccessible() async throws {
        try await TestUtilities.withApp { app, database in
            try await setupTestApp(app)

            try await app.test(.GET, "/") { response in
                // Home page should be accessible without auth
                #expect(response.status == .ok)

                // Check debug headers indicate no auth mode
                #expect(response.headers.first(name: "x-dev-auth-processed") == "true")
            }
        }
    }

    @Test("Environment variable configuration - DEV_AUTH_MODE")
    func environmentVariableAuthMode() async throws {
        // Set environment variable
        setenv("DEV_AUTH_MODE", "admin", 1)
        defer { unsetenv("DEV_AUTH_MODE") }

        try await TestUtilities.withApp { app, database in
            try await setupTestApp(app)

            // Add a test route
            app.get("env-test") { req -> String in
                guard let user = req.auth.get(User.self) else {
                    return "No user"
                }
                return "User: \(user.username), Role: \(user.role)"
            }

            try await app.test(.GET, "/env-test") { response in
                #expect(response.status == .ok)

                let body = response.body.string
                #expect(body.contains("dev-admin@neonlaw.com"))
                #expect(body.contains("admin"))
            }
        }
    }

    @Test("Environment variable configuration - DEV_AUTH_USER")
    func environmentVariableAuthUser() async throws {
        // Set environment variables
        setenv("DEV_AUTH_MODE", "customer", 1)
        setenv("DEV_AUTH_USER", "custom-test@example.com", 1)
        defer {
            unsetenv("DEV_AUTH_MODE")
            unsetenv("DEV_AUTH_USER")
        }

        try await TestUtilities.withApp { app, database in
            try await setupTestApp(app)

            // Add a test route
            app.get("custom-user-test") { req -> String in
                guard let user = req.auth.get(User.self) else {
                    return "No user"
                }
                return "User: \(user.username)"
            }

            try await app.test(.GET, "/custom-user-test") { response in
                #expect(response.status == .ok)

                let body = response.body.string
                #expect(body.contains("custom-test@example.com"))
            }
        }
    }

    @Test("ALB headers already present - middleware skips injection")
    func albHeadersAlreadyPresent() async throws {
        try await TestUtilities.withApp { app, database in
            try await setupTestApp(app)

            // Add a test route
            app.get("alb-test") { req -> String in
                if req.headers.first(name: "x-amzn-oidc-data") != nil {
                    return "ALB headers present"
                }
                return "No ALB headers"
            }

            // Send request with existing ALB headers
            var headers = HTTPHeaders()
            headers.add(name: "x-amzn-oidc-data", value: "existing-token")
            headers.add(name: "x-amzn-oidc-identity", value: "existing-user")

            try await app.test(.GET, "/alb-test", headers: headers) { response in
                #expect(response.status == .ok)

                let body = response.body.string
                #expect(body == "ALB headers present")

                // Dev auth should not have processed this
                #expect(response.headers.first(name: "x-dev-auth-injected") == nil)
            }
        }
    }

    @Test("Permission enforcement - staff cannot access admin routes")
    func permissionEnforcementStaffBlockedFromAdmin() async throws {
        try await TestUtilities.withApp { app, database in
            try await setupTestApp(app)

            // Configure admin route with proper auth check
            app.grouped("admin").get("restricted") { req -> String in
                guard let user = req.auth.get(User.self), user.role == .admin else {
                    throw Abort(.forbidden, reason: "Admin access required")
                }
                return "Admin only content"
            }

            try await app.test(.GET, "/admin/restricted?auth=staff") { response in
                // Staff should be forbidden from admin routes
                #expect(response.status == .forbidden)
            }
        }
    }

    @Test("Permission enforcement - customer cannot access staff routes")
    func permissionEnforcementCustomerBlockedFromStaff() async throws {
        try await TestUtilities.withApp { app, database in
            try await setupTestApp(app)

            // Configure staff route with proper auth check
            app.grouped("staff").get("reports") { req -> String in
                guard let user = req.auth.get(User.self),
                    user.role == .staff || user.role == .admin
                else {
                    throw Abort(.forbidden, reason: "Staff access required")
                }
                return "Staff reports"
            }

            try await app.test(.GET, "/staff/reports?auth=customer") { response in
                // Customer should be forbidden from staff routes
                #expect(response.status == .forbidden)
            }
        }
    }

    @Test("Mock user creation and persistence")
    func mockUserCreationAndPersistence() async throws {
        try await TestUtilities.withApp { app, database in
            try await setupTestApp(app)

            // First request should create/get the user
            try await app.test(.GET, "/app/me?auth=admin") { response in
                #expect(response.status == .ok)

                let body = response.body.string
                #expect(body.contains("dev-admin@neonlaw.com"))
            }

            // Second request should use the same user
            try await app.test(.GET, "/app/me?auth=admin") { response in
                #expect(response.status == .ok)

                let body = response.body.string
                #expect(body.contains("dev-admin@neonlaw.com"))
            }
        }
    }

    @Test("Debug headers provide helpful information")
    func debugHeadersProvideInformation() async throws {
        try await TestUtilities.withApp { app, database in
            try await setupTestApp(app)

            try await app.test(.GET, "/app/me?auth=customer") { response in
                #expect(response.status == .ok)

                // Check all debug headers
                #expect(response.headers.first(name: "x-dev-auth-processed") == "true")
                #expect(response.headers.first(name: "x-dev-auth-mode") == "customer")
                #expect(response.headers.first(name: "x-dev-auth-user") == "dev-customer@example.com")
                #expect(response.headers.first(name: "x-dev-auth-role") == "customer")
                #expect(response.headers.first(name: "x-dev-auth-hint") == "Add ?auth=admin|staff|customer|none to URL")
            }
        }
    }

    @Test("JWT token format is valid")
    func jwtTokenFormatValid() async throws {
        try await TestUtilities.withApp { app, database in
            try await setupTestApp(app)

            // Add a test route that returns the injected headers
            app.get("jwt-test") { req -> String in
                guard let jwtToken = req.headers.first(name: "x-amzn-oidc-data") else {
                    return "No JWT token"
                }

                // JWT should have three parts separated by dots
                let parts = jwtToken.split(separator: ".")
                guard parts.count == 3 else {
                    return "Invalid JWT format: \(parts.count) parts"
                }

                return "Valid JWT format"
            }

            try await app.test(.GET, "/jwt-test?auth=admin") { response in
                #expect(response.status == .ok)

                let body = response.body.string
                #expect(body == "Valid JWT format")
            }
        }
    }

    @Test("Cognito groups are properly set for each role")
    func cognitoGroupsProperlySet() async throws {
        try await TestUtilities.withApp { app, database in
            try await setupTestApp(app)

            // Add a test route that decodes and returns the groups
            app.get("groups-test") { req -> String in
                guard let jwtToken = req.headers.first(name: "x-amzn-oidc-data") else {
                    return "No JWT token"
                }

                let parts = jwtToken.split(separator: ".")
                guard parts.count == 3 else {
                    return "Invalid JWT"
                }

                // Decode the payload (second part)
                let payloadString = String(parts[1])
                var base64 =
                    payloadString
                    .replacingOccurrences(of: "-", with: "+")
                    .replacingOccurrences(of: "_", with: "/")

                // Add padding if needed
                while base64.count % 4 != 0 {
                    base64.append("=")
                }

                guard let payloadData = Data(base64Encoded: base64),
                    let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
                    let groups = payload["cognito:groups"] as? [String]
                else {
                    return "Failed to decode groups"
                }

                return groups.joined(separator: ", ")
            }

            // Test admin groups
            try await app.test(.GET, "/groups-test?auth=admin") { response in
                #expect(response.status == .ok)
                let body = response.body.string
                #expect(body.contains("admin"))
                #expect(body.contains("staff"))
                #expect(body.contains("users"))
            }

            // Test staff groups
            try await app.test(.GET, "/groups-test?auth=staff") { response in
                #expect(response.status == .ok)
                let body = response.body.string
                #expect(body.contains("staff"))
                #expect(body.contains("users"))
                #expect(!body.contains("admin"))
            }

            // Test customer groups
            try await app.test(.GET, "/groups-test?auth=customer") { response in
                #expect(response.status == .ok)
                let body = response.body.string
                #expect(body.contains("users"))
                #expect(body.contains("customers"))
                #expect(!body.contains("admin"))
                #expect(!body.contains("staff"))
            }
        }
    }

    // MARK: - Helper Functions

    private func setupTestApp(_ app: Application) async throws {
        // Add DevelopmentAuthMiddleware (will be enabled in testing environment)
        app.middleware.use(DevelopmentAuthMiddleware())

        // Add SmartAuthMiddleware with mock ALB authenticator
        let oidcConfig = OIDCConfiguration.create(from: .testing)
        let albAuthenticator = ALBHeaderAuthenticator(configuration: oidcConfig)
        let smartAuth = SmartAuthMiddleware(authenticator: albAuthenticator)
        app.middleware.use(smartAuth)

        // Add a public home route
        app.get { req -> String in
            "Welcome to the test app"
        }

        // Add a simple /app/me route for testing
        app.grouped("app").get("me") { req -> Response in
            guard let user = req.auth.get(User.self) else {
                throw Abort(.unauthorized, reason: "Authentication required")
            }

            let response = [
                "username": user.username,
                "role": user.role.rawValue,
                "email": user.person?.email ?? user.username,
            ]

            return try await response.encodeResponse(for: req)
        }
    }
}
