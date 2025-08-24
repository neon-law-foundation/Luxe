import Dali
import Fluent
import Foundation
import Vapor

/// Middleware that selectively applies authentication based on route patterns
///
/// This middleware implements a smart routing strategy where certain paths are public
/// (no authentication required) while others are protected. It replaces the need for
/// complex route grouping by handling authentication at the middleware level.
///
/// ## Features
///
/// - **Pattern-based routing**: Define public and protected path patterns
/// - **Role-based access**: Enforce role requirements for admin routes
/// - **Performance optimized**: Skip authentication for public routes
/// - **Configurable**: Easy to customize patterns for your application
///
/// ## Usage
///
/// ```swift
/// let authenticator = ALBHeaderAuthenticator(configuration: oidcConfig)
/// let smartAuth = SmartAuthMiddleware(authenticator: authenticator)
/// app.middleware.use(smartAuth)
/// ```
public final class SmartAuthMiddleware: AsyncMiddleware {
    /// Path patterns that don't require authentication
    private let publicPatterns: [String]
    
    /// Path patterns that require admin role
    private let adminPatterns: [String]
    
    /// Path patterns that require staff role or higher
    private let staffPatterns: [String]
    
    /// The authenticator to use for protected routes
    private let authenticator: ALBHeaderAuthenticator
    
    /// Default public patterns for common routes
    public static let defaultPublicPatterns = [
        "/",
        "/health",
        "/status",
        "/favicon.ico",
        "/robots.txt",
        "/api/public/*",
        "/assets/*",
        "/css/*",
        "/js/*",
        "/images/*",
        "/login",
        "/logout",
        "/auth/*",
        "/webhook/*"
    ]
    
    /// Default admin patterns
    public static let defaultAdminPatterns = [
        "/admin/*",
        "/api/admin/*"
    ]
    
    /// Default staff patterns
    public static let defaultStaffPatterns = [
        "/staff/*",
        "/api/staff/*",
        "/reports/*"
    ]
    
    /// Creates smart authentication middleware
    ///
    /// - Parameters:
    ///   - authenticator: The ALB header authenticator to use
    ///   - publicPatterns: Patterns for public routes (uses defaults if nil)
    ///   - adminPatterns: Patterns for admin-only routes (uses defaults if nil)
    ///   - staffPatterns: Patterns for staff-only routes (uses defaults if nil)
    public init(
        authenticator: ALBHeaderAuthenticator,
        publicPatterns: [String]? = nil,
        adminPatterns: [String]? = nil,
        staffPatterns: [String]? = nil
    ) {
        self.authenticator = authenticator
        self.publicPatterns = publicPatterns ?? Self.defaultPublicPatterns
        self.adminPatterns = adminPatterns ?? Self.defaultAdminPatterns
        self.staffPatterns = staffPatterns ?? Self.defaultStaffPatterns
    }
    
    /// Processes requests with smart authentication
    ///
    /// This method:
    /// 1. Checks if the route is public (skip authentication)
    /// 2. Applies authentication for protected routes
    /// 3. Enforces role-based access for admin/staff routes
    /// 4. Sets CurrentUserContext for authenticated requests
    ///
    /// - Parameters:
    ///   - request: The incoming HTTP request
    ///   - next: The next responder in the chain
    /// - Returns: The HTTP response
    /// - Throws: `Abort` if authentication or authorization fails
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let path = request.url.path
        request.logger.debug("🛡️ SmartAuthMiddleware checking path: \(path)")
        
        // Check if route is public
        if isPublicPath(path) {
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
    
    /// Checks if a path matches public patterns
    private func isPublicPath(_ path: String) -> Bool {
        return matchesPattern(path, patterns: publicPatterns)
    }
    
    /// Checks if a path matches admin patterns
    private func isAdminPath(_ path: String) -> Bool {
        return matchesPattern(path, patterns: adminPatterns)
    }
    
    /// Checks if a path matches staff patterns
    private func isStaffPath(_ path: String) -> Bool {
        return matchesPattern(path, patterns: staffPatterns)
    }
    
    /// Matches a path against a list of patterns
    ///
    /// Supports exact matches and wildcard patterns (ending with *)
    ///
    /// - Parameters:
    ///   - path: The path to check
    ///   - patterns: The patterns to match against
    /// - Returns: True if the path matches any pattern
    private func matchesPattern(_ path: String, patterns: [String]) -> Bool {
        for pattern in patterns {
            if pattern.hasSuffix("*") {
                // Wildcard pattern - check prefix match
                let prefix = String(pattern.dropLast())
                if path.hasPrefix(prefix) {
                    return true
                }
            } else {
                // Exact match
                if path == pattern {
                    return true
                }
            }
        }
        return false
    }
}

