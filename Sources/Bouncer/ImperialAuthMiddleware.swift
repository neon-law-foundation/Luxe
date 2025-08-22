import Dali
import Fluent
import Foundation
import Vapor

/// Middleware that handles Imperial OAuth session-based authentication for HTML pages.
///
/// This middleware integrates with Imperial to provide OAuth-based authentication
/// for browser sessions, working alongside the existing JWT-based authentication
/// for API endpoints. It supports both AWS Cognito (production) and Keycloak
/// (development) as OIDC providers.
///
/// ## Usage
///
/// Add this middleware to HTML routes that require authentication:
///
/// ```swift
/// let htmlRoutes = app.grouped("app")
///     .grouped(ImperialAuthMiddleware())
/// ```
///
/// The middleware will:
/// 1. Check for a valid Imperial session
/// 2. Load the associated user from the database
/// 3. Set the user in CurrentUserContext
/// 4. Redirect to login if no valid session exists
///
/// ## Security Model
///
/// - **Pre-existing Users Only**: Like OIDCMiddleware, this will NOT create new users
/// - **Session-based**: Uses Imperial's session management for browser authentication
/// - **Database Verification**: Each request validates the user exists in the database
/// - **User Context**: Sets `CurrentUserContext.user` for the request lifecycle
public struct ImperialAuthMiddleware: AsyncMiddleware {
    /// The login path to redirect to when authentication is required
    public let loginPath: String

    /// Creates a new Imperial authentication middleware.
    ///
    /// - Parameter loginPath: The path to redirect to for login (default: "/auth/login")
    public init(loginPath: String = "/auth/login") {
        self.loginPath = loginPath
    }

    /// Processes incoming requests and validates Imperial OAuth session.
    ///
    /// This method implements the core session authentication logic:
    /// 1. Checks for a valid Imperial session
    /// 2. Extracts user information from the session
    /// 3. Looks up the user in the database (does not create new users)
    /// 4. Sets the current user context if authentication succeeds
    /// 5. Redirects to login if no valid session exists
    ///
    /// - Parameters:
    ///   - request: The incoming HTTP request
    ///   - next: The next responder in the chain
    /// - Returns: The HTTP response from the next responder or a redirect
    /// - Throws: Database errors or other processing errors
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        request.logger.info("🔐 ImperialAuthMiddleware processing request for: \(request.url.path)")

        // Check if user is already authenticated via Imperial session
        guard let imperialToken = request.auth.get(ImperialToken.self) else {
            request.logger.info("❌ No Imperial session found, redirecting to login")
            return request.redirect(to: loginPath)
        }

        request.logger.info("🎫 Found Imperial session for user: \(imperialToken.userId)")

        // Find existing user in database - do not create if doesn't exist
        request.logger.info("🔍 Looking up user in database: \(imperialToken.userId)")

        // Try to find user by sub field first (preferred for OIDC)
        var user = try await User.query(on: request.db)
            .filter(\User.$sub == imperialToken.userId)
            .first()

        if user == nil {
            // Fallback to username lookup for backwards compatibility
            request.logger.info("🔄 Sub lookup failed, trying username lookup")
            user = try await User.query(on: request.db)
                .filter(\User.$username == imperialToken.userId)
                .first()
        }

        guard let user = user else {
            request.logger.error("❌ User not found in database: \(imperialToken.userId)")
            // Clear invalid session and redirect to login
            request.auth.logout(ImperialToken.self)
            return request.redirect(to: loginPath)
        }

        request.logger.info("✅ User found - ID: \(user.id ?? UUID()), role: \(user.role)")

        // Set current user in TaskLocal
        return try await CurrentUserContext.$user.withValue(user) {
            request.logger.info("🎯 CurrentUserContext set for user: \(user.username)")
            let response = try await next.respond(to: request)
            request.logger.info(
                "🏁 Response generated, CurrentUserContext user: \(CurrentUserContext.user?.username ?? "nil")"
            )
            return response
        }
    }
}

/// Token structure used by Imperial to store OAuth session information
public struct ImperialToken: Authenticatable {
    /// The user identifier from the OAuth provider (sub claim)
    public let userId: String

    /// The access token from the OAuth provider
    public let accessToken: String

    /// The refresh token from the OAuth provider (if available)
    public let refreshToken: String?

    /// Token expiration date
    public let expiresAt: Date?

    /// Creates a new Imperial token
    public init(
        userId: String,
        accessToken: String,
        refreshToken: String? = nil,
        expiresAt: Date? = nil
    ) {
        self.userId = userId
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }
}
