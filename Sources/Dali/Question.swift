import Fluent
import Foundation
import Vapor

/// A question template used in Sagebrush Standards forms and workflows.
///
/// Questions define the structure and behavior of form fields, including
/// their input types, validation rules, and display options.
public final class Question: Model, @unchecked Sendable {
    public static let schema = "questions"
    public static let space = "standards"

    @ID(custom: .id, generatedBy: .database)
    public var id: UUID?

    @Field(key: "prompt")
    public var prompt: String

    @Field(key: "question_type")
    public var questionType: QuestionType

    @Field(key: "code")
    public var code: String

    @Field(key: "help_text")
    public var helpText: String?

    @Field(key: "choices")
    public var choices: Choices

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {
        self.prompt = ""
        self.questionType = .string
        self.code = ""
        self.choices = Choices([])
    }

    /// Creates a new Question with the specified properties.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the question. If nil, a UUID will be generated.
    ///   - prompt: The question text displayed to users.
    ///   - questionType: The type of input control for the question.
    ///   - code: A unique code identifier for referencing the question.
    ///   - helpText: Optional additional help text displayed to users.
    ///   - choices: JSON object of choices for select/radio/multi_select types.
    public init(
        id: UUID? = nil,
        prompt: String,
        questionType: QuestionType,
        code: String,
        helpText: String? = nil,
        choices: Choices = Choices([])
    ) {
        self.id = id
        self.prompt = prompt
        self.questionType = questionType
        self.code = code
        self.helpText = helpText
        self.choices = choices
    }
}

extension Question: Content {}

// MARK: - Question Type Enum

extension Question {
    /// The type of input control for the question, matching the database enum constraint.
    public enum QuestionType: String, Codable, CaseIterable, Sendable {
        /// One line of text
        case string = "string"
        /// Multi-line text stored as Content Editable
        case text = "text"
        /// Date
        case date = "date"
        /// Date and time
        case datetime = "datetime"
        /// Number
        case number = "number"
        /// Yes or No
        case yesNo = "yes_no"
        /// Radio buttons for an XOR selection
        case radio = "radio"
        /// Select dropdown for a single selection
        case select = "select"
        /// Multi-select dropdown for multiple selections
        case multiSelect = "multi_select"
        /// Sensitive data like SSNs and EINs
        case secret = "secret"
        /// E-signature record in our database
        case signature = "signature"
        /// Notarization requiring an ID from Proof
        case notarization = "notarization"
        /// Phone number that we can verify by sending an OTP message to
        case phone = "phone"
        /// Email address that we can verify by sending an OTP message to
        case email = "email"
        /// Social Security Number, with a specific format
        case ssn = "ssn"
        /// Employer Identification Number, with a specific format
        case ein = "ein"
        /// File upload
        case file = "file"
        /// Directory.Person record
        case person = "person"
        /// Directory.Address record
        case address = "address"
        /// Shares.Issuance record
        case issuance = "issuance"
        /// Directory.Entity record
        case org = "org"
        /// Documents.Document record
        case document = "document"
        /// A registered agent record in our database
        case registeredAgent = "registered_agent"
    }
}

// MARK: - Choices Type

extension Question {
    /// JSON object of choices for select/radio/multi_select question types.
    public struct Choices: Codable, Equatable, Sendable {
        public let options: [String]

        public init(_ options: [String]) {
            self.options = options
        }
    }
}
