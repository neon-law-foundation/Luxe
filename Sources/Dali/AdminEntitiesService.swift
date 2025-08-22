import Fluent
import FluentPostgresDriver
import Foundation
import PostgresNIO
import Vapor

/// Service for admin-only entity management operations
public struct AdminEntitiesService: Sendable {

    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    /// Lists all entities
    /// - Parameter limit: Maximum number of results to return (default 100)
    /// - Parameter offset: Number of results to skip (default 0)
    /// - Returns: Array of entities
    public func listEntities(limit: Int = 100, offset: Int = 0) async throws -> [Entity] {
        try await Entity.query(on: database)
            .limit(limit)
            .offset(offset)
            .sort(\.$createdAt, .descending)
            .all()
    }

    /// Retrieves an entity by ID
    /// - Parameter entityId: The UUID of the entity to retrieve
    /// - Returns: The entity, or nil if not found
    public func getEntity(entityId: UUID) async throws -> Entity? {
        try await Entity.find(entityId, on: database)
    }

    /// Lists all entity types with their legal jurisdictions for dropdown menus
    /// - Returns: Array of entity types with jurisdictions loaded
    public func listEntityTypes() async throws -> [EntityType] {
        try await EntityType.query(on: database)
            .with(\.$legalJurisdiction)
            .all()
    }

    /// Retrieves an entity by ID with its type loaded
    /// - Parameter entityId: The UUID of the entity to retrieve
    /// - Returns: The entity with type loaded, or nil if not found
    public func getEntityWithType(entityId: UUID) async throws -> Entity? {
        try await Entity.find(entityId, on: database)
    }

    /// Creates a new entity
    /// - Parameters:
    ///   - name: The entity's name
    ///   - legalEntityTypeId: The UUID of the legal entity type
    /// - Returns: The created entity
    /// - Throws: ValidationError if input is invalid or database errors
    public func createEntity(name: String, legalEntityTypeId: UUID) async throws -> Entity {
        // Validate input
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            throw ValidationError("Entity name cannot be empty")
        }

        let entity = Entity(name: trimmedName, legalEntityTypeID: legalEntityTypeId)
        try await entity.save(on: database)
        return entity
    }

    /// Updates an entity
    /// - Parameters:
    ///   - entityId: The UUID of the entity to update
    ///   - name: The new name
    ///   - legalEntityTypeId: The new legal entity type ID
    /// - Returns: The updated entity
    /// - Throws: ValidationError if entity not found or input is invalid
    public func updateEntity(entityId: UUID, name: String, legalEntityTypeId: UUID) async throws -> Entity {
        guard let entity = try await Entity.find(entityId, on: database) else {
            throw ValidationError("Entity not found")
        }

        // Validate input
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            throw ValidationError("Entity name cannot be empty")
        }

        entity.name = trimmedName
        entity.$legalEntityType.id = legalEntityTypeId

        try await entity.save(on: database)
        return entity
    }

    /// Deletes an entity
    /// - Parameter entityId: The UUID of the entity to delete
    /// - Throws: ValidationError if the entity is not found
    public func deleteEntity(entityId: UUID) async throws {
        guard let entity = try await Entity.find(entityId, on: database) else {
            throw ValidationError("Entity not found")
        }

        try await entity.delete(on: database)
    }
}
