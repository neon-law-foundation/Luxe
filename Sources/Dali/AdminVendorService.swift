import Fluent
import FluentPostgresDriver
import Foundation
import PostgresNIO
import Vapor

/// Service for admin-only vendor management operations
public struct AdminVendorService: Sendable {

    /// Input parameters for creating a vendor
    public struct CreateVendorInput: Content, Sendable {
        public let name: String
        public let entityID: UUID?
        public let personID: UUID?

        public init(name: String, entityID: UUID? = nil, personID: UUID? = nil) {
            self.name = name
            self.entityID = entityID
            self.personID = personID
        }

        /// Validates the input parameters
        public func validate() throws {
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ValidationError("Name cannot be empty")
            }

            // Name length validation
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedName.count <= 255 else {
                throw ValidationError("Name cannot be longer than 255 characters")
            }

            // Ensure exactly one of entityID or personID is set
            guard (entityID != nil && personID == nil) || (entityID == nil && personID != nil) else {
                throw ValidationError("Exactly one of entityID or personID must be provided")
            }
        }
    }

    /// Input parameters for updating a vendor
    public struct UpdateVendorInput: Content, Sendable {
        public let name: String
        public let entityID: UUID?
        public let personID: UUID?

        public init(name: String, entityID: UUID? = nil, personID: UUID? = nil) {
            self.name = name
            self.entityID = entityID
            self.personID = personID
        }

        /// Validates the input parameters
        public func validate() throws {
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ValidationError("Name cannot be empty")
            }

            // Name length validation
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedName.count <= 255 else {
                throw ValidationError("Name cannot be longer than 255 characters")
            }

            // Ensure exactly one of entityID or personID is set
            guard (entityID != nil && personID == nil) || (entityID == nil && personID != nil) else {
                throw ValidationError("Exactly one of entityID or personID must be provided")
            }
        }
    }

    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    /// Creates a vendor with either entity or person reference
    /// - Parameter input: The input parameters for creating the vendor
    /// - Returns: The created vendor
    /// - Throws: ValidationError if input is invalid, or database errors
    public func createVendor(_ input: CreateVendorInput) async throws -> Vendor {
        // Validate input
        try input.validate()

        // Ensure we have a PostgresDatabase for raw SQL access
        guard database is PostgresDatabase else {
            throw ValidationError("PostgreSQL database required for admin operations")
        }

        // Trim and normalize input values
        let trimmedName = input.name.trimmingCharacters(in: .whitespacesAndNewlines)

        // Execute in a transaction and ensure admin context is set
        return try await database.transaction { connection in
            guard let postgresConnection = connection as? PostgresDatabase else {
                throw ValidationError("PostgreSQL database required for admin operations")
            }

            // Set admin role context if not already set
            try await setAdminContext(postgresConnection)

            // Create the vendor using raw SQL to ensure constraint validation
            let result = try await postgresConnection.sql()
                .raw(
                    """
                    INSERT INTO accounting.vendors (name, entity_id, person_id, created_at, updated_at)
                    VALUES (\(bind: trimmedName), \(bind: input.entityID), \(bind: input.personID), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    RETURNING id, name, entity_id, person_id, created_at, updated_at
                    """
                )
                .first()

            guard let result = result else {
                throw ValidationError("Failed to create vendor - no result returned")
            }

            // Create and return the Vendor object
            let vendor = Vendor()
            vendor.id = try result.decode(column: "id", as: UUID.self)
            vendor.name = try result.decode(column: "name", as: String.self)
            vendor.$entity.id = try result.decode(column: "entity_id", as: UUID?.self)
            vendor.$person.id = try result.decode(column: "person_id", as: UUID?.self)
            vendor.createdAt = try result.decode(column: "created_at", as: Date.self)
            vendor.updatedAt = try result.decode(column: "updated_at", as: Date.self)

            return vendor
        }
    }

    /// Updates a vendor
    /// - Parameters:
    ///   - vendorId: The UUID of the vendor to update
    ///   - input: The input parameters for updating the vendor
    /// - Returns: The updated vendor
    /// - Throws: ValidationError if input is invalid or vendor not found, or database errors
    public func updateVendor(vendorId: UUID, _ input: UpdateVendorInput) async throws -> Vendor {
        // Validate input
        try input.validate()

        // Ensure we have a PostgresDatabase for raw SQL access
        guard database is PostgresDatabase else {
            throw ValidationError("PostgreSQL database required for admin operations")
        }

        // Trim and normalize input values
        let trimmedName = input.name.trimmingCharacters(in: .whitespacesAndNewlines)

        // Execute in a transaction and ensure admin context is set
        return try await database.transaction { connection in
            guard let postgresConnection = connection as? PostgresDatabase else {
                throw ValidationError("PostgreSQL database required for admin operations")
            }

            // Set admin role context if not already set
            try await setAdminContext(postgresConnection)

            // Update the vendor using raw SQL to ensure constraint validation
            let result = try await postgresConnection.sql()
                .raw(
                    """
                    UPDATE accounting.vendors
                    SET name = \(bind: trimmedName), entity_id = \(bind: input.entityID), person_id = \(bind: input.personID), updated_at = CURRENT_TIMESTAMP
                    WHERE id = \(bind: vendorId)
                    RETURNING id, name, entity_id, person_id, created_at, updated_at
                    """
                )
                .first()

            guard let result = result else {
                throw ValidationError("Vendor not found or update failed")
            }

            // Create and return the updated Vendor object
            let vendor = Vendor()
            vendor.id = try result.decode(column: "id", as: UUID.self)
            vendor.name = try result.decode(column: "name", as: String.self)
            vendor.$entity.id = try result.decode(column: "entity_id", as: UUID?.self)
            vendor.$person.id = try result.decode(column: "person_id", as: UUID?.self)
            vendor.createdAt = try result.decode(column: "created_at", as: Date.self)
            vendor.updatedAt = try result.decode(column: "updated_at", as: Date.self)

            return vendor
        }
    }

    /// Retrieves a vendor by ID
    /// - Parameter vendorId: The UUID of the vendor to retrieve
    /// - Returns: The vendor if found, nil otherwise
    public func getVendor(vendorId: UUID) async throws -> Vendor? {
        try await Vendor.query(on: database)
            .filter(\.$id == vendorId)
            .first()
    }

    /// Lists all vendors with optional pagination
    /// - Parameters:
    ///   - limit: Maximum number of results to return (default 100)
    ///   - offset: Number of results to skip (default 0)
    /// - Returns: Array of vendors
    public func listVendors(limit: Int = 100, offset: Int = 0) async throws -> [Vendor] {
        try await Vendor.query(on: database)
            .limit(limit)
            .offset(offset)
            .sort(\.$createdAt, .descending)
            .all()
    }

    /// Lists all entities for dropdown menus
    /// - Returns: Array of entities
    public func listEntities() async throws -> [Entity] {
        try await Entity.query(on: database).all()
    }

    /// Lists all people for dropdown menus
    /// - Returns: Array of people
    public func listPeople() async throws -> [Person] {
        try await Person.query(on: database).all()
    }

    /// Searches vendors by name
    /// - Parameters:
    ///   - searchTerm: The search term to match against vendor name
    ///   - limit: Maximum number of results to return (default 50)
    ///   - offset: Number of results to skip (default 0)
    /// - Returns: Array of vendors matching the search
    public func searchVendors(
        searchTerm: String = "",
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [Vendor] {

        let trimmedSearchTerm = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedSearchTerm.isEmpty {
            return try await listVendors(limit: limit, offset: offset)
        }

        return try await Vendor.query(on: database)
            .filter(\.$name ~~ "%\(trimmedSearchTerm)%")
            .limit(limit)
            .offset(offset)
            .sort(\.$createdAt, .descending)
            .all()
    }

    /// Counts total vendors matching search criteria
    /// - Parameter searchTerm: The search term to match against vendor name
    /// - Returns: Total count of vendors matching the criteria
    public func countVendors(searchTerm: String = "") async throws -> Int {
        let trimmedSearchTerm = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedSearchTerm.isEmpty {
            return try await Vendor.query(on: database).count()
        }

        return try await Vendor.query(on: database)
            .filter(\.$name ~~ "%\(trimmedSearchTerm)%")
            .count()
    }

    /// Deletes a vendor
    /// - Parameter vendorId: The UUID of the vendor to delete
    /// - Throws: ValidationError if vendor not found, or database errors
    public func deleteVendor(vendorId: UUID) async throws {
        guard let vendor = try await getVendor(vendorId: vendorId) else {
            throw ValidationError("Vendor not found")
        }

        try await vendor.delete(on: database)
    }

    /// Sets admin context for database operations
    private func setAdminContext(_ connection: PostgresDatabase) async throws {
        // First try to check if session variable is already set (from middleware)
        let sessionCheck = try await connection.sql()
            .raw("SELECT current_setting('app.current_user_role', true) AS current_role")
            .first()

        let currentRole = try sessionCheck?.decode(column: "current_role", as: String?.self) ?? ""

        // If not already set to admin, set it (for direct service usage outside web context)
        if currentRole != "admin" {
            try await connection.sql()
                .raw("SET app.current_user_role = 'admin'")
                .run()
        }
    }
}
