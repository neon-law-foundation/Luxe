import Foundation
import PostgresNIO

public struct ServiceTicketConversation: Codable, Sendable {
    public let id: UUID
    public let ticketId: UUID
    public let userId: UUID?
    public let content: String
    public let contentType: ContentType
    public let isInternal: Bool
    public let isSystemMessage: Bool
    public let messageType: MessageType
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        ticketId: UUID,
        userId: UUID?,
        content: String,
        contentType: ContentType,
        isInternal: Bool,
        isSystemMessage: Bool,
        messageType: MessageType,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.ticketId = ticketId
        self.userId = userId
        self.content = content
        self.contentType = contentType
        self.isInternal = isInternal
        self.isSystemMessage = isSystemMessage
        self.messageType = messageType
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public enum ContentType: String, Codable, Sendable, CaseIterable {
        case text = "text"
        case html = "html"
    }

    public enum MessageType: String, Codable, Sendable, CaseIterable {
        case comment = "comment"
        case statusChange = "status_change"
        case assignmentChange = "assignment_change"
    }
}

extension ServiceTicketConversation: PostgresCodable {
    public static var postgresDataType: PostgresDataType {
        .jsonb
    }
}
