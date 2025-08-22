import Foundation
import PostgresNIO

public struct ServiceCustomField: Codable, Sendable {
    public let id: UUID
    public let name: String
    public let fieldType: FieldType
    public let description: String?
    public let required: Bool
    public let options: [String]?
    public let position: Int
    public let createdBy: UUID
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        name: String,
        fieldType: FieldType,
        description: String?,
        required: Bool,
        options: [String]?,
        position: Int,
        createdBy: UUID,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.fieldType = fieldType
        self.description = description
        self.required = required
        self.options = options
        self.position = position
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public enum FieldType: String, Codable, Sendable, CaseIterable {
        case text = "text"
        case textarea = "textarea"
        case number = "number"
        case date = "date"
        case select = "select"
        case multiselect = "multiselect"
        case checkbox = "checkbox"
    }
}

extension ServiceCustomField: PostgresCodable {
    public static var postgresDataType: PostgresDataType {
        .jsonb
    }
}
