import Crypto
import Dali
import Foundation
import Vapor

/// Test service account authentication middleware that bypasses database lookups for HTTP tests.
///
/// This middleware solves the transaction isolation issue where HTTP handlers cannot
/// see test data created within test transactions. Instead of querying the database,
/// it creates mock service account objects directly from token patterns.
///
/// ## Usage
///
/// Use this middleware in test configurations instead of ServiceAccountAuthenticationMiddleware:
///
/// ```swift
/// func configureTestApp(_ app: Application) throws {
///     let testServiceMiddleware = TestServiceAccountMiddleware()
///     let protected = app.grouped(testServiceMiddleware)
/// }
/// ```
///
/// ## Supported Token Patterns
///
/// The middleware recognizes these mock token patterns:
/// - `test-slack-token-1234567890abcdef` -> Slack bot service account
/// - `test-monitoring-token-9876543210fedcba` -> Monitoring service account
/// - `test-cicd-token-abcdef1234567890` -> CI/CD service account
///
/// ## Benefits
///
/// - **No Database Dependency**: Creates service accounts without database queries
/// - **Transaction Compatible**: Works with transaction-based test cleanup
/// - **Fast Execution**: Eliminates database round-trips during testing
/// - **Predictable Behavior**: Consistent test results without database state
public struct TestServiceAccountMiddleware: AsyncMiddleware {
    /// Logger for debugging
    private let logger: Logger

    /// Creates a new test service account authentication middleware.
    public init() {
        self.logger = Logger(label: "bouncer.test.service.account")
    }

    /// Processes incoming requests and provides mock service account authentication for tests.
    ///
    /// This method implements test service account authentication by:
    /// 1. Extracting Bearer token from Authorization header
    /// 2. Creating mock service account objects based on token patterns (no database lookup)
    /// 3. Setting service account in request storage
    /// 4. Forwarding the request to the next middleware/handler
    ///
    /// - Parameters:
    ///   - request: The incoming HTTP request
    ///   - next: The next responder in the chain
    /// - Returns: The HTTP response from the next responder
    /// - Throws: `Abort(.unauthorized)` if no valid Bearer token is found
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        logger.info("🧪 TestServiceAccountMiddleware processing request for: \(request.url.path)")

        // Extract Bearer token from Authorization header
        guard let authHeader = request.headers.bearerAuthorization else {
            logger.error("❌ Missing Authorization header for service account")
            throw Abort(.unauthorized, reason: "Missing authorization header")
        }

        let rawToken = authHeader.token
        logger.info("🎫 Found service account Bearer token (test mode)")

        // Validate token format (basic validation)
        guard !rawToken.isEmpty else {
            logger.error("❌ Empty service account token")
            throw Abort(.unauthorized, reason: "Invalid token format")
        }

        guard rawToken.count >= 32 else {
            logger.error("❌ Service account token too short")
            throw Abort(.unauthorized, reason: "Invalid token format")
        }

        // Create mock service account based on token pattern
        let serviceToken = try createMockServiceAccount(from: rawToken)

        logger.info("✅ Created mock service account: \(serviceToken.name) (\(serviceToken.serviceType.displayName))")

        // Check service type for Slack webhook endpoints (if path starts with /slack/)
        if request.url.path.hasPrefix("/slack/") {
            // For Slack endpoints, verify the token is for a Slack bot
            guard serviceToken.serviceType == .slackBot else {
                logger.error("🚫 Non-Slack bot token used for Slack endpoint")
                throw Abort(.forbidden, reason: "Invalid service account for Slack webhook access")
            }
        }

        // Set service account token in request storage for downstream use
        request.serviceAccountToken = serviceToken

        logger.info("✅ Test service account authentication successful for: \(serviceToken.name)")

        // Continue to next middleware/handler
        return try await next.respond(to: request)
    }

    /// Creates a mock service account object based on the Bearer token pattern.
    ///
    /// This method recognizes token patterns and creates corresponding ServiceAccountToken
    /// objects without any database interaction. This eliminates transaction isolation
    /// issues while maintaining compatibility with test tokens.
    ///
    /// - Parameter token: The Bearer token string
    /// - Returns: A mock ServiceAccountToken object
    /// - Throws: `Abort(.unauthorized)` for unrecognized token patterns
    private func createMockServiceAccount(from token: String) throws -> ServiceAccountToken {
        logger.info("🔧 Creating mock service account from token pattern")

        // Recognize test token patterns and create appropriate service accounts
        switch token {
        case "test-slack-token-1234567890abcdef":
            // SHA256 hash would be: bd358097ce2a8e7f36acc103ec68477988edf27cc4105fc89c84417c1b2371ac
            let serviceToken = ServiceAccountToken(
                name: "test-slack-bot",
                tokenHash: "bd358097ce2a8e7f36acc103ec68477988edf27cc4105fc89c84417c1b2371ac",
                serviceType: .slackBot
            )
            serviceToken.id = UUID()  // Set an ID for the mock
            serviceToken.isActive = true
            return serviceToken

        case "test-monitoring-token-9876543210fedcba":
            // SHA256 hash would be: 1ad277eb6cb868e3a5da07f47182901b81002da2b799b7f3a9216a9bb90ba8a8
            let serviceToken = ServiceAccountToken(
                name: "test-monitoring",
                tokenHash: "1ad277eb6cb868e3a5da07f47182901b81002da2b799b7f3a9216a9bb90ba8a8",
                serviceType: .monitoring
            )
            serviceToken.id = UUID()  // Set an ID for the mock
            serviceToken.isActive = true
            return serviceToken

        case "test-cicd-token-abcdef1234567890":
            let serviceToken = ServiceAccountToken(
                name: "test-cicd",
                tokenHash: "test-cicd-hash",
                serviceType: .cicd
            )
            serviceToken.id = UUID()  // Set an ID for the mock
            serviceToken.isActive = true
            return serviceToken

        default:
            logger.error("❌ Invalid or unrecognized test service account token")
            throw Abort(.unauthorized, reason: "Invalid service account token")
        }
    }
}

// MARK: - Test Configuration Helper

extension Application {
    /// Configures test service account authentication for the application.
    ///
    /// Use this in test setup instead of the real ServiceAccountAuthenticationMiddleware:
    ///
    /// ```swift
    /// func configureTestApp(_ app: Application) throws {
    ///     app.configureTestServiceAccountAuth()
    ///     // ... rest of configuration
    /// }
    /// ```
    public func configureTestServiceAccountAuth() {
        logger.info("🧪 Configuring test service account authentication")
        // This extension point can be used to set up test-specific configuration
    }
}
