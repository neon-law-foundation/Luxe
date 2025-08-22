import Bouncer
import Dali
import Fluent
import FluentPostgresDriver
import TestUtilities
import Testing
import Vapor
import VaporTesting

@testable import Bazaar

@Suite("Admin Projects CRUD Routes Tests", .serialized)
struct AdminProjectsRoutesTests {

    private func runSeeds(_ database: Database) async throws {
        let postgres = database as! PostgresDatabase
        // Insert seeded project data
        try await postgres.sql().raw(
            """
            INSERT INTO matters.projects (codename) VALUES
            ('DEFAULT-PROJECT')
            ON CONFLICT (codename) DO NOTHING
            """
        ).run()
    }

    @Test("GET /admin/projects returns list of all projects for admin user")
    func adminCanListAllProjects() async throws {
        try await TestUtilities.withWebApp { app in
            try configureAdminApp(app)

            // TestAuthMiddleware handles authentication - no need to create database users

            // Run seeds to populate test data - use committed database connection
            try await runSeeds(app.db)

            let adminToken = "admin@neonlaw.com:valid.test.token"

            try await app.test(.GET, "/admin/projects", headers: ["Authorization": "Bearer \(adminToken)"]) {
                response in
                #expect(response.status == .ok)

                // Should return HTML content
                #expect(response.headers.contentType?.type == "text")
                #expect(response.headers.contentType?.subType == "html")

                let html = response.body.string
                #expect(html.contains("Projects Management"))
                #expect(html.contains("Add New Project"))
            }
        }
    }

    @Test("GET /admin/projects/:id returns specific project for admin user")
    func adminCanGetSpecificProject() async throws {
        try await TestUtilities.withWebApp { app in
            try configureAdminApp(app)

            // TestAuthMiddleware handles authentication - no need to create database users

            // Create a test project using raw SQL (visible to HTTP handlers)
            let uniqueCodename = "TEST-PROJECT-\(UniqueCodeGenerator.generateISOCode(prefix: "test_project"))"
            let testProjectId = try await createTestProjectWithApp(app.db, codename: uniqueCodename)

            let adminToken = "admin@neonlaw.com:valid.test.token"

            try await app.test(
                .GET,
                "/admin/projects/\(testProjectId)",
                headers: ["Authorization": "Bearer \(adminToken)"]
            ) { response in
                #expect(response.status == .ok)

                let html = response.body.string
                #expect(html.contains(uniqueCodename))
                #expect(html.contains("Project Details"))
            }
        }
    }

    @Test("GET /admin/projects/new returns project creation form for admin user")
    func adminCanAccessProjectCreationForm() async throws {
        try await TestUtilities.withWebApp { app in
            try configureAdminApp(app)

            // TestAuthMiddleware handles authentication - no need to create database users

            let adminToken = "admin@neonlaw.com:valid.test.token"

            try await app.test(.GET, "/admin/projects/new", headers: ["Authorization": "Bearer \(adminToken)"]) {
                response in
                #expect(response.status == .ok)

                let html = response.body.string
                #expect(html.contains("Add New Project"))
                #expect(html.contains("Codename"))
                #expect(html.contains("form"))
            }
        }
    }

    @Test("POST /admin/projects creates new project for admin user")
    func adminCanCreateNewProject() async throws {
        try await TestUtilities.withWebApp { app in
            try configureAdminApp(app)

            // TestAuthMiddleware handles authentication - no need to create database users

            let adminToken = "admin@neonlaw.com:valid.test.token"

            let uniqueCodename = "NEW-PROJECT-\(UniqueCodeGenerator.generateISOCode(prefix: "new_project"))"
            let formData = "codename=\(uniqueCodename)"

            try await app.test(
                .POST,
                "/admin/projects",
                headers: [
                    "Authorization": "Bearer \(adminToken)",
                    "Content-Type": "application/x-www-form-urlencoded",
                ],
                body: .init(string: formData)
            ) { response in
                #expect(response.status == .seeOther)
                #expect(response.headers["Location"].first?.contains("/admin/projects/") == true)
            }

            // Verify the project was created using raw SQL (with committed connection)
            let postgres = app.db as! PostgresDatabase
            let result = try await postgres.sql().raw(
                "SELECT id, codename FROM matters.projects WHERE codename = \(bind: uniqueCodename)"
            ).first()
            #expect(result != nil)
            let retrievedCodename = try result?.decode(column: "codename", as: String.self)
            #expect(retrievedCodename == uniqueCodename)
        }
    }

    @Test("GET /admin/projects/:id/edit returns project edit form for admin user")
    func adminCanAccessProjectEditForm() async throws {
        try await TestUtilities.withWebApp { app in
            try configureAdminApp(app)

            // TestAuthMiddleware handles authentication - no need to create database users

            // Create a test project using raw SQL (visible to HTTP handlers)
            let uniqueCodename = "EDIT-TEST-PROJECT-\(UniqueCodeGenerator.generateISOCode(prefix: "edit_project"))"
            let testProjectId = try await createTestProjectWithApp(app.db, codename: uniqueCodename)

            let adminToken = "admin@neonlaw.com:valid.test.token"

            try await app.test(
                .GET,
                "/admin/projects/\(testProjectId)/edit",
                headers: ["Authorization": "Bearer \(adminToken)"]
            ) { response in
                #expect(response.status == .ok)

                let html = response.body.string
                #expect(html.contains("Edit Project"))
                #expect(html.contains(uniqueCodename))
                #expect(html.contains("form"))
            }
        }
    }

    @Test("PATCH /admin/projects/:id updates existing project for admin user")
    func adminCanUpdateProject() async throws {
        try await TestUtilities.withWebApp { app in
            try configureAdminApp(app)
            // TestAuthMiddleware handles authentication - no need to create database users

            // Create a test project using raw SQL (visible to HTTP handlers)
            let originalCodename =
                "UPDATE-TEST-PROJECT-\(UniqueCodeGenerator.generateISOCode(prefix: "update_project"))"
            let testProjectId = try await createTestProjectWithApp(app.db, codename: originalCodename)

            let adminToken = "admin@neonlaw.com:valid.test.token"

            let updatedCodename =
                "UPDATED-PROJECT-CODENAME-\(UniqueCodeGenerator.generateISOCode(prefix: "updated_project"))"
            let formData = "codename=\(updatedCodename)"

            try await app.test(
                .PATCH,
                "/admin/projects/\(testProjectId)",
                headers: [
                    "Authorization": "Bearer \(adminToken)",
                    "Content-Type": "application/x-www-form-urlencoded",
                ],
                body: .init(string: formData)
            ) { response in
                #expect(response.status == .seeOther)
                #expect(response.headers["Location"].first?.contains("/admin/projects/") == true)
            }

            // Verify the project was updated using raw SQL (with committed connection)
            let postgres = app.db as! PostgresDatabase
            let result = try await postgres.sql().raw(
                "SELECT codename FROM matters.projects WHERE id = \(bind: testProjectId)"
            ).first()
            let retrievedCodename = try result?.decode(column: "codename", as: String.self)
            #expect(retrievedCodename == updatedCodename)
        }
    }

    @Test("GET /admin/projects/:id/delete returns project delete confirmation for admin user")
    func adminCanAccessProjectDeleteConfirmation() async throws {
        try await TestUtilities.withWebApp { app in
            try configureAdminApp(app)
            // TestAuthMiddleware handles authentication - no need to create database users

            // Create a test project using raw SQL (visible to HTTP handlers)
            let uniqueCodename = "DELETE-TEST-PROJECT-\(UniqueCodeGenerator.generateISOCode(prefix: "delete_project"))"
            let testProjectId = try await createTestProjectWithApp(app.db, codename: uniqueCodename)

            let adminToken = "admin@neonlaw.com:valid.test.token"

            try await app.test(
                .GET,
                "/admin/projects/\(testProjectId)/delete",
                headers: ["Authorization": "Bearer \(adminToken)"]
            ) { response in
                #expect(response.status == .ok)

                let html = response.body.string
                #expect(html.contains("Delete Project"))
                #expect(html.contains(uniqueCodename))
                #expect(html.contains("Are you sure"))
            }
        }
    }

    @Test("POST /admin/projects/:id/delete removes project for admin user")
    func adminCanDeleteProject() async throws {
        try await TestUtilities.withWebApp { app in
            try configureAdminApp(app)
            // TestAuthMiddleware handles authentication - no need to create database users

            // Create a test project using raw SQL (visible to HTTP handlers)
            let uniqueCodename = "DELETE-TEST-PROJECT-\(UniqueCodeGenerator.generateISOCode(prefix: "delete_project"))"
            let projectId = try await createTestProjectWithApp(app.db, codename: uniqueCodename)

            let adminToken = "admin@neonlaw.com:valid.test.token"

            try await app.test(
                .POST,
                "/admin/projects/\(projectId)/delete",
                headers: [
                    "Authorization": "Bearer \(adminToken)",
                    "Content-Type": "application/x-www-form-urlencoded",
                ],
                body: .init(string: "_method=DELETE")
            ) { response in
                #expect(response.status == .seeOther)
                #expect(response.headers["Location"].first == "/admin/projects")
            }

            // Verify the project was deleted using raw SQL (with committed connection)
            let postgres = app.db as! PostgresDatabase
            let result = try await postgres.sql().raw(
                "SELECT id FROM matters.projects WHERE id = \(bind: projectId)"
            ).first()
            #expect(result == nil)
        }
    }
}

// MARK: - Helper Functions

private func createTestProject(
    _ database: Database,
    codename: String
) async throws -> UUID {
    let postgres = database as! PostgresDatabase

    let result = try await postgres.sql().raw(
        """
        INSERT INTO matters.projects (codename)
        VALUES (\(bind: codename))
        ON CONFLICT (codename) DO UPDATE SET codename = EXCLUDED.codename
        RETURNING id
        """
    ).first()

    guard let result = result else {
        throw Abort(.internalServerError, reason: "Failed to create project")
    }

    return try result.decode(column: "id", as: UUID.self)
}

private func createTestProjectWithApp(
    _ database: Database,
    codename: String
) async throws -> UUID {
    let postgres = database as! PostgresDatabase

    let result = try await postgres.sql().raw(
        """
        INSERT INTO matters.projects (codename)
        VALUES (\(bind: codename))
        ON CONFLICT (codename) DO UPDATE SET codename = EXCLUDED.codename
        RETURNING id
        """
    ).first()

    guard let result = result else {
        throw Abort(.internalServerError, reason: "Failed to create project")
    }

    return try result.decode(column: "id", as: UUID.self)
}
