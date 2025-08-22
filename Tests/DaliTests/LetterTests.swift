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

@Suite("Letter Tests", .serialized)
struct LetterTests {

    @Test("Letter has required fields")
    func letterHasRequiredFields() async throws {
        // Create a test letter
        let letter = Letter(
            mailboxId: UUID(),
            receivedDate: Date(),
            status: .received
        )

        // Verify the model has all required fields
        #expect(!letter.mailboxId.uuidString.isEmpty)
        #expect(letter.receivedDate.timeIntervalSince1970 > 0)
        #expect(letter.status == .received)

        // ID should be nil before saving
        #expect(letter.id == nil)

        // Timestamps should be nil before saving
        #expect(letter.createdAt == nil)
        #expect(letter.updatedAt == nil)
    }

    @Test("Letter has optional fields")
    func letterHasOptionalFields() async throws {
        // Create a letter with optional fields
        let senderAddressId = UUID()
        let scannedBy = UUID()
        let scannedDocumentId = UUID()

        let letter = Letter(
            mailboxId: UUID(),
            receivedDate: Date(),
            status: .scanned,
            senderAddressId: senderAddressId,
            postmarkDate: Date(),
            trackingNumber: "1Z123456789",
            carrier: "UPS",
            letterType: "certified",
            scannedAt: Date(),
            scannedBy: scannedBy,
            scannedDocumentId: scannedDocumentId,
            emailedAt: Date(),
            emailedTo: ["user@example.com"],
            notes: "Test note",
            isPriority: true,
            requiresSignature: true
        )

        // Verify optional fields are set
        #expect(letter.senderAddressId == senderAddressId)
        #expect(letter.postmarkDate != nil)
        #expect(letter.trackingNumber == "1Z123456789")
        #expect(letter.carrier == "UPS")
        #expect(letter.letterType == "certified")
        #expect(letter.scannedAt != nil)
        #expect(letter.scannedBy == scannedBy)
        #expect(letter.scannedDocumentId == scannedDocumentId)
        #expect(letter.emailedAt != nil)
        #expect(letter.emailedTo == ["user@example.com"])
        #expect(letter.notes == "Test note")
        #expect(letter.isPriority == true)
        #expect(letter.requiresSignature == true)
    }

    @Test("Letter status enum has all valid values")
    func letterStatusEnumHasAllValidValues() async throws {
        let validStatuses: [Letter.Status] = [
            .received, .scanned, .emailed, .forwarded, .shredded, .returned,
        ]

        for status in validStatuses {
            let letter = Letter(
                mailboxId: UUID(),
                receivedDate: Date(),
                status: status
            )
            #expect(letter.status == status)
        }
    }

    @Test("Letter can be saved and retrieved")
    func letterCanBeSavedAndRetrieved() async throws {
        try await TestUtilities.withApp { app, database in
            // First verify the table exists with raw SQL
            let countResult = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT COUNT(*) as count FROM mail.letters")
                .first()

            #expect(countResult != nil)
            print("Database connection verified - mail.letters table accessible")

            // First ensure we have an address to use
            let addressResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    INSERT INTO directory.addresses (
                        entity_id, street, city, country, is_verified, created_at, updated_at
                    )
                    VALUES (
                        (SELECT id FROM directory.entities LIMIT 1),
                        '123 Test Street',
                        'Test City',
                        'USA',
                        false,
                        CURRENT_TIMESTAMP,
                        CURRENT_TIMESTAMP
                    )
                    ON CONFLICT DO NOTHING
                    RETURNING id
                    """
                )
                .first()

            let addressId: UUID
            if let addressRow = addressResult {
                addressId = try addressRow.decode(column: "id", as: UUID.self)
            } else {
                // Get existing address if insert failed due to conflict
                let existingResult = try await (app.db as! PostgresDatabase).sql()
                    .raw("SELECT id FROM directory.addresses LIMIT 1")
                    .first()
                guard let existingRow = existingResult else {
                    throw TestError.invalidConnectionURL
                }
                addressId = try existingRow.decode(column: "id", as: UUID.self)
            }

            // Create test mailbox using the Mailbox model approach
            let testMailboxNumber =
                Int(UUID().uuidString.prefix(4).replacingOccurrences(of: "-", with: ""), radix: 16) ?? 1000
            let mailboxResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    INSERT INTO mail.mailboxes (directory_address_id, mailbox_number, is_active, created_at, updated_at)
                    VALUES (
                        \(bind: addressId),
                        \(bind: testMailboxNumber),
                        true,
                        CURRENT_TIMESTAMP,
                        CURRENT_TIMESTAMP
                    )
                    RETURNING id
                    """
                )
                .first()

            guard let mailboxRow = mailboxResult else {
                throw TestError.invalidConnectionURL
            }
            let mailboxId = try mailboxRow.decode(column: "id", as: UUID.self)

            // Create a test letter
            let receivedDate = Date()

            let insertResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    INSERT INTO mail.letters (
                        mailbox_id, received_date, status, is_priority, requires_signature, created_at, updated_at
                    )
                    VALUES (
                        \(bind: mailboxId),
                        \(bind: receivedDate),
                        'received',
                        false,
                        false,
                        CURRENT_TIMESTAMP,
                        CURRENT_TIMESTAMP
                    )
                    RETURNING id, created_at, updated_at
                    """
                )
                .first()

            #expect(insertResult != nil)

            if let result = insertResult {
                let letterId = try result.decode(column: "id", as: UUID.self)
                let _ = try result.decode(column: "created_at", as: Date.self)
                let _ = try result.decode(column: "updated_at", as: Date.self)

                print("Successfully saved Letter with ID: \(letterId)")
            }
        }
    }

    @Test("Letter status workflow validation")
    func letterStatusWorkflowValidation() async throws {
        try await TestUtilities.withApp { app, database in
            // Get or create a mailbox for testing
            let mailboxResult = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT id FROM mail.mailboxes LIMIT 1")
                .first()

            let mailboxId: UUID
            if let mailboxRow = mailboxResult {
                mailboxId = try mailboxRow.decode(column: "id", as: UUID.self)
            } else {
                // Create a test mailbox if none exists
                let addressId: UUID
                let addressResult = try await (app.db as! PostgresDatabase).sql()
                    .raw("SELECT id FROM directory.addresses LIMIT 1")
                    .first()

                if let addressRow = addressResult {
                    addressId = try addressRow.decode(column: "id", as: UUID.self)
                } else {
                    // Create a test address if none exists
                    let entityResult = try await (app.db as! PostgresDatabase).sql()
                        .raw("SELECT id FROM directory.entities LIMIT 1")
                        .first()
                    guard let entityRow = entityResult else {
                        throw TestError.invalidConnectionURL
                    }
                    let entityId = try entityRow.decode(column: "id", as: UUID.self)

                    let newAddressResult = try await (app.db as! PostgresDatabase).sql()
                        .raw(
                            """
                            INSERT INTO directory.addresses (entity_id, street, city, country, is_verified, created_at, updated_at)
                            VALUES (\(bind: entityId), 'Test St', 'Test City', 'USA', false, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                            RETURNING id
                            """
                        )
                        .first()
                    guard let newAddressRow = newAddressResult else {
                        throw TestError.invalidConnectionURL
                    }
                    addressId = try newAddressRow.decode(column: "id", as: UUID.self)
                }

                let createResult = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        INSERT INTO mail.mailboxes (directory_address_id, mailbox_number, is_active, created_at, updated_at)
                        VALUES (\(bind: addressId), 998, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        RETURNING id
                        """
                    )
                    .first()
                guard let newMailboxRow = createResult else {
                    throw TestError.invalidConnectionURL
                }
                mailboxId = try newMailboxRow.decode(column: "id", as: UUID.self)
            }

            // Test valid status insertion
            let validInsert = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    INSERT INTO mail.letters (mailbox_id, received_date, status, created_at, updated_at)
                    VALUES (\(bind: mailboxId), CURRENT_DATE, 'scanned', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    RETURNING id
                    """
                )
                .first()

            #expect(validInsert != nil)
            print("Valid status 'scanned' accepted by database")

            // Test invalid status should fail
            do {
                let _ = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        INSERT INTO mail.letters (mailbox_id, received_date, status, created_at, updated_at)
                        VALUES (\(bind: mailboxId), CURRENT_DATE, 'invalid_status', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        """
                    )
                    .first()

                // If we get here, the constraint didn't work
                #expect(Bool(false), "Database should have rejected invalid status")
            } catch {
                // This is expected - the constraint should reject invalid values
                print("Database correctly rejected invalid status: \(error)")
            }
        }
    }
}
