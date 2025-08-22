import Fluent
import FluentPostgresDriver
import Foundation
import Logging
import PostgresNIO
import ServiceLifecycle
import TestUtilities
import Testing
import Vapor

@testable import Dali
@testable import Palette

@Suite("NotationQuestion Model Tests", .serialized)
struct NotationQuestionTests {

    @Test("NotationQuestion model can be initialized")
    func notationQuestionModelCanBeInitialized() async throws {
        let notationQuestion = NotationQuestion()

        #expect(notationQuestion.id == nil)
        #expect(notationQuestion.createdAt == nil)
        #expect(notationQuestion.updatedAt == nil)
    }

    @Test("NotationQuestion model can be initialized with IDs")
    func notationQuestionModelCanBeInitializedWithIDs() async throws {
        let notationID = UUID()
        let questionID = UUID()

        let notationQuestion = NotationQuestion(
            notationID: notationID,
            questionID: questionID
        )

        #expect(notationQuestion.$notation.id == notationID)
        #expect(notationQuestion.$question.id == questionID)
    }

    @Test("NotationQuestion can link notation and question in database")
    func notationQuestionCanLinkNotationAndQuestion() async throws {
        try await TestUtilities.withApp { app, database in
            // First, create a notation
            let notationUID = TestUtilities.randomUID(prefix: "test")
            let notationCode = TestUtilities.randomCode(prefix: "test_notation")

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

            // Then, create a question
            let questionCode = TestUtilities.randomCode(prefix: "test_question")

            let questionRows = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                        INSERT INTO standards.questions
                        (prompt, question_type, code)
                        VALUES ('Test Question', 'string', \(bind: questionCode))
                        RETURNING id
                    """
                )
                .all()

            let questionID = try questionRows[0].decode(column: "id", as: UUID.self)

            // Link them through the join table
            let linkRows = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                        INSERT INTO standards.notations_questions
                        (notation_id, question_id)
                        VALUES (\(bind: notationID), \(bind: questionID))
                        RETURNING created_at, updated_at
                    """
                )
                .all()

            #expect(linkRows.count == 1)

            // Verify the link exists
            let verifyRows = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                        SELECT notation_id, question_id, created_at, updated_at
                        FROM standards.notations_questions
                        WHERE notation_id = \(bind: notationID)
                        AND question_id = \(bind: questionID)
                    """
                )
                .all()

            #expect(verifyRows.count == 1)
            let row = verifyRows[0]
            #expect(try row.decode(column: "notation_id", as: UUID.self) == notationID)
            #expect(try row.decode(column: "question_id", as: UUID.self) == questionID)
        }
    }

    @Test("NotationQuestion enforces unique notation-question pairs")
    func notationQuestionEnforcesUniqueNotationQuestionPairs() async throws {
        try await TestUtilities.withApp { app, database in
            // Create a notation and question
            let notationUID = TestUtilities.randomUID(prefix: "unique")
            let notationCode = TestUtilities.randomCode(prefix: "unique_notation")

            let notationRows = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                        INSERT INTO standards.notations
                        (uid, title, code, flow, alignment, published)
                        VALUES (\(bind: notationUID), 'Unique Notation', \(bind: notationCode),
                                '{}'::jsonb, '{}'::jsonb, false)
                        RETURNING id
                    """
                )
                .all()

            let notationID = try notationRows[0].decode(column: "id", as: UUID.self)

            let questionCode = TestUtilities.randomCode(prefix: "unique_question")

            let questionRows = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                        INSERT INTO standards.questions
                        (prompt, question_type, code)
                        VALUES ('Unique Question', 'string', \(bind: questionCode))
                        RETURNING id
                    """
                )
                .all()

            let questionID = try questionRows[0].decode(column: "id", as: UUID.self)

            // First link should succeed
            _ = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                        INSERT INTO standards.notations_questions
                        (notation_id, question_id)
                        VALUES (\(bind: notationID), \(bind: questionID))
                    """
                )
                .all()

            // Second link with same IDs should fail due to primary key constraint
            await #expect(throws: Error.self) {
                _ = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                            INSERT INTO standards.notations_questions
                            (notation_id, question_id)
                            VALUES (\(bind: notationID), \(bind: questionID))
                        """
                    )
                    .all()
            }
        }
    }

    @Test("NotationQuestion cascade deletes when notation is deleted")
    func notationQuestionCascadeDeletesWhenNotationIsDeleted() async throws {
        try await TestUtilities.withApp { app, database in
            // Create a notation and question, then link them
            let notationUID = TestUtilities.randomUID(prefix: "cascade")
            let notationCode = TestUtilities.randomCode(prefix: "cascade_notation")

            let notationRows = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                        INSERT INTO standards.notations
                        (uid, title, code, flow, alignment, published)
                        VALUES (\(bind: notationUID), 'Cascade Notation', \(bind: notationCode),
                                '{}'::jsonb, '{}'::jsonb, false)
                        RETURNING id
                    """
                )
                .all()

            let notationID = try notationRows[0].decode(column: "id", as: UUID.self)

            let questionCode = TestUtilities.randomCode(prefix: "cascade_question")

            let questionRows = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                        INSERT INTO standards.questions
                        (prompt, question_type, code)
                        VALUES ('Cascade Question', 'string', \(bind: questionCode))
                        RETURNING id
                    """
                )
                .all()

            let questionID = try questionRows[0].decode(column: "id", as: UUID.self)

            // Link them
            _ = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                        INSERT INTO standards.notations_questions
                        (notation_id, question_id)
                        VALUES (\(bind: notationID), \(bind: questionID))
                    """
                )
                .all()

            // Delete the notation
            _ = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                        DELETE FROM standards.notations
                        WHERE id = \(bind: notationID)
                    """
                )
                .all()

            // Verify the link was cascade deleted
            let remainingLinks = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                        SELECT COUNT(*) as count
                        FROM standards.notations_questions
                        WHERE notation_id = \(bind: notationID)
                    """
                )
                .all()

            #expect(try remainingLinks[0].decode(column: "count", as: Int.self) == 0)

            // Verify the question still exists
            let remainingQuestions = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                        SELECT COUNT(*) as count
                        FROM standards.questions
                        WHERE id = \(bind: questionID)
                    """
                )
                .all()

            #expect(try remainingQuestions[0].decode(column: "count", as: Int.self) == 1)
        }
    }
}
