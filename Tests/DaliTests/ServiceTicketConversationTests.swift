import Foundation
import PostgresNIO
import Testing

@testable import Dali

@Suite("ServiceTicketConversation Tests", .serialized)
struct ServiceTicketConversationTests {
    @Test("ServiceTicketConversation should store conversation information")
    func serviceTicketConversationPropertiesAreValidated() throws {
        let id = UUID()
        let ticketId = UUID()
        let userId = UUID()
        let content = "Thank you for contacting support. We're looking into your issue."
        let contentType = ServiceTicketConversation.ContentType.text
        let isInternal = false
        let isSystemMessage = false
        let messageType = ServiceTicketConversation.MessageType.comment
        let createdAt = Date()
        let updatedAt = Date()

        let conversation = ServiceTicketConversation(
            id: id,
            ticketId: ticketId,
            userId: userId,
            content: content,
            contentType: contentType,
            isInternal: isInternal,
            isSystemMessage: isSystemMessage,
            messageType: messageType,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        #expect(conversation.id == id)
        #expect(conversation.ticketId == ticketId)
        #expect(conversation.userId == userId)
        #expect(conversation.content == content)
        #expect(conversation.contentType == contentType)
        #expect(conversation.isInternal == isInternal)
        #expect(conversation.isSystemMessage == isSystemMessage)
        #expect(conversation.messageType == messageType)
        #expect(conversation.createdAt == createdAt)
        #expect(conversation.updatedAt == updatedAt)
    }

    @Test("ServiceTicketConversation ContentType should have correct cases")
    func contentTypeEnumWorksCorrectly() throws {
        #expect(ServiceTicketConversation.ContentType.text.rawValue == "text")
        #expect(ServiceTicketConversation.ContentType.html.rawValue == "html")
    }

    @Test("ServiceTicketConversation MessageType should have correct cases")
    func messageTypeEnumWorksCorrectly() throws {
        #expect(ServiceTicketConversation.MessageType.comment.rawValue == "comment")
        #expect(ServiceTicketConversation.MessageType.statusChange.rawValue == "status_change")
        #expect(ServiceTicketConversation.MessageType.assignmentChange.rawValue == "assignment_change")
    }

    @Test("ServiceTicketConversation should handle system messages")
    func systemMessageWorksCorrectly() throws {
        let conversation = ServiceTicketConversation(
            id: UUID(),
            ticketId: UUID(),
            userId: nil,  // System messages may not have a user
            content: "Ticket status changed from 'open' to 'in_progress'",
            contentType: .text,
            isInternal: false,
            isSystemMessage: true,
            messageType: .statusChange,
            createdAt: Date(),
            updatedAt: Date()
        )

        #expect(conversation.userId == nil)
        #expect(conversation.isSystemMessage == true)
        #expect(conversation.messageType == .statusChange)
    }

    @Test("ServiceTicketConversation should handle internal notes")
    func internalNoteWorksCorrectly() throws {
        let conversation = ServiceTicketConversation(
            id: UUID(),
            ticketId: UUID(),
            userId: UUID(),
            content: "Customer seems frustrated, handle with care",
            contentType: .text,
            isInternal: true,
            isSystemMessage: false,
            messageType: .comment,
            createdAt: Date(),
            updatedAt: Date()
        )

        #expect(conversation.isInternal == true)
        #expect(conversation.isSystemMessage == false)
    }

    @Test("ServiceTicketConversation should be codable")
    func serviceTicketConversationCodableWorksCorrectly() throws {
        let conversation = ServiceTicketConversation(
            id: UUID(),
            ticketId: UUID(),
            userId: UUID(),
            content: "Test message",
            contentType: .html,
            isInternal: false,
            isSystemMessage: false,
            messageType: .comment,
            createdAt: Date(),
            updatedAt: Date()
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(conversation)
        let decoded = try decoder.decode(ServiceTicketConversation.self, from: data)

        #expect(decoded.id == conversation.id)
        #expect(decoded.ticketId == conversation.ticketId)
        #expect(decoded.userId == conversation.userId)
        #expect(decoded.content == conversation.content)
        #expect(decoded.contentType == conversation.contentType)
        #expect(decoded.messageType == conversation.messageType)
    }
}
