import Fluent
import Foundation
import Vapor

/// Represents a share class in the equity schema.
///
/// Share classes define different types of shares that can be issued by an entity,
/// with each class having a unique priority level within the entity. The unique
/// compound index on entity_id and priority ensures no two share classes can have
/// the same priority within the same entity.
public final class ShareClass: Model, @unchecked Sendable {
    public static let schema = "share_classes"
    public static let space = "equity"

    @ID(custom: .id, generatedBy: .database)
    public var id: UUID?

    @Field(key: "name")
    public var name: String

    @Parent(key: "entity_id")
    public var entity: Entity

    @Field(key: "priority")
    public var priority: Int

    @OptionalField(key: "description")
    public var description: String?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(id: UUID? = nil, name: String, entityID: Entity.IDValue, priority: Int, description: String? = nil) {
        self.id = id
        self.name = name
        self.$entity.id = entityID
        self.priority = priority
        self.description = description
    }
}

extension ShareClass: Content {}
