import Dali
import Fluent
import FluentPostgresDriver
import PostgresNIO
import TestUtilities
import Testing
import Vapor

@Suite("Project model", .serialized)
struct ProjectTests {
    @Test("Create a new project with codename")
    func createProject() async throws {
        try await TestUtilities.withApp { app, database in
            let project = Project(
                codename: "PROJECT-ALPHA-\(TestUtilities.randomString())"
            )

            try await project.save(on: app.db)

            #expect(project.id != nil)
            #expect(project.codename.hasPrefix("PROJECT-ALPHA"))
            #expect(project.createdAt != nil)
            #expect(project.updatedAt != nil)
        }
    }

    @Test("Project codename must be unique")
    func uniqueCodename() async throws {
        try await TestUtilities.withApp { app, database in
            let codename = "PROJECT-BETA-\(TestUtilities.randomString())"
            let project1 = Project(codename: codename)
            try await project1.save(on: app.db)

            let project2 = Project(codename: codename)

            await #expect(throws: Error.self) {
                try await project2.save(on: app.db)
            }
        }
    }

    @Test("Find project by codename")
    func findByCodename() async throws {
        try await TestUtilities.withApp { app, database in
            let codename = "PROJECT-GAMMA-\(TestUtilities.randomString())"
            let project = Project(codename: codename)
            try await project.save(on: app.db)

            let foundProject = try await Project.query(on: app.db)
                .filter(\.$codename == codename)
                .first()

            #expect(foundProject != nil)
            #expect(foundProject?.id == project.id)
            #expect(foundProject?.codename == codename)
        }
    }

    @Test("Update project updates timestamp")
    func updateTimestamp() async throws {
        try await TestUtilities.withApp { app, database in
            let codename = "PROJECT-DELTA-\(TestUtilities.randomString())"
            let project = Project(codename: codename)
            try await project.save(on: app.db)

            let originalUpdatedAt = project.updatedAt

            // Sleep briefly to ensure timestamp difference
            try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

            project.codename = "PROJECT-DELTA-UPDATED-\(TestUtilities.randomString())"
            try await project.save(on: app.db)

            #expect(project.updatedAt != originalUpdatedAt)
        }
    }

    @Test(
        "Load project with assigned notations",
        .disabled("Connection timeout after 10+ seconds - needs connection investigation")
    )
    func loadWithAssignedNotations() async throws {
        try await TestUtilities.withApp { app, database in

            // Create test data using SQL like AssignedNotationTests pattern
            // Get Nevada jurisdiction ID (should exist from migrations)
            let nevadaResult = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT id FROM legal.jurisdictions WHERE code = 'NV'")
                .first()

            guard let nevada = nevadaResult,
                let jurisdictionId = try? nevada.decode(column: "id", as: UUID.self)
            else {
                throw TestError.invalidConnectionURL
            }

            // Create an entity type for Nevada if it doesn't exist
            let entityTypeResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    INSERT INTO legal.entity_types (legal_jurisdiction_id, name, created_at, updated_at)
                    VALUES (\(bind: jurisdictionId), 'LLC', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    ON CONFLICT (legal_jurisdiction_id, name) DO NOTHING
                    RETURNING id
                    """
                )
                .first()

            // Get the entity type ID (either newly created or existing)
            let entityTypeId: UUID
            if let result = entityTypeResult {
                entityTypeId = try result.decode(column: "id", as: UUID.self)
            } else {
                // If ON CONFLICT triggered, get the existing one
                let existingResult = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        SELECT id FROM legal.entity_types
                        WHERE legal_jurisdiction_id = \(bind: jurisdictionId) AND name = 'LLC'
                        """
                    )
                    .first()
                guard let existing = existingResult else {
                    throw TestError.invalidConnectionURL
                }
                entityTypeId = try existing.decode(column: "id", as: UUID.self)
            }

            // Create an entity
            let entityName = "Test Entity \(TestUtilities.randomString())"
            let entityRows = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                        INSERT INTO directory.entities
                        (name, legal_entity_type_id)
                        VALUES (\(bind: entityName), \(bind: entityTypeId))
                        RETURNING id
                    """
                )
                .all()

            let entityID = try entityRows[0].decode(column: "id", as: UUID.self)

            // Create a notation
            let notationUID = TestUtilities.randomUID(prefix: "project-notation")
            let notationCode = TestUtilities.randomCode(prefix: "project_notation")

            let notationRows = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                        INSERT INTO standards.notations
                        (uid, title, code, flow, alignment, published)
                        VALUES (\(bind: notationUID), 'Test Notation', \(bind: notationCode),
                                '{}'::jsonb, '{}'::jsonb, false)
                        RETURNING id
                    """
                )
                .all()

            let notationID = try notationRows[0].decode(column: "id", as: UUID.self)

            // Create a project
            let projectCodename = "TEST-PROJECT-\(TestUtilities.randomString())"
            let projectRows = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                        INSERT INTO matters.projects
                        (codename)
                        VALUES (\(bind: projectCodename))
                        RETURNING id
                    """
                )
                .all()

            let projectID = try projectRows[0].decode(column: "id", as: UUID.self)

            // Create an assigned notation
            let assignedNotationRows = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    INSERT INTO matters.assigned_notations
                    (entity_id, state, change_language, answers, notation_id, project_id)
                    VALUES (\(bind: entityID), 'awaiting_flow',
                            '{\"changes\": []}'::jsonb, '{}'::jsonb,
                            \(bind: notationID), \(bind: projectID))
                    RETURNING id
                    """
                )
                .all()

            let assignedNotationID = try assignedNotationRows[0].decode(column: "id", as: UUID.self)

            // Load project with assigned notations using Fluent
            let loadedProject = try await Project.query(on: app.db)
                .with(\.$assignedNotations)
                .filter(\.$id == projectID)
                .first()

            #expect(loadedProject != nil)
            #expect(loadedProject?.assignedNotations.count == 1)
            #expect(loadedProject?.assignedNotations.first?.id == assignedNotationID)
        }
    }
}
