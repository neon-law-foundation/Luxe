import Bouncer
import Dali
import Fluent
import FluentPostgresDriver
import TestUtilities
import Testing
import Vapor
import VaporTesting

@testable import Bazaar

@Suite("Admin Legal Jurisdictions CRUD Routes Tests", .serialized)
struct AdminLegalJurisdictionsRoutesTests {

    @Test("GET /admin/legal-jurisdictions returns list of all jurisdictions for admin user")
    func adminCanListAllLegalJurisdictions() async throws {
        try await TestUtilities.withWebApp { app in
            try configureAdminApp(app)

            // TestAuthMiddleware handles authentication - no need to create database users

            // Run seeds to populate test data using app's database connection
            try await runSeeds(app.db)

            let adminToken = "admin@neonlaw.com:valid.test.token"

            try await app.test(.GET, "/admin/legal-jurisdictions", headers: ["Authorization": "Bearer \(adminToken)"]) {
                response in
                #expect(response.status == .ok)

                // Should return HTML content
                #expect(response.headers.contentType?.type == "text")
                #expect(response.headers.contentType?.subType == "html")

                let html = response.body.string
                #expect(html.contains("Legal Jurisdictions Management"))
                // Should show actual seeded data, not sample data
                #expect(html.contains("Alabama"))
                #expect(html.contains("AL"))
                #expect(html.contains("Alaska"))
                #expect(html.contains("AK"))
            }
        }
    }

    @Test("GET /admin/legal-jurisdictions/:id returns specific jurisdiction for admin user")
    func adminCanGetSpecificLegalJurisdiction() async throws {
        try await TestUtilities.withWebApp { app in
            try configureAdminApp(app)

            // TestAuthMiddleware handles authentication - no need to create database users

            // Create a test jurisdiction using app's database connection and get its ID
            let jurisdictionId = try await createTestLegalJurisdictionWithApp(app.db, name: "Texas", code: "TX")

            let adminToken = "admin@neonlaw.com:valid.test.token"

            try await app.test(
                .GET,
                "/admin/legal-jurisdictions/\(jurisdictionId)",
                headers: ["Authorization": "Bearer \(adminToken)"]
            ) { response in
                #expect(response.status == .ok)

                let html = response.body.string
                #expect(html.contains("Texas"))
                #expect(html.contains("TX"))
            }
        }
    }

    @Test("GET /admin/legal-jurisdictions/new route does not exist")
    func adminCannotGetNewLegalJurisdictionForm() async throws {
        try await TestUtilities.withApp { app, db in
            try configureAdminApp(app)

            // Create the admin user in the test database
            try await createTestAdminUser(db)

            let adminToken = "admin@neonlaw.com:valid.test.token"

            try await app.test(
                .GET,
                "/admin/legal-jurisdictions/new",
                headers: ["Authorization": "Bearer \(adminToken)"]
            ) { response in
                // "new" gets matched by ":id" route and fails UUID parsing, returning 400
                #expect(response.status == .badRequest)
            }

        }
    }

    @Test("POST /admin/legal-jurisdictions route does not exist")
    func adminCannotCreateNewLegalJurisdiction() async throws {
        try await TestUtilities.withApp { app, db in
            try configureAdminApp(app)

            // Create the admin user in the test database
            try await createTestAdminUser(db)

            let adminToken = "admin@neonlaw.com:valid.test.token"

            var headers: HTTPHeaders = ["Authorization": "Bearer \(adminToken)"]
            headers.contentType = .urlEncodedForm

            let uniqueCode = "FL\(UUID().uuidString.prefix(2))"
            let uniqueName = "Florida-\(UUID().uuidString.prefix(4))"
            let body = "name=\(uniqueName)&code=\(uniqueCode)"

            try await app.test(.POST, "/admin/legal-jurisdictions", headers: headers, body: .init(string: body)) {
                response in
                #expect(response.status == .notFound)
            }

            // Verify no jurisdiction was created
            let jurisdictions = try await (db as! PostgresDatabase).sql()
                .raw("SELECT name, code FROM legal.jurisdictions WHERE code = \(bind: uniqueCode)")
                .all()

            #expect(jurisdictions.count == 0)

        }
    }

    @Test("GET /admin/legal-jurisdictions/:id/edit route does not exist")
    func adminCannotGetEditLegalJurisdictionForm() async throws {
        try await TestUtilities.withApp { app, db in
            try configureAdminApp(app)

            // Create the admin user in the test database
            try await createTestAdminUser(db)

            // Create a test jurisdiction
            let jurisdictionId = try await createTestLegalJurisdiction(db, name: "Edit State", code: "ES")

            let adminToken = "admin@neonlaw.com:valid.test.token"

            try await app.test(
                .GET,
                "/admin/legal-jurisdictions/\(jurisdictionId)/edit",
                headers: ["Authorization": "Bearer \(adminToken)"]
            ) { response in
                #expect(response.status == .notFound)
            }

        }
    }

    @Test("PATCH /admin/legal-jurisdictions/:id route does not exist")
    func adminCannotUpdateLegalJurisdiction() async throws {
        try await TestUtilities.withApp { app, db in
            try configureAdminApp(app)

            // Create the admin user in the test database
            try await createTestAdminUser(db)

            // Create a test jurisdiction
            let jurisdictionId = try await createTestLegalJurisdiction(db, name: "Old State", code: "OS")

            let adminToken = "admin@neonlaw.com:valid.test.token"

            var headers: HTTPHeaders = ["Authorization": "Bearer \(adminToken)"]
            headers.contentType = .urlEncodedForm

            let uniqueCode = "NS\(UUID().uuidString.prefix(2))"
            let body = "name=New State&code=\(uniqueCode)"

            try await app.test(
                .PATCH,
                "/admin/legal-jurisdictions/\(jurisdictionId)",
                headers: headers,
                body: .init(string: body)
            ) { response in
                #expect(response.status == .notFound)
            }

            // Verify the jurisdiction was NOT updated - should still have original data
            let jurisdictions = try await (db as! PostgresDatabase).sql()
                .raw("SELECT name, code FROM legal.jurisdictions WHERE id = \(bind: jurisdictionId)")
                .all()

            #expect(jurisdictions.count == 1)
            let jurisdiction = jurisdictions[0]
            let name = try jurisdiction.decode(column: "name", as: String.self)
            let code = try jurisdiction.decode(column: "code", as: String.self)
            #expect(name == "Old State")
            #expect(code == "OS")

        }
    }

    @Test("DELETE /admin/legal-jurisdictions/:id route does not exist")
    func adminCannotDeleteLegalJurisdiction() async throws {
        try await TestUtilities.withApp { app, db in
            try configureAdminApp(app)

            // Create the admin user in the test database
            try await createTestAdminUser(db)

            // Create a test jurisdiction
            let jurisdictionId = try await createTestLegalJurisdiction(db, name: "Cannot Delete State", code: "CD")

            let adminToken = "admin@neonlaw.com:valid.test.token"

            // Verify that DELETE route returns 404 (not found)
            try await app.test(
                .DELETE,
                "/admin/legal-jurisdictions/\(jurisdictionId)",
                headers: ["Authorization": "Bearer \(adminToken)"]
            ) { response in
                #expect(response.status == .notFound)
            }

            // Verify that GET delete confirmation route returns 404 (not found)
            try await app.test(
                .GET,
                "/admin/legal-jurisdictions/\(jurisdictionId)/delete",
                headers: ["Authorization": "Bearer \(adminToken)"]
            ) { response in
                #expect(response.status == .notFound)
            }

            // Verify the jurisdiction still exists (was not deleted)
            let jurisdictions = try await (db as! PostgresDatabase).sql()
                .raw("SELECT id FROM legal.jurisdictions WHERE id = \(bind: jurisdictionId)")
                .all()

            #expect(jurisdictions.count == 1)

        }
    }

    @Test("Admin jurisdiction list page has no delete buttons")
    func adminJurisdictionListPageHasNoDeleteButtons() async throws {
        try await TestUtilities.withWebApp { app in
            try configureAdminApp(app)

            // TestAuthMiddleware handles authentication - no need to create database users

            // Run seeds to populate test data using app's database connection
            try await runSeeds(app.db)

            let adminToken = "admin@neonlaw.com:valid.test.token"

            try await app.test(.GET, "/admin/legal-jurisdictions", headers: ["Authorization": "Bearer \(adminToken)"]) {
                response in
                #expect(response.status == .ok)

                let html = response.body.string
                #expect(html.contains("Legal Jurisdictions Management"))

                // Verify there are no delete buttons or delete links
                #expect(!html.contains("button is-small is-danger"))
                #expect(!html.contains("/delete"))
                #expect(!html.contains(">Delete<"))

                // Should still have View buttons but no Edit buttons or links
                #expect(html.contains("View"))
                #expect(!html.contains(">Edit<"))
                #expect(!html.contains("button is-small is-warning"))
                #expect(!html.contains("/edit"))
                #expect(!html.contains("Add New Legal Jurisdiction"))
            }

        }
    }

    @Test("Admin jurisdiction detail page has no delete button")
    func adminJurisdictionDetailPageHasNoDeleteButton() async throws {
        try await TestUtilities.withWebApp { app in
            try configureAdminApp(app)

            // TestAuthMiddleware handles authentication - no need to create database users

            // Create a test jurisdiction using committed connection - use unique code to avoid conflicts
            let uniqueCode = "NDT\(String(UUID().uuidString.prefix(2)))"
            let jurisdictionId = try await createTestLegalJurisdictionWithApp(
                app.db,
                name: "No Delete State Test",
                code: uniqueCode
            )

            let adminToken = "admin@neonlaw.com:valid.test.token"

            try await app.test(
                .GET,
                "/admin/legal-jurisdictions/\(jurisdictionId)",
                headers: ["Authorization": "Bearer \(adminToken)"]
            ) { response in
                #expect(response.status == .ok)

                let html = response.body.string
                #expect(html.contains("No Delete State Test"))
                #expect(html.contains(uniqueCode))

                // Verify there is no delete button or delete link
                #expect(!html.contains("Delete Legal Jurisdiction"))
                #expect(!html.contains("/delete"))
                #expect(!html.contains("button is-danger"))

                // Should not have any Edit buttons or links
                #expect(!html.contains("Edit Legal Jurisdiction"))
                #expect(!html.contains(">Edit<"))
                #expect(!html.contains("button is-warning"))
                #expect(!html.contains("/edit"))
            }

        }
    }

    @Test("Non-admin users cannot access admin legal jurisdiction routes")
    func nonAdminUsersCannotAccessAdminLegalJurisdictionRoutes() async throws {
        try await TestUtilities.withApp { app, db in
            try configureAdminApp(app)
            try await createTestStaffUser(db)

            let staffToken = "teststaff@example.com:valid.test.token"

            // Create a test legal jurisdiction to use for route testing
            let testJurisdictionId = try await createTestLegalJurisdiction(db, name: "Test Auth State", code: "TA")

            // Test existing routes return 403 for staff user
            let existingRoutes = [
                "/admin/legal-jurisdictions",
                "/admin/legal-jurisdictions/\(testJurisdictionId)",
            ]

            for route in existingRoutes {
                try await app.test(.GET, route, headers: ["Authorization": "Bearer \(staffToken)"]) { response in
                    #expect(response.status == .forbidden)
                }
            }

            // Test that "new" route gets 403 (caught by :id route first, then auth fails)
            try await app.test(
                .GET,
                "/admin/legal-jurisdictions/new",
                headers: ["Authorization": "Bearer \(staffToken)"]
            ) { response in
                #expect(response.status == .forbidden)
            }

            // Test that edit routes return 404 for staff user (same as admin)
            try await app.test(
                .GET,
                "/admin/legal-jurisdictions/\(testJurisdictionId)/edit",
                headers: ["Authorization": "Bearer \(staffToken)"]
            ) { response in
                #expect(response.status == .notFound)
            }

        }
    }
}

// MARK: - Helper Functions

private func runSeeds(_ database: Database) async throws {
    let postgres = database as! PostgresDatabase

    // Insert seeded legal jurisdiction data (first few states)
    try await postgres.sql().raw(
        """
        INSERT INTO legal.jurisdictions (name, code) VALUES
        ('Alabama', 'AL'),
        ('Alaska', 'AK'),
        ('Arizona', 'AZ'),
        ('Arkansas', 'AR'),
        ('California', 'CA')
        ON CONFLICT (code) DO NOTHING
        """
    ).run()
}

private func createTestLegalJurisdiction(_ database: Database, name: String, code: String) async throws -> UUID {
    let postgres = database as! PostgresDatabase

    let result = try await postgres.sql().raw(
        """
        INSERT INTO legal.jurisdictions (name, code)
        VALUES (\(bind: name), \(bind: code))
        ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name
        RETURNING id
        """
    ).first()

    guard let result = result else {
        throw Abort(.internalServerError, reason: "Failed to create legal jurisdiction")
    }

    return try result.decode(column: "id", as: UUID.self)
}

private func createTestLegalJurisdictionWithApp(_ database: Database, name: String, code: String) async throws -> UUID {
    let postgres = database as! PostgresDatabase

    let result = try await postgres.sql().raw(
        """
        INSERT INTO legal.jurisdictions (name, code)
        VALUES (\(bind: name), \(bind: code))
        ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name
        RETURNING id
        """
    ).first()

    guard let result = result else {
        throw Abort(.internalServerError, reason: "Failed to create legal jurisdiction")
    }

    return try result.decode(column: "id", as: UUID.self)
}
