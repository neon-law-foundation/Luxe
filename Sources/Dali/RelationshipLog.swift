import Fluent
import Foundation
import Vapor

/// Relationship logs for legal matters linking projects with legal credentials.
///
/// This model represents relationship logs in the matters schema, tracking
/// relationship information for legal matters.
public final class RelationshipLog: Model, @unchecked Sendable {
    public static let schema = "relationship_logs"
    public static let space = "matters"

    @ID(custom: .id, generatedBy: .database)
    public var id: UUID?

    @Parent(key: "project_id")
    public var project: Project

    @Parent(key: "credential_id")
    public var credential: Credential

    @Field(key: "body")
    public var body: String

    @Field(key: "relationships")
    public var relationships: RelationshipsData

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    /// Creates a new RelationshipLog with the specified properties.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the relationship log. If nil, a UUID will be generated.
    ///   - projectID: The ID of the project this relationship log belongs to.
    ///   - credentialID: The ID of the legal credential creating this relationship log.
    ///   - body: The text content of the relationship log entry.
    ///   - relationships: JSONB field containing relationship data (entities, people, etc.).
    public init(
        id: UUID? = nil,
        projectID: UUID,
        credentialID: UUID,
        body: String,
        relationships: RelationshipsData = RelationshipsData()
    ) {
        self.id = id
        self.$project.id = projectID
        self.$credential.id = credentialID
        self.body = body
        self.relationships = relationships
    }
}

/// Simple wrapper for JSONB data that works with Vapor 4's automatic JSON handling.
///
/// In Vapor 4, any Codable type can be stored directly in JSONB fields.
/// This wrapper provides a simple interface for storing arbitrary JSON data.
public struct RelationshipsData: Codable, Equatable, Sendable {
    public let data: [String: JSONValue]

    public init() {
        self.data = [:]
    }

    public init(rawValue: [String: Any]) {
        var convertedData: [String: JSONValue] = [:]
        for (key, value) in rawValue {
            convertedData[key] = JSONValue.from(value)
        }
        self.data = convertedData
    }

    /// Get the stored data as a dictionary
    public var rawValue: [String: Any] {
        data.mapValues { $0.anyValue }
    }

    public static func == (lhs: RelationshipsData, rhs: RelationshipsData) -> Bool {
        lhs.data == rhs.data
    }
}

/// JSON value type that can hold any JSON-compatible value
public enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    public var anyValue: Any {
        switch self {
        case .string(let value): return value
        case .number(let value): return value
        case .bool(let value): return value
        case .null: return NSNull()
        case .array(let value): return value.map { $0.anyValue }
        case .object(let value): return value.mapValues { $0.anyValue }
        }
    }

    public static func from(_ value: Any) -> JSONValue {
        switch value {
        case let string as String:
            return .string(string)
        case let number as Int:
            return .number(Double(number))
        case let number as Double:
            return .number(number)
        case let number as Float:
            return .number(Double(number))
        case let bool as Bool:
            return .bool(bool)
        case is NSNull:
            return .null
        case let array as [Any]:
            return .array(array.map { JSONValue.from($0) })
        case let dict as [String: Any]:
            return .object(dict.mapValues { JSONValue.from($0) })
        default:
            return .string(String(describing: value))
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.typeMismatch(
                JSONValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid JSON")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let string):
            try container.encode(string)
        case .number(let number):
            try container.encode(number)
        case .bool(let bool):
            try container.encode(bool)
        case .null:
            try container.encodeNil()
        case .array(let array):
            try container.encode(array)
        case .object(let object):
            try container.encode(object)
        }
    }
}

extension RelationshipLog: Content {}
