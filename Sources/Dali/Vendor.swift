import Fluent
import Foundation
import Vapor

/// Represents a vendor in the accounting schema
public final class Vendor: Model, @unchecked Sendable {
    public static let schema = "vendors"
    public static let space = "accounting"

    @ID(custom: .id, generatedBy: .database)
    public var id: UUID?

    @Field(key: "name")
    public var name: String

    @OptionalParent(key: "entity_id")
    public var entity: Entity?

    @OptionalParent(key: "person_id")
    public var person: Person?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(id: UUID? = nil, name: String, entityID: Entity.IDValue? = nil, personID: Person.IDValue? = nil) {
        self.id = id
        self.name = name
        if let entityID = entityID {
            self.$entity.id = entityID
        }
        if let personID = personID {
            self.$person.id = personID
        }
    }
}

extension Vendor: Content {}
