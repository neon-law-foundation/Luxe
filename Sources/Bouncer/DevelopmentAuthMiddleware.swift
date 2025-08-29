import Dali
import Fluent
import FluentPostgresDriver
import Foundation
import PostgresKit
import Vapor

/// Development authentication middleware for easy auth mode switching
///
/// This middleware provides convenient ways to switch between different authentication
/// modes during development without restarting the server or modifying configuration.
///
/// ## Features
///
/// - **URL Parameter Auth**: `?auth=admin|staff|customer|none`
/// - **Header Override**: Manual ALB header injection
/// - **Environment Variables**: `DEV_AUTH_MODE`, `DEV_AUTH_USER`
/// - **Route-Based Defaults**: Auto-select appropriate auth for different route patterns
/// - **Debug Information**: Detailed logging and debug headers
///
/// ## Usage
///
/// ```swift
/// // In development configuration only
/// if app.environment.isDevelopment {
///     app.middleware.use(DevelopmentAuthMiddleware())
/// }
/// ```
///
/// ## URL Parameter Examples
///
/// ```
/// http://localhost:8080/admin?auth=admin    # Admin authentication
/// http://localhost:8080/app?auth=staff      # Staff authentication
/// http://localhost:8080/api?auth=customer   # Customer authentication
/// http://localhost:8080/public?auth=none    # No authentication
/// ```
public struct DevelopmentAuthMiddleware: AsyncMiddleware {

    /// Available authentication modes
    public enum AuthMode: String, CaseIterable, Sendable {
        case admin
        case staff
        case customer
        case none

        var userRole: UserRole? {
            switch self {
            case .admin: return .admin
            case .staff: return .staff
            case .customer: return .customer
            case .none: return nil
            }
        }

        var defaultUsername: String {
            switch self {
            case .admin: return "dev-admin@neonlaw.com"
            case .staff: return "dev-staff@neonlaw.com"
            case .customer: return "dev-customer@example.com"
            case .none: return ""
            }
        }

        var cognitoGroups: [String] {
            switch self {
            case .admin: return ["admin", "administrators", "staff", "users"]
            case .staff: return ["staff", "employees", "users"]
            case .customer: return ["users", "customers"]
            case .none: return []
            }
        }
    }

    /// Configuration for the middleware
    public struct Configuration: Sendable {
        /// Enable URL parameter auth switching (?auth=mode)
        let enableURLParamAuth: Bool

        /// Enable environment variable auth mode
        let enableEnvAuth: Bool

        /// Enable route-based auto-detection
        let enableRouteBasedAuth: Bool

        /// Add debug headers to responses
        let enableDebugHeaders: Bool

        /// Default auth mode if none specified
        let defaultAuthMode: AuthMode?

        public init(
            enableURLParamAuth: Bool = true,
            enableEnvAuth: Bool = true,
            enableRouteBasedAuth: Bool = true,
            enableDebugHeaders: Bool = true,
            defaultAuthMode: AuthMode? = nil
        ) {
            self.enableURLParamAuth = enableURLParamAuth
            self.enableEnvAuth = enableEnvAuth
            self.enableRouteBasedAuth = enableRouteBasedAuth
            self.enableDebugHeaders = enableDebugHeaders
            self.defaultAuthMode = defaultAuthMode
        }
    }

    /// Middleware configuration
    private let config: Configuration

    /// Logger for development auth
    private let logger: Logger

    /// Creates development auth middleware
    ///
    /// - Parameter config: Configuration options
    public init(config: Configuration = Configuration()) {
        self.config = config
        self.logger = Logger(label: "dev.auth")
    }

    /// Processes requests and injects authentication based on various modes
    ///
    /// - Parameters:
    ///   - request: The incoming HTTP request
    ///   - next: The next responder in the chain
    /// - Returns: The HTTP response with debug information
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Only run in development or testing environment
        guard request.application.environment.isDevelopment || request.application.environment == .testing else {
            return try await next.respond(to: request)
        }

        logger.info("🛠️ DevelopmentAuthMiddleware processing: \(request.url.path)")

        // Skip if ALB headers already present
        if hasALBHeaders(request) {
            logger.info("🎫 ALB headers already present, skipping development auth")
            return try await next.respond(to: request)
        }

        // Determine authentication mode
        let authMode = determineAuthMode(from: request)

        if let authMode = authMode {
            logger.info("🎭 Using development auth mode: \(authMode.rawValue)")

            // Create and inject mock user
            try await injectDevelopmentAuth(authMode: authMode, request: request)
        } else {
            logger.info("🌍 No development auth mode, allowing unauthenticated")
        }

        // Process request
        let response = try await next.respond(to: request)

        // Add debug headers if enabled
        if config.enableDebugHeaders {
            addDebugHeaders(to: response, authMode: authMode, request: request)
        }

        return response
    }

    /// Determines the authentication mode to use
    ///
    /// Priority:
    /// 1. URL parameter (?auth=mode)
    /// 2. Environment variable (DEV_AUTH_MODE)
    /// 3. Route-based auto-detection
    /// 4. Default auth mode from configuration
    ///
    /// - Parameter request: The HTTP request
    /// - Returns: The auth mode or nil for no auth
    private func determineAuthMode(from request: Request) -> AuthMode? {
        // 1. Check URL parameter
        if config.enableURLParamAuth,
            let authParam = request.query[String.self, at: "auth"],
            let authMode = AuthMode(rawValue: authParam.lowercased())
        {
            logger.debug("🔗 Auth mode from URL parameter: \(authMode.rawValue)")
            return authMode
        }

        // 2. Check environment variable
        if config.enableEnvAuth,
            let envAuthMode = Environment.get("DEV_AUTH_MODE"),
            let authMode = AuthMode(rawValue: envAuthMode.lowercased())
        {
            logger.debug("🌍 Auth mode from environment: \(authMode.rawValue)")
            return authMode
        }

        // 3. Route-based auto-detection
        if config.enableRouteBasedAuth {
            let path = request.url.path

            if path.hasPrefix("/admin") {
                logger.debug("🛡️ Auto-detected admin route")
                return .admin
            } else if path.hasPrefix("/staff") || path.hasPrefix("/reports") {
                logger.debug("👥 Auto-detected staff route")
                return .staff
            } else if path.hasPrefix("/app") || path.hasPrefix("/api") {
                logger.debug("👤 Auto-detected customer route")
                return .customer
            }
        }

        // 4. Default mode
        if let defaultMode = config.defaultAuthMode {
            logger.debug("⚙️ Using default auth mode: \(defaultMode.rawValue)")
            return defaultMode
        }

        return nil
    }

    /// Checks if request already has ALB headers
    ///
    /// - Parameter request: The HTTP request
    /// - Returns: True if ALB headers are present
    private func hasALBHeaders(_ request: Request) -> Bool {
        request.headers.first(name: "x-amzn-oidc-data") != nil
            || request.headers.first(name: "x-amzn-oidc-identity") != nil
    }

    /// Injects development authentication for the specified mode
    ///
    /// - Parameters:
    ///   - authMode: The authentication mode to inject
    ///   - request: The request to modify
    private func injectDevelopmentAuth(authMode: AuthMode, request: Request) async throws {
        // Get or create mock user
        let user = try await getOrCreateDevelopmentUser(authMode: authMode, request: request)

        // Create mock ALB headers
        let headers = createMockALBHeaders(for: user, authMode: authMode)

        // Inject headers into request
        for (name, value) in headers {
            request.headers.replaceOrAdd(name: name, value: value)
        }

        // Set authentication context
        request.auth.login(user)

        logger.info("✅ Injected development auth for: \(user.username) (role: \(user.role))")
    }

    /// Gets or creates a development user for the specified auth mode
    ///
    /// - Parameters:
    ///   - authMode: The authentication mode
    ///   - request: The request for database access
    /// - Returns: A User object for the auth mode
    private func getOrCreateDevelopmentUser(authMode: AuthMode, request: Request) async throws -> User {
        guard let userRole = authMode.userRole else {
            throw Abort(.internalServerError, reason: "Cannot create user for auth mode: \(authMode)")
        }

        let username = authMode.defaultUsername

        // Check for custom username from environment
        let envUserKey = "DEV_AUTH_USER"
        let finalUsername = Environment.get(envUserKey) ?? username

        // Try to find existing user in database
        if let existingUser = try await User.query(on: request.db)
            .filter(\.$username == finalUsername)
            .with(\.$person)
            .first()
        {
            logger.debug("👤 Found existing user: \(finalUsername)")
            return existingUser
        }

        // Create development user in database
        logger.debug("🎭 Creating development user: \(finalUsername)")

        // Use raw SQL to create the user properly with the enum type
        let postgres = request.db as! PostgresDatabase

        // First create the person
        try await postgres.sql().raw(
            """
            INSERT INTO directory.people (name, email)
            VALUES (\(bind: "Development \(authMode.rawValue.capitalized) User"), \(bind: finalUsername))
            ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name
            """
        ).run()

        // Create user with proper role enum casting
        try await postgres.sql().raw(
            """
            INSERT INTO auth.users (username, person_id, role, sub)
            SELECT \(bind: finalUsername), p.id, \(bind: userRole.rawValue)::auth.user_role, \(bind: "dev-sub-\(authMode.rawValue)")
            FROM directory.people p
            WHERE p.email = \(bind: finalUsername)
            ON CONFLICT (username) DO UPDATE SET 
                role = EXCLUDED.role,
                sub = EXCLUDED.sub,
                person_id = EXCLUDED.person_id
            """
        ).run()

        // Now fetch the created user with person loaded
        guard
            let createdUser = try await User.query(on: request.db)
                .filter(\.$username == finalUsername)
                .with(\.$person)
                .first()
        else {
            throw Abort(.internalServerError, reason: "Failed to create development user")
        }

        return createdUser
    }

    /// Creates mock ALB headers for development authentication
    ///
    /// - Parameters:
    ///   - user: The user to create headers for
    ///   - authMode: The authentication mode
    /// - Returns: Dictionary of header names and values
    private func createMockALBHeaders(for user: User, authMode: AuthMode) -> [String: String] {
        // Create mock JWT header
        let header: [String: Any] = [
            "alg": "RS256",
            "typ": "JWT",
            "kid": "dev-key-id",
        ]

        // Create mock JWT payload
        let payload: [String: Any] = [
            "iss": "dev-cognito",
            "aud": ["dev-client"],
            "exp": Int(Date().addingTimeInterval(3600).timeIntervalSince1970),
            "iat": Int(Date().timeIntervalSince1970),
            "sub": user.sub ?? user.username,
            "email": user.person?.email ?? user.username,
            "name": user.person?.name ?? "Development User",
            "username": user.username,
            "cognito:groups": authMode.cognitoGroups,
            "custom:role": authMode.rawValue,
        ]

        // Create mock JWT token (header.payload.signature format)
        let headerData = try! JSONSerialization.data(withJSONObject: header)
        let payloadData = try! JSONSerialization.data(withJSONObject: payload)

        let headerBase64 = headerData.base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")

        let payloadBase64 = payloadData.base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")

        // Mock signature (not cryptographically valid, but sufficient for development)
        let mockSignature = "mock-signature-for-dev"

        let jwtToken = "\(headerBase64).\(payloadBase64).\(mockSignature)"

        return [
            "x-amzn-oidc-data": jwtToken,
            "x-amzn-oidc-identity": user.username,
            "x-amzn-oidc-accesstoken": "dev-access-token-\(authMode.rawValue)",
            "x-dev-auth-mode": authMode.rawValue,
            "x-dev-auth-injected": "true",
        ]
    }

    /// Adds debug headers to the response
    ///
    /// - Parameters:
    ///   - response: The HTTP response to modify
    ///   - authMode: The auth mode that was used
    ///   - request: The original request
    private func addDebugHeaders(to response: Response, authMode: AuthMode?, request: Request) {
        response.headers.add(name: "x-dev-auth-processed", value: "true")

        if let authMode = authMode {
            response.headers.add(name: "x-dev-auth-mode", value: authMode.rawValue)

            if let user = request.auth.get(User.self) {
                response.headers.add(name: "x-dev-auth-user", value: user.username)
                response.headers.add(name: "x-dev-auth-role", value: user.role.rawValue)
            }
        } else {
            response.headers.add(name: "x-dev-auth-mode", value: "none")
        }

        // Add usage hint header
        response.headers.add(name: "x-dev-auth-hint", value: "Add ?auth=admin|staff|customer|none to URL")
    }
}

// MARK: - Convenience Extensions

extension Application {
    /// Adds development authentication middleware with default configuration
    ///
    /// Only adds the middleware in development or testing environment
    public func addDevelopmentAuth() {
        guard environment.isDevelopment || environment == .testing else {
            return
        }

        middleware.use(DevelopmentAuthMiddleware())
        logger.info("🛠️ Development authentication middleware enabled")
        logger.info("💡 Use ?auth=admin|staff|customer|none in URLs to test different auth modes")
    }

    /// Adds development authentication middleware with custom configuration
    ///
    /// - Parameter config: Custom middleware configuration
    public func addDevelopmentAuth(config: DevelopmentAuthMiddleware.Configuration) {
        guard environment.isDevelopment || environment == .testing else {
            return
        }

        middleware.use(DevelopmentAuthMiddleware(config: config))
        logger.info("🛠️ Custom development authentication middleware enabled")
    }
}
