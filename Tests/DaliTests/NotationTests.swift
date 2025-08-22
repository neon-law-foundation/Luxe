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

@Suite("Notation Model Tests", .serialized)
struct NotationTests {

    @Test("Notation model has required fields and can be initialized")
    func notationModelHasRequiredFields() async throws {
        let notation = Notation()

        #expect(notation.id == nil)
        #expect(notation.createdAt == nil)
        #expect(notation.updatedAt == nil)
    }

    @Test("Notation model can be initialized with parameters")
    func notationModelCanBeInitializedWithParameters() async throws {
        let flow = Notation.FlowData(rawValue: "{\"step1\":\"value1\"}")
        let alignment = Notation.AlignmentData(rawValue: "{\"review1\":\"criteria1\"}")
        let documentMappings = Notation.DocumentMappings(rawValue: "{\"field1\":{\"x\":100,\"y\":200}}")

        let uid = TestUtilities.randomUID(prefix: "test")
        let code = TestUtilities.randomCode(prefix: "test_notation")

        let notation = Notation(
            uid: uid,
            title: "Test Notation",
            description: "A test notation for unit testing",
            flow: flow,
            code: code,
            documentUrl: "https://example.com/doc.pdf",
            documentMappings: documentMappings,
            alignment: alignment,
            respondentType: .org,
            documentText: "Sample document text",
            documentType: "pdf",
            repository: "neon-law/notations",
            commitSha: "abc123def456",
            published: false
        )

        #expect(notation.uid == uid)
        #expect(notation.title == "Test Notation")
        #expect(notation.$description.value == "A test notation for unit testing")
        #expect(notation.flow == flow)
        #expect(notation.code == code)
        #expect(notation.documentUrl == "https://example.com/doc.pdf")
        #expect(notation.documentMappings == documentMappings)
        #expect(notation.alignment == alignment)
        #expect(notation.respondentType == .org)
        #expect(notation.documentText == "Sample document text")
        #expect(notation.documentType == "pdf")
        #expect(notation.repository == "neon-law/notations")
        #expect(notation.commitSha == "abc123def456")
        #expect(notation.published == false)
    }

    @Test("Respondent type enum contains expected values")
    func respondentTypeEnumContainsExpectedValues() async throws {
        let expectedTypes: [Notation.RespondentType] = [.org, .orgAndUser]

        for type in expectedTypes {
            #expect(type.rawValue.isEmpty == false)
        }

        #expect(Notation.RespondentType.org.rawValue == "org")
        #expect(Notation.RespondentType.orgAndUser.rawValue == "org_and_user")
    }

    @Test("Notation can be saved and retrieved from database")
    func notationCanBeSavedAndRetrieved() async throws {
        try await TestUtilities.withApp { app, database in
            // Insert a notation using raw SQL
            let uid = TestUtilities.randomUID()
            let title = "Test Secretary of State Filing"
            let code = TestUtilities.randomCode(prefix: "sos_filing")
            let flow = "{}"
            let alignment = "{}"
            let respondentType = "org"
            let published = false

            let rows = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                        INSERT INTO standards.notations
                        (uid, title, code, flow, alignment, respondent_type, published)
                        VALUES (\(bind: uid), \(bind: title), \(bind: code),
                                \(bind: flow)::jsonb, \(bind: alignment)::jsonb,
                                \(bind: respondentType), \(bind: published))
                        RETURNING id, created_at, updated_at
                    """
                )
                .all()

            #expect(rows.count == 1)

            // Retrieve the notation using raw SQL
            let retrievedRows = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                        SELECT id, uid, title, code, flow, alignment,
                               respondent_type, published, created_at, updated_at
                        FROM standards.notations
                        WHERE code = \(bind: code)
                    """
                )
                .all()

            #expect(retrievedRows.count == 1)

            let row = retrievedRows[0]
            #expect(try row.decode(column: "uid", as: String.self) == uid)
            #expect(try row.decode(column: "title", as: String.self) == title)
            #expect(try row.decode(column: "code", as: String.self) == code)
            #expect(try row.decode(column: "respondent_type", as: String.self) == respondentType)
            #expect(try row.decode(column: "published", as: Bool.self) == published)
        }
    }

    @Test("Notation code and uid must be unique in database")
    func notationCodeAndUidMustBeUniqueInDatabase() async throws {
        try await TestUtilities.withApp { app, database in
            // Insert first notation
            let uid = TestUtilities.randomUID(prefix: "unique")
            let code = TestUtilities.randomCode(prefix: "unique_code")

            _ = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                        INSERT INTO standards.notations
                        (uid, title, code, flow, alignment, published)
                        VALUES (\(bind: uid), 'First Notation', \(bind: code),
                                '{}'::jsonb, '{}'::jsonb, false)
                    """
                )
                .all()

            // Try to insert second notation with same uid - should fail
            await #expect(throws: Error.self) {
                _ = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                            INSERT INTO standards.notations
                            (uid, title, code, flow, alignment, published)
                            VALUES (\(bind: uid), 'Second Notation', 'different_code',
                                    '{}'::jsonb, '{}'::jsonb, false)
                        """
                    )
                    .all()
            }

            // Try to insert second notation with same code - should fail
            await #expect(throws: Error.self) {
                _ = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                            INSERT INTO standards.notations
                            (uid, title, code, flow, alignment, published)
                            VALUES ('different-uid', 'Third Notation', \(bind: code),
                                    '{}'::jsonb, '{}'::jsonb, false)
                        """
                    )
                    .all()
            }
        }
    }

    @Test("Notation respondent type check constraint is enforced")
    func notationRespondentTypeCheckConstraintIsEnforced() async throws {
        try await TestUtilities.withApp { app, database in
            let uid = TestUtilities.randomUID(prefix: "test")
            let code = TestUtilities.randomCode(prefix: "test_code")

            // Try to insert notation with invalid respondent_type - should fail
            await #expect(throws: Error.self) {
                _ = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                            INSERT INTO standards.notations
                            (uid, title, code, flow, alignment, respondent_type, published)
                            VALUES (\(bind: uid), 'Invalid Type Notation', \(bind: code),
                                    '{}'::jsonb, '{}'::jsonb, 'invalid_type', false)
                        """
                    )
                    .all()
            }
        }
    }

    @Test("FlowData validates valid question map JSON against schema")
    func flowDataValidatesValidQuestionMapJSON() async throws {
        let validFlowJSON = """
            {
                "BEGIN": {
                    "_start": "question1",
                    "_error": "ERROR"
                }
            }
            """

        let flowData = Notation.FlowData(rawValue: validFlowJSON)
        let validationResult = try flowData.validateAgainstSchema()

        #expect(validationResult.isValid)
        #expect(validationResult.errors.isEmpty)
    }

    @Test("FlowData rejects invalid question map JSON - missing BEGIN")
    func flowDataRejectsInvalidQuestionMapMissingBegin() async throws {
        let invalidFlowJSON = """
            {
                "INVALID": {
                    "_start": "question1"
                }
            }
            """

        let flowData = Notation.FlowData(rawValue: invalidFlowJSON)
        let validationResult = try flowData.validateAgainstSchema()

        #expect(!validationResult.isValid)
        #expect(!validationResult.errors.isEmpty)
        #expect(validationResult.errors.contains { $0.contains("BEGIN") })
    }

    @Test("FlowData accepts valid flow patterns")
    func flowDataAcceptsValidFlowPatterns() async throws {
        let validFlowWithMultipleSteps = """
            {
                "BEGIN": {
                    "_start": "question1",
                    "_next": "question2",
                    "_complete": "END",
                    "_error": "ERROR"
                }
            }
            """

        let flowData = Notation.FlowData(rawValue: validFlowWithMultipleSteps)
        let validationResult = try flowData.validateAgainstSchema()

        #expect(validationResult.isValid)
        #expect(validationResult.errors.isEmpty)
    }

    @Test("AlignmentData validates valid question map JSON against schema")
    func alignmentDataValidatesValidQuestionMapJSON() async throws {
        let validAlignmentJSON = """
            {
                "BEGIN": {
                    "_review": "review1",
                    "_approve": "END"
                }
            }
            """

        let alignmentData = Notation.AlignmentData(rawValue: validAlignmentJSON)
        let validationResult = try alignmentData.validateAgainstSchema()

        #expect(validationResult.isValid)
        #expect(validationResult.errors.isEmpty)
    }

    @Test("AlignmentData rejects invalid question map JSON - missing BEGIN")
    func alignmentDataRejectsInvalidQuestionMapMissingBegin() async throws {
        let invalidAlignmentJSON = """
            {
                "REVIEW": {
                    "_start": "review1"
                }
            }
            """

        let alignmentData = Notation.AlignmentData(rawValue: invalidAlignmentJSON)
        let validationResult = try alignmentData.validateAgainstSchema()

        #expect(!validationResult.isValid)
        #expect(!validationResult.errors.isEmpty)
        #expect(validationResult.errors.contains { $0.contains("BEGIN") })
    }

    @Test("DocumentMappings validates valid document mappings JSON against schema")
    func documentMappingsValidatesValidDocumentMappingsJSON() async throws {
        let validDocumentMappingsJSON = """
            {
                "field1": {
                    "page": 1,
                    "upper_right": [100.5, 200.3],
                    "lower_right": [100.5, 180.7],
                    "upper_left": [50.2, 200.3],
                    "lower_left": [50.2, 180.7]
                },
                "signature_field": {
                    "page": 2,
                    "upper_right": [300.0, 400.0],
                    "lower_right": [300.0, 350.0],
                    "upper_left": [200.0, 400.0],
                    "lower_left": [200.0, 350.0]
                }
            }
            """

        let documentMappings = Notation.DocumentMappings(rawValue: validDocumentMappingsJSON)
        let validationResult = try documentMappings.validateAgainstSchema()

        #expect(validationResult.isValid)
        #expect(validationResult.errors.isEmpty)
    }

    @Test("DocumentMappings rejects invalid document mappings JSON - missing required page field")
    func documentMappingsRejectsInvalidDocumentMappingsMissingPage() async throws {
        let invalidDocumentMappingsJSON = """
            {
                "field1": {
                    "upper_right": [100.5, 200.3],
                    "lower_right": [100.5, 180.7],
                    "upper_left": [50.2, 200.3],
                    "lower_left": [50.2, 180.7]
                }
            }
            """

        let documentMappings = Notation.DocumentMappings(rawValue: invalidDocumentMappingsJSON)
        let validationResult = try documentMappings.validateAgainstSchema()

        #expect(!validationResult.isValid)
        #expect(!validationResult.errors.isEmpty)
        #expect(validationResult.errors.contains { $0.contains("page") })
    }

    @Test("DocumentMappings rejects invalid document mappings JSON - invalid coordinate array")
    func documentMappingsRejectsInvalidDocumentMappingsInvalidCoordinates() async throws {
        let invalidDocumentMappingsJSON = """
            {
                "field1": {
                    "page": 1,
                    "upper_right": [100.5],
                    "lower_right": [100.5, 180.7],
                    "upper_left": [50.2, 200.3],
                    "lower_left": [50.2, 180.7]
                }
            }
            """

        let documentMappings = Notation.DocumentMappings(rawValue: invalidDocumentMappingsJSON)
        let validationResult = try documentMappings.validateAgainstSchema()

        #expect(!validationResult.isValid)
        #expect(!validationResult.errors.isEmpty)
        #expect(validationResult.errors.contains { $0.contains("upper_right") || $0.contains("minItems") })
    }

    @Test("DocumentMappings rejects invalid document mappings JSON - non-numeric page")
    func documentMappingsRejectsInvalidDocumentMappingsNonNumericPage() async throws {
        let invalidDocumentMappingsJSON = """
            {
                "field1": {
                    "page": "first",
                    "upper_right": [100.5, 200.3],
                    "lower_right": [100.5, 180.7],
                    "upper_left": [50.2, 200.3],
                    "lower_left": [50.2, 180.7]
                }
            }
            """

        let documentMappings = Notation.DocumentMappings(rawValue: invalidDocumentMappingsJSON)
        let validationResult = try documentMappings.validateAgainstSchema()

        #expect(!validationResult.isValid)
        #expect(!validationResult.errors.isEmpty)
        #expect(validationResult.errors.contains { $0.contains("page") || $0.contains("integer") })
    }
}
