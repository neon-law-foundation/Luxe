import Fluent
import Foundation
import JSONSchema
import Vapor

/// A collection of documents, questionnaires, and workflows.
///
/// Notations define reusable templates for various legal and organizational processes,
/// such as Secretary of State filings or 83(b) elections.
public final class Notation: Model, @unchecked Sendable {
    public static let schema = "notations"
    public static let space = "standards"

    @ID(custom: .id, generatedBy: .database)
    public var id: UUID?

    @Field(key: "uid")
    public var uid: String

    @Field(key: "title")
    public var title: String

    @OptionalField(key: "description")
    public var description: String?

    @Field(key: "flow")
    public var flow: FlowData

    @Field(key: "code")
    public var code: String

    @OptionalField(key: "document_url")
    public var documentUrl: String?

    @OptionalField(key: "document_mappings")
    public var documentMappings: DocumentMappings?

    @Field(key: "alignment")
    public var alignment: AlignmentData

    @OptionalField(key: "respondent_type")
    public var respondentType: RespondentType?

    @OptionalField(key: "document_text")
    public var documentText: String?

    @OptionalField(key: "document_type")
    public var documentType: String?

    @OptionalField(key: "repository")
    public var repository: String?

    @OptionalField(key: "commit_sha")
    public var commitSha: String?

    @Field(key: "published")
    public var published: Bool

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    // MARK: - Relationships

    @Siblings(through: NotationQuestion.self, from: \.$notation, to: \.$question)
    public var questions: [Question]

    public init() {}

    /// Creates a new Notation with the specified properties.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the notation. If nil, a UUID will be generated.
    ///   - uid: User-defined unique identifier for the notation.
    ///   - title: Title of the notation.
    ///   - description: Detailed description of the notation.
    ///   - flow: How users are presented with questions. Must adhere to @question_map_schema.
    ///   - code: Case-insensitive unique code identifier for the notation.
    ///   - documentUrl: URL reference to the associated document.
    ///   - documentMappings: PDF field placement coordinates.
    ///   - alignment: How staff review questionnaires and provide answers.
    ///   - respondentType: Whether notation is for whole org or org and user.
    ///   - documentText: Full text content of the associated document.
    ///   - documentType: Type classification of the associated document.
    ///   - repository: Neon Law GitHub repository where the notation is stored.
    ///   - commitSha: Latest main branch commit SHA of most recent notation changes.
    ///   - published: If true, flow and alignment are empty. Used for public notations.
    public init(
        id: UUID? = nil,
        uid: String,
        title: String,
        description: String? = nil,
        flow: FlowData = FlowData(rawValue: "{}"),
        code: String,
        documentUrl: String? = nil,
        documentMappings: DocumentMappings? = nil,
        alignment: AlignmentData = AlignmentData(rawValue: "{}"),
        respondentType: RespondentType? = nil,
        documentText: String? = nil,
        documentType: String? = nil,
        repository: String? = nil,
        commitSha: String? = nil,
        published: Bool = false
    ) {
        self.id = id
        self.uid = uid
        self.title = title
        self.description = description
        self.flow = flow
        self.code = code
        self.documentUrl = documentUrl
        self.documentMappings = documentMappings
        self.alignment = alignment
        self.respondentType = respondentType
        self.documentText = documentText
        self.documentType = documentType
        self.repository = repository
        self.commitSha = commitSha
        self.published = published
    }
}

extension Notation: Content {}

// MARK: - Model Lifecycle Hooks

extension Notation {
    func willCreate(on database: Database) async throws {
        try await validateSchemas()
    }

    func willUpdate(on database: Database) async throws {
        try await validateSchemas()
    }

    private func validateSchemas() async throws {
        // Validate the flow JSON schema
        let flowValidationResult = try flow.validateAgainstSchema()
        if !flowValidationResult.isValid {
            throw Abort(
                .badRequest,
                reason: "Invalid flow format: \(flowValidationResult.errors.joined(separator: ", "))"
            )
        }

        // Validate the alignment JSON schema
        let alignmentValidationResult = try alignment.validateAgainstSchema()
        if !alignmentValidationResult.isValid {
            throw Abort(
                .badRequest,
                reason: "Invalid alignment format: \(alignmentValidationResult.errors.joined(separator: ", "))"
            )
        }

        // Validate the document mappings JSON schema if present
        if let documentMappings = documentMappings {
            let documentMappingsValidationResult = try documentMappings.validateAgainstSchema()
            if !documentMappingsValidationResult.isValid {
                throw Abort(
                    .badRequest,
                    reason:
                        "Invalid document mappings format: \(documentMappingsValidationResult.errors.joined(separator: ", "))"
                )
            }
        }
    }
}

// MARK: - Respondent Type Enum

extension Notation {
    /// Determines if notation is for whole org or org and user.
    public enum RespondentType: String, Codable, CaseIterable, Sendable {
        /// For whole organization (e.g., Secretary of State filing)
        case org = "org"
        /// For organization and user (e.g., 83(b) election)
        case orgAndUser = "org_and_user"
    }
}

// MARK: - Flow Data Type

extension Notation {
    /// How users are presented with questions. Must adhere to @question_map_schema.
    public struct FlowData: Codable, Equatable, Sendable {
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

        public static func == (lhs: FlowData, rhs: FlowData) -> Bool {
            lhs.rawValue == rhs.rawValue
        }

        /// Validates the JSON against the question map schema
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

                guard let beginObject = jsonObject["BEGIN"] as? [String: Any] else {
                    return ValidationResult(isValid: false, errors: ["Missing or invalid 'BEGIN' object"])
                }

                var errors: [String] = []
                let validPattern = try NSRegularExpression(pattern: "^(\\w*|END|ERROR)$")

                for (key, value) in beginObject {
                    if key.hasPrefix("_") {
                        guard let stringValue = value as? String else {
                            errors.append("BEGIN.\(key): value must be a string")
                            continue
                        }

                        let range = NSRange(location: 0, length: stringValue.utf16.count)
                        if validPattern.firstMatch(in: stringValue, options: [], range: range) == nil {
                            errors.append(
                                "BEGIN.\(key): value '\(stringValue)' does not match pattern '^(\\w*|END|ERROR)$'"
                            )
                        }
                    }
                }

                return ValidationResult(isValid: errors.isEmpty, errors: errors)
            } catch {
                return ValidationResult(isValid: false, errors: ["Invalid JSON: \(error.localizedDescription)"])
            }
        }
    }
}

// MARK: - Alignment Data Type

extension Notation {
    /// How staff review questionnaires and provide answers. Must adhere to @question_map_schema.
    public struct AlignmentData: Codable, Equatable, Sendable {
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

        public static func == (lhs: AlignmentData, rhs: AlignmentData) -> Bool {
            lhs.rawValue == rhs.rawValue
        }

        /// Validates the JSON against the question map schema
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

                guard let beginObject = jsonObject["BEGIN"] as? [String: Any] else {
                    return ValidationResult(isValid: false, errors: ["Missing or invalid 'BEGIN' object"])
                }

                var errors: [String] = []
                let validPattern = try NSRegularExpression(pattern: "^(\\w*|END|ERROR)$")

                for (key, value) in beginObject {
                    if key.hasPrefix("_") {
                        guard let stringValue = value as? String else {
                            errors.append("BEGIN.\(key): value must be a string")
                            continue
                        }

                        let range = NSRange(location: 0, length: stringValue.utf16.count)
                        if validPattern.firstMatch(in: stringValue, options: [], range: range) == nil {
                            errors.append(
                                "BEGIN.\(key): value '\(stringValue)' does not match pattern '^(\\w*|END|ERROR)$'"
                            )
                        }
                    }
                }

                return ValidationResult(isValid: errors.isEmpty, errors: errors)
            } catch {
                return ValidationResult(isValid: false, errors: ["Invalid JSON: \(error.localizedDescription)"])
            }
        }
    }
}

// MARK: - Document Mappings Type

extension Notation {
    /// PDF field placement coordinates.
    public struct DocumentMappings: Codable, Equatable, Sendable {
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

        public static func == (lhs: DocumentMappings, rhs: DocumentMappings) -> Bool {
            lhs.rawValue == rhs.rawValue
        }

        /// Validates the JSON against the document mappings schema
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

                var errors: [String] = []
                let requiredFields = ["page", "upper_right", "lower_right", "upper_left", "lower_left"]

                for (fieldName, fieldValue) in jsonObject {
                    guard let fieldObject = fieldValue as? [String: Any] else {
                        errors.append("\(fieldName): must be an object")
                        continue
                    }

                    // Check required fields
                    for requiredField in requiredFields {
                        guard fieldObject[requiredField] != nil else {
                            errors.append("\(fieldName): missing required field '\(requiredField)'")
                            continue
                        }

                        if requiredField == "page" {
                            guard fieldObject[requiredField] is Int else {
                                errors.append("\(fieldName).page: must be an integer")
                                continue
                            }
                        } else {
                            guard let coordinateArray = fieldObject[requiredField] as? [Any] else {
                                errors.append("\(fieldName).\(requiredField): must be an array")
                                continue
                            }

                            if coordinateArray.count != 2 {
                                errors.append("\(fieldName).\(requiredField): must have exactly 2 items")
                                continue
                            }

                            for (index, coordinate) in coordinateArray.enumerated() {
                                if !(coordinate is Double || coordinate is Int) {
                                    errors.append("\(fieldName).\(requiredField)[\(index)]: must be a number")
                                }
                            }
                        }
                    }
                }

                return ValidationResult(isValid: errors.isEmpty, errors: errors)
            } catch {
                return ValidationResult(isValid: false, errors: ["Invalid JSON: \(error.localizedDescription)"])
            }
        }
    }
}
