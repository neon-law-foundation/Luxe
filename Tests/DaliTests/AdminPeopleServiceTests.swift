import Fluent
import FluentPostgresDriver
import Logging
import PostgresNIO
import TestUtilities
import Testing
import Vapor

@testable import Dali
@testable import Palette

@Suite("Admin People Service Tests", .serialized)
struct AdminPeopleServiceTests {

    @Test("AdminPeopleService can list people")
    func adminPeopleServiceCanListPeople() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminPeopleService(database: database)

            // Create a test person first
            let uniqueEmail = "test_\(UniqueCodeGenerator.generateISOCode(prefix: "PEOPLE"))@example.com"
            let testPerson = Person(
                name: "Test Person \(UniqueCodeGenerator.generateISOCode(prefix: "TEST"))",
                email: uniqueEmail
            )
            try await testPerson.save(on: database)

            // Test listing people
            let people = try await service.listPeople()

            #expect(people.count >= 1)
            #expect(people.contains { $0.email == uniqueEmail })
        }
    }

    @Test("AdminPeopleService can get person by ID")
    func adminPeopleServiceCanGetPersonById() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminPeopleService(database: database)

            // Create a test person
            let uniqueEmail = "get_test_\(UniqueCodeGenerator.generateISOCode(prefix: "GET"))@example.com"
            let testPerson = Person(
                name: "Get Test Person \(UniqueCodeGenerator.generateISOCode(prefix: "GET"))",
                email: uniqueEmail
            )
            try await testPerson.save(on: database)

            // Test getting person by ID
            guard let personId = testPerson.id else {
                throw ValidationError("Person ID not available after save")
            }

            let retrievedPerson = try await service.getPerson(personId: personId)

            #expect(retrievedPerson != nil)
            #expect(retrievedPerson?.email == uniqueEmail)
            #expect(retrievedPerson?.name == testPerson.name)
        }
    }

    @Test("AdminPeopleService can create person")
    func adminPeopleServiceCanCreatePerson() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminPeopleService(database: database)

            let uniqueEmail = "create_test_\(UniqueCodeGenerator.generateISOCode(prefix: "CREATE"))@example.com"
            let testName = "Create Test Person \(UniqueCodeGenerator.generateISOCode(prefix: "CREATE"))"

            let createdPerson = try await service.createPerson(
                name: testName,
                email: uniqueEmail
            )

            #expect(createdPerson.name == testName)
            #expect(createdPerson.email == uniqueEmail.lowercased())  // Database normalizes emails to lowercase
            #expect(createdPerson.id != nil)

            // Verify person was actually saved to database
            let retrievedPerson = try await service.getPerson(personId: createdPerson.id!)
            #expect(retrievedPerson?.email == uniqueEmail.lowercased())  // Database normalizes emails to lowercase
        }
    }

    @Test("AdminPeopleService can update person")
    func adminPeopleServiceCanUpdatePerson() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminPeopleService(database: database)

            // Create a test person first
            let originalEmail = "update_test_\(UniqueCodeGenerator.generateISOCode(prefix: "UPDATE"))@example.com"
            let testPerson = Person(
                name: "Original Name \(UniqueCodeGenerator.generateISOCode(prefix: "ORIG"))",
                email: originalEmail
            )
            try await testPerson.save(on: database)

            // Update the person
            let newName = "Updated Name \(UniqueCodeGenerator.generateISOCode(prefix: "UPD"))"
            let newEmail = "updated_\(UniqueCodeGenerator.generateISOCode(prefix: "UPD"))@example.com"

            let updatedPerson = try await service.updatePerson(
                personId: testPerson.id!,
                name: newName,
                email: newEmail
            )

            #expect(updatedPerson.name == newName)
            #expect(updatedPerson.email == newEmail.lowercased())  // Database normalizes emails to lowercase
            #expect(updatedPerson.id == testPerson.id)

            // Verify changes were persisted
            let retrievedPerson = try await service.getPerson(personId: testPerson.id!)
            #expect(retrievedPerson?.name == newName)
            #expect(retrievedPerson?.email == newEmail.lowercased())  // Database normalizes emails to lowercase
        }
    }

    @Test("AdminPeopleService can delete person")
    func adminPeopleServiceCanDeletePerson() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminPeopleService(database: database)

            // Create a test person first
            let uniqueEmail = "delete_test_\(UniqueCodeGenerator.generateISOCode(prefix: "DELETE"))@example.com"
            let testPerson = Person(
                name: "Delete Test Person \(UniqueCodeGenerator.generateISOCode(prefix: "DELETE"))",
                email: uniqueEmail
            )
            try await testPerson.save(on: database)

            // Verify person exists
            let personBeforeDelete = try await service.getPerson(personId: testPerson.id!)
            #expect(personBeforeDelete != nil)

            // Delete the person
            try await service.deletePerson(personId: testPerson.id!)

            // Verify person no longer exists
            let personAfterDelete = try await service.getPerson(personId: testPerson.id!)
            #expect(personAfterDelete == nil)
        }
    }

    @Test("AdminPeopleService handles non-existent person gracefully")
    func adminPeopleServiceHandlesNonExistentPerson() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminPeopleService(database: database)

            let nonExistentId = UUID()
            let retrievedPerson = try await service.getPerson(personId: nonExistentId)

            #expect(retrievedPerson == nil)
        }
    }

    @Test("AdminPeopleService validates input data")
    func adminPeopleServiceValidatesInputData() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminPeopleService(database: database)

            // Test with empty name
            do {
                _ = try await service.createPerson(name: "", email: "test@example.com")
                #expect(Bool(false), "Should throw ValidationError for empty name")
            } catch let error as ValidationError {
                #expect(error.message.contains("Name cannot be empty"))
            }

            // Test with empty email
            do {
                _ = try await service.createPerson(name: "Test Name", email: "")
                #expect(Bool(false), "Should throw ValidationError for empty email")
            } catch let error as ValidationError {
                #expect(error.message.contains("Email cannot be empty"))
            }
        }
    }
}
