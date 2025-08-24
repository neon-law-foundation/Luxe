import Dali
import Fluent
import Foundation
import Vapor

/// Protocol for ALB-style authenticators
///
/// This protocol allows SmartAuthMiddleware to work with different authenticator implementations,
/// making it testable and more flexible.
public protocol ALBAuthenticatorProtocol: Sendable {
    /// OIDC configuration for the authenticator
    var configuration: OIDCConfiguration { get }

    /// Authenticates a request using headers or other methods
    ///
    /// - Parameter request: The request to authenticate
    /// - Throws: `Abort` if authentication fails
    func authenticate(request: Request) async throws
}

/// Middleware that applies authentication only to /app and /api routes
///
/// This middleware implements a simple authentication strategy where:
/// - All paths are public by default (no authentication required)
/// - Only paths starting with "/app" or "/api" require authentication
/// - Admin routes (/admin, /api/admin) require admin role
/// - Staff routes (/staff, /api/staff) require staff role or higher
///
/// ## Features
///
/// - **Simple routing**: Only /app and /api routes require authentication
/// - **Role-based access**: Enforce role requirements for admin/staff routes
/// - **Performance optimized**: Skip authentication for all other routes
/// - **No configuration needed**: Works out of the box
///
/// ## Usage
///
/// ```swift
/// let authenticator = ALBHeaderAuthenticator(configuration: oidcConfig)
/// let smartAuth = SmartAuthMiddleware(authenticator: authenticator)
/// app.middleware.use(smartAuth)
/// ```
public final class SmartAuthMiddleware: AsyncMiddleware {
    /// Path patterns that require admin role
    private let adminPatterns: [String]

    /// Path patterns that require staff role or higher
    private let staffPatterns: [String]

    /// The authenticator to use for protected routes
    private let authenticator: ALBAuthenticatorProtocol

    /// Default admin patterns
    public static let defaultAdminPatterns = [
        "/admin",
        "/api/admin",
    ]

    /// Default staff patterns
    public static let defaultStaffPatterns = [
        "/staff",
        "/api/staff",
        "/reports",
    ]

    /// Creates smart authentication middleware
    ///
    /// - Parameters:
    ///   - authenticator: The authenticator to use for protected routes
    ///   - adminPatterns: Patterns for admin-only routes (uses defaults if nil)
    ///   - staffPatterns: Patterns for staff-only routes (uses defaults if nil)
    public init(
        authenticator: ALBAuthenticatorProtocol,
        adminPatterns: [String]? = nil,
        staffPatterns: [String]? = nil
    ) {
        self.authenticator = authenticator
        self.adminPatterns = adminPatterns ?? Self.defaultAdminPatterns
        self.staffPatterns = staffPatterns ?? Self.defaultStaffPatterns
    }

    /// Processes requests with smart authentication
    ///
    /// This method:
    /// 1. Checks if the route requires authentication (/app or /api paths)
    /// 2. For non-protected routes, skips authentication
    /// 3. For protected routes, applies authentication
    /// 4. Enforces role-based access for admin/staff routes
    /// 5. Sets CurrentUserContext for authenticated requests
    ///
    /// - Parameters:
    ///   - request: The incoming HTTP request
    ///   - next: The next responder in the chain
    /// - Returns: The HTTP response
    /// - Throws: `Abort` if authentication or authorization fails
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let path = request.url.path
        request.logger.debug("🛡️ SmartAuthMiddleware checking path: \(path)")

        // Check if route requires authentication (only /app and /api paths)
        if !requiresAuthentication(path) {
            request.logger.debug("🌍 Public route, skipping authentication: \(path)")
            return try await next.respond(to: request)
        }

        // Authenticate for protected routes
        request.logger.debug("🔒 Protected route, applying authentication: \(path)")
        try await authenticator.authenticate(request: request)

        // Check if user was authenticated
        guard let user = request.auth.get(User.self) else {
            request.logger.error("❌ Authentication required but no user authenticated for: \(path)")
            throw Abort(.unauthorized, reason: "Authentication required")
        }

        request.logger.info("✅ User authenticated: \(user.username) with role: \(user.role)")

        // Check role-based access
        if isAdminPath(path) {
            guard user.hasRole(UserRole.admin) else {
                request.logger.error("🚫 Admin access denied for user: \(user.username)")
                throw Abort(.forbidden, reason: "Admin access required")
            }
            request.logger.info("👑 Admin access granted for: \(user.username)")
        }

        if isStaffPath(path) {
            guard user.hasRole(UserRole.staff) else {
                request.logger.error("🚫 Staff access denied for user: \(user.username)")
                throw Abort(.forbidden, reason: "Staff access required")
            }
            request.logger.info("🏢 Staff access granted for: \(user.username)")
        }

        // Set CurrentUserContext and continue
        return try await CurrentUserContext.$user.withValue(user) {
            try await next.respond(to: request)
        }
    }

    /// Checks if a path requires authentication
    ///
    /// Paths require authentication if they:
    /// - Start with "/app" or "/api"
    /// - Match any admin patterns
    /// - Match any staff patterns
    /// All other paths are public.
    ///
    /// - Parameter path: The path to check
    /// - Returns: True if the path requires authentication
    private func requiresAuthentication(_ path: String) -> Bool {
        // Check standard protected paths
        if path == "/app" || path.hasPrefix("/app/") || path == "/api" || path.hasPrefix("/api/") {
            return true
        }

        // Check admin patterns
        if isAdminPath(path) {
            return true
        }

        // Check staff patterns
        if isStaffPath(path) {
            return true
        }

        return false
    }

    /// Checks if a path requires admin role
    private func isAdminPath(_ path: String) -> Bool {
        for pattern in adminPatterns {
            if pattern.hasSuffix("*") {
                // Wildcard pattern - check prefix match
                let prefix = String(pattern.dropLast())
                if path.hasPrefix(prefix) {
                    return true
                }
            } else {
                // Exact match or prefix match for patterns without wildcards
                if path == pattern || path.hasPrefix(pattern + "/") {
                    return true
                }
            }
        }
        return false
    }

    /// Checks if a path requires staff role
    private func isStaffPath(_ path: String) -> Bool {
        for pattern in staffPatterns {
            if pattern.hasSuffix("*") {
                // Wildcard pattern - check prefix match
                let prefix = String(pattern.dropLast())
                if path.hasPrefix(prefix) {
                    return true
                }
            } else {
                // Exact match or prefix match for patterns without wildcards
                if path == pattern || path.hasPrefix(pattern + "/") {
                    return true
                }
            }
        }
        return false
    }
}
