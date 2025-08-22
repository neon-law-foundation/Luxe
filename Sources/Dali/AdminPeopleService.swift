import Fluent
import FluentPostgresDriver
import Foundation
import PostgresNIO
import Vapor

/// Service for admin-only people management operations
public struct AdminPeopleService: Sendable {

    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    /// Lists all people
    /// - Parameter limit: Maximum number of results to return (default 100)
    /// - Parameter offset: Number of results to skip (default 0)
    /// - Returns: Array of people
    public func listPeople(limit: Int = 100, offset: Int = 0) async throws -> [Person] {
        try await Person.query(on: database)
            .limit(limit)
            .offset(offset)
            .sort(\.$createdAt, .descending)
            .all()
    }

    /// Retrieves a person by ID
    /// - Parameter personId: The UUID of the person to retrieve
    /// - Returns: The person, or nil if not found
    public func getPerson(personId: UUID) async throws -> Person? {
        try await Person.find(personId, on: database)
    }

    /// Creates a new person
    /// - Parameters:
    ///   - name: The person's name
    ///   - email: The person's email
    /// - Returns: The created person
    /// - Throws: ValidationError if input is invalid or database errors
    public func createPerson(name: String, email: String) async throws -> Person {
        // Validate input
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !trimmedName.isEmpty else {
            throw ValidationError("Name cannot be empty")
        }

        guard !trimmedEmail.isEmpty else {
            throw ValidationError("Email cannot be empty")
        }

        // Basic email format validation
        let emailRegex = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/
        guard trimmedEmail.contains(emailRegex) else {
            throw ValidationError("Invalid email format")
        }

        let person = Person()
        person.name = trimmedName
        person.email = trimmedEmail

        try await person.save(on: database)
        return person
    }

    /// Updates a person
    /// - Parameters:
    ///   - personId: The UUID of the person to update
    ///   - name: The new name
    ///   - email: The new email
    /// - Returns: The updated person
    /// - Throws: ValidationError if person not found or input is invalid
    public func updatePerson(personId: UUID, name: String, email: String) async throws -> Person {
        guard let person = try await Person.find(personId, on: database) else {
            throw ValidationError("Person not found")
        }

        // Validate input
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !trimmedName.isEmpty else {
            throw ValidationError("Name cannot be empty")
        }

        guard !trimmedEmail.isEmpty else {
            throw ValidationError("Email cannot be empty")
        }

        // Basic email format validation
        let emailRegex = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/
        guard trimmedEmail.contains(emailRegex) else {
            throw ValidationError("Invalid email format")
        }

        person.name = trimmedName
        person.email = trimmedEmail

        try await person.save(on: database)
        return person
    }

    /// Retrieves a person for deletion confirmation, with protection checks
    /// - Parameter personId: The UUID of the person to retrieve
    /// - Returns: The person, or nil if not found
    /// - Throws: ValidationError if the person is protected from deletion
    public func getPersonForDeletion(personId: UUID) async throws -> Person? {
        guard let person = try await Person.find(personId, on: database) else {
            return nil
        }

        // Protect admin@neonlaw.com from deletion
        if person.email == "admin@neonlaw.com" {
            throw ValidationError("Cannot delete the system administrator account")
        }

        return person
    }

    /// Deletes a person with protection checks, including any linked users
    /// - Parameter personId: The UUID of the person to delete
    /// - Throws: ValidationError if the person is not found or protected from deletion
    public func deletePerson(personId: UUID) async throws {
        guard let person = try await Person.find(personId, on: database) else {
            throw ValidationError("Person not found")
        }

        // Protect admin@neonlaw.com from deletion
        if person.email == "admin@neonlaw.com" {
            throw ValidationError("Cannot delete the system administrator account")
        }

        // Delete in a transaction to ensure data consistency
        try await database.transaction { database in
            // First, delete any linked users to avoid foreign key constraint violation
            let linkedUsers = try await User.query(on: database)
                .filter(\.$person.$id == personId)
                .all()

            for user in linkedUsers {
                try await user.delete(on: database)
            }

            // Then delete the person
            try await person.delete(on: database)
        }
    }
}
