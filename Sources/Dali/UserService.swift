import Fluent
import FluentPostgresDriver
import Foundation
import PostgresNIO
import Vapor

/// Service for user profile operations
public struct UserService: Sendable {

    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    /// Prepares user profile information for endpoints that need both user and person data
    /// - Parameter user: The authenticated user
    /// - Returns: Tuple containing user and person, validating person exists
    /// - Throws: ValidationError if person record is not available
    public func prepareUserProfile(user: User) async throws -> (user: User, person: Person) {
        guard let person = user.person else {
            throw ValidationError("Person record not available")
        }

        return (user: user, person: person)
    }

    /// Loads person relationship for API endpoints and validates
    /// - Parameter user: The authenticated user
    /// - Returns: The user with person relationship loaded
    /// - Throws: ValidationError if person relationship cannot be loaded
    public func prepareUserForAPI(user: User) async throws -> User {
        // Load the person relationship if not already loaded
        try await user.$person.load(on: database)

        guard user.person != nil else {
            throw ValidationError("Person record not available")
        }

        return user
    }

    /// Retrieves a user by ID with person relationship loaded
    /// - Parameter userId: The UUID of the user to retrieve
    /// - Returns: The user with person loaded, or nil if not found
    public func getUserWithPerson(userId: UUID) async throws -> User? {
        guard let user = try await User.find(userId, on: database) else {
            return nil
        }

        try await user.$person.load(on: database)
        return user
    }

    /// Retrieves a user by username with person relationship loaded
    /// - Parameter username: The username to search for
    /// - Returns: The user with person loaded, or nil if not found
    public func getUserByUsername(username: String) async throws -> User? {
        guard
            let user = try await User.query(on: database)
                .filter(\.$username == username)
                .with(\.$person)
                .first()
        else {
            return nil
        }

        return user
    }

    /// Updates user profile information
    /// - Parameters:
    ///   - user: The user to update
    ///   - name: Optional new name for the person record
    ///   - email: Optional new email for the person record
    /// - Returns: The updated user with person information
    /// - Throws: ValidationError if updates fail or person record is missing
    public func updateUserProfile(user: User, name: String? = nil, email: String? = nil) async throws -> User {
        guard let person = user.person else {
            throw ValidationError("Person record not available for profile update")
        }

        var updated = false

        if let newName = name?.trimmingCharacters(in: .whitespacesAndNewlines), !newName.isEmpty {
            person.name = newName
            updated = true
        }

        if let newEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines), !newEmail.isEmpty {
            person.email = newEmail
            updated = true
        }

        if updated {
            try await person.save(on: database)
        }

        return user
    }
}
