import Foundation
import PostgresNIO

public struct ServiceTicketAssignment: Codable, Sendable {
    public let id: UUID
    public let ticketId: UUID
    public let assignedTo: UUID?
    public let assignedFrom: UUID?
    public let assignedBy: UUID?
    public let assignmentReason: String?
    public let createdAt: Date

    public init(
        id: UUID,
        ticketId: UUID,
        assignedTo: UUID?,
        assignedFrom: UUID?,
        assignedBy: UUID?,
        assignmentReason: String?,
        createdAt: Date
    ) {
        self.id = id
        self.ticketId = ticketId
        self.assignedTo = assignedTo
        self.assignedFrom = assignedFrom
        self.assignedBy = assignedBy
        self.assignmentReason = assignmentReason
        self.createdAt = createdAt
    }
}

extension ServiceTicketAssignment: PostgresCodable {
    public static var postgresDataType: PostgresDataType {
        .jsonb
    }
}
