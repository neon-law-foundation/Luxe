import Fluent
import Foundation
import JSONSchema
import Vapor

/// Tracks assigned notations to entities with their completion state and answers.
///
/// This model represents instances of notations that have been assigned to specific entities
/// for completion, tracking their progress through various states.
public final class AssignedNotation: Model, @unchecked Sendable {
    public static let schema = "assigned_notations"
    public static let space = "matters"

    @ID(custom: .id, generatedBy: .database)
    public var id: UUID?

    @Parent(key: "entity_id")
    public var entity: Entity

    @Field(key: "state")
    public var state: State

    @Field(key: "change_language")
    public var changeLanguage: ChangeLanguage

    @OptionalField(key: "due_at")
    public var dueAt: Date?

    @OptionalParent(key: "person_id")
    public var person: Person?

    @Field(key: "answers")
    public var answers: Answers

    @Parent(key: "notation_id")
    public var notation: Notation

    @Parent(key: "project_id")
    public var project: Project

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    /// Creates a new AssignedNotation with the specified properties.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the assigned notation. If nil, a UUID will be generated.
    ///   - entityID: Foreign key reference to the entity this notation is assigned to.
    ///   - state: Current state of the notation.
    ///   - changeLanguage: JSON object containing any change language or modifications.
    ///   - dueAt: Optional timestamp indicating when this notation assignment is due.
    ///   - personID: Optional foreign key reference to the person assigned to complete this notation.
    ///   - answers: JSON object containing the answers provided for this notation.
    ///   - notationID: Foreign key reference to the notation template being used.
    ///   - projectID: Foreign key reference to the project this notation assignment belongs to.
    public init(
        id: UUID? = nil,
        entityID: UUID,
        state: State = .awaitingFlow,
        changeLanguage: ChangeLanguage = ChangeLanguage(rawValue: "{}"),
        dueAt: Date? = nil,
        personID: UUID? = nil,
        answers: Answers = Answers(rawValue: "{}"),
        notationID: UUID,
        projectID: UUID
    ) {
        self.id = id
        self.$entity.id = entityID
        self.state = state
        self.changeLanguage = changeLanguage
        self.dueAt = dueAt
        self.$person.id = personID
        self.answers = answers
        self.$notation.id = notationID
        self.$project.id = projectID
    }
}

extension AssignedNotation: Content {}

// MARK: - Model Lifecycle Hooks

extension AssignedNotation {
    func willCreate(on database: Database) async throws {
        try await validateSchemas()
    }

    func willUpdate(on database: Database) async throws {
        try await validateSchemas()
    }

    private func validateSchemas() async throws {
        // Validate the changelog JSON schema
        let validationResult = try changeLanguage.validateAgainstSchema()
        if !validationResult.isValid {
            throw Abort(
                .badRequest,
                reason: "Invalid changelog format: \(validationResult.errors.joined(separator: ", "))"
            )
        }
    }
}

// MARK: - State Enum

extension AssignedNotation {
    /// Current state of the notation assignment.
    public enum State: String, Codable, CaseIterable, Sendable {
        /// Awaiting user to complete the flow
        case awaitingFlow = "awaiting_flow"
        /// Awaiting staff review
        case awaitingReview = "awaiting_review"
        /// Awaiting alignment process
        case awaitingAlignment = "awaiting_alignment"
        /// Completed successfully
        case complete = "complete"
        /// Completed with errors
        case completeWithError = "complete_with_error"
    }
}

// MARK: - Change Language Type

extension AssignedNotation {
    /// JSON object containing any change language or modifications to the notation.
    public struct ChangeLanguage: Codable, Equatable, Sendable {
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

        public static func == (lhs: ChangeLanguage, rhs: ChangeLanguage) -> Bool {
            lhs.rawValue == rhs.rawValue
        }

        /// Validates the JSON against the changelog schema
        public func validateAgainstSchema() throws -> ValidationResult {
            // For now, implement a basic JSON structure validation
            // TODO: Use proper JSON schema validation once the library API is clarified

            guard let jsonData = rawValue.data(using: .utf8) else {
                return ValidationResult(isValid: false, errors: ["Invalid JSON string"])
            }

            do {
                guard let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                    return ValidationResult(isValid: false, errors: ["JSON must be an object"])
                }

                guard let changes = jsonObject["changes"] as? [[String: Any]] else {
                    return ValidationResult(isValid: false, errors: ["Missing or invalid 'changes' array"])
                }

                var errors: [String] = []
                let validActions = ["created", "updated", "reviewed", "approved", "rejected", "deleted"]

                for (index, change) in changes.enumerated() {
                    // Check required fields
                    if change["action"] == nil {
                        errors.append("changes[\(index)]: missing required field 'action'")
                    } else if let action = change["action"] as? String, !validActions.contains(action) {
                        errors.append("changes[\(index)]: invalid action '\(action)'")
                    }

                    if change["timestamp"] == nil {
                        errors.append("changes[\(index)]: missing required field 'timestamp'")
                    }

                    if change["user_id"] == nil {
                        errors.append("changes[\(index)]: missing required field 'user_id'")
                    }
                }

                return ValidationResult(isValid: errors.isEmpty, errors: errors)
            } catch {
                return ValidationResult(isValid: false, errors: ["Invalid JSON: \(error.localizedDescription)"])
            }
        }
    }
}

// MARK: - Answers Type

extension AssignedNotation {
    /// JSON object containing the answers provided for this notation.
    public struct Answers: Codable, Equatable, Sendable {
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

        public static func == (lhs: Answers, rhs: Answers) -> Bool {
            lhs.rawValue == rhs.rawValue
        }
    }
}

// MARK: - Validation Result

/// Result of JSON schema validation
public struct ValidationResult {
    public let isValid: Bool
    public let errors: [String]

    public init(isValid: Bool, errors: [String]) {
        self.isValid = isValid
        self.errors = errors
    }
}
