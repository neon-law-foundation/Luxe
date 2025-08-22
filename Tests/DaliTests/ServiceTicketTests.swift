import Foundation
import PostgresNIO
import Testing

@testable import Dali

@Suite("ServiceTicket Tests", .serialized)
struct ServiceTicketTests {
    @Test("ServiceTicket should store all ticket information")
    func serviceTicketPropertiesAreValidated() throws {
        let id = UUID()
        let ticketNumber = "TKT-001234"
        let subject = "Cannot access my account"
        let description = "I'm unable to log in to my account since yesterday"
        let requesterId = UUID()
        let requesterEmail = "user@example.com"
        let assigneeId = UUID()
        let priority = ServiceTicket.Priority.high
        let status = ServiceTicket.Status.open
        let source = ServiceTicket.Source.web
        let tags = ["login", "account-access"]
        let createdAt = Date()
        let updatedAt = Date()
        let resolvedAt = Date()
        let closedAt = Date()

        let ticket = ServiceTicket(
            id: id,
            ticketNumber: ticketNumber,
            subject: subject,
            description: description,
            requesterId: requesterId,
            requesterEmail: requesterEmail,
            assigneeId: assigneeId,
            priority: priority,
            status: status,
            source: source,
            tags: tags,
            createdAt: createdAt,
            updatedAt: updatedAt,
            resolvedAt: resolvedAt,
            closedAt: closedAt
        )

        #expect(ticket.id == id)
        #expect(ticket.ticketNumber == ticketNumber)
        #expect(ticket.subject == subject)
        #expect(ticket.description == description)
        #expect(ticket.requesterId == requesterId)
        #expect(ticket.requesterEmail == requesterEmail)
        #expect(ticket.assigneeId == assigneeId)
        #expect(ticket.priority == priority)
        #expect(ticket.status == status)
        #expect(ticket.source == source)
        #expect(ticket.tags == tags)
        #expect(ticket.createdAt == createdAt)
        #expect(ticket.updatedAt == updatedAt)
        #expect(ticket.resolvedAt == resolvedAt)
        #expect(ticket.closedAt == closedAt)
    }

    @Test("ServiceTicket Priority should have correct cases")
    func priorityEnumWorksCorrectly() throws {
        #expect(ServiceTicket.Priority.low.rawValue == "low")
        #expect(ServiceTicket.Priority.medium.rawValue == "medium")
        #expect(ServiceTicket.Priority.high.rawValue == "high")
        #expect(ServiceTicket.Priority.critical.rawValue == "critical")
    }

    @Test("ServiceTicket Status should have correct cases")
    func statusEnumWorksCorrectly() throws {
        #expect(ServiceTicket.Status.open.rawValue == "open")
        #expect(ServiceTicket.Status.pending.rawValue == "pending")
        #expect(ServiceTicket.Status.inProgress.rawValue == "in_progress")
        #expect(ServiceTicket.Status.resolved.rawValue == "resolved")
        #expect(ServiceTicket.Status.closed.rawValue == "closed")
    }

    @Test("ServiceTicket Source should have correct cases")
    func sourceEnumWorksCorrectly() throws {
        #expect(ServiceTicket.Source.email.rawValue == "email")
        #expect(ServiceTicket.Source.web.rawValue == "web")
        #expect(ServiceTicket.Source.phone.rawValue == "phone")
        #expect(ServiceTicket.Source.chat.rawValue == "chat")
    }

    @Test("ServiceTicket should be codable")
    func serviceTicketCodableWorksCorrectly() throws {
        let ticket = ServiceTicket(
            id: UUID(),
            ticketNumber: "TKT-001235",
            subject: "Billing question",
            description: "I have a question about my invoice",
            requesterId: UUID(),
            requesterEmail: nil,
            assigneeId: nil,
            priority: .medium,
            status: .open,
            source: .email,
            tags: ["billing"],
            createdAt: Date(),
            updatedAt: Date(),
            resolvedAt: nil,
            closedAt: nil
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(ticket)
        let decoded = try decoder.decode(ServiceTicket.self, from: data)

        #expect(decoded.id == ticket.id)
        #expect(decoded.ticketNumber == ticket.ticketNumber)
        #expect(decoded.subject == ticket.subject)
        #expect(decoded.description == ticket.description)
        #expect(decoded.priority == ticket.priority)
        #expect(decoded.status == ticket.status)
        #expect(decoded.source == ticket.source)
        #expect(decoded.tags == ticket.tags)
    }

    @Test("ServiceTicket should handle optional fields")
    func serviceTicketOptionalFieldsWorkCorrectly() throws {
        let ticket = ServiceTicket(
            id: UUID(),
            ticketNumber: "TKT-001236",
            subject: "General inquiry",
            description: "I need some information",
            requesterId: UUID(),
            requesterEmail: nil,
            assigneeId: nil,
            priority: .low,
            status: .open,
            source: .web,
            tags: [],
            createdAt: Date(),
            updatedAt: Date(),
            resolvedAt: nil,
            closedAt: nil
        )

        #expect(ticket.requesterEmail == nil)
        #expect(ticket.assigneeId == nil)
        #expect(ticket.resolvedAt == nil)
        #expect(ticket.closedAt == nil)
        #expect(ticket.tags.isEmpty)
    }
}
