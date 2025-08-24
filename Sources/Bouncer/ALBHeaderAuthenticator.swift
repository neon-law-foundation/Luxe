import Dali
import Fluent
import Foundation
import JWT
import Vapor

/// Authenticator that validates AWS ALB/Cognito injected headers
///
/// This authenticator processes authentication headers injected by AWS Application Load Balancer
/// when configured with Cognito authentication. It replaces session-based authentication
/// with stateless header-based authentication.
///
/// ## Security Model
///
/// - **Pre-existing Users Only**: Will NOT create new users automatically
/// - **Database Verification**: Each request validates the user exists in `auth.users`
/// - **Stateless**: No session state required, purely header-based
/// - **ALB Trust**: Headers are trusted only when coming from ALB (production) or mocked (development)
///
/// ## Usage
///
/// ```swift
/// let authenticator = ALBHeaderAuthenticator(configuration: oidcConfig)
/// let protected = app.grouped(authenticator)
/// ```
public struct ALBHeaderAuthenticator: AsyncRequestAuthenticator, ALBAuthenticatorProtocol {
    /// OIDC configuration for JWT validation
    public let configuration: OIDCConfiguration

    /// ALB header validator for parsing and validating headers
    private let headerValidator: ALBHeaderValidator

    /// Audit logger for authentication events
    private let auditLogger: AuthAuditLogger

    /// Creates a new ALB header authenticator
    ///
    /// - Parameter configuration: OIDC configuration for the environment
    public init(configuration: OIDCConfiguration) {
        self.configuration = configuration
        self.headerValidator = ALBHeaderValidator(
            logger: Logger(label: "alb.header.validator"),
            requireAllHeaders: false
        )
        self.auditLogger = AuthAuditLogger(logger: Logger(label: "auth.audit"))
    }

    /// Authenticates requests using ALB-injected headers
    ///
    /// This method:
    /// 1. Checks for ALB OIDC headers (allows public routes if not present)
    /// 2. Validates and decodes the ALB JWT token
    /// 3. Looks up the user in the database
    /// 4. Sets authentication context if successful
    /// 5. Logs authentication events for audit purposes
    ///
    /// - Parameter request: The incoming HTTP request
    /// - Throws: `Abort(.unauthorized)` if authentication fails
    public func authenticate(request: Request) async throws {
        request.logger.info("🔐 ALBHeaderAuthenticator processing request: \(request.url.path)")

        // Validate ALB headers
        let validationResult = headerValidator.validate(request: request)

        // No headers = public route, allow through
        guard let extractedData = validationResult.extractedData else {
            request.logger.debug("🌍 No ALB headers found, allowing public access")
            return
        }

        // Headers present but invalid = authentication failure
        if !validationResult.isValid {
            request.logger.error("❌ Invalid ALB headers: \(validationResult.errors.joined(separator: ", "))")

            auditLogger.logAuthenticationFailure(
                reason: "Invalid ALB headers: \(validationResult.errors.joined(separator: ", "))",
                requestPath: request.url.path,
                userAgent: request.headers.first(name: "user-agent"),
                sourceIP: request.remoteAddress?.hostname
            )

            throw Abort(.unauthorized, reason: "Invalid authentication headers")
        }

        request.logger.info("🎫 Valid ALB headers found for sub: \(extractedData.cognitoSub)")

        // Find existing user in database
        let user = try await findOrCreateUser(
            extractedData: extractedData,
            request: request
        )

        // Load person relationship
        try await user.$person.load(on: request.db)

        // Set authentication context
        // Note: User itself is stored, not wrapped in another type
        request.auth.login(user)

        // Audit log successful authentication
        let albHeaders = extractHeaders(from: request)
        auditLogger.logAuthentication(
            userId: user.id,
            cognitoSub: extractedData.cognitoSub,
            cognitoGroups: extractedData.cognitoGroups,
            requestPath: request.url.path,
            userAgent: request.headers.first(name: "user-agent"),
            sourceIP: request.remoteAddress?.hostname,
            albHeaders: albHeaders
        )

        request.logger.info("✅ User authenticated from ALB headers: \(user.username)")
    }

    /// Finds an existing user or returns nil (does not create)
    ///
    /// Lookup strategy:
    /// 1. First try to find by Cognito sub
    /// 2. Then try by email
    /// 3. Finally try by username
    ///
    /// - Parameters:
    ///   - extractedData: Data extracted from ALB headers
    ///   - request: The HTTP request for database access
    /// - Returns: The authenticated user
    /// - Throws: `Abort(.unauthorized)` if user not found
    private func findOrCreateUser(
        extractedData: ALBHeaderValidator.ValidationResult.ExtractedData,
        request: Request
    ) async throws -> User {
        request.logger.info("🔍 Looking up user with sub: \(extractedData.cognitoSub)")

        // Try to find by Cognito sub first
        if let user = try await User.query(on: request.db)
            .filter(\.$sub == extractedData.cognitoSub)
            .first()
        {
            request.logger.info("🎯 Found user by Cognito sub: \(extractedData.cognitoSub)")
            return user
        }

        // Try to find by email
        if let email = extractedData.email {
            if let user = try await User.query(on: request.db)
                .filter(\.$username == email)
                .first()
            {
                request.logger.info("📧 Found user by email: \(email)")
                // Update the sub field if not set
                if user.sub == nil || user.sub?.isEmpty == true {
                    user.sub = extractedData.cognitoSub
                    try await user.save(on: request.db)
                    request.logger.info("🔄 Updated user sub field")
                }
                return user
            }
        }

        // Try to find by username
        if let user = try await User.query(on: request.db)
            .filter(\.$username == extractedData.username)
            .first()
        {
            request.logger.info("👤 Found user by username: \(extractedData.username)")
            // Update the sub field if not set
            if user.sub == nil || user.sub?.isEmpty == true {
                user.sub = extractedData.cognitoSub
                try await user.save(on: request.db)
                request.logger.info("🔄 Updated user sub field")
            }
            return user
        }

        request.logger.error("❌ User not found in database for sub: \(extractedData.cognitoSub)")
        throw Abort(.unauthorized, reason: "User not found in system")
    }

    /// Extracts ALB headers for audit logging
    private func extractHeaders(from request: Request) -> [String: String] {
        var headers: [String: String] = [:]

        for header in request.headers {
            if header.name.lowercased().hasPrefix("x-amzn-") {
                headers[header.name] = header.value
            }
        }

        return headers
    }
}

/// Error type for validation failures
struct ValidationError: Error, LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}
