import Fluent
import Foundation
import Vapor

/// Individual answers to questions provided by users, linked to entities and optionally assigned notations.
///
/// This model stores user responses to specific questions, tracking who provided the answer
/// and linking to relevant entities and optional document attachments.
public final class Answer: Model, @unchecked Sendable {
    public static let schema = "answers"
    public static let space = "matters"

    @ID(custom: .id, generatedBy: .database)
    public var id: UUID?

    @OptionalParent(key: "blob_id")
    public var blob: Blob?

    @Parent(key: "answerer_id")
    public var answerer: Person

    @Parent(key: "question_id")
    public var question: Question

    @Parent(key: "entity_id")
    public var entity: Entity

    @OptionalParent(key: "assigned_notation_id")
    public var assignedNotation: AssignedNotation?

    @Field(key: "response")
    public var response: Response

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    /// Creates a new Answer with the specified properties.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the answer. If nil, a UUID will be generated.
    ///   - blobID: Optional foreign key reference to a document blob associated with this answer.
    ///   - answererID: Foreign key reference to the person who provided this answer.
    ///   - questionID: Foreign key reference to the question being answered.
    ///   - entityID: Foreign key reference to the entity this answer relates to.
    ///   - assignedNotationID: Optional foreign key reference to the assigned notation this answer belongs to.
    ///   - response: JSON object containing the structured answer data.
    public init(
        id: UUID? = nil,
        blobID: UUID? = nil,
        answererID: UUID,
        questionID: UUID,
        entityID: UUID,
        assignedNotationID: UUID? = nil,
        response: Response = Response(rawValue: "{}")
    ) {
        self.id = id
        self.$blob.id = blobID
        self.$answerer.id = answererID
        self.$question.id = questionID
        self.$entity.id = entityID
        self.$assignedNotation.id = assignedNotationID
        self.response = response
    }
}

extension Answer: Content {}

// MARK: - Response Type

extension Answer {
    /// JSON object containing the structured answer data.
    public struct Response: Codable, Equatable, Sendable {
        public let rawValue: String

        public init(rawValue: String = "{}") {
            self.rawValue = rawValue
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            self.rawValue = try container.decode(String.self)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }

        public static func == (lhs: Response, rhs: Response) -> Bool {
            lhs.rawValue == rhs.rawValue
        }
    }
}
