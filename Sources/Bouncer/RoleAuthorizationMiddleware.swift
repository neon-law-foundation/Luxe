import Dali
import Foundation
import Vapor

/// Middleware for role-based authorization
///
/// This middleware enforces role requirements on routes after authentication.
/// It should be used in conjunction with authentication middleware to ensure
/// that authenticated users have the required role to access specific endpoints.
///
/// ## Role Hierarchy
///
/// The system uses a hierarchical role model:
/// - **Admin**: Full access to all resources
/// - **Staff**: Access to staff and customer resources
/// - **Customer**: Access to customer resources only
///
/// ## Usage
///
/// ```swift
/// // Require admin role
/// let adminOnly = app.grouped(authenticator)
///     .grouped(RoleAuthorizationMiddleware(requiredRole: .admin))
///
/// // Require staff or higher
/// let staffOnly = app.grouped(authenticator)
///     .grouped(RoleAuthorizationMiddleware(requiredRole: .staff))
/// ```
public struct RoleAuthorizationMiddleware: AsyncMiddleware {
    /// The minimum role required to access the route
    public let requiredRole: UserRole

    /// Whether to allow higher roles (hierarchical check)
    public let allowHigherRoles: Bool

    /// Custom error message for authorization failures
    public let errorMessage: String?

    /// Logger for debugging
    private let logger: Logger

    /// Creates role authorization middleware
    ///
    /// - Parameters:
    ///   - requiredRole: The minimum role required
    ///   - allowHigherRoles: Whether to allow users with higher roles (default: true)
    ///   - errorMessage: Custom error message for failures (optional)
    public init(
        requiredRole: UserRole,
        allowHigherRoles: Bool = true,
        errorMessage: String? = nil
    ) {
        self.requiredRole = requiredRole
        self.allowHigherRoles = allowHigherRoles
        self.errorMessage = errorMessage
        self.logger = Logger(label: "role.authorization")
    }

    /// Validates the user has the required role
    ///
    /// - Parameters:
    ///   - request: The incoming HTTP request
    ///   - next: The next responder in the chain
    /// - Returns: The HTTP response
    /// - Throws: `Abort(.forbidden)` if user lacks required role
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        logger.debug("🔐 Checking role authorization for: \(request.url.path)")

        // Get authenticated user
        guard let user = request.auth.get(User.self) else {
            logger.error("❌ No authenticated user for role check")
            throw Abort(.unauthorized, reason: "Authentication required")
        }

        logger.info("👤 User \(user.username) has role: \(user.role), required: \(requiredRole)")

        // Check role authorization
        let isAuthorized: Bool
        if allowHigherRoles {
            isAuthorized = checkHierarchicalRole(userRole: user.role, requiredRole: requiredRole)
        } else {
            isAuthorized = user.role == requiredRole
        }

        guard isAuthorized else {
            let message = errorMessage ?? "Insufficient privileges. Required role: \(requiredRole)"
            logger.error("🚫 Access denied for user \(user.username): \(message)")
            throw Abort(.forbidden, reason: message)
        }

        logger.info("✅ Role authorization passed for user: \(user.username)")

        // Continue to next middleware/handler
        return try await next.respond(to: request)
    }

    /// Checks if a user role meets the hierarchical requirement
    ///
    /// - Parameters:
    ///   - userRole: The user's actual role
    ///   - requiredRole: The minimum required role
    /// - Returns: True if the user role is sufficient
    private func checkHierarchicalRole(userRole: UserRole, requiredRole: UserRole) -> Bool {
        switch requiredRole {
        case .customer:
            // Any role can access customer resources
            return true

        case .staff:
            // Staff or admin can access staff resources
            return userRole == .staff || userRole == .admin

        case .admin:
            // Only admin can access admin resources
            return userRole == .admin
        }
    }
}

// MARK: - Convenience Factory Methods

extension RoleAuthorizationMiddleware {
    /// Creates middleware requiring admin role
    public static var requireAdmin: RoleAuthorizationMiddleware {
        RoleAuthorizationMiddleware(
            requiredRole: .admin,
            errorMessage: "Admin access required"
        )
    }

    /// Creates middleware requiring staff role or higher
    public static var requireStaff: RoleAuthorizationMiddleware {
        RoleAuthorizationMiddleware(
            requiredRole: .staff,
            errorMessage: "Staff access required"
        )
    }

    /// Creates middleware requiring customer role or higher
    public static var requireCustomer: RoleAuthorizationMiddleware {
        RoleAuthorizationMiddleware(
            requiredRole: .customer,
            errorMessage: "Customer access required"
        )
    }
}

// MARK: - Route Group Extensions

extension RoutesBuilder {
    /// Groups routes that require a specific role
    ///
    /// - Parameters:
    ///   - role: The minimum required role
    ///   - allowHigherRoles: Whether to allow users with higher roles
    /// - Returns: A route group with role authorization
    public func requireRole(
        _ role: UserRole,
        allowHigherRoles: Bool = true
    ) -> RoutesBuilder {
        self.grouped(
            RoleAuthorizationMiddleware(
                requiredRole: role,
                allowHigherRoles: allowHigherRoles
            )
        )
    }

    /// Groups routes that require admin role
    public var requireAdmin: RoutesBuilder {
        self.grouped(RoleAuthorizationMiddleware.requireAdmin)
    }

    /// Groups routes that require staff role or higher
    public var requireStaff: RoutesBuilder {
        self.grouped(RoleAuthorizationMiddleware.requireStaff)
    }

    /// Groups routes that require customer role or higher
    public var requireCustomer: RoutesBuilder {
        self.grouped(RoleAuthorizationMiddleware.requireCustomer)
    }
}
