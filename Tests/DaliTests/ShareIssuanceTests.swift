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

@Suite("ShareIssuance Tests", .serialized)
struct ShareIssuanceTests {

    @Test("ShareIssuance has required fields")
    func shareIssuanceHasRequiredFields() async throws {
        // Create a test share issuance
        let shareClassId = UUID()
        let holderId = UUID()
        let documentId = UUID()
        let shareIssuance = ShareIssuance(
            shareClassID: shareClassId,
            holderID: holderId,
            documentID: documentId,
            fairMarketValuePerShare: 10.50,
            amountPaidPerShare: 8.00,
            amountPaidForShares: 800.00,
            amountToIncludeInGrossIncome: 200.00,
            restrictions: "Transfer restrictions apply",
            taxableYear: "2025",
            calendarYear: "2025"
        )

        // Verify the model has all required fields
        #expect(shareIssuance.$shareClass.id == shareClassId)
        #expect(shareIssuance.$holder.id == holderId)
        #expect(shareIssuance.$document.id == documentId)
        #expect(shareIssuance.fairMarketValuePerShare == 10.50)
        #expect(shareIssuance.amountPaidPerShare == 8.00)
        #expect(shareIssuance.amountPaidForShares == 800.00)
        #expect(shareIssuance.amountToIncludeInGrossIncome == 200.00)
        #expect(shareIssuance.restrictions == "Transfer restrictions apply")
        #expect(shareIssuance.taxableYear == "2025")
        #expect(shareIssuance.calendarYear == "2025")

        // ID should be nil before saving
        #expect(shareIssuance.id == nil)

        // Timestamps should be nil before saving
        #expect(shareIssuance.createdAt == nil)
        #expect(shareIssuance.updatedAt == nil)
    }

    @Test("ShareIssuance can be saved with valid references")
    func shareIssuanceCanBeSavedWithValidReferences() async throws {
        try await TestUtilities.withApp { app, database in
            // First verify the table exists with raw SQL
            let countResult = try await (database as! PostgresDatabase).sql()
                .raw("SELECT COUNT(*) as count FROM equity.share_issuances")
                .first()

            #expect(countResult != nil)
            print("Database connection verified - equity.share_issuances table accessible")

            // Create test dependencies
            let entityId = try await Self.createTestEntity(database: app.db)
            let shareClassId = try await Self.createTestShareClass(database: app.db, entityId: entityId)
            let documentId = try await Self.createTestDocument(database: app.db)

            // Create a test share issuance
            let shareIssuance = ShareIssuance(
                shareClassID: shareClassId,
                holderID: entityId,
                documentID: documentId,
                fairMarketValuePerShare: 15.75,
                amountPaidPerShare: 12.00,
                amountPaidForShares: 1200.00,
                amountToIncludeInGrossIncome: 375.00,
                restrictions: "Vesting schedule applies",
                taxableYear: "2025",
                calendarYear: "2025"
            )

            // Use raw SQL to insert
            do {
                let insertResult = try await (database as! PostgresDatabase).sql()
                    .raw(
                        """
                        INSERT INTO equity.share_issuances (share_class_id, holder_id, document_id, fair_market_value_per_share,
                        amount_paid_per_share, amount_paid_for_shares, amount_to_include_in_gross_income, restrictions,
                        taxable_year, calendar_year, created_at, updated_at)
                        VALUES (\(bind: shareClassId), \(bind: entityId), \(bind: documentId), \(bind: shareIssuance.fairMarketValuePerShare!),
                        \(bind: shareIssuance.amountPaidPerShare!), \(bind: shareIssuance.amountPaidForShares!),
                        \(bind: shareIssuance.amountToIncludeInGrossIncome!), \(bind: shareIssuance.restrictions!),
                        \(bind: shareIssuance.taxableYear!), \(bind: shareIssuance.calendarYear!), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        RETURNING id, created_at, updated_at
                        """
                    )
                    .first()

                #expect(insertResult != nil)

                // Extract the returned values
                if let result = insertResult {
                    let shareIssuanceId = try result.decode(column: "id", as: UUID.self)
                    let _ = try result.decode(column: "created_at", as: Date.self)
                    let _ = try result.decode(column: "updated_at", as: Date.self)

                    print("Successfully saved ShareIssuance with ID: \(shareIssuanceId)")
                }
            } catch {
                print("Insert error: \(String(reflecting: error))")
                throw error
            }
        }
    }

    @Test("ShareIssuance can query relationship to share class and holder")
    func shareIssuanceCanQueryRelationshipToShareClassAndHolder() async throws {
        try await TestUtilities.withApp { app, database in
            // Create test dependencies
            let entityId = try await Self.createTestEntity(database: app.db)
            let shareClassId = try await Self.createTestShareClass(database: app.db, entityId: entityId)
            let documentId = try await Self.createTestDocument(database: app.db)

            // Create and insert a test share issuance
            let insertResult = try await (database as! PostgresDatabase).sql()
                .raw(
                    """
                    INSERT INTO equity.share_issuances (share_class_id, holder_id, document_id, fair_market_value_per_share,
                    amount_paid_per_share, amount_paid_for_shares, amount_to_include_in_gross_income, restrictions,
                    taxable_year, calendar_year, created_at, updated_at)
                    VALUES (\(bind: shareClassId), \(bind: entityId), \(bind: documentId), 25.00, 20.00, 2000.00, 500.00,
                    'No restrictions', '2025', '2025', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    RETURNING id
                    """
                )
                .first()

            guard let shareIssuanceResult = insertResult,
                let shareIssuanceId = try? shareIssuanceResult.decode(column: "id", as: UUID.self)
            else {
                Issue.record("Failed to create test share issuance")
                return
            }

            // Query the share issuance with its relationships
            let queryResult = try await (database as! PostgresDatabase).sql()
                .raw(
                    """
                    SELECT si.fair_market_value_per_share, si.amount_paid_per_share, si.taxable_year,
                           sc.name as share_class_name, e.name as holder_name
                    FROM equity.share_issuances si
                    JOIN equity.share_classes sc ON si.share_class_id = sc.id
                    JOIN directory.entities e ON si.holder_id = e.id
                    WHERE si.id = \(bind: shareIssuanceId)
                    """
                )
                .first()

            #expect(queryResult != nil)

            if let result = queryResult {
                let fairMarketValue = try result.decode(column: "fair_market_value_per_share", as: Decimal.self)
                let amountPaid = try result.decode(column: "amount_paid_per_share", as: Decimal.self)
                let taxableYear = try result.decode(column: "taxable_year", as: String.self)
                let shareClassName = try result.decode(column: "share_class_name", as: String.self)
                let holderName = try result.decode(column: "holder_name", as: String.self)

                #expect(fairMarketValue == 25.00)
                #expect(amountPaid == 20.00)
                #expect(taxableYear == "2025")
                #expect(shareClassName.contains("Class A Common"))
                #expect(holderName.contains("Test Company"))

                print(
                    "ShareIssuance relationship query successful: \(holderName) issued \(shareClassName) at $\(fairMarketValue)"
                )
            }
        }
    }

    // Helper functions
    private static func createTestEntity(database: Database) async throws -> UUID {
        // First get Nevada jurisdiction ID
        let nevadaResult = try await (database as! PostgresDatabase).sql()
            .raw("SELECT id FROM legal.jurisdictions WHERE code = 'NV'")
            .first()

        guard let nevada = nevadaResult,
            let nevadaJurisdictionId = try? nevada.decode(column: "id", as: UUID.self)
        else {
            throw Abort(.internalServerError, reason: "Nevada jurisdiction not found")
        }

        // Create Nevada LLC entity type if it doesn't exist
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
            // Create the entity type
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
                throw Abort(.internalServerError, reason: "Failed to create Nevada LLC entity type")
            }
            entityTypeId = newId
        }

        // Create a test entity
        let uniqueName = "Test Company \(UniqueCodeGenerator.generateISOCode(prefix: "TST")) LLC"
        let entityInsertResult = try await (database as! PostgresDatabase).sql()
            .raw(
                """
                INSERT INTO directory.entities (name, legal_entity_type_id, created_at, updated_at)
                VALUES (\(bind: uniqueName), \(bind: entityTypeId), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                RETURNING id
                """
            )
            .first()

        guard let entityResult = entityInsertResult,
            let entityId = try? entityResult.decode(column: "id", as: UUID.self)
        else {
            throw Abort(.internalServerError, reason: "Failed to create test entity")
        }

        return entityId
    }

    private static func createTestShareClass(database: Database, entityId: UUID) async throws -> UUID {
        let uniqueName = "Class A Common \(UniqueCodeGenerator.generateISOCode(prefix: "CLS"))"
        let insertResult = try await (database as! PostgresDatabase).sql()
            .raw(
                """
                INSERT INTO equity.share_classes (name, entity_id, priority, description, created_at, updated_at)
                VALUES (\(bind: uniqueName), \(bind: entityId), 1, 'Common shares', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                RETURNING id
                """
            )
            .first()

        guard let result = insertResult,
            let shareClassId = try? result.decode(column: "id", as: UUID.self)
        else {
            throw Abort(.internalServerError, reason: "Failed to create test share class")
        }

        return shareClassId
    }

    private static func createTestDocument(database: Database) async throws -> UUID {
        let uniqueUrl = "s3://test-bucket/documents/test_\(UniqueCodeGenerator.generateISOCode(prefix: "DOC")).pdf"
        let referencedById = UUID()  // Random UUID for test
        let insertResult = try await (database as! PostgresDatabase).sql()
            .raw(
                """
                INSERT INTO documents.blobs (id, object_storage_url, referenced_by, referenced_by_id, created_at, updated_at)
                VALUES (gen_random_uuid(), \(bind: uniqueUrl), 'letters', \(bind: referencedById), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                RETURNING id
                """
            )
            .first()

        guard let result = insertResult,
            let documentId = try? result.decode(column: "id", as: UUID.self)
        else {
            throw Abort(.internalServerError, reason: "Failed to create test document")
        }

        return documentId
    }
}
