import Foundation
import PostgresNIO

public struct ServiceTicketCustomField: Codable, Sendable {
    public let id: UUID
    public let ticketId: UUID
    public let customFieldId: UUID
    public let value: String
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        ticketId: UUID,
        customFieldId: UUID,
        value: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.ticketId = ticketId
        self.customFieldId = customFieldId
        self.value = value
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension ServiceTicketCustomField: PostgresCodable {
    public static var postgresDataType: PostgresDataType {
        .jsonb
    }
}
