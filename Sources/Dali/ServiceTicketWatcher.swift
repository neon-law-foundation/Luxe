import Foundation
import PostgresNIO

public struct ServiceTicketWatcher: Codable, Sendable {
    public let id: UUID
    public let ticketId: UUID
    public let userId: UUID
    public let addedBy: UUID
    public let createdAt: Date

    public init(
        id: UUID,
        ticketId: UUID,
        userId: UUID,
        addedBy: UUID,
        createdAt: Date
    ) {
        self.id = id
        self.ticketId = ticketId
        self.userId = userId
        self.addedBy = addedBy
        self.createdAt = createdAt
    }
}

extension ServiceTicketWatcher: PostgresCodable {
    public static var postgresDataType: PostgresDataType {
        .jsonb
    }
}
