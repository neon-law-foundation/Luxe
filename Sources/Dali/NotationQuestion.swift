import Fluent
import Foundation
import Vapor

/// Join table linking notations to their associated questions.
///
/// This model represents the many-to-many relationship between notations and questions,
/// allowing questions to be reused across multiple notations.
public final class NotationQuestion: Model, @unchecked Sendable {
    public static let schema = "notations_questions"
    public static let space = "standards"

    @ID(custom: .id, generatedBy: .database)
    public var id: UUID?

    @Parent(key: "notation_id")
    public var notation: Notation

    @Parent(key: "question_id")
    public var question: Question

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    /// Creates a new NotationQuestion relationship.
    ///
    /// - Parameters:
    ///   - notationID: The ID of the notation.
    ///   - questionID: The ID of the question.
    public init(notationID: UUID, questionID: UUID) {
        self.$notation.id = notationID
        self.$question.id = questionID
    }
}

extension NotationQuestion: Content {}
