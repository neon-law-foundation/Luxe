import Fluent
import Foundation
import Vapor

/// Represents a legal entity in the directory
public final class Entity: Model, @unchecked Sendable {
    public static let schema = "entities"
    public static let space = "directory"

    @ID(custom: .id, generatedBy: .database)
    public var id: UUID?

    @Field(key: "name")
    public var name: String

    @Parent(key: "legal_entity_type_id")
    public var legalEntityType: EntityType

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(id: UUID? = nil, name: String, legalEntityTypeID: EntityType.IDValue) {
        self.id = id
        self.name = name
        self.$legalEntityType.id = legalEntityTypeID
    }
}

extension Entity: Content {}
