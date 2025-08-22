import Fluent
import Foundation
import Vapor

/// Type of legal jurisdiction
public enum JurisdictionType: String, Codable, CaseIterable, Content {
    case city = "city"
    case county = "county"
    case state = "state"
    case country = "country"
}

/// Represents a legal jurisdiction (state, country, etc.)
public final class LegalJurisdiction: Model, @unchecked Sendable {
    public static let schema = "jurisdictions"
    public static let space = "legal"

    @ID(custom: .id, generatedBy: .database)
    public var id: UUID?

    @Field(key: "name")
    public var name: String

    @Field(key: "code")
    public var code: String

    @Enum(key: "jurisdiction_type")
    public var jurisdictionType: JurisdictionType

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(id: UUID? = nil, name: String, code: String, jurisdictionType: JurisdictionType = .state) {
        self.id = id
        self.name = name
        self.code = code
        self.jurisdictionType = jurisdictionType
    }
}

extension LegalJurisdiction: Content {}
