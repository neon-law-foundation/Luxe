import Bouncer
import Dali
import Fluent
import Foundation
import JWT
import Vapor

/// Extended OIDC middleware that supports both Bearer tokens and ALB authentication headers.
///
/// This middleware extends the base OIDCMiddleware to support authentication via:
/// 1. Bearer tokens in the Authorization header (primary method)
/// 2. ALB-injected headers when no Bearer token is present (fallback method)
///
/// ## ALB Authentication Flow
///
/// When AWS Application Load Balancer is configured with authentication actions,
/// it injects the following headers after successful authentication:
/// - `X-Amzn-Oidc-Accesstoken`: The access token from the IdP
/// - `X-Amzn-Oidc-Identity`: The user's identity (usually the username)
/// - `X-Amzn-Oidc-Data`: Encoded JWT with user claims
///
/// ## Usage
///
/// ```swift
/// let config = OIDCConfiguration.create(from: app.environment)
/// let middleware = ALBAuthMiddleware(configuration: config)
/// let protected = app.grouped(middleware)
/// ```
public struct ALBAuthMiddleware: AsyncMiddleware {
    /// The OIDC configuration for this middleware instance.
    public let configuration: OIDCConfiguration

    /// The base OIDC middleware for Bearer token authentication.
    private let oidcMiddleware: OIDCMiddleware

    /// Creates a new ALB-aware authentication middleware.
    ///
    /// - Parameter configuration: The OIDC configuration to use for authentication
    public init(configuration: OIDCConfiguration) {
        self.configuration = configuration
        self.oidcMiddleware = OIDCMiddleware(configuration: configuration)
    }

    /// Processes incoming requests and validates authentication via Bearer token or ALB headers.
    ///
    /// This method attempts authentication in the following order:
    /// 1. If an Authorization header with Bearer token is present, use standard OIDC middleware
    /// 2. If ALB headers are present, extract and validate the user from those headers
    /// 3. If neither is present, return 401 Unauthorized
    ///
    /// - Parameters:
    ///   - request: The incoming HTTP request
    ///   - next: The next responder in the chain
    /// - Returns: The HTTP response from the next responder
    /// - Throws: `Abort(.unauthorized)` if authentication fails
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        request.logger.info("🛡️ ALBAuthMiddleware checking authentication for: \(request.url.path)")

        // First, check if there's a Bearer token - if so, use the standard OIDC middleware
        if request.headers.bearerAuthorization != nil {
            request.logger.info("🎫 Found Bearer token in Authorization header")
            return try await oidcMiddleware.respond(to: request, chainingTo: next)
        }

        // Check for session cookie
        if let sessionId = request.cookies["luxe-session"]?.string {
            request.logger.info("🍪 Found session cookie with ID: \(sessionId)")

            if let sessionToken = request.application.storage[SessionStorageKey.self]?[sessionId] {
                request.logger.info("✅ Session found in storage")

                // Session token format is "username:jwt-token" from OAuth callback
                let parts = sessionToken.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let username = String(parts[0])
                    let jwtToken = String(parts[1])
                    request.logger.info("📧 Session username: \(username)")

                    // For JWT tokens, pass to OIDC middleware
                    if jwtToken.contains(".") {
                        request.logger.info("🎫 Session contains JWT token, passing to OIDC middleware")
                        request.headers.bearerAuthorization = BearerAuthorization(token: jwtToken)
                        return try await oidcMiddleware.respond(to: request, chainingTo: next)
                    } else {
                        // For mock tokens, use the username directly
                        request.logger.info("🔍 Looking up user in database: \(username)")
                        guard let user = try await findUser(username: username, on: request.db) else {
                            request.logger.error("❌ User not found in database: \(username)")
                            throw Abort(.unauthorized, reason: "User not found in system")
                        }
                        request.logger.info("✅ User found in database - ID: \(user.id ?? UUID()), role: \(user.role)")

                        return try await CurrentUserContext.$user.withValue(user) {
                            // Create a mock JWT payload for consistency
                            let mockPayload = CustomJWTPayload(
                                iss: IssuerClaim(value: configuration.issuer),
                                aud: AudienceClaim(value: [configuration.clientId]),
                                exp: ExpirationClaim(value: Date().addingTimeInterval(3600)),
                                sub: SubjectClaim(value: username),
                                email: user.person?.email,
                                name: user.person?.name
                            )
                            request.auth.login(mockPayload)

                            return try await next.respond(to: request)
                        }
                    }
                } else {
                    // Fallback: treat as direct JWT token
                    request.logger.info("🎫 Session contains single token, treating as JWT")
                    request.headers.bearerAuthorization = BearerAuthorization(token: sessionToken)
                    return try await oidcMiddleware.respond(to: request, chainingTo: next)
                }
            } else {
                request.logger.warning("⚠️ Session ID not found in storage: \(sessionId)")
            }
        } else {
            request.logger.info("🍪 No session cookie found")
        }

        // Otherwise, check for ALB headers
        guard let albIdentity = request.headers.first(name: "X-Amzn-Oidc-Identity") else {
            // Always redirect to login page when authentication is missing
            request.logger.info("🚫 No authentication found, redirecting to login")
            let redirectURL = "/login?redirect=\(request.url.path)"
            return request.redirect(to: redirectURL)
        }

        request.logger.info("🔐 Found ALB authentication header - Identity: \(albIdentity)")

        // Extract username from ALB identity header
        let username = albIdentity

        // Find existing user in database - do not create if doesn't exist
        request.logger.info("🔍 Looking up ALB user in database: \(username)")
        guard let user = try await findUser(username: username, on: request.db) else {
            request.logger.error("❌ ALB user not found in database: \(username)")
            throw Abort(.unauthorized, reason: "User not found in system")
        }
        request.logger.info("✅ ALB user found in database - ID: \(user.id ?? UUID()), role: \(user.role)")

        // Set current user in TaskLocal
        return try await CurrentUserContext.$user.withValue(user) {
            // Create a mock JWT payload for consistency with Bearer token auth
            let mockPayload = CustomJWTPayload(
                iss: IssuerClaim(value: configuration.issuer),
                aud: AudienceClaim(value: [configuration.clientId]),
                exp: ExpirationClaim(value: Date().addingTimeInterval(3600)),
                sub: SubjectClaim(value: username),
                email: user.person?.email,
                name: user.person?.name
            )
            request.auth.login(mockPayload)

            return try await next.respond(to: request)
        }
    }

    /// Finds an existing user in the database by username.
    ///
    /// This method implements the security requirement that only pre-existing users can authenticate.
    /// It will NOT create new users and returns `nil` if the user doesn't exist.
    ///
    /// - Parameters:
    ///   - username: The username to search for
    ///   - db: The database connection to use for the query
    /// - Returns: The user if found, `nil` if not found
    /// - Throws: Database errors if the query fails
    private func findUser(username: String, on db: Database) async throws -> User? {
        db.logger.info("🗄️ Querying database for user: \(username)")

        // Only find existing user - do not create new users
        let user = try await User.query(on: db)
            .filter(\.$username == username)
            .with(\.$person)
            .first()

        if let user = user {
            db.logger.info("✅ User found - ID: \(user.id ?? UUID()), username: \(user.username), role: \(user.role)")
            if let person = user.person {
                db.logger.info(
                    "👤 Person linked - ID: \(person.id ?? UUID()), name: \(person.name), email: \(person.email)"
                )
            } else {
                db.logger.warning("⚠️ User has no linked person record")
            }
        } else {
            db.logger.warning("❌ No user found with username: \(username)")
        }

        return user
    }

    /// Constructs the Dex login URL for the current request.
    ///
    /// This method builds the OIDC authorization URL with appropriate parameters
    /// for the Dex login flow.
    ///
    /// - Parameter request: The current HTTP request
    /// - Returns: The complete Dex login URL
    private func constructDexLoginURL(for request: Request) -> String {
        let dexBase = configuration.issuer
        let clientId = configuration.clientId
        let redirectUri = "http://localhost:8080/auth/dex/callback"

        // Construct the authorization endpoint URL
        let authEndpoint = "\(dexBase)/auth"

        // Build query parameters
        var components = URLComponents(string: authEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "state", value: request.url.path),
        ]

        return components.string ?? authEndpoint
    }
}
