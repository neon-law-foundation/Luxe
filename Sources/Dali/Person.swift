import Fluent
import Foundation
import Vapor

/// Represents a person in the directory schema
public final class Person: Model, @unchecked Sendable {
    public static let schema = "people"
    public static let space = "directory"

    @ID(custom: .id, generatedBy: .database)
    public var id: UUID?

    @Field(key: "name")
    public var name: String

    @Field(key: "email")
    public var email: String

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(id: UUID? = nil, name: String, email: String) {
        self.id = id
        self.name = name
        self.email = email
    }
}

extension Person: Content {}
