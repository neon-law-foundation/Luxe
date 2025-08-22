import Foundation
import PostgresNIO

public struct ServiceTicketAttachment: Codable, Sendable {
    public let id: UUID
    public let ticketId: UUID
    public let conversationId: UUID?
    public let blobId: UUID
    public let originalFilename: String
    public let uploadedBy: UUID
    public let createdAt: Date

    public init(
        id: UUID,
        ticketId: UUID,
        conversationId: UUID?,
        blobId: UUID,
        originalFilename: String,
        uploadedBy: UUID,
        createdAt: Date
    ) {
        self.id = id
        self.ticketId = ticketId
        self.conversationId = conversationId
        self.blobId = blobId
        self.originalFilename = originalFilename
        self.uploadedBy = uploadedBy
        self.createdAt = createdAt
    }
}

extension ServiceTicketAttachment: PostgresCodable {
    public static var postgresDataType: PostgresDataType {
        .jsonb
    }
}
