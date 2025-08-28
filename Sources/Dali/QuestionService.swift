import Fluent
import FluentPostgresDriver
import Foundation
import PostgresNIO
import Vapor

/// Service for question operations
public struct QuestionService: Sendable {

    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    /// Lists all questions
    /// - Parameter limit: Maximum number of results to return (default 100)
    /// - Parameter offset: Number of results to skip (default 0)
    /// - Returns: Array of questions
    public func listQuestions(limit: Int = 100, offset: Int = 0) async throws -> [Question] {
        try await Question.query(on: database)
            .limit(limit)
            .offset(offset)
            .sort(\.$code, .ascending)
            .all()
    }

    /// Retrieves a question by ID
    /// - Parameter questionId: The UUID of the question to retrieve
    /// - Returns: The question, or nil if not found
    public func getQuestion(questionId: UUID) async throws -> Question? {
        try await Question.find(questionId, on: database)
    }

    /// Retrieves a question by code
    /// - Parameter code: The unique code of the question to retrieve
    /// - Returns: The question, or nil if not found
    public func getQuestionByCode(code: String) async throws -> Question? {
        try await Question.query(on: database)
            .filter(\.$code == code)
            .first()
    }

    /// Creates a new question
    /// - Parameters:
    ///   - prompt: The question text displayed to users
    ///   - questionType: The type of input control for the question
    ///   - code: A unique code identifier for referencing the question
    ///   - helpText: Optional additional help text displayed to users
    ///   - choices: JSON object of choices for select/radio/multi_select types
    /// - Returns: The created question
    /// - Throws: ValidationError if input is invalid or database errors
    public func createQuestion(
        prompt: String,
        questionType: Question.QuestionType,
        code: String,
        helpText: String? = nil,
        choices: Question.Choices = Question.Choices([])
    ) async throws -> Question {
        // Validate input
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedPrompt.isEmpty else {
            throw ValidationError("Question prompt cannot be empty")
        }

        guard !trimmedCode.isEmpty else {
            throw ValidationError("Question code cannot be empty")
        }

        // Check if code is unique
        if try await getQuestionByCode(code: trimmedCode) != nil {
            throw ValidationError("Question code '\(trimmedCode)' already exists")
        }

        let question = Question(
            prompt: trimmedPrompt,
            questionType: questionType,
            code: trimmedCode,
            helpText: helpText?.trimmingCharacters(in: .whitespacesAndNewlines),
            choices: choices
        )

        try await question.save(on: database)
        return question
    }

    /// Updates a question
    /// - Parameters:
    ///   - questionId: The UUID of the question to update
    ///   - prompt: The question text displayed to users
    ///   - questionType: The type of input control for the question
    ///   - code: A unique code identifier for referencing the question
    ///   - helpText: Optional additional help text displayed to users
    ///   - choices: JSON object of choices for select/radio/multi_select types
    /// - Returns: The updated question
    /// - Throws: ValidationError if question not found or input is invalid
    public func updateQuestion(
        questionId: UUID,
        prompt: String,
        questionType: Question.QuestionType,
        code: String,
        helpText: String? = nil,
        choices: Question.Choices = Question.Choices([])
    ) async throws -> Question {
        guard let question = try await Question.find(questionId, on: database) else {
            throw ValidationError("Question not found")
        }

        // Validate input
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedPrompt.isEmpty else {
            throw ValidationError("Question prompt cannot be empty")
        }

        guard !trimmedCode.isEmpty else {
            throw ValidationError("Question code cannot be empty")
        }

        // Check if code is unique (unless it's the same as current)
        if trimmedCode != question.code {
            if try await getQuestionByCode(code: trimmedCode) != nil {
                throw ValidationError("Question code '\(trimmedCode)' already exists")
            }
        }

        question.prompt = trimmedPrompt
        question.questionType = questionType
        question.code = trimmedCode
        question.helpText = helpText?.trimmingCharacters(in: .whitespacesAndNewlines)
        question.choices = choices

        try await question.save(on: database)
        return question
    }

    /// Deletes a question
    /// - Parameter questionId: The UUID of the question to delete
    /// - Throws: ValidationError if the question is not found
    public func deleteQuestion(questionId: UUID) async throws {
        guard let question = try await Question.find(questionId, on: database) else {
            throw ValidationError("Question not found")
        }

        try await question.delete(on: database)
    }

    /// Searches questions by prompt or code
    /// - Parameters:
    ///   - searchTerm: The search term to match against question prompt or code
    ///   - limit: Maximum number of results to return (default 50)
    ///   - offset: Number of results to skip (default 0)
    /// - Returns: Array of questions matching the search
    public func searchQuestions(
        searchTerm: String = "",
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [Question] {
        let trimmedSearchTerm = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedSearchTerm.isEmpty {
            return try await listQuestions(limit: limit, offset: offset)
        }

        return try await Question.query(on: database)
            .group(.or) { or in
                or.filter(\.$prompt ~~ "%\(trimmedSearchTerm)%")
                or.filter(\.$code ~~ "%\(trimmedSearchTerm)%")
            }
            .limit(limit)
            .offset(offset)
            .sort(\.$code, .ascending)
            .all()
    }

    /// Lists questions by type
    /// - Parameters:
    ///   - questionType: The type of questions to filter by
    ///   - limit: Maximum number of results to return (default 50)
    ///   - offset: Number of results to skip (default 0)
    /// - Returns: Array of questions of the specified type
    public func listQuestionsByType(
        questionType: Question.QuestionType,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [Question] {
        try await Question.query(on: database)
            .filter(\.$questionType == questionType)
            .limit(limit)
            .offset(offset)
            .sort(\.$code, .ascending)
            .all()
    }

    /// Counts total questions matching search criteria
    /// - Parameter searchTerm: The search term to match against question prompt or code
    /// - Returns: Total count of questions matching the criteria
    public func countQuestions(searchTerm: String = "") async throws -> Int {
        let trimmedSearchTerm = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedSearchTerm.isEmpty {
            return try await Question.query(on: database).count()
        }

        return try await Question.query(on: database)
            .group(.or) { or in
                or.filter(\.$prompt ~~ "%\(trimmedSearchTerm)%")
                or.filter(\.$code ~~ "%\(trimmedSearchTerm)%")
            }
            .count()
    }
}
