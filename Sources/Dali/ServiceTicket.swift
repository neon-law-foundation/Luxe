import Foundation
import PostgresNIO

public struct ServiceTicket: Codable, Sendable {
    public let id: UUID
    public let ticketNumber: String
    public let subject: String
    public let description: String
    public let requesterId: UUID
    public let requesterEmail: String?
    public let assigneeId: UUID?
    public let priority: Priority
    public let status: Status
    public let source: Source
    public let tags: [String]
    public let createdAt: Date
    public let updatedAt: Date
    public let resolvedAt: Date?
    public let closedAt: Date?

    public init(
        id: UUID,
        ticketNumber: String,
        subject: String,
        description: String,
        requesterId: UUID,
        requesterEmail: String?,
        assigneeId: UUID?,
        priority: Priority,
        status: Status,
        source: Source,
        tags: [String],
        createdAt: Date,
        updatedAt: Date,
        resolvedAt: Date?,
        closedAt: Date?
    ) {
        self.id = id
        self.ticketNumber = ticketNumber
        self.subject = subject
        self.description = description
        self.requesterId = requesterId
        self.requesterEmail = requesterEmail
        self.assigneeId = assigneeId
        self.priority = priority
        self.status = status
        self.source = source
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.resolvedAt = resolvedAt
        self.closedAt = closedAt
    }

    public enum Priority: String, Codable, Sendable, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"
    }

    public enum Status: String, Codable, Sendable, CaseIterable {
        case open = "open"
        case pending = "pending"
        case inProgress = "in_progress"
        case resolved = "resolved"
        case closed = "closed"
    }

    public enum Source: String, Codable, Sendable, CaseIterable {
        case email = "email"
        case web = "web"
        case phone = "phone"
        case chat = "chat"
    }
}

extension ServiceTicket: PostgresCodable {
    public static var postgresDataType: PostgresDataType {
        .jsonb
    }
}
