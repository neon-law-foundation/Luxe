import Dali
import Foundation
import Vapor

/// Middleware that ensures the current user has admin role
///
/// This middleware should be applied after authentication middleware
/// to protect routes that require admin access. It checks the current
/// user's role and returns 403 Forbidden if they don't have admin privileges.
///
/// ## Usage
///
/// Add this middleware to admin-only routes:
///
/// ```swift
/// let adminRoutes = app.grouped("admin")
///     .grouped(albAuthMiddleware)
///     .grouped(AdminAuthMiddleware())
/// ```
///
/// The middleware will:
/// 1. Check if there's an authenticated user in CurrentUserContext
/// 2. Verify the user has admin role
/// 3. Allow the request to proceed if authorized
/// 4. Return 403 Forbidden if unauthorized
public struct AdminAuthMiddleware: AsyncMiddleware {

    public init() {}

    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let user = CurrentUserContext.user else {
            throw Abort(.unauthorized, reason: "Authentication required")
        }

        guard user.isAdmin() else {
            throw Abort(.forbidden, reason: "Admin access required")
        }

        return try await next.respond(to: request)
    }
}
