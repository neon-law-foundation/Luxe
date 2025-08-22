import Foundation
import PostgresNIO
import Testing

@testable import Dali

@Suite("ServiceTicketAttachment Tests", .serialized)
struct ServiceTicketAttachmentTests {
    @Test("ServiceTicketAttachment should store attachment information")
    func serviceTicketAttachmentPropertiesAreValidated() throws {
        let id = UUID()
        let ticketId = UUID()
        let conversationId = UUID()
        let blobId = UUID()
        let originalFilename = "support_screenshot.png"
        let uploadedBy = UUID()
        let createdAt = Date()

        let attachment = ServiceTicketAttachment(
            id: id,
            ticketId: ticketId,
            conversationId: conversationId,
            blobId: blobId,
            originalFilename: originalFilename,
            uploadedBy: uploadedBy,
            createdAt: createdAt
        )

        #expect(attachment.id == id)
        #expect(attachment.ticketId == ticketId)
        #expect(attachment.conversationId == conversationId)
        #expect(attachment.blobId == blobId)
        #expect(attachment.originalFilename == originalFilename)
        #expect(attachment.uploadedBy == uploadedBy)
        #expect(attachment.createdAt == createdAt)
    }

    @Test("ServiceTicketAttachment should handle attachment without conversation")
    func attachmentWithoutConversationWorksCorrectly() throws {
        let attachment = ServiceTicketAttachment(
            id: UUID(),
            ticketId: UUID(),
            conversationId: nil,
            blobId: UUID(),
            originalFilename: "invoice.pdf",
            uploadedBy: UUID(),
            createdAt: Date()
        )

        #expect(attachment.conversationId == nil)
        #expect(attachment.originalFilename == "invoice.pdf")
    }

    @Test("ServiceTicketAttachment should handle various file types")
    func variousFileTypesWorkCorrectly() throws {
        let fileTypes = [
            "document.pdf",
            "screenshot.png",
            "error_log.txt",
            "recording.mp4",
            "spreadsheet.xlsx",
            "presentation.pptx",
        ]

        for filename in fileTypes {
            let attachment = ServiceTicketAttachment(
                id: UUID(),
                ticketId: UUID(),
                conversationId: UUID(),
                blobId: UUID(),
                originalFilename: filename,
                uploadedBy: UUID(),
                createdAt: Date()
            )

            #expect(attachment.originalFilename == filename)
        }
    }

    @Test("ServiceTicketAttachment should be codable")
    func serviceTicketAttachmentCodableWorksCorrectly() throws {
        let attachment = ServiceTicketAttachment(
            id: UUID(),
            ticketId: UUID(),
            conversationId: nil,
            blobId: UUID(),
            originalFilename: "test_file.jpg",
            uploadedBy: UUID(),
            createdAt: Date()
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(attachment)
        let decoded = try decoder.decode(ServiceTicketAttachment.self, from: data)

        #expect(decoded.id == attachment.id)
        #expect(decoded.ticketId == attachment.ticketId)
        #expect(decoded.conversationId == attachment.conversationId)
        #expect(decoded.blobId == attachment.blobId)
        #expect(decoded.originalFilename == attachment.originalFilename)
        #expect(decoded.uploadedBy == attachment.uploadedBy)
    }
}
