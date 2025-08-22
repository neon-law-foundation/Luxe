import Fluent
import Foundation
import Vapor

/// Represents a letter received at a physical address
public final class Letter: Model, @unchecked Sendable {
    public static let schema = "letters"
    public static let space = "mail"

    @ID(custom: .id, generatedBy: .database)
    public var id: UUID?

    @Field(key: "mailbox_id")
    public var mailboxId: UUID

    @OptionalField(key: "sender_address_id")
    public var senderAddressId: UUID?

    @Field(key: "received_date")
    public var receivedDate: Date

    @OptionalField(key: "postmark_date")
    public var postmarkDate: Date?

    @OptionalField(key: "tracking_number")
    public var trackingNumber: String?

    @OptionalField(key: "carrier")
    public var carrier: String?

    @OptionalField(key: "letter_type")
    public var letterType: String?

    @Field(key: "status")
    public var status: Status

    @OptionalField(key: "scanned_at")
    public var scannedAt: Date?

    @OptionalField(key: "scanned_by")
    public var scannedBy: UUID?

    @OptionalField(key: "scanned_document_id")
    public var scannedDocumentId: UUID?

    @OptionalField(key: "emailed_at")
    public var emailedAt: Date?

    @OptionalField(key: "emailed_to")
    public var emailedTo: [String]?

    @OptionalField(key: "forwarded_at")
    public var forwardedAt: Date?

    @OptionalField(key: "forwarded_to_address")
    public var forwardedToAddress: String?

    @OptionalField(key: "forwarding_tracking_number")
    public var forwardingTrackingNumber: String?

    @OptionalField(key: "shredded_at")
    public var shreddedAt: Date?

    @OptionalField(key: "returned_at")
    public var returnedAt: Date?

    @OptionalField(key: "return_reason")
    public var returnReason: String?

    @OptionalField(key: "notes")
    public var notes: String?

    @Field(key: "is_priority")
    public var isPriority: Bool

    @Field(key: "requires_signature")
    public var requiresSignature: Bool

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    /// Creates a new Letter with the required fields.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the letter. If nil, a UUID will be generated.
    ///   - mailboxId: The UUID of the mailbox that received the letter.
    ///   - receivedDate: The date when the letter was physically received.
    ///   - status: The current processing status of the letter.
    ///   - senderAddressId: Optional UUID reference to the sender's address.
    ///   - postmarkDate: Optional date from the postal cancellation mark.
    ///   - trackingNumber: Optional tracking number for trackable mail.
    ///   - carrier: Optional delivery service name.
    ///   - letterType: Optional classification of the mail type.
    ///   - scannedAt: Optional timestamp when the letter was scanned.
    ///   - scannedBy: Optional UUID of the user who scanned the letter.
    ///   - scannedDocumentId: Optional UUID reference to the scanned document.
    ///   - emailedAt: Optional timestamp when the scan was emailed.
    ///   - emailedTo: Optional array of email addresses the scan was sent to.
    ///   - forwardedAt: Optional timestamp when the letter was forwarded.
    ///   - forwardedToAddress: Optional address where the letter was forwarded.
    ///   - forwardingTrackingNumber: Optional tracking number for forwarded mail.
    ///   - shreddedAt: Optional timestamp when the letter was destroyed.
    ///   - returnedAt: Optional timestamp when the letter was returned.
    ///   - returnReason: Optional reason for returning the letter.
    ///   - notes: Optional additional notes about the letter.
    ///   - isPriority: Whether the letter requires urgent handling.
    ///   - requiresSignature: Whether the letter requires signature confirmation.
    public init(
        id: UUID? = nil,
        mailboxId: UUID,
        receivedDate: Date,
        status: Status,
        senderAddressId: UUID? = nil,
        postmarkDate: Date? = nil,
        trackingNumber: String? = nil,
        carrier: String? = nil,
        letterType: String? = nil,
        scannedAt: Date? = nil,
        scannedBy: UUID? = nil,
        scannedDocumentId: UUID? = nil,
        emailedAt: Date? = nil,
        emailedTo: [String]? = nil,
        forwardedAt: Date? = nil,
        forwardedToAddress: String? = nil,
        forwardingTrackingNumber: String? = nil,
        shreddedAt: Date? = nil,
        returnedAt: Date? = nil,
        returnReason: String? = nil,
        notes: String? = nil,
        isPriority: Bool = false,
        requiresSignature: Bool = false
    ) {
        self.id = id
        self.mailboxId = mailboxId
        self.receivedDate = receivedDate
        self.status = status
        self.senderAddressId = senderAddressId
        self.postmarkDate = postmarkDate
        self.trackingNumber = trackingNumber
        self.carrier = carrier
        self.letterType = letterType
        self.scannedAt = scannedAt
        self.scannedBy = scannedBy
        self.scannedDocumentId = scannedDocumentId
        self.emailedAt = emailedAt
        self.emailedTo = emailedTo
        self.forwardedAt = forwardedAt
        self.forwardedToAddress = forwardedToAddress
        self.forwardingTrackingNumber = forwardingTrackingNumber
        self.shreddedAt = shreddedAt
        self.returnedAt = returnedAt
        self.returnReason = returnReason
        self.notes = notes
        self.isPriority = isPriority
        self.requiresSignature = requiresSignature
    }
}

extension Letter: Content {}

// MARK: - Letter Status Enum

extension Letter {
    /// The processing status of the letter, matching the database enum constraint.
    public enum Status: String, Codable, CaseIterable, Sendable {
        /// Letter has been received at the mailbox
        case received = "received"
        /// Letter has been scanned and digitized
        case scanned = "scanned"
        /// Scanned letter has been emailed to the customer
        case emailed = "emailed"
        /// Letter has been physically forwarded to another address
        case forwarded = "forwarded"
        /// Letter has been securely destroyed
        case shredded = "shredded"
        /// Letter has been returned to sender
        case returned = "returned"
    }
}
