import Dali
import Fluent
import Foundation
import JWT
import Vapor

/// Unified authentication middleware that supports multiple authentication strategies
///
/// This middleware allows routes to choose between JWT Bearer token authentication (for APIs),
/// OAuth session authentication (for HTML pages), or hybrid mode that accepts either.
///
/// ## Usage
///
/// ```swift
/// // JWT only (API routes)
/// let apiAuth = AuthenticationMiddleware(strategy: .jwt, oidcConfig: oidcConfig)
/// let api = app.grouped("api").grouped(apiAuth)
///
/// // OAuth only (HTML routes)
/// let htmlAuth = AuthenticationMiddleware(strategy: .oauth, oidcConfig: oidcConfig)
/// let html = app.grouped(htmlAuth)
///
/// // Hybrid (accepts either)
/// let hybridAuth = AuthenticationMiddleware(strategy: .hybrid, oidcConfig: oidcConfig)
/// let mixed = app.grouped(hybridAuth)
/// ```
public struct AuthenticationMiddleware: AsyncMiddleware {
    /// The authentication strategy to use
    public let strategy: AuthenticationStrategy

    /// OIDC configuration for JWT validation
    public let oidcConfig: OIDCConfiguration

    /// OAuth configuration for session validation
    public let oauthConfig: OAuthConfiguration?

    /// Creates a new authentication middleware
    ///
    /// - Parameters:
    ///   - strategy: The authentication strategy to use
    ///   - oidcConfig: OIDC configuration for JWT validation
    ///   - oauthConfig: OAuth configuration for session validation (optional, uses default if nil)
    public init(
        strategy: AuthenticationStrategy,
        oidcConfig: OIDCConfiguration,
        oauthConfig: OAuthConfiguration? = nil
    ) {
        self.strategy = strategy
        self.oidcConfig = oidcConfig
        self.oauthConfig = oauthConfig
    }

    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        request.logger.info("🔐 AuthenticationMiddleware processing request for: \(request.url.path)")

        switch strategy {
        case .jwt:
            return try await handleJWTAuth(request: request, next: next)
        case .oauth:
            return try await handleOAuthAuth(request: request, next: next)
        case .hybrid:
            return try await handleHybridAuth(request: request, next: next)
        case .serviceAccount:
            return try await handleServiceAccountAuth(request: request, next: next)
        }
    }

    /// Handle JWT Bearer token authentication
    private func handleJWTAuth(request: Request, next: AsyncResponder) async throws -> Response {
        // Use existing OIDC middleware logic
        let oidcMiddleware = OIDCMiddleware(configuration: oidcConfig)
        return try await oidcMiddleware.respond(to: request, chainingTo: next)
    }

    /// Handle OAuth session authentication
    private func handleOAuthAuth(request: Request, next: AsyncResponder) async throws -> Response {
        request.logger.info("🔐 Checking OAuth session authentication")

        // Check for OAuth tokens in session
        guard let accessToken = request.session.data["oauth_access_token"] else {
            request.logger.error("❌ No OAuth session found")
            throw Abort(.unauthorized, reason: "No OAuth session found")
        }

        // Validate token is still present (basic check)
        guard !accessToken.isEmpty else {
            request.logger.error("❌ Invalid OAuth session")
            throw Abort(.unauthorized, reason: "Invalid OAuth session")
        }

        // Get user from session
        guard let userId = request.session.data["oauth_user_id"],
            let userIdUUID = UUID(uuidString: userId),
            let user = try await User.find(userIdUUID, on: request.db)
        else {
            request.logger.error("❌ User not found in session")
            throw Abort(.unauthorized, reason: "User not found")
        }

        // Load person relation
        try await user.$person.load(on: request.db)

        request.logger.info("✅ OAuth session valid for user: \(user.username)")

        // Set current user context
        return try await CurrentUserContext.$user.withValue(user) {
            try await next.respond(to: request)
        }
    }

    /// Handle hybrid authentication (try JWT first, fallback to OAuth)
    private func handleHybridAuth(request: Request, next: AsyncResponder) async throws -> Response {
        request.logger.info("🔐 Checking hybrid authentication")

        // First try JWT authentication
        if request.headers.bearerAuthorization != nil {
            request.logger.info("🎫 Found Bearer token, attempting JWT authentication")
            do {
                return try await handleJWTAuth(request: request, next: next)
            } catch {
                request.logger.warning("⚠️ JWT authentication failed: \(error)")
                // Continue to OAuth check
            }
        }

        // Then try OAuth session authentication
        if request.session.data["oauth_access_token"] != nil {
            request.logger.info("🎫 Found OAuth session, attempting session authentication")
            return try await handleOAuthAuth(request: request, next: next)
        }

        request.logger.error("❌ No valid authentication found (neither JWT nor OAuth)")
        throw Abort(.unauthorized, reason: "Authentication required")
    }

    /// Handle service account authentication
    private func handleServiceAccountAuth(request: Request, next: AsyncResponder) async throws -> Response {
        request.logger.info("🔐 Checking service account authentication")

        guard request.headers.bearerAuthorization != nil else {
            request.logger.error("❌ Missing authorization header for service account")
            throw Abort(.unauthorized, reason: "Missing authorization header")
        }

        // Use the ServiceAccountAuthenticationMiddleware for actual validation
        let serviceAccountMiddleware = ServiceAccountAuthenticationMiddleware()
        return try await serviceAccountMiddleware.respond(to: request, chainingTo: next)
    }
}

/// Extension to create OAuth login/callback routes
extension Application {
    /// Configure OAuth routes for authentication
    ///
    /// This adds the necessary routes for OAuth login and callback handling.
    ///
    /// - Parameters:
    ///   - config: OAuth configuration
    ///   - loginPath: Path for initiating OAuth login (default: "/auth/login")
    ///   - callbackPath: Path for OAuth callback (default: "/auth/callback")
    ///   - successRedirect: Path to redirect after successful login (default: "/")
    public func configureOAuthRoutes(
        config: OAuthConfiguration? = nil,
        loginPath: String = "/auth/login",
        callbackPath: String = "/auth/callback",
        successRedirect: String = "/"
    ) throws {
        let oauthConfig = config ?? OAuthConfiguration.create(from: self.environment)

        // Login route - initiates OAuth flow
        self.get(PathComponent(stringLiteral: loginPath)) { req -> Response in
            let state = req.session.createOAuthState()
            let authURL = oauthConfig.provider.authorizationURL(
                state: state,
                redirectURI: oauthConfig.callbackURL
            )
            return req.redirect(to: authURL)
        }

        // Callback route - handles OAuth response
        self.get(PathComponent(stringLiteral: callbackPath)) { req async throws -> Response in
            guard let code = req.query[String.self, at: "code"],
                let state = req.query[String.self, at: "state"]
            else {
                throw Abort(.badRequest, reason: "Missing code or state parameter")
            }

            let handler = OAuthHandler(configuration: oauthConfig, db: req.db)
            let user = try await handler.handleCallback(
                code: code,
                state: state,
                session: req.session
            )

            // Store user ID in session
            req.session.data["oauth_user_id"] = user.id?.uuidString

            // Redirect to success page
            return req.redirect(to: successRedirect)
        }

        // Logout route
        self.post("auth", "logout") { req -> Response in
            req.session.destroy()
            return req.redirect(to: "/")
        }
    }
}
