import Fluent
import Foundation
import Vapor

/// Represents a type of legal entity
public final class EntityType: Model, @unchecked Sendable {
    public static let schema = "entity_types"
    public static let space = "legal"

    @ID(custom: .id, generatedBy: .database)
    public var id: UUID?

    @Parent(key: "legal_jurisdiction_id")
    public var legalJurisdiction: LegalJurisdiction

    @Field(key: "name")
    public var name: String

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(id: UUID? = nil, legalJurisdictionID: LegalJurisdiction.IDValue, name: String) {
        self.id = id
        self.$legalJurisdiction.id = legalJurisdictionID
        self.name = name
    }
}

extension EntityType: Content {}
