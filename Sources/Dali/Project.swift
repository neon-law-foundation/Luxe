import Fluent
import Foundation
import Vapor

/// Projects that group assigned notations together.
///
/// This model represents projects in the matters schema, each with a unique codename
/// and containing multiple assigned notations. Projects serve as containers to organize
/// related legal work and notation assignments.
public final class Project: Model, @unchecked Sendable {
    public static let schema = "projects"
    public static let space = "matters"

    @ID(custom: .id, generatedBy: .database)
    public var id: UUID?

    @Field(key: "codename")
    public var codename: String

    @Children(for: \.$project)
    public var assignedNotations: [AssignedNotation]

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    /// Creates a new Project with the specified properties.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the project. If nil, a UUID will be generated.
    ///   - codename: Unique codename for the project.
    public init(
        id: UUID? = nil,
        codename: String
    ) {
        self.id = id
        self.codename = codename
    }
}

extension Project: Content {}
