import Fluent
import Foundation
import Vapor

/// Represents a blob reference stored in object storage (AWS S3).
///
/// **Polymorphism Pattern:**
/// This model uses polymorphism to allow a single blob storage table to be referenced
/// by multiple different entity types. The `referencedBy` field acts as a discriminator
/// that identifies which type of entity is referencing the blob, while `referencedById`
/// contains the UUID of that specific entity.
///
/// This pattern enables:
/// - A single blob storage table that can serve multiple entity types
/// - Consistent blob management across the application
/// - Easier maintenance of file storage logic
/// - Referential integrity through foreign key constraints
///
/// **Current referencing tables:**
/// - `mail.letters` (scanned_document_id field)
/// - `equity.share_issuances` (document_id field)
/// - `matters.answers` (blob_id field)
public final class Blob: Model, @unchecked Sendable {
    public static let schema = "blobs"
    public static let space = "documents"

    @ID(custom: .id, generatedBy: .database)
    public var id: UUID?

    @Field(key: "object_storage_url")
    public var objectStorageUrl: String

    /// Polymorphic discriminator indicating which type of entity references this blob
    @Field(key: "referenced_by")
    public var referencedBy: ReferencedBy

    /// UUID of the specific entity that references this blob (polymorphic foreign key)
    @Field(key: "referenced_by_id")
    public var referencedById: UUID

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    /// Creates a new Blob with the specified properties.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the blob reference. If nil, a UUID will be generated.
    ///   - objectStorageUrl: The URL or URI to the file in AWS S3.
    ///   - referencedBy: The type of entity referencing this blob.
    ///   - referencedById: The UUID of the entity referencing this blob.
    public init(
        id: UUID? = nil,
        objectStorageUrl: String,
        referencedBy: ReferencedBy,
        referencedById: UUID
    ) {
        self.id = id
        self.objectStorageUrl = objectStorageUrl
        self.referencedBy = referencedBy
        self.referencedById = referencedById
    }
}

extension Blob: Content {}

// MARK: - Referenced By Enum

extension Blob {
    /// The type of entity referencing this blob (polymorphic discriminator).
    ///
    /// This enum acts as a discriminator in the polymorphic relationship pattern,
    /// identifying which type of entity is referencing the blob. The corresponding
    /// `referencedById` field contains the UUID of that specific entity.
    ///
    /// Values must match the database CHECK constraint defined in the migration.
    public enum ReferencedBy: String, Codable, CaseIterable, Sendable {
        /// Referenced by a letter in the mail.letters table (scanned_document_id field)
        case letters = "letters"

        /// Referenced by a share issuance in the equity.share_issuances table (document_id field)
        case shareIssuances = "share_issuances"

        /// Referenced by an answer in the matters.answers table (blob_id field)
        case answers = "answers"
    }
}
