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

@Suite("Blob Tests", .serialized)
struct BlobTests {

    @Test("Blob has required fields")
    func blobHasRequiredFields() async throws {
        // Create a test blob
        let blob = Blob(
            objectStorageUrl: "s3://test-bucket/documents/letter-123.pdf",
            referencedBy: .letters,
            referencedById: UUID()
        )

        // Verify the model has all required fields
        #expect(blob.objectStorageUrl == "s3://test-bucket/documents/letter-123.pdf")
        #expect(blob.referencedBy == .letters)
        #expect(!blob.referencedById.uuidString.isEmpty)

        // ID should be nil before saving
        #expect(blob.id == nil)

        // Timestamps should be nil before saving
        #expect(blob.createdAt == nil)
        #expect(blob.updatedAt == nil)
    }

    @Test("Blob referenced by enum has valid values")
    func blobReferencedByEnumHasValidValues() async throws {
        let validTypes: [Blob.ReferencedBy] = [.letters]

        for referencedBy in validTypes {
            let blob = Blob(
                objectStorageUrl: "s3://test-bucket/file.pdf",
                referencedBy: referencedBy,
                referencedById: UUID()
            )
            #expect(blob.referencedBy == referencedBy)
        }
    }

    @Test("Blob with different storage URLs")
    func blobWithDifferentStorageUrls() async throws {
        let testUrls = [
            "s3://bucket-name/path/to/document.pdf",
            "https://s3.amazonaws.com/bucket/file.jpg",
            "s3://legal-documents/2024/letters/scan-001.pdf",
        ]

        for url in testUrls {
            let blob = Blob(
                objectStorageUrl: url,
                referencedBy: .letters,
                referencedById: UUID()
            )
            #expect(blob.objectStorageUrl == url)
        }
    }

    @Test("Blob can be saved and retrieved")
    func blobCanBeSavedAndRetrieved() async throws {
        try await TestUtilities.withApp { app, database in
            // First verify the table exists with raw SQL
            let countResult = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT COUNT(*) as count FROM documents.blobs")
                .first()

            #expect(countResult != nil)
            print("Database connection verified - documents.blobs table accessible")

            // Create a test blob
            let referencedById = UUID()
            let objectStorageUrl =
                "s3://test-bucket/documents/test-\(UniqueCodeGenerator.generateISOCode(prefix: "test")).pdf"

            let insertResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    INSERT INTO documents.blobs (
                        object_storage_url, referenced_by, referenced_by_id, created_at, updated_at
                    )
                    VALUES (
                        \(bind: objectStorageUrl),
                        'letters',
                        \(bind: referencedById),
                        CURRENT_TIMESTAMP,
                        CURRENT_TIMESTAMP
                    )
                    RETURNING id, created_at, updated_at
                    """
                )
                .first()

            #expect(insertResult != nil)

            if let result = insertResult {
                let blobId = try result.decode(column: "id", as: UUID.self)
                let _ = try result.decode(column: "created_at", as: Date.self)
                let _ = try result.decode(column: "updated_at", as: Date.self)

                print("Successfully saved Blob with ID: \(blobId)")

                // Verify we can retrieve it
                let retrieveResult = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        SELECT object_storage_url, referenced_by, referenced_by_id
                        FROM documents.blobs
                        WHERE id = \(bind: blobId)
                        """
                    )
                    .first()

                #expect(retrieveResult != nil)

                if let retrievedRow = retrieveResult {
                    let retrievedUrl = try retrievedRow.decode(column: "object_storage_url", as: String.self)
                    let retrievedType = try retrievedRow.decode(column: "referenced_by", as: String.self)
                    let retrievedId = try retrievedRow.decode(column: "referenced_by_id", as: UUID.self)

                    #expect(retrievedUrl == objectStorageUrl)
                    #expect(retrievedType == "letters")
                    #expect(retrievedId == referencedById)
                }
            }
        }
    }

    @Test("Blob referenced by constraint validation")
    func blobReferencedByConstraintValidation() async throws {
        try await TestUtilities.withApp { app, database in
            let referencedById = UUID()
            let objectStorageUrl = "s3://test-bucket/valid-document.pdf"

            // Test valid referenced_by value should succeed
            let validInsert = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    INSERT INTO documents.blobs (
                        object_storage_url, referenced_by, referenced_by_id, created_at, updated_at
                    )
                    VALUES (
                        \(bind: objectStorageUrl),
                        'letters',
                        \(bind: referencedById),
                        CURRENT_TIMESTAMP,
                        CURRENT_TIMESTAMP
                    )
                    RETURNING id
                    """
                )
                .first()

            #expect(validInsert != nil)
            print("Valid referenced_by 'letters' accepted by database")

            // Test invalid referenced_by value should fail
            do {
                let _ = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        INSERT INTO documents.blobs (
                            object_storage_url, referenced_by, referenced_by_id, created_at, updated_at
                        )
                        VALUES (
                            \(bind: objectStorageUrl),
                            'invalid_type',
                            \(bind: referencedById),
                            CURRENT_TIMESTAMP,
                            CURRENT_TIMESTAMP
                        )
                        """
                    )
                    .first()

                // If we get here, the constraint didn't work
                #expect(Bool(false), "Database should have rejected invalid referenced_by value")
            } catch {
                // This is expected - the constraint should reject invalid values
                print("Database correctly rejected invalid referenced_by: \(error)")
            }
        }
    }

    @Test("Blob unique constraint validation")
    func blobUniqueConstraintValidation() async throws {
        try await TestUtilities.withApp { app, database in
            let referencedById = UUID()
            let objectStorageUrl = "s3://test-bucket/unique-test.pdf"

            // Insert first blob
            let firstInsert = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    INSERT INTO documents.blobs (
                        object_storage_url, referenced_by, referenced_by_id, created_at, updated_at
                    )
                    VALUES (
                        \(bind: objectStorageUrl),
                        'letters',
                        \(bind: referencedById),
                        CURRENT_TIMESTAMP,
                        CURRENT_TIMESTAMP
                    )
                    RETURNING id
                    """
                )
                .first()

            #expect(firstInsert != nil)
            print("First blob with unique reference created successfully")

            // Try to insert duplicate (same referenced_by + referenced_by_id) should fail
            do {
                let _ = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        INSERT INTO documents.blobs (
                            object_storage_url, referenced_by, referenced_by_id, created_at, updated_at
                        )
                        VALUES (
                            's3://test-bucket/different-url.pdf',
                            'letters',
                            \(bind: referencedById),
                            CURRENT_TIMESTAMP,
                            CURRENT_TIMESTAMP
                        )
                        """
                    )
                    .first()

                // If we get here, the unique constraint didn't work
                #expect(Bool(false), "Database should have rejected duplicate reference")
            } catch {
                // This is expected - the unique constraint should prevent duplicates
                print("Database correctly rejected duplicate reference: \(error)")
            }
        }
    }
}
