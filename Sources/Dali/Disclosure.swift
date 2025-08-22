import Fluent
import Foundation
import Vapor

/// Join table between legal credentials and projects tracking disclosure periods.
///
/// This model represents disclosures in the matters schema, connecting legal credentials
/// to specific projects and tracking the time periods during which the disclosure
/// is active. Used for managing legal disclosure requirements and compliance.
public final class Disclosure: Model, @unchecked Sendable {
    public static let schema = "disclosures"
    public static let space = "matters"

    @ID(custom: .id, generatedBy: .database)
    public var id: UUID?

    @Parent(key: "credential_id")
    public var credential: Credential

    @Parent(key: "project_id")
    public var project: Project

    @Field(key: "disclosed_at")
    public var disclosedAt: Date

    @OptionalField(key: "end_disclosed_at")
    public var endDisclosedAt: Date?

    @Field(key: "active")
    public var active: Bool

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    /// Creates a new Disclosure with the specified properties.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the disclosure. If nil, a UUID will be generated.
    ///   - credentialID: The ID of the legal credential being disclosed.
    ///   - projectID: The ID of the project where the disclosure applies.
    ///   - disclosedAt: The date when the disclosure period begins.
    ///   - endDisclosedAt: The date when the disclosure period ends (optional).
    ///   - active: Boolean flag indicating if the disclosure is currently active.
    public init(
        id: UUID? = nil,
        credentialID: UUID,
        projectID: UUID,
        disclosedAt: Date,
        endDisclosedAt: Date? = nil,
        active: Bool = true
    ) {
        self.id = id
        self.$credential.id = credentialID
        self.$project.id = projectID
        self.disclosedAt = disclosedAt
        self.endDisclosedAt = endDisclosedAt
        self.active = active
    }
}

extension Disclosure: Content {}
