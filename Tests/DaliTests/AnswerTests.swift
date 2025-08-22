import Fluent
import FluentPostgresDriver
import Foundation
import Logging
import PostgresNIO
import ServiceLifecycle
import Testing
import Vapor

@testable import Dali
@testable import Palette

@Suite("Answer Model Tests", .serialized)
struct AnswerTests {

    /// Generates a unique code with ISO timestamp and UUID suffix
    private func generateUniqueCode(prefix: String = "code") -> String {
        UniqueCodeGenerator.generateISOCode(prefix: prefix)
    }

    @Test("Answer model has required fields and can be initialized")
    func answerModelHasRequiredFields() async throws {
        let answer = Answer()

        #expect(answer.id == nil)
        #expect(answer.createdAt == nil)
        #expect(answer.updatedAt == nil)
    }

    @Test("Answer model can be initialized with parameters")
    func answerModelCanBeInitializedWithParameters() async throws {
        let blobID = UUID()
        let answererID = UUID()
        let questionID = UUID()
        let entityID = UUID()
        let assignedNotationID = UUID()
        let response = Answer.Response(
            rawValue: """
                    {"answer": "Yes", "confidence": "high"}
                """
        )

        let answer = Answer(
            blobID: blobID,
            answererID: answererID,
            questionID: questionID,
            entityID: entityID,
            assignedNotationID: assignedNotationID,
            response: response
        )

        #expect(answer.$blob.id == blobID)
        #expect(answer.$answerer.id == answererID)
        #expect(answer.$question.id == questionID)
        #expect(answer.$entity.id == entityID)
        #expect(answer.$assignedNotation.id == assignedNotationID)
        #expect(answer.response == response)
    }

    @Test("Answer can be initialized with minimal required parameters")
    func answerCanBeInitializedWithMinimalParameters() async throws {
        let answererID = UUID()
        let questionID = UUID()
        let entityID = UUID()

        let answer = Answer(
            answererID: answererID,
            questionID: questionID,
            entityID: entityID
        )

        #expect(answer.$blob.id == nil)
        #expect(answer.$answerer.id == answererID)
        #expect(answer.$question.id == questionID)
        #expect(answer.$entity.id == entityID)
        #expect(answer.$assignedNotation.id == nil)
        #expect(answer.response.rawValue == "{}")
    }

    @Test("Answer response type handles JSON encoding and decoding")
    func answerResponseHandlesJsonEncodingAndDecoding() async throws {
        let jsonString = """
                {"answer": "John Doe", "question_type": "string", "validated": true}
            """
        let response = Answer.Response(rawValue: jsonString)

        // Test encoding
        let encoder = JSONEncoder()
        let encodedData = try encoder.encode(response)

        // Test decoding
        let decoder = JSONDecoder()
        let decodedResponse = try decoder.decode(Answer.Response.self, from: encodedData)

        #expect(decodedResponse == response)
        #expect(decodedResponse.rawValue == jsonString)
    }

    @Test("Answer response type equality works correctly")
    func answerResponseEqualityWorksCorrectly() async throws {
        let response1 = Answer.Response(
            rawValue: """
                    {"answer": "test"}
                """
        )
        let response2 = Answer.Response(
            rawValue: """
                    {"answer": "test"}
                """
        )
        let response3 = Answer.Response(
            rawValue: """
                    {"answer": "different"}
                """
        )

        #expect(response1 == response2)
        #expect(response1 != response3)
    }
}
