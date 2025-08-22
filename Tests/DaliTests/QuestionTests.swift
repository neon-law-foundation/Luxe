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

@Suite("Question Model Tests", .serialized)
struct QuestionTests {

    /// Generates a unique code with ISO timestamp and UUID suffix
    private func generateUniqueCode(prefix: String = "code") -> String {
        UniqueCodeGenerator.generateISOCode(prefix: prefix)
    }

    @Test("Question model has required fields and can be initialized")
    func questionModelHasRequiredFields() async throws {
        let question = Question()

        #expect(question.id == nil)
        #expect(question.createdAt == nil)
        #expect(question.updatedAt == nil)

        // Verify the model can be initialized without errors
    }

    @Test("Question model can be initialized with parameters")
    func questionModelCanBeInitializedWithParameters() async throws {
        let questionType = Question.QuestionType.string
        let choices = Question.Choices(["Option A", "Option B"])

        let question = Question(
            prompt: "What is your name?",
            questionType: questionType,
            code: "full_name",
            helpText: "Please enter your full legal name",
            choices: choices
        )

        #expect(question.prompt == "What is your name?")
        #expect(question.questionType == .string)
        #expect(question.code == "full_name")
        #expect(question.helpText == "Please enter your full legal name")
        #expect(question.choices == choices)
    }

    @Test("Question type enum contains all expected values")
    func questionTypeEnumContainsAllExpectedValues() async throws {
        let expectedTypes: [Question.QuestionType] = [
            .string, .text, .date, .datetime, .number, .yesNo,
            .radio, .select, .multiSelect, .secret, .signature,
            .notarization, .phone, .email, .ssn, .ein, .file,
            .person, .address, .issuance, .org, .document, .registeredAgent,
        ]

        for type in expectedTypes {
            #expect(type.rawValue.isEmpty == false)
        }
    }

    @Test("Question can be saved and retrieved from database")
    func questionCanBeSavedAndRetrieved() async throws {
        try await TestUtilities.withApp { app, database in
            // Insert a question using raw SQL
            let prompt = "Do you agree to the terms?"
            let questionType = "yes_no"
            let code = generateUniqueCode(prefix: "terms_agreement")
            let helpText = "Please read the terms carefully before agreeing"

            let rows = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                        INSERT INTO standards.questions (prompt, question_type, code, help_text)
                        VALUES (\(bind: prompt), \(bind: questionType), \(bind: code), \(bind: helpText))
                        RETURNING id, created_at, updated_at
                    """
                )
                .all()

            #expect(rows.count == 1)

            // Retrieve the question using raw SQL
            let retrievedRows = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                        SELECT id, prompt, question_type, code, help_text, created_at, updated_at
                        FROM standards.questions
                        WHERE code = \(bind: code)
                    """
                )
                .all()

            #expect(retrievedRows.count == 1)

            let row = retrievedRows[0]
            #expect(try row.decode(column: "prompt", as: String.self) == prompt)
            #expect(try row.decode(column: "question_type", as: String.self) == questionType)
            #expect(try row.decode(column: "code", as: String.self) == code)
            #expect(try row.decode(column: "help_text", as: String.self) == helpText)
        }
    }

    @Test("Question code must be unique in database")
    func questionCodeMustBeUniqueInDatabase() async throws {
        try await TestUtilities.withApp { app, database in
            // Insert first question with a unique code to avoid conflicts
            let firstPrompt = "First question"
            let firstType = "string"
            let uniqueCode = generateUniqueCode(prefix: "unique_code")

            _ = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                        INSERT INTO standards.questions (prompt, question_type, code)
                        VALUES (\(bind: firstPrompt), \(bind: firstType), \(bind: uniqueCode))
                    """
                )
                .all()

            // Try to insert second question with same code - should fail
            let secondPrompt = "Second question"
            let secondType = "text"

            await #expect(throws: Error.self) {
                _ = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                            INSERT INTO standards.questions (prompt, question_type, code)
                            VALUES (\(bind: secondPrompt), \(bind: secondType), \(bind: uniqueCode))
                        """
                    )
                    .all()
            }
        }
    }
}
