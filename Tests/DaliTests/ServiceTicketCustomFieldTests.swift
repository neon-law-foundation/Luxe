import Foundation
import PostgresNIO
import Testing

@testable import Dali

@Suite("ServiceTicketCustomField Tests", .serialized)
struct ServiceTicketCustomFieldTests {
    @Test("ServiceTicketCustomField should store custom field values")
    func serviceTicketCustomFieldPropertiesAreValidated() throws {
        let id = UUID()
        let ticketId = UUID()
        let customFieldId = UUID()
        let value = "High Priority Customer"
        let createdAt = Date()
        let updatedAt = Date()

        let ticketCustomField = ServiceTicketCustomField(
            id: id,
            ticketId: ticketId,
            customFieldId: customFieldId,
            value: value,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        #expect(ticketCustomField.id == id)
        #expect(ticketCustomField.ticketId == ticketId)
        #expect(ticketCustomField.customFieldId == customFieldId)
        #expect(ticketCustomField.value == value)
        #expect(ticketCustomField.createdAt == createdAt)
        #expect(ticketCustomField.updatedAt == updatedAt)
    }

    @Test("ServiceTicketCustomField should handle text field values")
    func textFieldValueWorksCorrectly() throws {
        let ticketCustomField = ServiceTicketCustomField(
            id: UUID(),
            ticketId: UUID(),
            customFieldId: UUID(),
            value: "John Doe Customer",
            createdAt: Date(),
            updatedAt: Date()
        )

        #expect(ticketCustomField.value == "John Doe Customer")
        #expect(ticketCustomField.value.contains("Customer"))
    }

    @Test("ServiceTicketCustomField should handle select field values")
    func selectFieldValueWorksCorrectly() throws {
        let ticketCustomField = ServiceTicketCustomField(
            id: UUID(),
            ticketId: UUID(),
            customFieldId: UUID(),
            value: "Bug Report",
            createdAt: Date(),
            updatedAt: Date()
        )

        #expect(ticketCustomField.value == "Bug Report")
    }

    @Test("ServiceTicketCustomField should handle multiselect field values")
    func multiselectFieldValueWorksCorrectly() throws {
        // Multiselect values stored as JSON array string
        let multiselectValue = "[\"Email\", \"Phone\", \"Chat\"]"
        let ticketCustomField = ServiceTicketCustomField(
            id: UUID(),
            ticketId: UUID(),
            customFieldId: UUID(),
            value: multiselectValue,
            createdAt: Date(),
            updatedAt: Date()
        )

        #expect(ticketCustomField.value == multiselectValue)
        #expect(ticketCustomField.value.contains("Email"))
        #expect(ticketCustomField.value.contains("Phone"))
    }

    @Test("ServiceTicketCustomField should handle checkbox field values")
    func checkboxFieldValueWorksCorrectly() throws {
        let checkedField = ServiceTicketCustomField(
            id: UUID(),
            ticketId: UUID(),
            customFieldId: UUID(),
            value: "true",
            createdAt: Date(),
            updatedAt: Date()
        )

        let uncheckedField = ServiceTicketCustomField(
            id: UUID(),
            ticketId: UUID(),
            customFieldId: UUID(),
            value: "false",
            createdAt: Date(),
            updatedAt: Date()
        )

        #expect(checkedField.value == "true")
        #expect(uncheckedField.value == "false")
    }

    @Test("ServiceTicketCustomField should handle number field values")
    func numberFieldValueWorksCorrectly() throws {
        let ticketCustomField = ServiceTicketCustomField(
            id: UUID(),
            ticketId: UUID(),
            customFieldId: UUID(),
            value: "15000",
            createdAt: Date(),
            updatedAt: Date()
        )

        #expect(ticketCustomField.value == "15000")
        // Verify it can be converted to number
        #expect(Int(ticketCustomField.value) == 15000)
    }

    @Test("ServiceTicketCustomField should handle date field values")
    func dateFieldValueWorksCorrectly() throws {
        let dateValue = "2025-01-15"
        let ticketCustomField = ServiceTicketCustomField(
            id: UUID(),
            ticketId: UUID(),
            customFieldId: UUID(),
            value: dateValue,
            createdAt: Date(),
            updatedAt: Date()
        )

        #expect(ticketCustomField.value == dateValue)
        #expect(ticketCustomField.value.contains("2025"))
    }

    @Test("ServiceTicketCustomField should handle empty values")
    func emptyFieldValueWorksCorrectly() throws {
        let ticketCustomField = ServiceTicketCustomField(
            id: UUID(),
            ticketId: UUID(),
            customFieldId: UUID(),
            value: "",
            createdAt: Date(),
            updatedAt: Date()
        )

        #expect(ticketCustomField.value == "")
        #expect(ticketCustomField.value.isEmpty)
    }

    @Test("ServiceTicketCustomField should handle multiple values for same ticket")
    func multipleCustomFieldsPerTicketWorkCorrectly() throws {
        let ticketId = UUID()
        let customField1Id = UUID()
        let customField2Id = UUID()

        let field1 = ServiceTicketCustomField(
            id: UUID(),
            ticketId: ticketId,
            customFieldId: customField1Id,
            value: "High Priority",
            createdAt: Date(),
            updatedAt: Date()
        )

        let field2 = ServiceTicketCustomField(
            id: UUID(),
            ticketId: ticketId,
            customFieldId: customField2Id,
            value: "Enterprise Customer",
            createdAt: Date(),
            updatedAt: Date()
        )

        #expect(field1.ticketId == field2.ticketId)
        #expect(field1.customFieldId != field2.customFieldId)
        #expect(field1.value != field2.value)
        #expect(field1.id != field2.id)
    }

    @Test("ServiceTicketCustomField should be codable")
    func serviceTicketCustomFieldCodableWorksCorrectly() throws {
        let ticketCustomField = ServiceTicketCustomField(
            id: UUID(),
            ticketId: UUID(),
            customFieldId: UUID(),
            value: "Test Value",
            createdAt: Date(),
            updatedAt: Date()
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(ticketCustomField)
        let decoded = try decoder.decode(ServiceTicketCustomField.self, from: data)

        #expect(decoded.id == ticketCustomField.id)
        #expect(decoded.ticketId == ticketCustomField.ticketId)
        #expect(decoded.customFieldId == ticketCustomField.customFieldId)
        #expect(decoded.value == ticketCustomField.value)
    }
}
