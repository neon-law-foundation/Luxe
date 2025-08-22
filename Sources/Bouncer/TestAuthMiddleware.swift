import Dali
import Foundation
import JWT
import Vapor

/// Test authentication middleware that bypasses database lookups for HTTP tests.
///
/// This middleware solves the transaction isolation issue where HTTP handlers cannot
/// see test data created within test transactions. Instead of querying the database,
/// it creates mock user objects directly from token patterns.
///
/// ## Usage
///
/// Use this middleware in test configurations instead of OIDCMiddleware:
///
/// ```swift
/// func configureTestApp(_ app: Application) throws {
///     let testAuthMiddleware = TestAuthMiddleware()
///     let protected = app.grouped(testAuthMiddleware)
/// }
/// ```
///
/// ## Supported Token Patterns
///
/// The middleware recognizes the same mock token patterns as OIDCMiddleware:
/// - `admin@neonlaw.com:valid.test.token` -> Admin user
/// - `teststaff@example.com:valid.test.token` -> Staff user
/// - `testcustomer@example.com:valid.test.token` -> Customer user
///
/// ## Benefits
///
/// - **No Database Dependency**: Creates users without database queries
/// - **Transaction Compatible**: Works with transaction-based test cleanup
/// - **Fast Execution**: Eliminates database round-trips during testing
/// - **Existing Token Support**: Uses same token format as current tests
public struct TestAuthMiddleware: AsyncMiddleware {

    /// Creates a new test authentication middleware.
    public init() {}

    /// Processes incoming requests and provides mock authentication for tests.
    ///
    /// This method implements test authentication by:
    /// 1. Extracting Bearer token from Authorization header
    /// 2. Creating mock user objects based on token patterns (no database lookup)
    /// 3. Setting CurrentUserContext for the request
    /// 4. Forwarding the request to the next middleware/handler
    ///
    /// - Parameters:
    ///   - request: The incoming HTTP request
    ///   - next: The next responder in the chain
    /// - Returns: The HTTP response from the next responder
    /// - Throws: `Abort(.unauthorized)` if no valid Bearer token is found
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        request.logger.info("🧪 TestAuthMiddleware processing request for: \(request.url.path)")

        guard let authorization = request.headers.bearerAuthorization else {
            request.logger.error("❌ Missing Authorization header")
            throw Abort(.unauthorized, reason: "Missing Authorization header")
        }

        request.logger.info("🎫 Found Bearer token: \(String(authorization.token.prefix(20)))...")

        // Create mock user based on token pattern (no database lookup needed)
        let mockUser = try createMockUser(from: authorization.token, logger: request.logger)

        request.logger.info("✅ Created mock user - username: \(mockUser.username), role: \(mockUser.role)")

        // Create JWT payload for compatibility
        let jwtPayload = CustomJWTPayload(
            iss: IssuerClaim(value: "test-issuer"),
            aud: AudienceClaim(value: ["test-audience"]),
            exp: ExpirationClaim(value: Date().addingTimeInterval(3600)),
            sub: SubjectClaim(value: mockUser.username),
            email: mockUser.person?.email,
            name: mockUser.person?.name
        )

        // Set current user context and continue
        return try await CurrentUserContext.$user.withValue(mockUser) {
            request.auth.login(jwtPayload)
            return try await next.respond(to: request)
        }
    }

    /// Creates a mock user object based on the Bearer token pattern.
    ///
    /// This method recognizes token patterns and creates corresponding User and Person
    /// objects without any database interaction. This eliminates transaction isolation
    /// issues while maintaining compatibility with existing test tokens.
    ///
    /// - Parameters:
    ///   - token: The Bearer token string
    ///   - logger: Logger for debugging output
    /// - Returns: A mock User object with associated Person
    /// - Throws: `Abort(.unauthorized)` for invalid or expired tokens
    private func createMockUser(from token: String, logger: Logger) throws -> User {
        logger.info("🔧 Creating mock user from token pattern")

        let username: String
        let email: String
        let name: String
        let role: UserRole

        // Map token patterns to user properties (same logic as OIDCMiddleware)
        if token.hasPrefix("admin@neonlaw.com:") {
            username = "admin@neonlaw.com"
            email = "admin@neonlaw.com"
            name = "Admin User"
            role = .admin
            logger.info("🔧 Using admin@neonlaw.com admin pattern")
        } else if token.hasPrefix("teststaff@example.com:") {
            username = "teststaff@example.com"
            email = "teststaff@example.com"
            name = "Test Staff User"
            role = .staff
            logger.info("🔧 Using test staff pattern")
        } else if token.hasPrefix("testcustomer@example.com:") {
            username = "testcustomer@example.com"
            email = "testcustomer@example.com"
            name = "Test Customer User"
            role = .customer
            logger.info("🔧 Using test customer pattern")
        } else {
            // Reject specific invalid token patterns
            if token == "invalid-token-format" || token == "expired-token-format" || token == "invalid" {
                logger.error("❌ Invalid/expired token pattern: \(token)")
                throw Abort(.unauthorized, reason: "Invalid or expired token")
            }

            // Default test user for unrecognized patterns
            username = "test-user-123"
            email = "test@example.com"
            name = "Test User"
            role = .customer
            logger.info("🔧 Using default test user pattern")
        }

        // Create mock Person object
        let mockPerson = Person()
        mockPerson.id = UUID()
        mockPerson.name = name
        mockPerson.email = email

        // Create mock User object
        let mockUser = User()
        mockUser.id = UUID()
        mockUser.username = username
        mockUser.sub = username  // Use username as sub for consistency
        mockUser.role = role

        // Don't set the person relationship directly - it's read-only
        // The TestAuthMiddleware doesn't need the relationship for authentication
        // If needed, we can set the person_id field instead, but for now it's not required

        logger.info("👤 Created mock person - ID: \(mockPerson.id!), name: \(name), email: \(email)")
        logger.info("👤 Created mock user - ID: \(mockUser.id!), username: \(username), role: \(role)")

        return mockUser
    }
}
