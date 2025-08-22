import Fluent
import Vapor

public final class Credential: Model, @unchecked Sendable {
    public static let schema = "credentials"
    public static let space = "legal"

    @ID(custom: .id, generatedBy: .database)
    public var id: UUID?

    @Parent(key: "person_id")
    public var person: Person

    @Parent(key: "jurisdiction_id")
    public var jurisdiction: LegalJurisdiction

    @Field(key: "license_number")
    public var licenseNumber: String

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        personID: UUID,
        jurisdictionID: UUID,
        licenseNumber: String
    ) {
        self.id = id
        self.$person.id = personID
        self.$jurisdiction.id = jurisdictionID
        self.licenseNumber = licenseNumber
    }
}

extension Credential: Content {}
