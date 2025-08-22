import Dali
import Fluent
import FluentPostgresDriver
import TestUtilities
import Testing
import Vapor

@Suite("Admin Entities Service Tests", .serialized)
struct AdminEntitiesRoutesTests {

    private func createTestEntityType(_ database: Database) async throws -> UUID {
        let postgres = database as! PostgresDatabase

        // Create Nevada jurisdiction if it doesn't exist
        try await postgres.sql().raw(
            """
            INSERT INTO legal.jurisdictions (name, code) VALUES
            ('Nevada', 'NV')
            ON CONFLICT (code) DO NOTHING
            """
        ).run()

        // Get Nevada jurisdiction ID
        let jurisdictionResult = try await postgres.sql().raw(
            """
            SELECT id FROM legal.jurisdictions WHERE code = 'NV'
            """
        ).first()

        guard let jurisdictionResult = jurisdictionResult else {
            throw ValidationError("Failed to find Nevada jurisdiction")
        }

        let jurisdictionId = try jurisdictionResult.decode(column: "id", as: UUID.self)

        // Create LLC entity type
        let entityTypeResult = try await postgres.sql().raw(
            """
            INSERT INTO legal.entity_types (name, legal_jurisdiction_id)
            VALUES ('LLC', \(bind: jurisdictionId))
            ON CONFLICT (legal_jurisdiction_id, name) DO UPDATE SET name = EXCLUDED.name
            RETURNING id
            """
        ).first()

        guard let entityTypeResult = entityTypeResult else {
            throw ValidationError("Failed to create entity type")
        }

        return try entityTypeResult.decode(column: "id", as: UUID.self)
    }

    @Test("AdminEntitiesService can list all entities")
    func adminServiceCanListAllEntities() async throws {
        try await TestUtilities.withApp { app, db in
            let entityTypeId = try await createTestEntityType(db)

            let entitiesService = AdminEntitiesService(database: db)

            // Create test entities using the service
            let entity1 = try await entitiesService.createEntity(
                name: "Test Company LLC",
                legalEntityTypeId: entityTypeId
            )

            let entity2 = try await entitiesService.createEntity(
                name: "Another Corp LLC",
                legalEntityTypeId: entityTypeId
            )

            // Test listing entities
            let entities = try await entitiesService.listEntities()

            #expect(entities.count >= 2)

            let entity1Found = entities.contains { $0.name == "Test Company LLC" }
            let entity2Found = entities.contains { $0.name == "Another Corp LLC" }

            #expect(entity1Found)
            #expect(entity2Found)
        }
    }

    @Test("AdminEntitiesService can get specific entity by ID")
    func adminServiceCanGetSpecificEntity() async throws {
        try await TestUtilities.withApp { app, db in
            let entityTypeId = try await createTestEntityType(db)

            let entitiesService = AdminEntitiesService(database: db)

            // Create test entity
            let createdEntity = try await entitiesService.createEntity(
                name: "Test Entity LLC",
                legalEntityTypeId: entityTypeId
            )

            // Test getting entity by ID
            let retrievedEntity = try await entitiesService.getEntity(entityId: createdEntity.id!)

            #expect(retrievedEntity != nil)
            #expect(retrievedEntity?.name == "Test Entity LLC")
            #expect(retrievedEntity?.$legalEntityType.id == entityTypeId)
        }
    }

    @Test("AdminEntitiesService can list entity types")
    func adminServiceCanListEntityTypes() async throws {
        try await TestUtilities.withApp { app, db in
            let entityTypeId = try await createTestEntityType(db)

            let entitiesService = AdminEntitiesService(database: db)

            // Test listing entity types
            let entityTypes = try await entitiesService.listEntityTypes()

            #expect(entityTypes.count >= 1)

            let llcTypeFound = entityTypes.contains { $0.name == "LLC" }
            #expect(llcTypeFound)
        }
    }

    @Test("AdminEntitiesService validates entity creation input")
    func adminServiceValidatesEntityInput() async throws {
        try await TestUtilities.withApp { app, db in
            let entitiesService = AdminEntitiesService(database: db)

            // Test that empty name throws validation error
            do {
                let entityTypeId = try await createTestEntityType(db)

                _ = try await entitiesService.createEntity(
                    name: "",
                    legalEntityTypeId: entityTypeId
                )

                #expect(Bool(false), "Should have thrown validation error for empty name")
            } catch {
                #expect(error is ValidationError)
            }
        }
    }
}
