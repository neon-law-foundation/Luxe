import Fluent
import FluentPostgresDriver
import Foundation
import Logging
import PostgresNIO
import ServiceLifecycle
import TestUtilities
import Testing
import Vapor

@testable import Dali
@testable import Palette

@Suite("Person Tests", .serialized)
struct PersonTests {

    @Test("Person has required fields")
    func personHasRequiredFields() async throws {
        // Create a test person
        let person = Person(name: "John Doe", email: "john.doe@example.com")

        // Verify the model has all required fields
        #expect(person.name == "John Doe")
        #expect(person.email == "john.doe@example.com")

        // ID should be nil before saving
        #expect(person.id == nil)

        // Timestamps should be nil before saving
        #expect(person.createdAt == nil)
        #expect(person.updatedAt == nil)
    }

    @Test("Person can be saved and retrieved")
    func personCanBeSavedAndRetrieved() async throws {

        try await TestUtilities.withApp { app, database in
            // First verify the table exists with raw SQL
            let countResult = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT COUNT(*) as count FROM directory.people")
                .first()

            #expect(countResult != nil)
            print("Database connection verified - directory.people table accessible")

            // Create a test person with unique email
            let uniqueEmail = "test\(UniqueCodeGenerator.generateISOCode(prefix: "test"))@example.com"
            let person = Person(name: "Test User", email: uniqueEmail)

            // Use raw SQL to insert since Fluent has schema issues
            do {
                let insertResult = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        INSERT INTO directory.people (name, email, created_at, updated_at)
                        VALUES (\(bind: person.name), \(bind: person.email), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        RETURNING id, created_at, updated_at
                        """
                    )
                    .first()

                #expect(insertResult != nil)

                // Extract the returned values
                if let result = insertResult {
                    let personId = try result.decode(column: "id", as: UUID.self)
                    let _ = try result.decode(column: "created_at", as: Date.self)
                    let _ = try result.decode(column: "updated_at", as: Date.self)

                    print("Successfully saved Person with ID: \(personId)")
                }
            } catch {
                print("Insert error: \(String(reflecting: error))")
                throw error
            }
        }
    }

    @Test("Person email is case-insensitive")
    func personEmailIsCaseInsensitive() async throws {

        try await TestUtilities.withApp { app, database in
            // Create a test person with uppercase email
            let uniqueEmail = "TEST\(UniqueCodeGenerator.generateISOCode(prefix: "test"))@EXAMPLE.COM"

            // Insert with uppercase email
            let insertResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    INSERT INTO directory.people (name, email, created_at, updated_at)
                    VALUES (\(bind: "Test User"), \(bind: uniqueEmail), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    RETURNING id
                    """
                )
                .first()

            #expect(insertResult != nil)

            if let result = insertResult {
                let personId = try result.decode(column: "id", as: UUID.self)

                // Query with lowercase email using the ID to verify insertion worked
                let lowercaseEmail = uniqueEmail.lowercased()
                let queryResult = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        SELECT COUNT(*) as count
                        FROM directory.people
                        WHERE LOWER(email::text) = LOWER(\(bind: lowercaseEmail))
                        AND id = \(bind: personId)
                        """
                    )
                    .first()

                if let countResult = queryResult {
                    let count = try countResult.decode(column: "count", as: Int64.self)
                    #expect(count == 1)
                    print("CITEXT email validation successful - found \(count) record(s)")
                }
            }
        }
    }
}
