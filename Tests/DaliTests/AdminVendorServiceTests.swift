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

@Suite("Admin Vendor Service Tests", .serialized)
struct AdminVendorServiceTests {

    @Test("Admin vendor service can create vendor with entity reference")
    func adminVendorServiceCanCreateVendorWithEntityReference() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminVendorService(database: database)

            // First create a test entity
            let entityId = try await createTestEntity(database)

            // Create vendor with entity reference
            let input = AdminVendorService.CreateVendorInput(
                name: "Test Entity Vendor",
                entityID: entityId,
                personID: nil
            )

            let vendor = try await service.createVendor(input)

            #expect(vendor.id != nil)
            #expect(vendor.name == "Test Entity Vendor")
            #expect(vendor.$entity.id == entityId)
            #expect(vendor.$person.id == nil)
            #expect(vendor.createdAt != nil)
            #expect(vendor.updatedAt != nil)
        }
    }

    @Test("Admin vendor service can create vendor with person reference")
    func adminVendorServiceCanCreateVendorWithPersonReference() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminVendorService(database: database)

            // First create a test person
            let personId = try await createTestPerson(database)

            // Create vendor with person reference
            let input = AdminVendorService.CreateVendorInput(
                name: "Test Person Vendor",
                entityID: nil,
                personID: personId
            )

            let vendor = try await service.createVendor(input)

            #expect(vendor.id != nil)
            #expect(vendor.name == "Test Person Vendor")
            #expect(vendor.$entity.id == nil)
            #expect(vendor.$person.id == personId)
            #expect(vendor.createdAt != nil)
            #expect(vendor.updatedAt != nil)
        }
    }

    @Test("Admin vendor service prevents creating vendor with both entity and person references")
    func adminVendorServicePreventsCreatingVendorWithBothReferences() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminVendorService(database: database)

            // Create test entity and person
            let entityId = try await createTestEntity(database)
            let personId = try await createTestPerson(database)

            // Try to create vendor with both references - should fail validation
            let input = AdminVendorService.CreateVendorInput(
                name: "Invalid Vendor",
                entityID: entityId,
                personID: personId
            )

            do {
                let _ = try await service.createVendor(input)
                Issue.record("Expected validation error but vendor creation succeeded")
            } catch let error as ValidationError {
                #expect(error.localizedDescription.contains("Exactly one of entityID or personID must be provided"))
            } catch {
                Issue.record("Expected ValidationError but got: \(error)")
            }
        }
    }

    @Test("Admin vendor service prevents creating vendor with neither entity nor person reference")
    func adminVendorServicePreventsCreatingVendorWithoutReferences() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminVendorService(database: database)

            // Try to create vendor with no references - should fail validation
            let input = AdminVendorService.CreateVendorInput(
                name: "Invalid Vendor",
                entityID: nil,
                personID: nil
            )

            do {
                let _ = try await service.createVendor(input)
                Issue.record("Expected validation error but vendor creation succeeded")
            } catch let error as ValidationError {
                #expect(error.localizedDescription.contains("Exactly one of entityID or personID must be provided"))
            } catch {
                Issue.record("Expected ValidationError but got: \(error)")
            }
        }
    }

    @Test("Admin vendor service can update vendor")
    func adminVendorServiceCanUpdateVendor() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminVendorService(database: database)

            // Create test entities and person
            let entityId1 = try await createTestEntity(database, name: "Entity 1")
            let entityId2 = try await createTestEntity(database, name: "Entity 2")

            // Create vendor with first entity
            let createInput = AdminVendorService.CreateVendorInput(
                name: "Original Vendor",
                entityID: entityId1,
                personID: nil
            )

            let vendor = try await service.createVendor(createInput)
            guard let vendorId = vendor.id else {
                Issue.record("Vendor ID should not be nil")
                return
            }

            // Update vendor to second entity
            let updateInput = AdminVendorService.UpdateVendorInput(
                name: "Updated Vendor",
                entityID: entityId2,
                personID: nil
            )

            let updatedVendor = try await service.updateVendor(vendorId: vendorId, updateInput)

            #expect(updatedVendor.id == vendorId)
            #expect(updatedVendor.name == "Updated Vendor")
            #expect(updatedVendor.$entity.id == entityId2)
            #expect(updatedVendor.$person.id == nil)
        }
    }

    @Test("Admin vendor service can list vendors")
    func adminVendorServiceCanListVendors() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminVendorService(database: database)

            // Create test vendors
            let entityId = try await createTestEntity(database)
            let personId = try await createTestPerson(database)

            let input1 = AdminVendorService.CreateVendorInput(name: "Vendor 1", entityID: entityId)
            let input2 = AdminVendorService.CreateVendorInput(name: "Vendor 2", personID: personId)

            let _ = try await service.createVendor(input1)
            let _ = try await service.createVendor(input2)

            // List vendors
            let vendors = try await service.listVendors(limit: 10)

            #expect(vendors.count >= 2)
            let vendorNames = vendors.map { $0.name }
            #expect(vendorNames.contains("Vendor 1"))
            #expect(vendorNames.contains("Vendor 2"))
        }
    }

    @Test("Admin vendor service can search vendors")
    func adminVendorServiceCanSearchVendors() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminVendorService(database: database)

            // Create test vendors
            let entityId = try await createTestEntity(database)
            let personId = try await createTestPerson(database)

            let input1 = AdminVendorService.CreateVendorInput(name: "Acme Corporation", entityID: entityId)
            let input2 = AdminVendorService.CreateVendorInput(name: "John Doe Consulting", personID: personId)

            let _ = try await service.createVendor(input1)
            let _ = try await service.createVendor(input2)

            // Search for "Acme"
            let acmeResults = try await service.searchVendors(searchTerm: "Acme")
            #expect(acmeResults.count >= 1)
            #expect(acmeResults.first?.name == "Acme Corporation")

            // Search for "John"
            let johnResults = try await service.searchVendors(searchTerm: "John")
            #expect(johnResults.count >= 1)
            #expect(johnResults.first?.name == "John Doe Consulting")
        }
    }

    @Test("Admin vendor service can delete vendor")
    func adminVendorServiceCanDeleteVendor() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminVendorService(database: database)

            // Create test vendor
            let entityId = try await createTestEntity(database)
            let input = AdminVendorService.CreateVendorInput(name: "Vendor to Delete", entityID: entityId)
            let vendor = try await service.createVendor(input)

            guard let vendorId = vendor.id else {
                Issue.record("Vendor ID should not be nil")
                return
            }

            // Verify vendor exists
            let foundVendor = try await service.getVendor(vendorId: vendorId)
            #expect(foundVendor != nil)

            // Delete vendor
            try await service.deleteVendor(vendorId: vendorId)

            // Verify vendor no longer exists
            let deletedVendor = try await service.getVendor(vendorId: vendorId)
            #expect(deletedVendor == nil)
        }
    }

    // MARK: - Helper Methods

    private func createTestEntity(_ database: Database, name: String = "Test Entity") async throws -> UUID {
        // Get Nevada jurisdiction ID
        let nevadaResult = try await (database as! PostgresDatabase).sql()
            .raw("SELECT id FROM legal.jurisdictions WHERE code = 'NV'")
            .first()

        guard let nevada = nevadaResult,
            let nevadaJurisdictionId = try? nevada.decode(column: "id", as: UUID.self)
        else {
            throw ValidationError("Nevada jurisdiction not found")
        }

        // Create entity type if it doesn't exist
        let entityTypeId: UUID
        let existingResult = try await (database as! PostgresDatabase).sql()
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
            let insertResult = try await (database as! PostgresDatabase).sql()
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
                throw ValidationError("Failed to create entity type")
            }
            entityTypeId = newId
        }

        // Create entity
        let uniqueEntityName = "\(name) \(UniqueCodeGenerator.generateISOCode(prefix: "ENT")) LLC"
        let entityInsertResult = try await (database as! PostgresDatabase).sql()
            .raw(
                """
                INSERT INTO directory.entities (name, legal_entity_type_id, created_at, updated_at)
                VALUES (\(bind: uniqueEntityName), \(bind: entityTypeId), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                RETURNING id
                """
            )
            .first()

        guard let entityResult = entityInsertResult,
            let entityId = try? entityResult.decode(column: "id", as: UUID.self)
        else {
            throw ValidationError("Failed to create test entity")
        }

        return entityId
    }

    private func createTestPerson(_ database: Database, name: String = "Test Person") async throws -> UUID {
        let uniqueEmail = "test\(UniqueCodeGenerator.generateISOCode(prefix: "PER"))@example.com"
        let personInsertResult = try await (database as! PostgresDatabase).sql()
            .raw(
                """
                INSERT INTO directory.people (name, email, created_at, updated_at)
                VALUES (\(bind: name), \(bind: uniqueEmail), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                RETURNING id
                """
            )
            .first()

        guard let personResult = personInsertResult,
            let personId = try? personResult.decode(column: "id", as: UUID.self)
        else {
            throw ValidationError("Failed to create test person")
        }

        return personId
    }
}
