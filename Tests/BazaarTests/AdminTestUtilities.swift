import Bouncer
import Dali
import Fluent
import FluentPostgresDriver
// Import additional types needed for app/me route
import Foundation
import Vapor
import VaporElementary

@testable import Bazaar

/// Configures the Bazaar application for admin testing with TestAuthMiddleware.
///
/// This function is a simplified version that just sets up the minimal configuration
/// needed to test admin routes with TestAuthMiddleware.
///
/// - Parameter app: The Vapor application to configure
/// - Throws: Configuration errors if setup fails
func configureAppWithTestAuth(_ app: Application) throws {
    // Configure essential middleware
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))

    // Configure DALI models and database
    try configureDali(app)

    // Create TestAuthMiddleware that bypasses database lookups
    let testAuthMiddleware = TestAuthMiddleware()

    // Simple test route to verify basic functionality
    app.get("health") { _ in
        "OK"
    }

    // Test admin routes with our authentication middleware
    let adminRoutes = app.grouped("admin")
        .grouped(testAuthMiddleware)  // Use our test middleware
        .grouped(AdminAuthMiddleware())

    // Add the admin dashboard route (this is defined outside configureAdminRoutes in the main app)
    adminRoutes.get { req async throws in
        let currentUser = CurrentUserContext.user
        let page = AdminDashboardPage(currentUser: currentUser)
        return try await HTMLResponse { page }.encodeResponse(for: req)
    }

    // Simple test route to verify admin authentication works
    adminRoutes.get("test") { req async throws in
        guard let user = CurrentUserContext.user else {
            throw Abort(.internalServerError, reason: "Current user not available")
        }
        return [
            "user_id": user.id?.uuidString ?? "unknown",
            "username": user.username,
            "role": user.role.rawValue,
            "message": "TestAuthMiddleware working!",
        ]
    }

    // Add the actual admin routes from the main app
    try configureAdminRoutes(adminRoutes)

    // Add app/me route for ALB authentication tests
    let appRoutes = app.grouped("app")
    let protectedAppRoutes = appRoutes.grouped(testAuthMiddleware)
    protectedAppRoutes.get("me") { req async throws -> Response in
        guard let user = CurrentUserContext.user else {
            throw Abort(.internalServerError, reason: "Current user not available")
        }
        // Create response matching the test's expected structure
        let responseDict: [String: Any] = [
            "user": [
                "id": user.id?.uuidString ?? UUID().uuidString,
                "username": user.username,
                "role": user.role.rawValue,
            ],
            "person": [
                "id": UUID().uuidString,
                "name": "Mock Person",
                "email": user.username,
            ],
        ]
        return Response(
            status: .ok,
            headers: ["Content-Type": "application/json"],
            body: .init(data: try JSONSerialization.data(withJSONObject: responseDict))
        )
    }
}

// Configuration function for admin tests
func configureAdminApp(_ app: Application) throws {
    // Use most of the main app configuration but with test authentication
    try configureAppWithTestAuth(app)
}

func createTestAdminUser(_ database: Database) async throws {
    // Use the transaction database parameter directly to avoid nested transactions
    let postgresConnection = database as! PostgresDatabase

    // Set admin context for the session and disable RLS for tests
    try await postgresConnection.sql()
        .raw("SET app.current_user_role = 'admin'")
        .run()

    // Temporarily disable RLS for testing (postgres superuser can do this)
    try await postgresConnection.sql()
        .raw("SET row_security = off")
        .run()

    // Create person first
    try await postgresConnection.sql().raw(
        """
        INSERT INTO directory.people (name, email)
        VALUES ('Admin User', 'admin@neonlaw.com')
        ON CONFLICT (email) DO NOTHING
        """
    ).run()

    // Verify person exists before creating user
    let personExists = try await postgresConnection.sql().raw(
        "SELECT id FROM directory.people WHERE email = 'admin@neonlaw.com'"
    ).first()

    if personExists != nil {
        // Create user with admin role
        try await postgresConnection.sql().raw(
            """
            INSERT INTO auth.users (username, person_id, role)
            SELECT 'admin@neonlaw.com', p.id, 'admin'::auth.user_role
            FROM directory.people p
            WHERE p.email = 'admin@neonlaw.com'
            ON CONFLICT (username) DO NOTHING
            """
        ).run()
    }
}

func createTestStaffUser(_ database: Database) async throws {
    // Use the transaction database parameter directly to avoid nested transactions
    let postgresConnection = database as! PostgresDatabase

    // Set admin context for the session and disable RLS for tests
    try await postgresConnection.sql()
        .raw("SET app.current_user_role = 'admin'")
        .run()

    // Temporarily disable RLS for testing (postgres superuser can do this)
    try await postgresConnection.sql()
        .raw("SET row_security = off")
        .run()

    // Create person first
    try await postgresConnection.sql().raw(
        """
        INSERT INTO directory.people (name, email)
        VALUES ('Test Staff User', 'teststaff@example.com')
        ON CONFLICT (email) DO NOTHING
        """
    ).run()

    // Verify person exists before creating user
    let personExists = try await postgresConnection.sql().raw(
        "SELECT id FROM directory.people WHERE email = 'teststaff@example.com'"
    ).first()

    if personExists != nil {
        // Create user with staff role
        try await postgresConnection.sql().raw(
            """
            INSERT INTO auth.users (username, person_id, role)
            SELECT 'teststaff@example.com', p.id, 'staff'::auth.user_role
            FROM directory.people p
            WHERE p.email = 'teststaff@example.com'
            ON CONFLICT (username) DO NOTHING
            """
        ).run()
    }
}

func createTestCustomerUser(_ database: Database) async throws {
    // Use the transaction database parameter directly to avoid nested transactions
    let postgresConnection = database as! PostgresDatabase

    // Set admin context for the session and disable RLS for tests
    try await postgresConnection.sql()
        .raw("SET app.current_user_role = 'admin'")
        .run()

    // Temporarily disable RLS for testing (postgres superuser can do this)
    try await postgresConnection.sql()
        .raw("SET row_security = off")
        .run()

    // Create person first
    try await postgresConnection.sql().raw(
        """
        INSERT INTO directory.people (name, email)
        VALUES ('Test Customer User', 'testcustomer@example.com')
        ON CONFLICT (email) DO NOTHING
        """
    ).run()

    // Verify person exists before creating user
    let personExists = try await postgresConnection.sql().raw(
        "SELECT id FROM directory.people WHERE email = 'testcustomer@example.com'"
    ).first()

    if personExists != nil {
        // Create user with customer role
        try await postgresConnection.sql().raw(
            """
            INSERT INTO auth.users (username, person_id, role)
            SELECT 'testcustomer@example.com', p.id, 'customer'::auth.user_role
            FROM directory.people p
            WHERE p.email = 'testcustomer@example.com'
            ON CONFLICT (username) DO NOTHING
            """
        ).run()
    }
}
