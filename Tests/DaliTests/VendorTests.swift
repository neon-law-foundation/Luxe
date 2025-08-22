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

@Suite("Vendor Tests", .serialized)
struct VendorTests {

    @Test("Vendor has required fields")
    func vendorHasRequiredFields() async throws {
        // Create a test vendor with no entity or person
        let vendor = Vendor(name: "Acme Supply Co")

        // Verify the model has all required fields
        #expect(vendor.name == "Acme Supply Co")

        // ID should be nil before saving
        #expect(vendor.id == nil)

        // Optional foreign keys should be nil
        #expect(vendor.$entity.id == nil)
        #expect(vendor.$person.id == nil)

        // Timestamps should be nil before saving
        #expect(vendor.createdAt == nil)
        #expect(vendor.updatedAt == nil)
    }

    @Test("Vendor can be created with entity reference")
    func vendorCanBeCreatedWithEntityReference() async throws {
        let entityId = UUID()
        let vendor = Vendor(name: "Corporate Vendor", entityID: entityId)

        #expect(vendor.name == "Corporate Vendor")
        #expect(vendor.$entity.id == entityId)
        #expect(vendor.$person.id == nil)
    }

    @Test("Vendor can be created with person reference")
    func vendorCanBeCreatedWithPersonReference() async throws {
        let personId = UUID()
        let vendor = Vendor(name: "Individual Contractor", personID: personId)

        #expect(vendor.name == "Individual Contractor")
        #expect(vendor.$person.id == personId)
        #expect(vendor.$entity.id == nil)
    }

    @Test("Vendor constraint prevents saving without entity or person reference")
    func vendorConstraintPreventsNullEntityAndPersonReferences() async throws {
        try await TestUtilities.withApp { app, database in
            // First verify the table exists with raw SQL
            let countResult = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT COUNT(*) as count FROM accounting.vendors")
                .first()

            #expect(countResult != nil)
            print("Database connection verified - accounting.vendors table accessible")

            // Create a test vendor with unique name
            let uniqueName = "Test Vendor \(UniqueCodeGenerator.generateISOCode(prefix: "VENDOR"))"

            // Try to insert vendor with both entity_id AND person_id NULL - this should fail
            do {
                let _ = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        INSERT INTO accounting.vendors (name, entity_id, person_id, created_at, updated_at)
                        VALUES (\(bind: uniqueName), NULL, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        RETURNING id, created_at, updated_at
                        """
                    )
                    .first()

                Issue.record("Expected constraint violation but insert succeeded")
            } catch {
                // This is expected - the constraint should prevent the insert
                print("Constraint successfully prevented vendor creation with null references: \(error)")
                // Test passes if we get an error
            }
        }
    }

    @Test("Vendor can be saved with entity reference")
    func vendorCanBeSavedWithEntityReference() async throws {
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

            // Create a test entity first
            let uniqueEntityName = "Vendor Entity \(UniqueCodeGenerator.generateISOCode(prefix: "ENTITY")) LLC"
            let entityInsertResult = try await (app.db as! PostgresDatabase).sql()
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
                Issue.record("Failed to create test entity")
                return
            }

            // Create a test vendor with entity reference
            let uniqueName = "Corporate Vendor \(UniqueCodeGenerator.generateISOCode(prefix: "VENDOR"))"
            let vendorInsertResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    INSERT INTO accounting.vendors (name, entity_id, person_id, created_at, updated_at)
                    VALUES (\(bind: uniqueName), \(bind: entityId), NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    RETURNING id
                    """
                )
                .first()

            #expect(vendorInsertResult != nil)

            if let result = vendorInsertResult {
                let vendorId = try result.decode(column: "id", as: UUID.self)
                print("Successfully saved Vendor with Entity reference, Vendor ID: \(vendorId)")
            }
        }
    }

    @Test("Vendor can be saved with person reference")
    func vendorCanBeSavedWithPersonReference() async throws {
        try await TestUtilities.withApp { app, database in
            // Create a test person first
            let uniqueEmail = "vendor\(UniqueCodeGenerator.generateISOCode(prefix: "VENDOR"))@example.com"
            let personInsertResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    INSERT INTO directory.people (name, email, created_at, updated_at)
                    VALUES (\(bind: "Jane Contractor"), \(bind: uniqueEmail), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    RETURNING id
                    """
                )
                .first()

            guard let personResult = personInsertResult,
                let personId = try? personResult.decode(column: "id", as: UUID.self)
            else {
                Issue.record("Failed to create test person")
                return
            }

            // Create a test vendor with person reference
            let uniqueName = "Individual Vendor \(UniqueCodeGenerator.generateISOCode(prefix: "VENDOR"))"
            let vendorInsertResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    INSERT INTO accounting.vendors (name, entity_id, person_id, created_at, updated_at)
                    VALUES (\(bind: uniqueName), NULL, \(bind: personId), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    RETURNING id
                    """
                )
                .first()

            #expect(vendorInsertResult != nil)

            if let result = vendorInsertResult {
                let vendorId = try result.decode(column: "id", as: UUID.self)
                print("Successfully saved Vendor with Person reference, Vendor ID: \(vendorId)")
            }
        }
    }

    @Test("Vendor constraint prevents both entity and person references")
    func vendorConstraintPreventsBothEntityAndPersonReferences() async throws {
        try await TestUtilities.withApp { app, database in
            // Create test person and entity
            let uniqueEmail = "constraint\(UniqueCodeGenerator.generateISOCode(prefix: "VENDOR"))@example.com"
            let personInsertResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    INSERT INTO directory.people (name, email, created_at, updated_at)
                    VALUES (\(bind: "Test Person"), \(bind: uniqueEmail), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    RETURNING id
                    """
                )
                .first()

            guard let personResult = personInsertResult,
                let personId = try? personResult.decode(column: "id", as: UUID.self)
            else {
                Issue.record("Failed to create test person")
                return
            }

            // Get Nevada jurisdiction and create entity
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

            let uniqueEntityName = "Test Entity \(UniqueCodeGenerator.generateISOCode(prefix: "ENTITY")) LLC"
            let entityInsertResult = try await (app.db as! PostgresDatabase).sql()
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
                Issue.record("Failed to create test entity")
                return
            }

            // Try to insert vendor with both entity_id AND person_id - this should fail
            do {
                let _ = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        INSERT INTO accounting.vendors (name, entity_id, person_id, created_at, updated_at)
                        VALUES (\(bind: "Invalid Vendor"), \(bind: entityId), \(bind: personId), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        """
                    )
                    .first()

                Issue.record("Expected constraint violation but insert succeeded")
            } catch {
                // This is expected - the constraint should prevent the insert
                print("Constraint successfully prevented invalid vendor creation: \(String(reflecting: error))")
                // Test passes if we get an error
            }
        }
    }
}
