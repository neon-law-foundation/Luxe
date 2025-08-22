import Foundation
import PostgresNIO
import Testing

@testable import Dali

@Suite("ServiceTicketAssignment Tests", .serialized)
struct ServiceTicketAssignmentTests {
    @Test("ServiceTicketAssignment should store assignment information")
    func serviceTicketAssignmentPropertiesAreValidated() throws {
        let id = UUID()
        let ticketId = UUID()
        let assignedTo = UUID()
        let assignedFrom = UUID()
        let assignedBy = UUID()
        let assignmentReason = "Ticket escalated to senior support"
        let createdAt = Date()

        let assignment = ServiceTicketAssignment(
            id: id,
            ticketId: ticketId,
            assignedTo: assignedTo,
            assignedFrom: assignedFrom,
            assignedBy: assignedBy,
            assignmentReason: assignmentReason,
            createdAt: createdAt
        )

        #expect(assignment.id == id)
        #expect(assignment.ticketId == ticketId)
        #expect(assignment.assignedTo == assignedTo)
        #expect(assignment.assignedFrom == assignedFrom)
        #expect(assignment.assignedBy == assignedBy)
        #expect(assignment.assignmentReason == assignmentReason)
        #expect(assignment.createdAt == createdAt)
    }

    @Test("ServiceTicketAssignment should handle initial assignment")
    func initialAssignmentWorksCorrectly() throws {
        let assignment = ServiceTicketAssignment(
            id: UUID(),
            ticketId: UUID(),
            assignedTo: UUID(),
            assignedFrom: nil,  // Initial assignment has no previous assignee
            assignedBy: UUID(),
            assignmentReason: "Initial assignment to support team",
            createdAt: Date()
        )

        #expect(assignment.assignedFrom == nil)
        #expect(assignment.assignmentReason == "Initial assignment to support team")
    }

    @Test("ServiceTicketAssignment should handle unassignment")
    func unassignmentWorksCorrectly() throws {
        let assignment = ServiceTicketAssignment(
            id: UUID(),
            ticketId: UUID(),
            assignedTo: nil,  // Unassigned
            assignedFrom: UUID(),
            assignedBy: UUID(),
            assignmentReason: "Unassigned pending review",
            createdAt: Date()
        )

        #expect(assignment.assignedTo == nil)
        #expect(assignment.assignmentReason == "Unassigned pending review")
    }

    @Test("ServiceTicketAssignment should handle reassignment")
    func reassignmentWorksCorrectly() throws {
        let fromUserId = UUID()
        let toUserId = UUID()
        let byUserId = UUID()

        let assignment = ServiceTicketAssignment(
            id: UUID(),
            ticketId: UUID(),
            assignedTo: toUserId,
            assignedFrom: fromUserId,
            assignedBy: byUserId,
            assignmentReason: "Reassigned due to workload balancing",
            createdAt: Date()
        )

        #expect(assignment.assignedTo == toUserId)
        #expect(assignment.assignedFrom == fromUserId)
        #expect(assignment.assignedBy == byUserId)
        #expect(assignment.assignmentReason?.contains("workload") == true)
    }

    @Test("ServiceTicketAssignment should handle optional assignment reason")
    func optionalAssignmentReasonWorksCorrectly() throws {
        let assignment = ServiceTicketAssignment(
            id: UUID(),
            ticketId: UUID(),
            assignedTo: UUID(),
            assignedFrom: nil,
            assignedBy: UUID(),
            assignmentReason: nil,
            createdAt: Date()
        )

        #expect(assignment.assignmentReason == nil)
    }

    @Test("ServiceTicketAssignment should be codable")
    func serviceTicketAssignmentCodableWorksCorrectly() throws {
        let assignment = ServiceTicketAssignment(
            id: UUID(),
            ticketId: UUID(),
            assignedTo: UUID(),
            assignedFrom: UUID(),
            assignedBy: UUID(),
            assignmentReason: "Test assignment",
            createdAt: Date()
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(assignment)
        let decoded = try decoder.decode(ServiceTicketAssignment.self, from: data)

        #expect(decoded.id == assignment.id)
        #expect(decoded.ticketId == assignment.ticketId)
        #expect(decoded.assignedTo == assignment.assignedTo)
        #expect(decoded.assignedFrom == assignment.assignedFrom)
        #expect(decoded.assignedBy == assignment.assignedBy)
        #expect(decoded.assignmentReason == assignment.assignmentReason)
    }
}
