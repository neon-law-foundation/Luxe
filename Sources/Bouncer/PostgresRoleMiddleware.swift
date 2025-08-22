import Dali
import Fluent
import FluentPostgresDriver
import Foundation
import PostgresNIO
import Vapor

/// Middleware that sets the PostgreSQL role based on the current user's role
///
/// This middleware ensures that database operations are performed with the appropriate
/// PostgreSQL role based on the authenticated user's role (customer, staff, admin).
/// This enables row-level security policies to work correctly.
///
/// ## Usage
///
/// Add this middleware after authentication middleware but before route handlers:
///
/// ```swift
/// app.middleware.use(SessionMiddleware())
/// app.middleware.use(PostgresRoleMiddleware())
/// ```
///
/// The middleware will:
/// 1. Check if there's an authenticated user in CurrentUserContext
/// 2. Map the user's role to the corresponding PostgreSQL role
/// 3. Execute `SET ROLE` to switch to that role for the request
/// 4. Execute the request with the appropriate role
/// 5. Reset the role when the request completes
public struct PostgresRoleMiddleware: AsyncMiddleware {

    public init() {}

    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let user = CurrentUserContext.user else {
            // No authenticated user, proceed without role switching
            return try await next.respond(to: request)
        }

        // Determine the PostgreSQL role based on user role
        let pgRole =
            switch user.role {
            case .customer: "customer"
            case .staff: "staff"
            case .admin: "admin"
            }

        // Set the PostgreSQL role for this request
        return try await withPostgresRole(pgRole, on: request.db) {
            try await next.respond(to: request)
        }
    }
}

/// Sets the PostgreSQL role for the duration of the closure
///
/// This function temporarily switches the PostgreSQL role for a database connection,
/// executes the provided closure, and then resets the role.
///
/// - Parameters:
///   - role: The PostgreSQL role name to switch to
///   - database: The database connection to use
///   - closure: The closure to execute with the switched role
/// - Returns: The result of the closure
/// - Throws: Any error thrown by the closure or database operations
private func withPostgresRole<T>(
    _ role: String,
    on database: Database,
    _ closure: () async throws -> T
) async throws -> T {
    guard let postgres = database as? PostgresDatabase else {
        // Not a PostgreSQL database, proceed without role switching
        return try await closure()
    }

    // Set the role for this connection
    // Note: PostgreSQL role names cannot be parameterized, so we use string interpolation
    // The role names are validated enum values (customer, staff, admin) so this is safe
    try await postgres.sql().raw("SET ROLE \(unsafeRaw: role)").run()

    // Set the search path to include all schemas after switching roles
    // This ensures that all tables in non-public schemas are accessible
    try await postgres.sql().raw(
        """
        SET search_path = auth, directory, mail, accounting, equity, estates, standards, legal, matters, documents, service, admin, public
        """
    ).run()

    // Also set session variable for compatibility with SECURITY DEFINER functions
    try await postgres.sql().raw("SET app.current_user_role = '\(unsafeRaw: role)'").run()

    do {
        // Execute the closure with the role set
        let result = try await closure()

        // Reset to the default role (the connection user) and session variable
        try await postgres.sql().raw("RESET ROLE").run()
        try await postgres.sql().raw("RESET app.current_user_role").run()

        return result
    } catch {
        // Make sure to reset the role even if an error occurs
        try? await postgres.sql().raw("RESET ROLE").run()
        try? await postgres.sql().raw("RESET app.current_user_role").run()
        throw error
    }
}
