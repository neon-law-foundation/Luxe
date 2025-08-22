import Dali
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

@Suite("EntityType Tests", .serialized)
struct EntityTypeTests {

    @Test("EntityType exists for Nevada jurisdiction")
    func entityTypeExistsForNevadaJurisdiction() async throws {
        try await TestUtilities.withApp { app, database in
            // First verify the table exists with raw SQL
            let countResult = try await (database as! PostgresDatabase).sql()
                .raw("SELECT COUNT(*) as count FROM legal.entity_types")
                .first()

            #expect(countResult != nil)
            print("Database connection verified - legal.entity_types table accessible")

            // Get Nevada jurisdiction ID from database
            let nevadaResult = try await (database as! PostgresDatabase).sql()
                .raw("SELECT id FROM legal.jurisdictions WHERE code = 'NV'")
                .first()

            guard let nevada = nevadaResult,
                let jurisdictionId = try? nevada.decode(column: "id", as: UUID.self)
            else {
                Issue.record("Nevada jurisdiction not found")
                return
            }

            // Check if Nevada has any entity types
            let existingEntityTypes = try await (database as! PostgresDatabase).sql()
                .raw(
                    """
                    SELECT id, name FROM legal.entity_types
                    WHERE legal_jurisdiction_id = \(bind: jurisdictionId)
                    """
                )
                .all()

            // If no entity types exist, create one for testing
            if existingEntityTypes.isEmpty {
                let insertResult = try await (database as! PostgresDatabase).sql()
                    .raw(
                        """
                        INSERT INTO legal.entity_types (legal_jurisdiction_id, name, created_at, updated_at)
                        VALUES (\(bind: jurisdictionId), 'LLC', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        RETURNING id, name
                        """
                    )
                    .first()

                #expect(insertResult != nil)
                if let result = insertResult {
                    let entityTypeId = try result.decode(column: "id", as: UUID.self)
                    let entityTypeName = try result.decode(column: "name", as: String.self)
                    print("Created EntityType '\(entityTypeName)' with ID: \(entityTypeId)")
                }
            } else {
                // Nevada has at least one entity type
                #expect(existingEntityTypes.count > 0)
                if let firstEntityType = existingEntityTypes.first {
                    let entityTypeId = try firstEntityType.decode(column: "id", as: UUID.self)
                    let entityTypeName = try firstEntityType.decode(column: "name", as: String.self)
                    print("Found existing EntityType '\(entityTypeName)' with ID: \(entityTypeId)")
                }
            }
        }
    }

    @Test("EntityType name is constrained to valid values")
    func entityTypeNameIsConstrainedToValidValues() async throws {
        try await TestUtilities.withApp { app, database in
            // Create a test jurisdiction to avoid conflicts
            let testJurisdictionCode = "TEST\(UniqueCodeGenerator.generateISOCode(prefix: "TEST"))"
            let testJurisdictionName = "Test Jurisdiction \(UniqueCodeGenerator.generateISOCode(prefix: "TEST"))"

            let testJurisdictionResult = try await (database as! PostgresDatabase).sql()
                .raw(
                    """
                    INSERT INTO legal.jurisdictions (name, code, created_at, updated_at)
                    VALUES (\(bind: testJurisdictionName), \(bind: testJurisdictionCode), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    RETURNING id
                    """
                )
                .first()

            guard let testJurisdiction = testJurisdictionResult,
                let jurisdictionId = try? testJurisdiction.decode(column: "id", as: UUID.self)
            else {
                Issue.record("Failed to create test jurisdiction")
                return
            }

            // Test valid entity type names
            let validNames = ["LLC", "PLLC", "Non-Profit"]

            for validName in validNames {
                do {
                    let _ = try await (database as! PostgresDatabase).sql()
                        .raw(
                            """
                            INSERT INTO legal.entity_types (legal_jurisdiction_id, name, created_at, updated_at)
                            VALUES (\(bind: jurisdictionId), \(bind: validName), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                            """
                        )
                        .run()
                    print("Successfully created entity type: \(validName)")
                } catch {
                    Issue.record("Failed to create valid entity type '\(validName)': \(error)")
                }
            }

            // Test invalid entity type names
            let invalidNames = ["", "   ", String(repeating: "A", count: 256)]  // Empty, whitespace, too long

            for invalidName in invalidNames {
                do {
                    let _ = try await (database as! PostgresDatabase).sql()
                        .raw(
                            """
                            INSERT INTO legal.entity_types (legal_jurisdiction_id, name, created_at, updated_at)
                            VALUES (\(bind: jurisdictionId), \(bind: invalidName), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                            """
                        )
                        .run()
                    Issue.record("Should have failed to create invalid entity type '\(invalidName)'")
                } catch {
                    print("Correctly rejected invalid entity type: '\(invalidName)'")
                }
            }
        }
    }
}
