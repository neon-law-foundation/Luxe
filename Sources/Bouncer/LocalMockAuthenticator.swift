import Dali
import Fluent
import Foundation
import JWT
import Vapor

/// Mock authenticator for local development and testing
///
/// This authenticator simulates ALB header injection for local development environments
/// where there is no actual ALB/Cognito infrastructure. It allows developers to test
/// authentication flows without needing AWS resources.
///
/// ## Features
///
/// - **Auto-authentication**: Can automatically authenticate as a default user
/// - **Header simulation**: Creates mock ALB headers that match production format
/// - **Environment-based**: Only active in development/testing environments
/// - **Role testing**: Easy switching between different user roles
///
/// ## Usage
///
/// ```swift
/// // In development configuration
/// if app.environment.isDevelopment {
///     let mockUser = try await User.query(on: app.db)
///         .filter(\.$username == "admin@example.com")
///         .first()!
///
///     let mockAuth = LocalMockAuthenticator(defaultUser: mockUser)
///     app.middleware.use(mockAuth)
/// }
/// ```
public struct LocalMockAuthenticator: AsyncRequestAuthenticator {
    /// The default user to authenticate as
    public let defaultUser: User?

    /// Environment variable to check for mock user override
    private let mockUserEnvKey = "MOCK_AUTH_USER"

    /// Environment variable to check for mock user role
    private let mockRoleEnvKey = "MOCK_AUTH_ROLE"

    /// Whether to auto-authenticate (true) or require mock headers (false)
    private let autoAuthenticate: Bool

    /// Logger for debugging
    private let logger: Logger

    /// Creates a mock authenticator for local development
    ///
    /// - Parameters:
    ///   - defaultUser: Optional default user to authenticate as
    ///   - autoAuthenticate: Whether to automatically authenticate requests
    public init(
        defaultUser: User? = nil,
        autoAuthenticate: Bool = true
    ) {
        self.defaultUser = defaultUser
        self.autoAuthenticate = autoAuthenticate
        self.logger = Logger(label: "local.mock.auth")
    }

    /// Authenticates requests in development mode
    ///
    /// This method either:
    /// 1. Auto-authenticates with a default user (if configured)
    /// 2. Looks for mock headers in the request
    /// 3. Creates mock user based on environment variables
    ///
    /// - Parameter request: The incoming HTTP request
    public func authenticate(request: Request) async throws {
        logger.info("🧪 LocalMockAuthenticator processing request: \(request.url.path)")

        // Check if mock headers are already present
        if let existingHeader = request.headers.first(name: "x-amzn-oidc-data") {
            logger.info("🎫 Found existing mock ALB header, skipping mock injection")
            return
        }

        // Only proceed if we're in development/testing
        guard request.application.environment.isDevelopment || request.application.environment.isTesting else {
            logger.warning("⚠️ LocalMockAuthenticator should not be used in production!")
            return
        }

        // Try to get user from environment or use default
        let user = try await getMockUser(from: request)

        guard let user = user else {
            logger.debug("🌍 No mock user configured, allowing unauthenticated access")
            return
        }

        // Create mock ALB headers
        injectMockHeaders(for: user, into: request)

        // Set auth context
        request.auth.login(user)

        logger.info("✅ Mock authenticated as: \(user.username) with role: \(user.role)")
    }

    /// Gets the mock user to authenticate as
    ///
    /// Priority:
    /// 1. User specified in MOCK_AUTH_USER environment variable
    /// 2. Default user passed to initializer
    /// 3. Create temporary mock user based on MOCK_AUTH_ROLE
    ///
    /// - Parameter request: The request for database access
    /// - Returns: The mock user or nil
    private func getMockUser(from request: Request) async throws -> User? {
        // Check for environment variable override
        if let mockUsername = Environment.get(mockUserEnvKey) {
            logger.info("📧 Using mock user from environment: \(mockUsername)")

            if let user = try await User.query(on: request.db)
                .filter(\.$username == mockUsername)
                .with(\.$person)
                .first()
            {
                return user
            }

            logger.warning("⚠️ Mock user not found in database: \(mockUsername)")
        }

        // Use default user if provided
        if let defaultUser = defaultUser {
            // Ensure person is loaded
            if defaultUser.person == nil {
                try await defaultUser.$person.load(on: request.db)
            }
            return defaultUser
        }

        // Create mock user based on role
        if let mockRole = Environment.get(mockRoleEnvKey) {
            return createMockUser(withRole: mockRole)
        }

        // No mock user configured
        return nil
    }

    /// Creates a temporary mock user with the specified role
    ///
    /// Note: This creates an in-memory user only, not persisted to database
    ///
    /// - Parameter role: The role string (admin, staff, customer)
    /// - Returns: A mock user with the specified role
    private func createMockUser(withRole role: String) -> User {
        let userRole: UserRole
        let username: String
        let personName: String

        switch role.lowercased() {
        case "admin":
            userRole = .admin
            username = "mock-admin@example.com"
            personName = "Mock Admin"
        case "staff":
            userRole = .staff
            username = "mock-staff@example.com"
            personName = "Mock Staff"
        default:
            userRole = .customer
            username = "mock-customer@example.com"
            personName = "Mock Customer"
        }

        let user = User(
            id: UUID(),
            username: username,
            sub: "mock-sub-\(UUID().uuidString)",
            role: userRole
        )

        // Create associated person
        let person = Person(
            id: UUID(),
            name: personName,
            email: username
        )

        user.person = person

        logger.info("🎭 Created mock user: \(username) with role: \(userRole)")

        return user
    }

    /// Injects mock ALB headers into the request
    ///
    /// Creates headers that match the format expected by ALBHeaderAuthenticator
    ///
    /// - Parameters:
    ///   - user: The user to create headers for
    ///   - request: The request to inject headers into
    private func injectMockHeaders(for user: User, into request: Request) {
        let mockToken = createMockJWT(for: user)

        // Inject ALB-style headers
        request.headers.replaceOrAdd(name: "x-amzn-oidc-data", value: mockToken)
        request.headers.replaceOrAdd(name: "x-amzn-oidc-identity", value: user.username)
        request.headers.replaceOrAdd(name: "x-amzn-oidc-accesstoken", value: "mock-access-token-\(UUID().uuidString)")

        // Add trace header for debugging
        request.headers.replaceOrAdd(name: "x-amzn-trace-id", value: "Root=1-mock-\(UUID().uuidString)")

        logger.debug("💉 Injected mock ALB headers for user: \(user.username)")
    }

    /// Creates a mock JWT token for the user
    ///
    /// The token format matches what ALB would provide in production
    ///
    /// - Parameter user: The user to create a token for
    /// - Returns: A base64-encoded JWT token string
    private func createMockJWT(for user: User) -> String {
        // Create JWT header
        let header = [
            "typ": "JWT",
            "alg": "RS256",
        ]

        // Map user role to Cognito groups
        let cognitoGroups: [String]
        switch user.role {
        case .admin:
            cognitoGroups = ["admin", "staff", "users"]
        case .staff:
            cognitoGroups = ["staff", "users"]
        case .customer:
            cognitoGroups = ["users"]
        }

        // Create JWT payload matching ALB format
        let payload =
            [
                "iss": "https://cognito-idp.us-west-2.amazonaws.com/mock-pool",
                "aud": "mock-client-id",
                "exp": Int(Date().addingTimeInterval(3600).timeIntervalSince1970),
                "iat": Int(Date().timeIntervalSince1970),
                "sub": user.sub ?? user.username,
                "email": user.person?.email ?? user.username,
                "name": user.person?.name ?? "Mock User",
                "preferred_username": user.username,
                "cognito:groups": cognitoGroups,
            ] as [String: Any]

        // Encode to JSON and base64
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        guard let headerData = try? JSONSerialization.data(withJSONObject: header),
            let payloadData = try? JSONSerialization.data(withJSONObject: payload)
        else {
            logger.error("❌ Failed to create mock JWT data")
            return ""
        }

        let headerBase64 = headerData.base64URLEncodedString()
        let payloadBase64 = payloadData.base64URLEncodedString()

        // Create mock signature (not validated in development)
        let signature = "mock-signature"

        // Combine into JWT format
        let jwt = "\(headerBase64).\(payloadBase64).\(signature)"

        logger.debug("🎫 Created mock JWT for user: \(user.username)")

        return jwt
    }
}

// MARK: - Environment Helpers

extension Environment {
    /// Check if this is a development environment
    var isDevelopment: Bool {
        self == .development
    }

    /// Check if this is a testing environment
    var isTesting: Bool {
        self == .testing
    }
}

// MARK: - Base64 URL Encoding

extension Data {
    /// Encodes data as base64 URL-safe string (no padding)
    func base64URLEncodedString() -> String {
        self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
