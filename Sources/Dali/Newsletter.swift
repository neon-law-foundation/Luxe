import Fluent
import Foundation
import PostgresNIO
import SQLKit

public struct Newsletter: Codable, Sendable {
    public let id: UUID
    public let name: NewsletterName
    public let subjectLine: String
    public let markdownContent: String
    public let sentAt: Date?
    public let recipientCount: Int
    public let createdBy: UUID
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        name: NewsletterName,
        subjectLine: String,
        markdownContent: String,
        sentAt: Date? = nil,
        recipientCount: Int = 0,
        createdBy: UUID,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.subjectLine = subjectLine
        self.markdownContent = markdownContent
        self.sentAt = sentAt
        self.recipientCount = recipientCount
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public enum NewsletterName: String, Codable, CaseIterable, Sendable {
        case nvSciTech = "nv-sci-tech"
        case sagebrush = "sagebrush"
        case neonLaw = "neon-law"
    }

    public var isSent: Bool {
        sentAt != nil
    }

    public var isDraft: Bool {
        sentAt == nil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case subjectLine = "subject_line"
        case markdownContent = "markdown_content"
        case sentAt = "sent_at"
        case recipientCount = "recipient_count"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension Newsletter {
    public init(row: SQLRow) throws {
        self.init(
            id: try row.decode(column: "id", as: UUID.self),
            name: NewsletterName(rawValue: try row.decode(column: "name", as: String.self)) ?? .nvSciTech,
            subjectLine: try row.decode(column: "subject_line", as: String.self),
            markdownContent: try row.decode(column: "markdown_content", as: String.self),
            sentAt: try row.decode(column: "sent_at", as: Date?.self),
            recipientCount: try row.decode(column: "recipient_count", as: Int.self),
            createdBy: try row.decode(column: "created_by", as: UUID.self),
            createdAt: try row.decode(column: "created_at", as: Date.self),
            updatedAt: try row.decode(column: "updated_at", as: Date.self)
        )
    }
}
