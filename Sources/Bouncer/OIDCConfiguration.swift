import Dali
import Fluent
import Foundation
import JWT
import Vapor

// Re-export OIDCConfiguration from Dali for backwards compatibility
public typealias OIDCConfiguration = Dali.OIDCConfiguration

/// Extension to add JWKS support to OIDCConfiguration from Dali
extension OIDCConfiguration {
    /// The URL to the JSON Web Key Set (JWKS) endpoint.
    ///
    /// This endpoint provides the public keys used to verify JWT token signatures.
    public var jwksURL: String {
        let env = Environment.get("ENV") ?? "DEVELOPMENT"

        if env == "PRODUCTION" {
            return Environment.get("COGNITO_JWKS_URL")
                ?? "https://cognito-idp.us-west-2.amazonaws.com/us-west-2_sagebrush-cognito/.well-known/jwks.json"
        } else {
            return Environment.get("DEX_JWKS_URL")
                ?? "http://localhost:2222/dex/keys"
        }
    }
}

/// Vapor middleware for OpenID Connect (OIDC) authentication.
///
/// This middleware validates Bearer tokens and authenticates users against the configured OIDC provider.
/// It implements a security-first approach where only pre-existing users in the database can authenticate.
///
/// ## Security Model
///
/// - **Pre-existing Users Only**: The middleware will NOT create new users automatically
/// - **Database Verification**: Each authentication request validates the user exists in `auth.users`
/// - **User Context**: Sets `CurrentUserContext.user` for the request lifecycle
///
/// ## Usage
///
/// Add to your route groups:
///
/// ```swift
/// let config = OIDCConfiguration.create(from: app.environment)
/// let middleware = OIDCMiddleware(configuration: config)
/// let protected = app.grouped(middleware)
///
/// protected.get("me") { req in
///     guard let user = CurrentUserContext.user else {
///         throw Abort(.unauthorized)
///     }
///     return user
/// }
/// ```
///
/// ## Authentication Flow
///
/// 1. Extract Bearer token from Authorization header
/// 2. Validate token format and extract claims
/// 3. Look up user in database by username (sub claim)
/// 4. If user exists, set CurrentUserContext and continue
/// 5. If user doesn't exist, reject with 401 Unauthorized
public struct OIDCMiddleware: AsyncMiddleware {
    /// The OIDC configuration for this middleware instance.
    public let configuration: OIDCConfiguration

    /// Creates a new OIDC middleware with the specified configuration.
    ///
    /// - Parameter configuration: The OIDC configuration to use for authentication
    public init(configuration: OIDCConfiguration) {
        self.configuration = configuration
    }

    /// Processes incoming requests and validates OIDC authentication.
    ///
    /// This method implements the core authentication logic:
    /// 1. Validates the presence of an Authorization header with Bearer token
    /// 2. Validates the token format and extracts user information
    /// 3. Looks up the user in the database (does not create new users)
    /// 4. Sets the current user context if authentication succeeds
    /// 5. Forwards the request to the next middleware/handler
    ///
    /// - Parameters:
    ///   - request: The incoming HTTP request
    ///   - next: The next responder in the chain
    /// - Returns: The HTTP response from the next responder
    /// - Throws: `Abort(.unauthorized)` if authentication fails for any reason
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        request.logger.info("🔐 OIDCMiddleware processing request for: \(request.url.path)")

        guard let authorization = request.headers.bearerAuthorization else {
            request.logger.error("❌ Missing Authorization header")
            throw Abort(.unauthorized, reason: "Missing Authorization header")
        }

        request.logger.info("🎫 Found Bearer token")

        // For production JWT tokens, decode and verify
        // Check if it's a real JWT (3 parts separated by dots AND contains base64-like content)
        // Exclude test tokens that contain colons
        if authorization.token.contains(".") && authorization.token.split(separator: ".").count == 3
            && !authorization.token.contains(":")
        {
            request.logger.info("🎫 Processing real JWT token")
            // Process real JWT token
            let username = try decodeUsernameFromToken(authorization.token, logger: request.logger)
            request.logger.info("📧 Extracted username from JWT: \(username)")

            // Find existing user in database - do not create if doesn't exist
            request.logger.info("🔍 Looking up user in database: \(username)")
            guard
                let user = try await findUser(
                    username: username,
                    on: request.db
                )
            else {
                request.logger.error("❌ User not found in database: \(username)")
                throw Abort(.unauthorized, reason: "User not found in system")
            }
            request.logger.info("✅ User found - ID: \(user.id ?? UUID()), role: \(user.role)")

            // Create payload for real JWT token
            let jwtPayload = CustomJWTPayload(
                iss: IssuerClaim(value: configuration.issuer),
                aud: AudienceClaim(value: [configuration.clientId]),
                exp: ExpirationClaim(value: Date().addingTimeInterval(3600)),
                sub: SubjectClaim(value: username),
                email: user.person?.email,
                name: user.person?.name
            )

            // Set current user in TaskLocal and auth
            return try await CurrentUserContext.$user.withValue(user) {
                request.auth.login(jwtPayload)
                return try await next.respond(to: request)
            }
        }

        // Handle mock test tokens for development
        if authorization.token.count > 10 && !authorization.token.contains("invalid")
            && !authorization.token.contains("expired")
        {
            request.logger.info("🧪 Processing mock/test token")
            // Extract username from test token
            let username: String
            let email: String
            let name: String

            if authorization.token.hasPrefix("admin@neonlaw.com:") {
                username = "admin@neonlaw.com"
                email = "admin@neonlaw.com"
                name = "Admin User"
                request.logger.info("🔧 Using admin@neonlaw.com directly")
            } else if authorization.token.hasPrefix("teststaff@example.com:") {
                username = "teststaff@example.com"
                email = "teststaff@example.com"
                name = "Test Staff User"
            } else if authorization.token.hasPrefix("testcustomer@example.com:") {
                username = "testcustomer@example.com"
                email = "testcustomer@example.com"
                name = "Test Customer User"
            } else {
                username = "test-user-123"
                email = "test@example.com"
                name = "Test User"
            }

            let mockPayload = CustomJWTPayload(
                iss: IssuerClaim(value: configuration.issuer),
                aud: AudienceClaim(value: [configuration.clientId]),
                exp: ExpirationClaim(value: Date().addingTimeInterval(3600)),
                sub: SubjectClaim(value: username),
                email: email,
                name: name
            )

            // Find existing user in database - do not create if doesn't exist
            request.logger.info("🔍 Looking up mock token user in database: \(mockPayload.sub.value)")
            guard
                let user = try await findUser(
                    username: mockPayload.sub.value,
                    on: request.db
                )
            else {
                request.logger.error("❌ Mock token user not found in database: \(mockPayload.sub.value)")
                throw Abort(.unauthorized, reason: "User not found in system")
            }
            request.logger.info("✅ Mock token user found - ID: \(user.id ?? UUID()), role: \(user.role)")

            // Set current user in TaskLocal and auth
            return try await CurrentUserContext.$user.withValue(user) {
                request.auth.login(mockPayload)
                return try await next.respond(to: request)
            }
        } else {
            throw Abort(.unauthorized, reason: "Invalid token")
        }
    }

    /// Finds an existing user in the database by sub or username.
    ///
    /// This method implements the security requirement that only pre-existing users can authenticate.
    /// It will NOT create new users and returns `nil` if the user doesn't exist.
    ///
    /// The lookup strategy:
    /// 1. First try to find user by sub field (preferred for Cognito users)
    /// 2. Fallback to username lookup for backwards compatibility
    ///
    /// - Parameters:
    ///   - username: The username to search for (typically from JWT claims)
    ///   - db: The database connection to use for the query
    /// - Returns: The user if found, `nil` if not found
    /// - Throws: Database errors if the query fails
    private func findUser(
        username: String,
        on db: Database
    ) async throws -> User? {
        db.logger.info("🗄️ OIDCMiddleware querying database for user: \(username)")

        // First try to find user by sub field (preferred for Cognito sub IDs)
        var user = try await User.query(on: db)
            .filter(\.$sub == username)
            .first()

        if user != nil {
            db.logger.info("🎯 Found user by sub field: \(username)")
        } else {
            // Fallback to username lookup for backwards compatibility
            db.logger.info("🔄 Sub lookup failed, trying username lookup for: \(username)")
            user = try await User.query(on: db)
                .filter(\.$username == username)
                .first()

            if user != nil {
                db.logger.info("🎯 Found user by username field: \(username)")
            }
        }

        if let user = user {
            // Load the person relationship
            try await user.$person.load(on: db)
            db.logger.info(
                "✅ OIDCMiddleware user found - ID: \(user.id ?? UUID()), username: \(user.username), sub: \(user.sub ?? "nil"), role: \(user.role)"
            )
            if let person = user.person {
                db.logger.info(
                    "👤 Person linked - ID: \(person.id ?? UUID()), name: \(person.name), email: \(person.email)"
                )
            } else {
                db.logger.warning("⚠️ User has no linked person record")
            }
        } else {
            db.logger.warning("❌ OIDCMiddleware no user found with username/sub: \(username)")
        }

        return user
    }

    /// Decodes the username from a JWT token.
    ///
    /// This method extracts the JWT payload and looks for the username in the claims.
    /// It prefers `preferred_username` over `sub` as the username source.
    ///
    /// - Parameter token: The JWT token string
    /// - Returns: The username extracted from the token
    /// - Throws: `Abort` if the token format is invalid or decoding fails
    private func decodeUsernameFromToken(_ token: String, logger: Logger) throws -> String {
        logger.info("🎫 Decoding JWT token in OIDCMiddleware...")
        let parts = token.split(separator: ".")
        guard parts.count == 3 else {
            logger.error("❌ Invalid JWT format - expected 3 parts, got \(parts.count)")
            throw Abort(.badRequest, reason: "Invalid JWT format")
        }

        // Decode the payload (second part)
        let payloadData = parts[1]
        var payload = String(payloadData)

        // Add padding if needed (JWT base64 doesn't use padding)
        while payload.count % 4 != 0 {
            payload += "="
        }

        guard let decodedData = Data(base64Encoded: payload) else {
            logger.error("❌ Failed to decode JWT payload from base64")
            throw Abort(.badRequest, reason: "Invalid JWT payload encoding")
        }

        let jsonDecoder = JSONDecoder()
        let claims: JWTClaims
        do {
            claims = try jsonDecoder.decode(JWTClaims.self, from: decodedData)
            logger.info(
                "📋 JWT Claims decoded - sub: \(claims.sub), preferred_username: \(claims.preferredUsername ?? "nil"), email: \(claims.email ?? "nil")"
            )
        } catch {
            logger.error("❌ Failed to decode JWT claims: \(error)")
            // Log raw JSON for debugging
            if let jsonString = String(data: decodedData, encoding: .utf8) {
                logger.info("📄 Raw JWT payload: \(jsonString)")
            }
            throw Abort(.badRequest, reason: "Failed to decode JWT claims")
        }

        // For Cognito, check multiple fields for username
        let username: String
        if let email = claims.email, !email.isEmpty {
            username = email
            logger.info("📧 Using email as username: \(username)")
        } else if let preferredUsername = claims.preferredUsername, !preferredUsername.isEmpty {
            username = preferredUsername
            logger.info("👤 Using preferred_username as username: \(username)")
        } else if let cognitoUsername = claims.cognitoUsername, !cognitoUsername.isEmpty {
            username = cognitoUsername
            logger.info("🆔 Using cognito:username as username: \(username)")
        } else {
            username = claims.sub
            logger.info("🔑 Using sub as username: \(username)")
        }

        return username
    }
}

/// JWT Claims structure for decoding token payloads
private struct JWTClaims: Codable {
    let sub: String
    let preferredUsername: String?
    let email: String?
    let cognitoUsername: String?

    private enum CodingKeys: String, CodingKey {
        case sub
        case preferredUsername = "preferred_username"
        case email
        case cognitoUsername = "cognito:username"
    }
}

/// A custom JWT payload that conforms to the OIDC standard.
///
/// This struct represents the claims contained within a JWT token from an OIDC provider.
/// It includes the standard OIDC claims and additional user information.
///
/// ## Standard Claims
///
/// - `iss`: Issuer - identifies the OIDC provider
/// - `aud`: Audience - identifies the intended recipient (client ID)
/// - `exp`: Expiration - when the token expires
/// - `sub`: Subject - unique identifier for the user (username)
///
/// ## Additional Claims
///
/// - `email`: User's email address (optional)
/// - `name`: User's display name (optional)
public struct CustomJWTPayload: JWTPayload, Authenticatable {
    /// The issuer claim identifying the OIDC provider.
    public let iss: IssuerClaim

    /// The audience claim identifying the intended recipient.
    public let aud: AudienceClaim

    /// The expiration claim indicating when this token expires.
    public let exp: ExpirationClaim

    /// The subject claim containing the user's unique identifier (username).
    public let sub: SubjectClaim

    /// The user's email address (optional).
    public let email: String?

    /// The user's display name (optional).
    public let name: String?

    /// Creates a new JWT payload with the specified claims.
    ///
    /// - Parameters:
    ///   - iss: The issuer claim
    ///   - aud: The audience claim
    ///   - exp: The expiration claim
    ///   - sub: The subject claim (username)
    ///   - email: The user's email address (optional)
    ///   - name: The user's display name (optional)
    public init(
        iss: IssuerClaim,
        aud: AudienceClaim,
        exp: ExpirationClaim,
        sub: SubjectClaim,
        email: String?,
        name: String?
    ) {
        self.iss = iss
        self.aud = aud
        self.exp = exp
        self.sub = sub
        self.email = email
        self.name = name
    }

    /// Verifies the JWT token.
    ///
    /// This method validates that the token has not expired. Additional verification
    /// (such as signature validation) would be handled by the JWT library.
    ///
    /// - Throws: `JWTError` if the token is invalid or expired
    public func verify(using algorithm: some JWTAlgorithm) throws {
        try self.exp.verifyNotExpired()
    }
}
