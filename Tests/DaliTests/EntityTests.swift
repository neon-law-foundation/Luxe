import Fluent
import FluentPostgresDriver
import Foundation
import Logging
import PostgresNIO
import ServiceLifecycle
import TestUtilities
import Testing
import Vapor

@testable import Dali
@testable import Palette

@Suite("Entity Tests", .serialized)
struct EntityTests {

    @Test("Entity has required fields")
    func entityHasRequiredFields() async throws {
        // Create a test entity
        let entityTypeId = UUID()
        let entity = Entity(name: "Test Company LLC", legalEntityTypeID: entityTypeId)

        // Verify the model has all required fields
        #expect(entity.name == "Test Company LLC")
        #expect(entity.$legalEntityType.id == entityTypeId)

        // ID should be nil before saving
        #expect(entity.id == nil)

        // Timestamps should be nil before saving
        #expect(entity.createdAt == nil)
        #expect(entity.updatedAt == nil)
    }

    @Test("Entity can be saved with valid entity type", .disabled("CI connection timeout issues"))
    func entityCanBeSavedWithValidEntityType() async throws {
        try await TestUtilities.withApp { app, database in
            // First verify the table exists with raw SQL
            let countResult = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT COUNT(*) as count FROM directory.entities")
                .first()

            #expect(countResult != nil)
            print("Database connection verified - directory.entities table accessible")

            // First get Nevada jurisdiction ID
            let nevadaResult = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT id FROM legal.jurisdictions WHERE code = 'NV'")
                .first()

            guard let nevada = nevadaResult,
                let nevadaJurisdictionId = try? nevada.decode(column: "id", as: UUID.self)
            else {
                Issue.record("Nevada jurisdiction not found")
                return
            }

            // Create Nevada LLC entity type if it doesn't exist
            let entityTypeId: UUID
            let existingResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    SELECT id FROM legal.entity_types
                    WHERE legal_jurisdiction_id = \(bind: nevadaJurisdictionId) AND name = 'LLC'
                    """
                )
                .first()

            if let existing = existingResult,
                let existingId = try? existing.decode(column: "id", as: UUID.self)
            {
                entityTypeId = existingId
            } else {
                // Create the entity type
                let insertResult = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        INSERT INTO legal.entity_types (legal_jurisdiction_id, name, created_at, updated_at)
                        VALUES (\(bind: nevadaJurisdictionId), 'LLC', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        RETURNING id
                        """
                    )
                    .first()

                guard let entityType = insertResult,
                    let newId = try? entityType.decode(column: "id", as: UUID.self)
                else {
                    Issue.record("Failed to create Nevada LLC entity type")
                    return
                }
                entityTypeId = newId
            }

            // Create a test entity with unique name
            let uniqueName = "Test Company \(UniqueCodeGenerator.generateISOCode(prefix: "TEST")) LLC"
            let entity = Entity(name: uniqueName, legalEntityTypeID: entityTypeId)

            // Use raw SQL to insert
            do {
                let insertResult = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        INSERT INTO directory.entities (name, legal_entity_type_id, created_at, updated_at)
                        VALUES (\(bind: entity.name), \(bind: entityTypeId), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        RETURNING id, created_at, updated_at
                        """
                    )
                    .first()

                #expect(insertResult != nil)

                // Extract the returned values
                if let result = insertResult {
                    let entityId = try result.decode(column: "id", as: UUID.self)
                    let _ = try result.decode(column: "created_at", as: Date.self)
                    let _ = try result.decode(column: "updated_at", as: Date.self)

                    print("Successfully saved Entity with ID: \(entityId)")
                }
            } catch {
                print("Insert error: \(String(reflecting: error))")
                throw error
            }
        }
    }

    @Test("Entity can query relationship to entity type", .disabled("CI connection timeout issues"))
    func entityCanQueryRelationshipToEntityType() async throws {
        try await TestUtilities.withApp { app, database in
            // First get Nevada jurisdiction ID
            let nevadaResult = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT id FROM legal.jurisdictions WHERE code = 'NV'")
                .first()

            guard let nevada = nevadaResult,
                let nevadaJurisdictionId = try? nevada.decode(column: "id", as: UUID.self)
            else {
                Issue.record("Nevada jurisdiction not found")
                return
            }

            // Create Nevada LLC entity type if it doesn't exist
            let entityTypeId: UUID
            let existingResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    SELECT id FROM legal.entity_types
                    WHERE legal_jurisdiction_id = \(bind: nevadaJurisdictionId) AND name = 'LLC'
                    """
                )
                .first()

            if let existing = existingResult,
                let existingId = try? existing.decode(column: "id", as: UUID.self)
            {
                entityTypeId = existingId
            } else {
                // Create the entity type
                let insertResult = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        INSERT INTO legal.entity_types (legal_jurisdiction_id, name, created_at, updated_at)
                        VALUES (\(bind: nevadaJurisdictionId), 'LLC', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        RETURNING id
                        """
                    )
                    .first()

                guard let entityType = insertResult,
                    let newId = try? entityType.decode(column: "id", as: UUID.self)
                else {
                    Issue.record("Failed to create Nevada LLC entity type")
                    return
                }
                entityTypeId = newId
            }

            // Create and insert a test entity
            let uniqueName = "Relationship Test Company \(UniqueCodeGenerator.generateISOCode(prefix: "REL")) LLC"
            let insertResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    INSERT INTO directory.entities (name, legal_entity_type_id, created_at, updated_at)
                    VALUES (\(bind: uniqueName), \(bind: entityTypeId), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    RETURNING id
                    """
                )
                .first()

            guard let entityResult = insertResult,
                let entityId = try? entityResult.decode(column: "id", as: UUID.self)
            else {
                Issue.record("Failed to create test entity")
                return
            }

            // Query the entity with its type information
            let queryResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    SELECT e.name as entity_name, et.name as entity_type_name, j.name as jurisdiction_name
                    FROM directory.entities e
                    JOIN legal.entity_types et ON e.legal_entity_type_id = et.id
                    JOIN legal.jurisdictions j ON et.legal_jurisdiction_id = j.id
                    WHERE e.id = \(bind: entityId)
                    """
                )
                .first()

            #expect(queryResult != nil)

            if let result = queryResult {
                let entityName = try result.decode(column: "entity_name", as: String.self)
                let entityTypeName = try result.decode(column: "entity_type_name", as: String.self)
                let jurisdictionName = try result.decode(column: "jurisdiction_name", as: String.self)

                #expect(entityName == uniqueName)
                #expect(entityTypeName == "LLC")
                #expect(jurisdictionName == "Nevada")

                print("Entity relationship query successful: \(entityName) is a \(jurisdictionName) \(entityTypeName)")
            }
        }
    }
}
