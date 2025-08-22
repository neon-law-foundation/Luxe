import Foundation
import PostgresNIO
import Testing

@testable import Dali

@Suite("ServiceCustomField Tests", .serialized)
struct ServiceCustomFieldTests {
    @Test("ServiceCustomField should store custom field definition")
    func serviceCustomFieldPropertiesAreValidated() throws {
        let id = UUID()
        let name = "Priority Level"
        let fieldType = ServiceCustomField.FieldType.select
        let description = "Customer priority classification"
        let required = true
        let options = ["Low", "Medium", "High", "Critical"]
        let position = 5
        let createdBy = UUID()
        let createdAt = Date()
        let updatedAt = Date()

        let customField = ServiceCustomField(
            id: id,
            name: name,
            fieldType: fieldType,
            description: description,
            required: required,
            options: options,
            position: position,
            createdBy: createdBy,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        #expect(customField.id == id)
        #expect(customField.name == name)
        #expect(customField.fieldType == fieldType)
        #expect(customField.description == description)
        #expect(customField.required == required)
        #expect(customField.options == options)
        #expect(customField.position == position)
        #expect(customField.createdBy == createdBy)
        #expect(customField.createdAt == createdAt)
        #expect(customField.updatedAt == updatedAt)
    }

    @Test("ServiceCustomField FieldType should have all expected types")
    func fieldTypeEnumWorksCorrectly() throws {
        let allTypes = ServiceCustomField.FieldType.allCases

        #expect(allTypes.contains(.text))
        #expect(allTypes.contains(.textarea))
        #expect(allTypes.contains(.number))
        #expect(allTypes.contains(.date))
        #expect(allTypes.contains(.select))
        #expect(allTypes.contains(.multiselect))
        #expect(allTypes.contains(.checkbox))
        #expect(allTypes.count == 7)
    }

    @Test("ServiceCustomField should handle text field type")
    func textFieldTypeWorksCorrectly() throws {
        let customField = ServiceCustomField(
            id: UUID(),
            name: "Customer Name",
            fieldType: .text,
            description: "Name of the customer",
            required: true,
            options: nil,  // Text fields don't need options
            position: 1,
            createdBy: UUID(),
            createdAt: Date(),
            updatedAt: Date()
        )

        #expect(customField.fieldType == .text)
        #expect(customField.options == nil)
        #expect(customField.required == true)
    }

    @Test("ServiceCustomField should handle select field with options")
    func selectFieldWithOptionsWorksCorrectly() throws {
        let options = ["Bug", "Feature Request", "Question", "Complaint"]
        let customField = ServiceCustomField(
            id: UUID(),
            name: "Issue Type",
            fieldType: .select,
            description: "Type of customer issue",
            required: true,
            options: options,
            position: 2,
            createdBy: UUID(),
            createdAt: Date(),
            updatedAt: Date()
        )

        #expect(customField.fieldType == .select)
        #expect(customField.options == options)
        #expect(customField.options?.count == 4)
    }

    @Test("ServiceCustomField should handle multiselect field")
    func multiselectFieldWorksCorrectly() throws {
        let options = ["Email", "Phone", "Chat", "Video Call"]
        let customField = ServiceCustomField(
            id: UUID(),
            name: "Contact Preferences",
            fieldType: .multiselect,
            description: "Preferred contact methods",
            required: false,
            options: options,
            position: 3,
            createdBy: UUID(),
            createdAt: Date(),
            updatedAt: Date()
        )

        #expect(customField.fieldType == .multiselect)
        #expect(customField.required == false)
        #expect(customField.options?.contains("Email") == true)
        #expect(customField.options?.contains("Phone") == true)
    }

    @Test("ServiceCustomField should handle checkbox field")
    func checkboxFieldWorksCorrectly() throws {
        let customField = ServiceCustomField(
            id: UUID(),
            name: "Urgent Issue",
            fieldType: .checkbox,
            description: "Mark as urgent if immediate attention needed",
            required: false,
            options: nil,  // Checkbox doesn't need options
            position: 4,
            createdBy: UUID(),
            createdAt: Date(),
            updatedAt: Date()
        )

        #expect(customField.fieldType == .checkbox)
        #expect(customField.options == nil)
        #expect(customField.required == false)
    }

    @Test("ServiceCustomField should handle number field")
    func numberFieldWorksCorrectly() throws {
        let customField = ServiceCustomField(
            id: UUID(),
            name: "Budget Range",
            fieldType: .number,
            description: "Estimated budget for the project",
            required: false,
            options: nil,
            position: 6,
            createdBy: UUID(),
            createdAt: Date(),
            updatedAt: Date()
        )

        #expect(customField.fieldType == .number)
        #expect(customField.options == nil)
    }

    @Test("ServiceCustomField should handle date field")
    func dateFieldWorksCorrectly() throws {
        let customField = ServiceCustomField(
            id: UUID(),
            name: "Expected Resolution Date",
            fieldType: .date,
            description: "When customer expects issue to be resolved",
            required: false,
            options: nil,
            position: 7,
            createdBy: UUID(),
            createdAt: Date(),
            updatedAt: Date()
        )

        #expect(customField.fieldType == .date)
        #expect(customField.description?.contains("resolved") == true)
    }

    @Test("ServiceCustomField should be codable")
    func serviceCustomFieldCodableWorksCorrectly() throws {
        let customField = ServiceCustomField(
            id: UUID(),
            name: "Test Field",
            fieldType: .select,
            description: "Test description",
            required: true,
            options: ["Option 1", "Option 2"],
            position: 1,
            createdBy: UUID(),
            createdAt: Date(),
            updatedAt: Date()
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(customField)
        let decoded = try decoder.decode(ServiceCustomField.self, from: data)

        #expect(decoded.id == customField.id)
        #expect(decoded.name == customField.name)
        #expect(decoded.fieldType == customField.fieldType)
        #expect(decoded.description == customField.description)
        #expect(decoded.required == customField.required)
        #expect(decoded.options == customField.options)
        #expect(decoded.position == customField.position)
        #expect(decoded.createdBy == customField.createdBy)
    }
}
