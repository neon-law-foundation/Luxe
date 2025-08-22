import Fluent
import FluentPostgresDriver
import Logging
import PostgresNIO
import TestUtilities
import Testing
import Vapor

@testable import Dali
@testable import Palette

@Suite("Admin Entities Service Tests", .serialized)
struct AdminEntitiesServiceTests {

    @Test("AdminEntitiesService can list entities")
    func adminEntitiesServiceCanListEntities() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminEntitiesService(database: database)

            // Create a test entity first - need an entity type
            let entityType = try await createTestEntityType(database: database)
            let uniqueName = "Test Entity \(UniqueCodeGenerator.generateISOCode(prefix: "ENT"))"
            let testEntity = Entity(name: uniqueName, legalEntityTypeID: entityType.id!)
            try await testEntity.save(on: database)

            // Test listing entities
            let entities = try await service.listEntities()

            #expect(entities.count >= 1)
            #expect(entities.contains { $0.name == uniqueName })
        }
    }

    @Test("AdminEntitiesService can get entity by ID")
    func adminEntitiesServiceCanGetEntityById() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminEntitiesService(database: database)

            // Create a test entity
            let entityType = try await createTestEntityType(database: database)
            let uniqueName = "Get Test Entity \(UniqueCodeGenerator.generateISOCode(prefix: "GET"))"
            let testEntity = Entity(name: uniqueName, legalEntityTypeID: entityType.id!)
            try await testEntity.save(on: database)

            // Test getting entity by ID
            guard let entityId = testEntity.id else {
                throw ValidationError("Entity ID not available after save")
            }

            let retrievedEntity = try await service.getEntity(entityId: entityId)

            #expect(retrievedEntity != nil)
            #expect(retrievedEntity?.name == uniqueName)
            #expect(retrievedEntity?.$legalEntityType.id == entityType.id)
        }
    }

    @Test("AdminEntitiesService can create entity")
    func adminEntitiesServiceCanCreateEntity() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminEntitiesService(database: database)

            let entityType = try await createTestEntityType(database: database)
            let uniqueName = "Create Test Entity \(UniqueCodeGenerator.generateISOCode(prefix: "CREATE"))"

            let createdEntity = try await service.createEntity(
                name: uniqueName,
                legalEntityTypeId: entityType.id!
            )

            #expect(createdEntity.name == uniqueName)
            #expect(createdEntity.$legalEntityType.id == entityType.id!)
            #expect(createdEntity.id != nil)

            // Verify entity was actually saved to database
            let retrievedEntity = try await service.getEntity(entityId: createdEntity.id!)
            #expect(retrievedEntity?.name == uniqueName)
        }
    }

    @Test("AdminEntitiesService can update entity")
    func adminEntitiesServiceCanUpdateEntity() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminEntitiesService(database: database)

            // Create test entity types
            let originalEntityType = try await createTestEntityType(database: database)
            let newEntityType = try await createTestEntityType(database: database, suffix: "NEW")

            // Create a test entity first
            let originalName = "Original Entity \(UniqueCodeGenerator.generateISOCode(prefix: "ORIG"))"
            let testEntity = Entity(name: originalName, legalEntityTypeID: originalEntityType.id!)
            try await testEntity.save(on: database)

            // Update the entity
            let newName = "Updated Entity \(UniqueCodeGenerator.generateISOCode(prefix: "UPD"))"

            let updatedEntity = try await service.updateEntity(
                entityId: testEntity.id!,
                name: newName,
                legalEntityTypeId: newEntityType.id!
            )

            #expect(updatedEntity.name == newName)
            #expect(updatedEntity.$legalEntityType.id == newEntityType.id!)
            #expect(updatedEntity.id == testEntity.id)

            // Verify changes were persisted
            let retrievedEntity = try await service.getEntity(entityId: testEntity.id!)
            #expect(retrievedEntity?.name == newName)
            #expect(retrievedEntity?.$legalEntityType.id == newEntityType.id!)
        }
    }

    @Test("AdminEntitiesService can delete entity")
    func adminEntitiesServiceCanDeleteEntity() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminEntitiesService(database: database)

            // Create a test entity first
            let entityType = try await createTestEntityType(database: database)
            let uniqueName = "Delete Test Entity \(UniqueCodeGenerator.generateISOCode(prefix: "DELETE"))"
            let testEntity = Entity(name: uniqueName, legalEntityTypeID: entityType.id!)
            try await testEntity.save(on: database)

            // Verify entity exists
            let entityBeforeDelete = try await service.getEntity(entityId: testEntity.id!)
            #expect(entityBeforeDelete != nil)

            // Delete the entity
            try await service.deleteEntity(entityId: testEntity.id!)

            // Verify entity no longer exists
            let entityAfterDelete = try await service.getEntity(entityId: testEntity.id!)
            #expect(entityAfterDelete == nil)
        }
    }

    @Test("AdminEntitiesService can list entity types")
    func adminEntitiesServiceCanListEntityTypes() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminEntitiesService(database: database)

            // Create a test entity type
            let testEntityType = try await createTestEntityType(database: database)

            // Test listing entity types
            let entityTypes = try await service.listEntityTypes()

            #expect(entityTypes.count >= 1)
            #expect(entityTypes.contains { $0.id == testEntityType.id })
        }
    }

    @Test("AdminEntitiesService handles non-existent entity gracefully")
    func adminEntitiesServiceHandlesNonExistentEntity() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminEntitiesService(database: database)

            let nonExistentId = UUID()
            let retrievedEntity = try await service.getEntity(entityId: nonExistentId)

            #expect(retrievedEntity == nil)
        }
    }

    @Test("AdminEntitiesService validates input data")
    func adminEntitiesServiceValidatesInputData() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminEntitiesService(database: database)
            let entityType = try await createTestEntityType(database: database)

            // Test with empty name
            do {
                _ = try await service.createEntity(name: "", legalEntityTypeId: entityType.id!)
                #expect(Bool(false), "Should throw ValidationError for empty name")
            } catch let error as ValidationError {
                #expect(error.message.contains("Entity name cannot be empty"))
            }

            // Test with whitespace-only name
            do {
                _ = try await service.createEntity(name: "   ", legalEntityTypeId: entityType.id!)
                #expect(Bool(false), "Should throw ValidationError for whitespace-only name")
            } catch let error as ValidationError {
                #expect(error.message.contains("Entity name cannot be empty"))
            }
        }
    }

    @Test("AdminEntitiesService trims whitespace from entity name")
    func adminEntitiesServiceTrimsWhitespaceFromEntityName() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminEntitiesService(database: database)
            let entityType = try await createTestEntityType(database: database)

            let nameParts = UniqueCodeGenerator.generateISOCode(prefix: "TRIM")
            let nameWithWhitespace = "  Trimmed Entity \(nameParts)  "
            let expectedName = "Trimmed Entity \(nameParts)"

            let createdEntity = try await service.createEntity(
                name: nameWithWhitespace,
                legalEntityTypeId: entityType.id!
            )

            #expect(createdEntity.name == expectedName)

            // Verify trimmed value was saved
            let retrievedEntity = try await service.getEntity(entityId: createdEntity.id!)
            #expect(retrievedEntity?.name == expectedName)
        }
    }

    @Test("AdminEntitiesService lists entities in descending creation order")
    func adminEntitiesServiceListsEntitiesInDescendingOrder() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminEntitiesService(database: database)

            // Create test entity type
            let entityType = try await createTestEntityType(database: database)

            // Create multiple test entities with slight time differences
            let uniqueId = UniqueCodeGenerator.generateISOCode(prefix: "ORDER")
            let firstName = "First Entity \(uniqueId)"
            let secondName = "Second Entity \(uniqueId)"

            let firstEntity = Entity(name: firstName, legalEntityTypeID: entityType.id!)
            try await firstEntity.save(on: database)

            // Small delay to ensure different creation times
            try await Task.sleep(nanoseconds: 10_000_000)  // 10ms

            let secondEntity = Entity(name: secondName, legalEntityTypeID: entityType.id!)
            try await secondEntity.save(on: database)

            // List entities and verify order (newest first)
            let entities = try await service.listEntities()

            // Find our test entities in the results
            guard let firstIndex = entities.firstIndex(where: { $0.name == firstName }),
                let secondIndex = entities.firstIndex(where: { $0.name == secondName })
            else {
                throw ValidationError("Test entities not found in results")
            }

            // Second entity should come before first entity (descending order)
            #expect(secondIndex < firstIndex)
        }
    }
}

// MARK: - Helper Functions

/// Creates a test entity type for testing purposes
private func createTestEntityType(database: Database, suffix: String = "") async throws -> EntityType {
    // First try to find Nevada jurisdiction or create a test one
    let existingJurisdiction = try await LegalJurisdiction.query(on: database)
        .filter(\.$code == "NV")
        .first()

    let jurisdiction: LegalJurisdiction
    if let existing = existingJurisdiction {
        jurisdiction = existing
    } else {
        // Create a test jurisdiction with unique code
        let uniqueCode = "T\(UniqueCodeGenerator.generateISOCode(prefix: "J").suffix(3))\(suffix)"
        jurisdiction = LegalJurisdiction(
            name: "Test Jurisdiction \(uniqueCode)",
            code: uniqueCode
        )
        try await jurisdiction.save(on: database)
    }

    // Use valid entity type names that comply with the CHECK constraint
    let validEntityTypes = ["LLC", "PLLC", "Non-Profit"]
    let entityTypeName = validEntityTypes[abs(suffix.hashValue) % validEntityTypes.count]

    // First check if this entity type already exists for this jurisdiction
    let existingEntityType = try await EntityType.query(on: database)
        .filter(\.$legalJurisdiction.$id == jurisdiction.id!)
        .filter(\.$name == entityTypeName)
        .first()

    if let existing = existingEntityType {
        return existing
    }

    // Create entity type with valid name
    let entityType = EntityType(
        legalJurisdictionID: jurisdiction.id!,
        name: entityTypeName
    )
    try await entityType.save(on: database)

    return entityType
}
