import Fluent
import FluentPostgresDriver
import Foundation
import JSONSchema
import Logging
import PostgresNIO
import ServiceLifecycle
import TestUtilities
import Testing
import Vapor

@testable import Dali
@testable import Palette

@Suite("AssignedNotation Model Tests", .serialized)
struct AssignedNotationTests {

    @Test("AssignedNotation model has required fields and can be initialized")
    func assignedNotationModelHasRequiredFields() async throws {
        let assignedNotation = AssignedNotation()

        #expect(assignedNotation.id == nil)
        #expect(assignedNotation.createdAt == nil)
        #expect(assignedNotation.updatedAt == nil)
    }

    @Test("AssignedNotation model can be initialized with parameters")
    func assignedNotationModelCanBeInitializedWithParameters() async throws {
        let entityID = UUID()
        let notationID = UUID()
        let projectID = UUID()
        let personID = UUID()
        let dueDate = Date().addingTimeInterval(86400 * 7)  // 7 days from now
        let changeLanguage = AssignedNotation.ChangeLanguage(rawValue: "{\"modification\":\"updated terms\"}")
        let answers = AssignedNotation.Answers(rawValue: "{\"question1\":\"answer1\"}")

        let assignedNotation = AssignedNotation(
            entityID: entityID,
            state: .awaitingReview,
            changeLanguage: changeLanguage,
            dueAt: dueDate,
            personID: personID,
            answers: answers,
            notationID: notationID,
            projectID: projectID
        )

        #expect(assignedNotation.$entity.id == entityID)
        #expect(assignedNotation.state == AssignedNotation.State.awaitingReview)
        #expect(assignedNotation.changeLanguage == changeLanguage)
        #expect(assignedNotation.dueAt == dueDate)
        #expect(assignedNotation.$person.id == personID)
        #expect(assignedNotation.answers == answers)
        #expect(assignedNotation.$notation.id == notationID)
        #expect(assignedNotation.$project.id == projectID)
    }

    @Test("State enum contains all expected values")
    func stateEnumContainsAllExpectedValues() async throws {
        let expectedStates: [AssignedNotation.State] = [
            .awaitingFlow,
            .awaitingReview,
            .awaitingAlignment,
            .complete,
            .completeWithError,
        ]

        for state in expectedStates {
            #expect(state.rawValue.isEmpty == false)
        }

        #expect(AssignedNotation.State.awaitingFlow.rawValue == "awaiting_flow")
        #expect(AssignedNotation.State.awaitingReview.rawValue == "awaiting_review")
        #expect(AssignedNotation.State.awaitingAlignment.rawValue == "awaiting_alignment")
        #expect(AssignedNotation.State.complete.rawValue == "complete")
        #expect(AssignedNotation.State.completeWithError.rawValue == "complete_with_error")
    }

    @Test(
        "AssignedNotation can be saved and retrieved from database",
        .disabled("Connection timeout after 10+ seconds - needs connection investigation")
    )
    func assignedNotationCanBeSavedAndRetrieved() async throws {
        try await TestUtilities.withApp { app, database in
            // First, create required entities for foreign keys
            // Get Nevada jurisdiction ID (should exist from migrations)
            let nevadaResult = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT id FROM legal.jurisdictions WHERE code = 'NV'")
                .first()

            guard let nevada = nevadaResult,
                let jurisdictionId = try? nevada.decode(column: "id", as: UUID.self)
            else {
                throw TestError.invalidConnectionURL  // Use existing error type
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
            let notationUID = TestUtilities.randomUID(prefix: "assigned")
            let notationCode = TestUtilities.randomCode(prefix: "assigned_notation")

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

            // Insert an assigned notation
            let state = "awaiting_flow"
            let changeLanguage = "{}"
            let answers = "{}"

            let rows = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                        INSERT INTO matters.assigned_notations
                        (entity_id, state, change_language, answers, notation_id, project_id)
                        VALUES (\(bind: entityID), \(bind: state),
                                \(bind: changeLanguage)::jsonb, \(bind: answers)::jsonb,
                                \(bind: notationID), \(bind: projectID))
                        RETURNING id, created_at, updated_at
                    """
                )
                .all()

            #expect(rows.count == 1)

            // Retrieve the assigned notation
            let assignedNotationID = try rows[0].decode(column: "id", as: UUID.self)

            let retrievedRows = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                        SELECT id, entity_id, state, change_language, answers,
                               notation_id, project_id, created_at, updated_at
                        FROM matters.assigned_notations
                        WHERE id = \(bind: assignedNotationID)
                    """
                )
                .all()

            #expect(retrievedRows.count == 1)

            let row = retrievedRows[0]
            #expect(try row.decode(column: "entity_id", as: UUID.self) == entityID)
            #expect(try row.decode(column: "state", as: String.self) == state)
            #expect(try row.decode(column: "notation_id", as: UUID.self) == notationID)
            #expect(try row.decode(column: "project_id", as: UUID.self) == projectID)
        }
    }

    @Test("AssignedNotation state check constraint is enforced")
    func assignedNotationStateCheckConstraintIsEnforced() async throws {
        try await TestUtilities.withApp { app, database in
            // Create required entities
            let entityName = "Test Entity \(TestUtilities.randomString())"
            let entityRows = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                        INSERT INTO directory.entities
                        (name, legal_entity_type_id)
                        VALUES (\(bind: entityName),
                                (SELECT id FROM legal.entity_types LIMIT 1))
                        RETURNING id
                    """
                )
                .all()

            let entityID = try entityRows[0].decode(column: "id", as: UUID.self)

            let notationUID = TestUtilities.randomUID(prefix: "invalid-state")
            let notationCode = TestUtilities.randomCode(prefix: "invalid_state_notation")

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

            // Try to insert with invalid state - should fail
            await #expect(throws: Error.self) {
                _ = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                            INSERT INTO matters.assigned_notations
                            (entity_id, state, change_language, answers, notation_id, project_id)
                            VALUES (\(bind: entityID), 'invalid_state',
                                    '{}'::jsonb, '{}'::jsonb, \(bind: notationID), \(bind: projectID))
                        """
                    )
                    .all()
            }
        }
    }

    @Test("AssignedNotation can have optional person assignment", .disabled("CI connection timeout issues"))
    func assignedNotationCanHaveOptionalPersonAssignment() async throws {
        try await TestUtilities.withApp { app, database in
            // Create required entities
            let entityName = "Test Entity \(TestUtilities.randomString())"
            let entityRows = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                        INSERT INTO directory.entities
                        (name, legal_entity_type_id)
                        VALUES (\(bind: entityName),
                                (SELECT id FROM legal.entity_types LIMIT 1))
                        RETURNING id
                    """
                )
                .all()

            let entityID = try entityRows[0].decode(column: "id", as: UUID.self)

            let notationUID = TestUtilities.randomUID(prefix: "person-test")
            let notationCode = TestUtilities.randomCode(prefix: "person_test_notation")

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

            // Get a person ID (use the first one available)
            let personRows = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT id FROM directory.people LIMIT 1")
                .all()

            guard !personRows.isEmpty else {
                // If no person exists, create one
                let createPersonRows = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                            INSERT INTO directory.people
                            (name, display_name)
                            VALUES ('Test Person', 'Test Person')
                            RETURNING id
                        """
                    )
                    .all()

                let personID = try createPersonRows[0].decode(column: "id", as: UUID.self)

                // Insert with person
                let rows = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                            INSERT INTO matters.assigned_notations
                            (entity_id, state, change_language, answers, notation_id, person_id, project_id)
                            VALUES (\(bind: entityID), 'awaiting_flow',
                                    '{}'::jsonb, '{}'::jsonb, \(bind: notationID), \(bind: personID), \(bind: projectID))
                            RETURNING id, person_id
                        """
                    )
                    .all()

                #expect(rows.count == 1)
                #expect(try rows[0].decode(column: "person_id", as: UUID.self) == personID)
                return
            }

            let personID = try personRows[0].decode(column: "id", as: UUID.self)

            // Insert with person
            let rows = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                        INSERT INTO matters.assigned_notations
                        (entity_id, state, change_language, answers, notation_id, person_id, project_id)
                        VALUES (\(bind: entityID), 'awaiting_flow',
                                '{}'::jsonb, '{}'::jsonb, \(bind: notationID), \(bind: personID), \(bind: projectID))
                        RETURNING id, person_id
                    """
                )
                .all()

            #expect(rows.count == 1)
            #expect(try rows[0].decode(column: "person_id", as: UUID.self) == personID)
        }
    }

    @Test("ChangeLanguage can validate valid changelog JSON against schema")
    func changeLanguageValidatesValidChangelogJSON() async throws {
        let validChangelogJSON = """
            {
                "changes": [
                    {
                        "action": "created",
                        "timestamp": "2024-01-15T10:30:00Z",
                        "user_id": "\(UUID().uuidString)",
                        "notes": "Initial creation of notation"
                    },
                    {
                        "action": "updated",
                        "timestamp": "2024-01-16T14:20:00Z",
                        "user_id": "\(UUID().uuidString)"
                    }
                ]
            }
            """

        let changeLanguage = AssignedNotation.ChangeLanguage(rawValue: validChangelogJSON)
        let validationResult = try changeLanguage.validateAgainstSchema()

        #expect(validationResult.isValid)
        #expect(validationResult.errors.isEmpty)
    }

    @Test("ChangeLanguage rejects invalid changelog JSON - missing required action field")
    func changeLanguageRejectsInvalidChangelogMissingAction() async throws {
        let invalidChangelogJSON = """
            {
                "changes": [
                    {
                        "timestamp": "2024-01-15T10:30:00Z",
                        "user_id": "\(UUID().uuidString)",
                        "notes": "Missing action field"
                    }
                ]
            }
            """

        let changeLanguage = AssignedNotation.ChangeLanguage(rawValue: invalidChangelogJSON)
        let validationResult = try changeLanguage.validateAgainstSchema()

        #expect(!validationResult.isValid)
        #expect(!validationResult.errors.isEmpty)
        #expect(validationResult.errors.contains { $0.contains("action") })
    }

    @Test("ChangeLanguage rejects invalid changelog JSON - missing required timestamp field")
    func changeLanguageRejectsInvalidChangelogMissingTimestamp() async throws {
        let invalidChangelogJSON = """
            {
                "changes": [
                    {
                        "action": "created",
                        "user_id": "\(UUID().uuidString)",
                        "notes": "Missing timestamp field"
                    }
                ]
            }
            """

        let changeLanguage = AssignedNotation.ChangeLanguage(rawValue: invalidChangelogJSON)
        let validationResult = try changeLanguage.validateAgainstSchema()

        #expect(!validationResult.isValid)
        #expect(!validationResult.errors.isEmpty)
        #expect(validationResult.errors.contains { $0.contains("timestamp") })
    }

    @Test("ChangeLanguage rejects invalid changelog JSON - missing required user_id field")
    func changeLanguageRejectsInvalidChangelogMissingUserId() async throws {
        let invalidChangelogJSON = """
            {
                "changes": [
                    {
                        "action": "created",
                        "timestamp": "2024-01-15T10:30:00Z",
                        "notes": "Missing user_id field"
                    }
                ]
            }
            """

        let changeLanguage = AssignedNotation.ChangeLanguage(rawValue: invalidChangelogJSON)
        let validationResult = try changeLanguage.validateAgainstSchema()

        #expect(!validationResult.isValid)
        #expect(!validationResult.errors.isEmpty)
        #expect(validationResult.errors.contains { $0.contains("user_id") })
    }

    @Test("ChangeLanguage rejects invalid changelog JSON - invalid action value")
    func changeLanguageRejectsInvalidActionValue() async throws {
        let invalidChangelogJSON = """
            {
                "changes": [
                    {
                        "action": "invalid_action",
                        "timestamp": "2024-01-15T10:30:00Z",
                        "user_id": "\(UUID().uuidString)",
                        "notes": "Invalid action value"
                    }
                ]
            }
            """

        let changeLanguage = AssignedNotation.ChangeLanguage(rawValue: invalidChangelogJSON)
        let validationResult = try changeLanguage.validateAgainstSchema()

        #expect(!validationResult.isValid)
        #expect(!validationResult.errors.isEmpty)
        #expect(validationResult.errors.contains { $0.contains("action") })
    }

    @Test("ChangeLanguage accepts optional notes field")
    func changeLanguageAcceptsOptionalNotesField() async throws {
        let validChangelogWithoutNotesJSON = """
            {
                "changes": [
                    {
                        "action": "created",
                        "timestamp": "2024-01-15T10:30:00Z",
                        "user_id": "\(UUID().uuidString)"
                    }
                ]
            }
            """

        let changeLanguage = AssignedNotation.ChangeLanguage(rawValue: validChangelogWithoutNotesJSON)
        let validationResult = try changeLanguage.validateAgainstSchema()

        #expect(validationResult.isValid)
        #expect(validationResult.errors.isEmpty)
    }

    @Test("ChangeLanguage supports multiple valid actions")
    func changeLanguageSupportsMultipleValidActions() async throws {
        let validActions = ["created", "updated", "reviewed", "approved", "rejected", "deleted"]

        for action in validActions {
            let changelogJSON = """
                {
                    "changes": [
                        {
                            "action": "\(action)",
                            "timestamp": "2024-01-15T10:30:00Z",
                            "user_id": "\(UUID().uuidString)",
                            "notes": "Test action: \(action)"
                        }
                    ]
                }
                """

            let changeLanguage = AssignedNotation.ChangeLanguage(rawValue: changelogJSON)
            let validationResult = try changeLanguage.validateAgainstSchema()

            #expect(validationResult.isValid, "Action '\(action)' should be valid")
            #expect(validationResult.errors.isEmpty, "Action '\(action)' should not produce errors")
        }
    }
}
