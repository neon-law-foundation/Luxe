import Crypto
import Dali
import Fluent
import Foundation
import Vapor

/// Storage key for service account token in request storage
struct ServiceAccountTokenKey: StorageKey {
    typealias Value = ServiceAccountToken
}

/// Extension to provide convenient access to service account token from request
extension Request {
    /// The authenticated service account token (if any)
    var serviceAccountToken: ServiceAccountToken? {
        get { storage[ServiceAccountTokenKey.self] }
        set { storage[ServiceAccountTokenKey.self] = newValue }
    }
}

/// Middleware for service account authentication
///
/// This middleware validates service account tokens using SHA256 hash-based authentication.
/// It's designed for authenticating bots and automated services that don't use OAuth flows.
///
/// ## Security Model
///
/// - **Hash-based Authentication**: Tokens are stored as SHA256 hashes for security
/// - **Token Expiration**: Supports optional expiration dates
/// - **Service Type Validation**: Tokens are categorized by service type
/// - **Active Status**: Tokens can be deactivated without deletion
/// - **Last Used Tracking**: Automatically updates last used timestamp
///
/// ## Usage
///
/// ```swift
/// let middleware = ServiceAccountAuthenticationMiddleware()
/// let protected = app.grouped(middleware)
///
/// protected.get("api", "metrics") { req in
///     guard let token = req.serviceAccountToken else {
///         throw Abort(.unauthorized)
///     }
///     // Use token.serviceType to check permissions
///     return try await generateMetrics(for: token.serviceType)
/// }
/// ```
///
/// ## Token Format
///
/// Clients must send tokens in the Authorization header:
/// ```
/// Authorization: Bearer <service-account-token>
/// ```
///
/// ## Database Requirements
///
/// This middleware requires the `service_account_tokens` table to exist.
/// Tokens must be pre-created in the database with their SHA256 hashes.
public struct ServiceAccountAuthenticationMiddleware: AsyncMiddleware {
    /// Logger for debugging and security monitoring
    private let logger: Logger

    /// Creates a new service account authentication middleware
    public init() {
        self.logger = Logger(label: "bouncer.service.account.auth")
    }

    /// Validates service account token and sets authentication context
    ///
    /// ## Authentication Flow
    ///
    /// 1. Extract Bearer token from Authorization header
    /// 2. Compute SHA256 hash of the token
    /// 3. Look up token in database by hash
    /// 4. Validate token is active and not expired
    /// 5. Update last used timestamp
    /// 6. Set service account token in request context
    ///
    /// - Parameters:
    ///   - request: The incoming HTTP request
    ///   - next: The next responder in the chain
    /// - Returns: The HTTP response from the next responder
    /// - Throws: `Abort(.unauthorized)` if authentication fails
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        logger.info("🔐 ServiceAccountAuthenticationMiddleware processing request for: \(request.url.path)")

        // Extract Bearer token from Authorization header
        guard let authHeader = request.headers.bearerAuthorization else {
            logger.error("❌ Missing Authorization header for service account")
            throw Abort(.unauthorized, reason: "Missing authorization header")
        }

        let rawToken = authHeader.token
        logger.info("🎫 Found service account Bearer token")

        // Validate token format (basic validation)
        guard !rawToken.isEmpty else {
            logger.error("❌ Empty service account token")
            throw Abort(.unauthorized, reason: "Invalid token format")
        }

        guard rawToken.count >= 32 else {
            logger.error("❌ Service account token too short")
            throw Abort(.unauthorized, reason: "Invalid token format")
        }

        // Compute SHA256 hash of the token
        let tokenData = Data(rawToken.utf8)
        let hashData = SHA256.hash(data: tokenData)
        let tokenHash = hashData.compactMap { String(format: "%02x", $0) }.joined()

        logger.info("🔒 Computed token hash for lookup")

        // Look up token in database
        guard
            let serviceToken = try await ServiceAccountToken.query(on: request.db)
                .filter(\.$tokenHash == tokenHash)
                .filter(\.$isActive == true)
                .first()
        else {
            logger.error("❌ Invalid or inactive service account token")
            throw Abort(.unauthorized, reason: "Invalid service account token")
        }

        logger.info("🎯 Found service account token: \(serviceToken.name) (\(serviceToken.serviceType.displayName))")

        // Check if token has expired
        if let expiresAt = serviceToken.expiresAt, expiresAt <= Date() {
            logger.error("⏰ Service account token has expired: \(serviceToken.name)")
            throw Abort(.unauthorized, reason: "Service account token expired")
        }

        // Update last used timestamp
        serviceToken.lastUsedAt = Date()
        do {
            try await serviceToken.save(on: request.db)
            logger.debug("📊 Updated last used timestamp for token: \(serviceToken.name)")
        } catch {
            // Don't fail authentication if we can't update timestamp, just log the error
            logger.warning("⚠️ Failed to update last used timestamp: \(error)")
        }

        // Set service account token in request storage for downstream use
        request.serviceAccountToken = serviceToken

        logger.info("✅ Service account authentication successful for: \(serviceToken.name)")

        // Continue to next middleware/handler
        return try await next.respond(to: request)
    }
}

// MARK: - Service Type Authorization Extensions

extension ServiceAccountAuthenticationMiddleware {
    /// Creates middleware that only allows specific service types
    ///
    /// - Parameter allowedTypes: The service types that are allowed
    /// - Returns: A middleware that validates service type
    public static func requireServiceType(_ allowedTypes: ServiceType...) -> ServiceTypeAuthorizationMiddleware {
        ServiceTypeAuthorizationMiddleware(allowedTypes: Set(allowedTypes))
    }

    /// Creates middleware that only allows Slack bot tokens
    public static var requireSlackBot: ServiceTypeAuthorizationMiddleware {
        ServiceTypeAuthorizationMiddleware(allowedTypes: [.slackBot])
    }

    /// Creates middleware that only allows CI/CD tokens
    public static var requireCICD: ServiceTypeAuthorizationMiddleware {
        ServiceTypeAuthorizationMiddleware(allowedTypes: [.cicd])
    }

    /// Creates middleware that only allows monitoring tokens
    public static var requireMonitoring: ServiceTypeAuthorizationMiddleware {
        ServiceTypeAuthorizationMiddleware(allowedTypes: [.monitoring])
    }
}

/// Middleware for service type authorization (used after service account authentication)
///
/// This middleware ensures that only specific service types can access certain endpoints.
/// It must be used after ServiceAccountAuthenticationMiddleware.
///
/// ## Usage
///
/// ```swift
/// let slackOnly = app.grouped(ServiceAccountAuthenticationMiddleware())
///     .grouped(ServiceAccountAuthenticationMiddleware.requireSlackBot)
/// ```
public struct ServiceTypeAuthorizationMiddleware: AsyncMiddleware {
    /// The allowed service types for this middleware
    private let allowedTypes: Set<ServiceType>

    /// Logger for debugging
    private let logger: Logger

    /// Creates service type authorization middleware
    ///
    /// - Parameter allowedTypes: Set of service types that are allowed
    internal init(allowedTypes: Set<ServiceType>) {
        self.allowedTypes = allowedTypes
        self.logger = Logger(label: "bouncer.service.type.auth")
    }

    /// Validates that the authenticated service account has an allowed service type
    ///
    /// - Parameters:
    ///   - request: The incoming HTTP request
    ///   - next: The next responder in the chain
    /// - Returns: The HTTP response from the next responder
    /// - Throws: `Abort(.forbidden)` if service type is not allowed
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        logger.debug("🔐 Checking service type authorization")

        guard let serviceToken = request.serviceAccountToken else {
            logger.error("❌ No service account token found - authentication required first")
            throw Abort(.unauthorized, reason: "Service account authentication required")
        }

        guard allowedTypes.contains(serviceToken.serviceType) else {
            let allowedNames = allowedTypes.map(\.displayName).joined(separator: ", ")
            logger.error(
                "🚫 Service type '\(serviceToken.serviceType.displayName)' not allowed. Allowed types: \(allowedNames)"
            )
            throw Abort(.forbidden, reason: "Service type not authorized for this endpoint")
        }

        logger.info("✅ Service type authorization passed: \(serviceToken.serviceType.displayName)")
        return try await next.respond(to: request)
    }
}

// MARK: - Route Group Extensions

extension RoutesBuilder {
    /// Apply service account authentication to route group
    ///
    /// - Returns: Route group with service account authentication
    public func serviceAccountAuthenticated() -> RoutesBuilder {
        self.grouped(ServiceAccountAuthenticationMiddleware())
    }

    /// Apply service account authentication with specific service type requirements
    ///
    /// - Parameter allowedTypes: The service types that are allowed
    /// - Returns: Route group with service account authentication and type validation
    public func serviceAccountAuthenticated(allowingTypes allowedTypes: ServiceType...) -> RoutesBuilder {
        self.grouped(ServiceAccountAuthenticationMiddleware())
            .grouped(ServiceTypeAuthorizationMiddleware(allowedTypes: Set(allowedTypes)))
    }

    /// Apply service account authentication for Slack bot endpoints
    public var slackBotAuthenticated: RoutesBuilder {
        serviceAccountAuthenticated(allowingTypes: .slackBot)
    }

    /// Apply service account authentication for CI/CD endpoints
    public var cicdAuthenticated: RoutesBuilder {
        serviceAccountAuthenticated(allowingTypes: .cicd)
    }

    /// Apply service account authentication for monitoring endpoints
    public var monitoringAuthenticated: RoutesBuilder {
        serviceAccountAuthenticated(allowingTypes: .monitoring)
    }
}
