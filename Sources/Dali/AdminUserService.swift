import Fluent
import FluentPostgresDriver
import Foundation
import PostgresNIO
import Vapor

/// Service for admin-only user management operations
public struct AdminUserService: Sendable {

    /// Result type for create_person_and_user function
    public struct CreatePersonAndUserResult: Sendable {
        public let personId: UUID
        public let userId: UUID
        public let createdAt: Date

        public init(personId: UUID, userId: UUID, createdAt: Date) {
            self.personId = personId
            self.userId = userId
            self.createdAt = createdAt
        }
    }

    /// Input parameters for creating a person and user
    public struct CreatePersonAndUserInput: Content, Sendable {
        public let name: String
        public let email: String
        public let username: String
        public let role: UserRole

        public init(name: String, email: String, username: String, role: UserRole = .customer) {
            self.name = name
            self.email = email
            self.username = username
            self.role = role
        }

        /// Validates the input parameters
        public func validate() throws {
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ValidationError("Name cannot be empty")
            }

            guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ValidationError("Email cannot be empty")
            }

            guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ValidationError("Username cannot be empty")
            }

            // Basic email format validation
            let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            let emailRegex = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/
            guard trimmedEmail.contains(emailRegex) else {
                throw ValidationError("Invalid email format")
            }

            // Username length validation
            let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedUsername.count >= 3 else {
                throw ValidationError("Username must be at least 3 characters long")
            }

            guard trimmedUsername.count <= 255 else {
                throw ValidationError("Username cannot be longer than 255 characters")
            }

            // Name length validation
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedName.count <= 255 else {
                throw ValidationError("Name cannot be longer than 255 characters")
            }

            // Email length validation
            guard trimmedEmail.count <= 255 else {
                throw ValidationError("Email cannot be longer than 255 characters")
            }
        }
    }

    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    /// Creates a person and user atomically using the admin.create_person_and_user function
    /// - Parameter input: The input parameters for creating the person and user
    /// - Returns: The result containing the created person and user IDs
    /// - Throws: ValidationError if input is invalid, or database errors
    public func createPersonAndUser(_ input: CreatePersonAndUserInput) async throws -> CreatePersonAndUserResult {
        // Validate input
        try input.validate()

        // Ensure we have a PostgresDatabase for raw SQL access
        guard database is PostgresDatabase else {
            throw ValidationError("PostgreSQL database required for admin operations")
        }

        // Trim and normalize input values
        let trimmedName = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = input.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedUsername = input.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Execute in a transaction and ensure admin context is set for the function call
        return try await database.transaction { connection in
            guard let postgresConnection = connection as? PostgresDatabase else {
                throw ValidationError("PostgreSQL database required for admin operations")
            }

            // First try to check if session variable is already set (from middleware)
            let sessionCheck = try await postgresConnection.sql()
                .raw("SELECT current_setting('app.current_user_role', true) AS current_role")
                .first()

            let currentRole = try sessionCheck?.decode(column: "current_role", as: String?.self) ?? ""

            // If not already set to admin, set it (for direct service usage outside web context)
            if currentRole != "admin" {
                try await postgresConnection.sql()
                    .raw("SET app.current_user_role = 'admin'")
                    .run()
            }

            // Call the create_person_and_user function
            let result = try await postgresConnection.sql()
                .raw(
                    """
                    SELECT person_id, user_id, created_at
                    FROM admin.create_person_and_user(\(bind: trimmedName)::varchar(255), \(bind: trimmedEmail)::citext, \(bind: trimmedUsername)::varchar(255), \(bind: input.role.rawValue)::auth.user_role)
                    """
                )
                .first()

            guard let result = result else {
                throw ValidationError("Failed to create person and user - no result returned")
            }

            let personId = try result.decode(column: "person_id", as: UUID.self)
            let userId = try result.decode(column: "user_id", as: UUID.self)
            let createdAt = try result.decode(column: "created_at", as: Date.self)

            return CreatePersonAndUserResult(
                personId: personId,
                userId: userId,
                createdAt: createdAt
            )
        }
    }

    /// Retrieves a person with their associated user information
    /// - Parameter personId: The UUID of the person to retrieve
    /// - Returns: A tuple containing the person and user information, or nil if not found
    public func getPersonWithUser(personId: UUID) async throws -> (person: Person, user: User)? {
        // Use Fluent to join person and user
        guard
            let person = try await Person.query(on: database)
                .filter(\.$id == personId)
                .first()
        else {
            return nil
        }

        guard
            let user = try await User.query(on: database)
                .filter(\.$person.$id == personId)
                .first()
        else {
            return nil
        }

        return (person: person, user: user)
    }

    /// Lists all people with their associated users (admin only)
    /// - Parameter limit: Maximum number of results to return (default 100)
    /// - Parameter offset: Number of results to skip (default 0)
    /// - Returns: Array of tuples containing person and user information
    public func listPeopleWithUsers(limit: Int = 100, offset: Int = 0) async throws -> [(person: Person, user: User)] {
        let people = try await Person.query(on: database)
            .limit(limit)
            .offset(offset)
            .sort(\.$createdAt, .descending)
            .all()

        var results: [(person: Person, user: User)] = []

        for person in people {
            if let user = try await User.query(on: database)
                .filter(\.$person.$id == person.id)
                .first()
            {
                results.append((person: person, user: user))
            }
        }

        return results
    }

    /// Updates a user's role (admin only)
    /// - Parameters:
    ///   - userId: The UUID of the user to update
    ///   - newRole: The new role to assign
    /// - Returns: The updated user
    /// - Throws: ValidationError if user not found or database errors
    public func updateUserRole(userId: UUID, newRole: UserRole) async throws -> User {
        // Ensure we have a PostgresDatabase for raw SQL access
        guard database is PostgresDatabase else {
            throw ValidationError("PostgreSQL database required for admin operations")
        }

        // Execute in a transaction and ensure admin context is set
        return try await database.transaction { connection in
            guard let postgresConnection = connection as? PostgresDatabase else {
                throw ValidationError("PostgreSQL database required for admin operations")
            }

            // First try to check if session variable is already set (from middleware)
            let sessionCheck = try await postgresConnection.sql()
                .raw("SELECT current_setting('app.current_user_role', true) AS current_role")
                .first()

            let currentRole = try sessionCheck?.decode(column: "current_role", as: String?.self) ?? ""

            // If not already set to admin, set it (for direct service usage outside web context)
            if currentRole != "admin" {
                try await postgresConnection.sql()
                    .raw("SET app.current_user_role = 'admin'")
                    .run()
            }

            // Use raw SQL to update the role with proper enum casting
            let updateResult = try await postgresConnection.sql()
                .raw(
                    """
                    UPDATE auth.users
                    SET role = \(bind: newRole.rawValue)::auth.user_role, updated_at = CURRENT_TIMESTAMP
                    WHERE id = \(bind: userId)
                    RETURNING id, username, sub, role, person_id, created_at, updated_at
                    """
                )
                .first()

            guard let result = updateResult else {
                throw ValidationError("User not found or update failed")
            }

            // Create and return the updated User object
            let user = User()
            user.id = try result.decode(column: "id", as: UUID.self)
            user.username = try result.decode(column: "username", as: String.self)
            user.sub = try result.decode(column: "sub", as: String?.self)
            user.role = UserRole(rawValue: try result.decode(column: "role", as: String.self)) ?? .customer
            user.$person.id = try result.decode(column: "person_id", as: UUID?.self)
            user.createdAt = try result.decode(column: "created_at", as: Date.self)
            user.updatedAt = try result.decode(column: "updated_at", as: Date.self)

            return user
        }
    }

    /// Checks if a username is available
    /// - Parameter username: The username to check
    /// - Returns: true if the username is available, false otherwise
    public func isUsernameAvailable(_ username: String) async throws -> Bool {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let existingUser = try await User.query(on: database)
            .filter(\.$username == trimmedUsername)
            .first()

        return existingUser == nil
    }

    /// Checks if an email is available
    /// - Parameter email: The email to check
    /// - Returns: true if the email is available, false otherwise
    public func isEmailAvailable(_ email: String) async throws -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let existingPerson = try await Person.query(on: database)
            .filter(\.$email == trimmedEmail)
            .first()

        return existingPerson == nil
    }

    /// Searches users by name, email, or username with optional role filtering
    /// - Parameters:
    ///   - searchTerm: The search term to match against name, email, or username
    ///   - roleFilter: Optional role to filter by
    ///   - limit: Maximum number of results to return (default 50)
    ///   - offset: Number of results to skip (default 0)
    /// - Returns: Array of tuples containing person and user information matching the search
    public func searchUsers(
        searchTerm: String = "",
        roleFilter: UserRole? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [(person: Person, user: User)] {

        // For now, use the existing listPeopleWithUsers method
        // TODO: Implement proper search functionality when PostgreSQL binding syntax is clarified
        try await listPeopleWithUsers(limit: limit, offset: offset)
    }

    /// Counts total users matching search criteria
    /// - Parameters:
    ///   - searchTerm: The search term to match against name, email, or username
    ///   - roleFilter: Optional role to filter by
    /// - Returns: Total count of users matching the criteria
    public func countUsers(searchTerm: String = "", roleFilter: UserRole? = nil) async throws -> Int {
        // For now, use a simple count query
        let users = try await User.query(on: database).count()
        return users
    }

    /// Creates a User record for an existing Person with a specific Cognito sub ID
    /// This is useful for fixing authentication issues where Cognito users exist but don't have corresponding User records
    /// - Parameters:
    ///   - personEmail: The email of the existing Person record
    ///   - cognitoSubId: The Cognito sub ID to use as the username
    ///   - role: The role to assign to the user (default: admin)
    /// - Returns: The created User record
    /// - Throws: ValidationError if person not found or user creation fails
    public func createUserForExistingPerson(
        personEmail: String,
        cognitoSubId: String,
        role: UserRole = .admin
    ) async throws -> User {
        // Validate inputs
        guard !personEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError("Person email cannot be empty")
        }

        guard !cognitoSubId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError("Cognito sub ID cannot be empty")
        }

        // Ensure we have a PostgresDatabase for raw SQL access
        guard database is PostgresDatabase else {
            throw ValidationError("PostgreSQL database required for admin operations")
        }

        let trimmedEmail = personEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedSubId = cognitoSubId.trimmingCharacters(in: .whitespacesAndNewlines)

        // Execute in a transaction
        return try await database.transaction { connection in
            guard let postgresConnection = connection as? PostgresDatabase else {
                throw ValidationError("PostgreSQL database required for admin operations")
            }

            // Set admin context for the function call
            try await postgresConnection.sql()
                .raw("SET app.current_user_role = 'admin'")
                .run()

            // First, find the existing person
            let personResult = try await postgresConnection.sql()
                .raw("SELECT id FROM directory.people WHERE email = \(bind: trimmedEmail)")
                .first()

            guard let personResult = personResult else {
                throw ValidationError("Person with email \(trimmedEmail) not found")
            }

            let personId = try personResult.decode(column: "id", as: UUID.self)

            // Check if a user already exists for this person
            let existingUserResult = try await postgresConnection.sql()
                .raw("SELECT id FROM auth.users WHERE person_id = \(bind: personId)")
                .first()

            if existingUserResult != nil {
                throw ValidationError("User already exists for person with email \(trimmedEmail)")
            }

            // Check if username is already taken
            let usernameCheck = try await postgresConnection.sql()
                .raw("SELECT id FROM auth.users WHERE username = \(bind: trimmedSubId)")
                .first()

            if usernameCheck != nil {
                throw ValidationError("Username \(trimmedSubId) is already taken")
            }

            // Create the user record with the Cognito sub ID as both username and sub field
            let userResult = try await postgresConnection.sql()
                .raw(
                    """
                    INSERT INTO auth.users (username, sub, role, person_id, created_at, updated_at)
                    VALUES (\(bind: trimmedSubId), \(bind: trimmedSubId), \(bind: role.rawValue)::auth.user_role, \(bind: personId), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    RETURNING id, username, sub, role, person_id, created_at, updated_at
                    """
                )
                .first()

            guard let result = userResult else {
                throw ValidationError("Failed to create user record")
            }

            // Create and return the User object
            let user = User()
            user.id = try result.decode(column: "id", as: UUID.self)
            user.username = try result.decode(column: "username", as: String.self)
            user.sub = try result.decode(column: "sub", as: String?.self)
            user.role = UserRole(rawValue: try result.decode(column: "role", as: String.self)) ?? .customer
            user.$person.id = try result.decode(column: "person_id", as: UUID.self)
            user.createdAt = try result.decode(column: "created_at", as: Date.self)
            user.updatedAt = try result.decode(column: "updated_at", as: Date.self)

            return user
        }
    }

    /// Retrieves a user by ID with their associated person information loaded
    /// - Parameter userId: The UUID of the user to retrieve
    /// - Returns: The user with person relationship loaded, or nil if not found
    public func getUserWithPerson(userId: UUID) async throws -> User? {
        guard let user = try await User.find(userId, on: database) else {
            return nil
        }

        // Load the person relationship
        try await user.$person.load(on: database)

        return user
    }

    /// Retrieves a user by ID for deletion confirmation, with protection checks
    /// - Parameter userId: The UUID of the user to retrieve
    /// - Returns: The user with person relationship loaded, or nil if not found
    /// - Throws: ValidationError if the user is protected from deletion
    public func getUserForDeletion(userId: UUID) async throws -> User? {
        guard let user = try await getUserWithPerson(userId: userId) else {
            return nil
        }

        // Protect admin@neonlaw.com from deletion
        if user.username == "admin@neonlaw.com" {
            throw ValidationError("Cannot delete the system administrator account")
        }

        return user
    }

    /// Deletes a user with protection checks
    /// - Parameter userId: The UUID of the user to delete
    /// - Throws: ValidationError if the user is not found or protected from deletion
    public func deleteUser(userId: UUID) async throws {
        guard let user = try await User.find(userId, on: database) else {
            throw ValidationError("User not found")
        }

        // Protect admin@neonlaw.com from deletion
        if user.username == "admin@neonlaw.com" {
            throw ValidationError("Cannot delete the system administrator account")
        }

        try await user.delete(on: database)
    }
}
