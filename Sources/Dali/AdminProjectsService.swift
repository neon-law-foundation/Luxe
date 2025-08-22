import Fluent
import FluentPostgresDriver
import Foundation
import PostgresNIO
import Vapor

/// Service for admin-only project management operations
public struct AdminProjectsService: Sendable {

    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    /// Lists all projects
    /// - Parameter limit: Maximum number of results to return (default 100)
    /// - Parameter offset: Number of results to skip (default 0)
    /// - Returns: Array of projects
    public func listProjects(limit: Int = 100, offset: Int = 0) async throws -> [Project] {
        try await Project.query(on: database)
            .limit(limit)
            .offset(offset)
            .sort(\.$createdAt, .descending)
            .all()
    }

    /// Retrieves a project by ID
    /// - Parameter projectId: The UUID of the project to retrieve
    /// - Returns: The project, or nil if not found
    public func getProject(projectId: UUID) async throws -> Project? {
        try await Project.find(projectId, on: database)
    }

    /// Creates a new project
    /// - Parameters:
    ///   - codename: The project's codename
    /// - Returns: The created project
    /// - Throws: ValidationError if input is invalid or database errors
    public func createProject(codename: String) async throws -> Project {
        // Validate input
        let trimmedCodename = codename.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedCodename.isEmpty else {
            throw ValidationError("Codename cannot be empty")
        }

        let project = Project()
        project.codename = trimmedCodename

        try await project.save(on: database)
        return project
    }

    /// Updates a project
    /// - Parameters:
    ///   - projectId: The UUID of the project to update
    ///   - codename: The new codename
    /// - Returns: The updated project
    /// - Throws: ValidationError if project not found or input is invalid
    public func updateProject(projectId: UUID, codename: String) async throws -> Project {
        guard let project = try await Project.find(projectId, on: database) else {
            throw ValidationError("Project not found")
        }

        // Validate input
        let trimmedCodename = codename.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedCodename.isEmpty else {
            throw ValidationError("Codename cannot be empty")
        }

        project.codename = trimmedCodename

        try await project.save(on: database)
        return project
    }

    /// Deletes a project
    /// - Parameter projectId: The UUID of the project to delete
    /// - Throws: ValidationError if the project is not found
    public func deleteProject(projectId: UUID) async throws {
        guard let project = try await Project.find(projectId, on: database) else {
            throw ValidationError("Project not found")
        }

        try await project.delete(on: database)
    }
}
