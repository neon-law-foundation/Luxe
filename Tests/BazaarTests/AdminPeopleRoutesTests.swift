import Dali
import Fluent
import FluentPostgresDriver
import TestUtilities
import Testing
import Vapor

@Suite("Admin People Service Tests", .serialized)
struct AdminPeopleRoutesTests {

    @Test("AdminPeopleService can list all people")
    func adminServiceCanListAllPeople() async throws {
        try await TestUtilities.withApp { app, database in
            let peopleService = AdminPeopleService(database: database)

            // Create test people using the service
            _ = try await peopleService.createPerson(
                name: "John Doe",
                email: "john.doe@example.com"
            )

            _ = try await peopleService.createPerson(
                name: "Jane Smith",
                email: "jane.smith@example.com"
            )

            // Test listing people
            let people = try await peopleService.listPeople()

            #expect(people.count >= 2)

            let person1Found = people.contains { $0.name == "John Doe" }
            let person2Found = people.contains { $0.name == "Jane Smith" }

            #expect(person1Found)
            #expect(person2Found)
        }
    }

    @Test("AdminPeopleService can get specific person by ID")
    func adminServiceCanGetSpecificPerson() async throws {
        try await TestUtilities.withApp { app, database in
            let peopleService = AdminPeopleService(database: database)

            // Create test person with unique email
            let uniqueEmail = "test.person.\(UUID().uuidString.lowercased())@example.com"
            let createdPerson = try await peopleService.createPerson(
                name: "Test Person",
                email: uniqueEmail
            )

            // Test getting person by ID
            let personId = try createdPerson.requireID()
            let retrievedPerson = try await peopleService.getPerson(personId: personId)

            #expect(retrievedPerson != nil)
            #expect(retrievedPerson?.name == "Test Person")
            #expect(retrievedPerson?.email == uniqueEmail)
        }
    }

    @Test("AdminPeopleService can create new person")
    func adminServiceCanCreateNewPerson() async throws {
        try await TestUtilities.withApp { app, database in
            let peopleService = AdminPeopleService(database: database)

            let person = try await peopleService.createPerson(
                name: "New Person",
                email: "new.person@example.com"
            )

            // Verify person was created correctly
            #expect(person.name == "New Person")
            #expect(person.email == "new.person@example.com")
            #expect(person.id != nil)
        }
    }

    @Test("AdminPeopleService validates person creation input")
    func adminServiceValidatesPersonInput() async throws {
        try await TestUtilities.withApp { app, database in
            let peopleService = AdminPeopleService(database: database)

            // Test that empty name throws validation error
            do {
                _ = try await peopleService.createPerson(
                    name: "",
                    email: "test@example.com"
                )

                #expect(Bool(false), "Should have thrown validation error for empty name")
            } catch {
                #expect(error is ValidationError)
            }

            // Test that empty email throws validation error
            do {
                _ = try await peopleService.createPerson(
                    name: "Test Person",
                    email: ""
                )

                #expect(Bool(false), "Should have thrown validation error for empty email")
            } catch {
                #expect(error is ValidationError)
            }
        }
    }

    @Test("AdminPeopleService can update person")
    func adminServiceCanUpdatePerson() async throws {
        try await TestUtilities.withApp { app, database in
            let peopleService = AdminPeopleService(database: database)

            // Create test person
            let person = try await peopleService.createPerson(
                name: "Original Name",
                email: "original@example.com"
            )

            // Update the person
            let updatedPerson = try await peopleService.updatePerson(
                personId: person.id!,
                name: "Updated Name",
                email: "updated@example.com"
            )

            // Verify update
            #expect(updatedPerson.name == "Updated Name")
            #expect(updatedPerson.email == "updated@example.com")
            #expect(updatedPerson.id == person.id)
        }
    }
}
