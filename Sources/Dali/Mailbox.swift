import Fluent
import Foundation
import Vapor

/// Represents a mailbox at a physical address in the mail schema.
///
/// The `Mailbox` model stores mailbox information that is linked to specific physical
/// addresses in the directory system. Each mailbox has a unique number at its address
/// and can be activated or deactivated for mail receiving.
///
/// ## Database Schema
/// This model maps to the `mail.mailboxes` table with the following structure:
/// - `id`: UUID primary key
/// - `directory_address_id`: Foreign key to `directory.address`
/// - `mailbox_number`: Integer mailbox number at the address
/// - `is_active`: Boolean indicating if the mailbox can receive mail
/// - `created_at`: Timestamp of creation
/// - `updated_at`: Timestamp of last update
///
/// ## Usage
/// ```swift
/// let mailbox = Mailbox(
///     directoryAddressId: address.id!,
///     mailboxNumber: 9000,
///     isActive: true
/// )
/// try await mailbox.create(on: app.db)
/// ```
public final class Mailbox: Model, @unchecked Sendable {
    public static let schema = "mailboxes"
    public static let space = "mail"

    @ID(custom: .id, generatedBy: .database)
    public var id: UUID?

    @Field(key: "directory_address_id")
    public var directoryAddressId: UUID

    @Field(key: "mailbox_number")
    public var mailboxNumber: Int

    @Field(key: "is_active")
    public var isActive: Bool

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    /// Creates a new Mailbox with the specified properties.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the mailbox. If nil, a UUID will be generated.
    ///   - directoryAddressId: The UUID of the directory.address where this mailbox is located.
    ///   - mailboxNumber: The mailbox number at the given address.
    ///   - isActive: Whether the mailbox is currently active and can receive mail.
    public init(
        id: UUID? = nil,
        directoryAddressId: UUID,
        mailboxNumber: Int,
        isActive: Bool = true
    ) {
        self.id = id
        self.directoryAddressId = directoryAddressId
        self.mailboxNumber = mailboxNumber
        self.isActive = isActive
    }
}

extension Mailbox: Content {}
