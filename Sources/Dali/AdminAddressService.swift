import Fluent
import FluentPostgresDriver
import Foundation
import PostgresNIO
import Vapor

/// Service for admin-only address management operations
public struct AdminAddressService: Sendable {

    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    /// Lists all addresses with their entities and people loaded
    /// - Parameter limit: Maximum number of results to return (default 100)
    /// - Parameter offset: Number of results to skip (default 0)
    /// - Returns: Array of addresses with relationships loaded
    public func listAddresses(limit: Int = 100, offset: Int = 0) async throws -> [Address] {
        try await Address.query(on: database)
            .with(\.$entity)
            .with(\.$person)
            .limit(limit)
            .offset(offset)
            .sort(\.$createdAt, .descending)
            .all()
    }

    /// Lists all entities with their types for dropdown menus
    /// - Returns: Array of entities with types loaded
    public func listEntities() async throws -> [Entity] {
        try await Entity.query(on: database)
            .with(\.$legalEntityType)
            .all()
    }

    /// Lists all people for dropdown menus
    /// - Returns: Array of people
    public func listPeople() async throws -> [Person] {
        try await Person.query(on: database).all()
    }

    /// Retrieves an address by ID
    /// - Parameter addressId: The UUID of the address to retrieve
    /// - Returns: The address, or nil if not found
    public func getAddress(addressId: UUID) async throws -> Address? {
        try await Address.find(addressId, on: database)
    }

    /// Creates a new address
    /// - Parameters:
    ///   - entityId: The UUID of the entity (optional, mutually exclusive with personId)
    ///   - personId: The UUID of the person (optional, mutually exclusive with entityId)
    ///   - street: Street address
    ///   - city: City name
    ///   - state: State or province (optional)
    ///   - zip: Postal code (optional)
    ///   - country: Country name
    ///   - isVerified: Whether the address is verified
    /// - Returns: The created address
    /// - Throws: ValidationError if input is invalid
    public func createAddress(
        entityId: UUID?,
        personId: UUID?,
        street: String,
        city: String,
        state: String?,
        zip: String?,
        country: String,
        isVerified: Bool = false
    ) async throws -> Address {
        // Validate XOR constraint - exactly one of entityId or personId must be provided
        guard (entityId != nil) != (personId != nil) else {
            throw ValidationError("Address must belong to either an entity or a person, but not both")
        }

        // Validate input
        let trimmedStreet = street.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCountry = country.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedStreet.isEmpty else {
            throw ValidationError("Street address cannot be empty")
        }

        guard !trimmedCity.isEmpty else {
            throw ValidationError("City cannot be empty")
        }

        guard !trimmedCountry.isEmpty else {
            throw ValidationError("Country cannot be empty")
        }

        let address = Address()
        address.$entity.id = entityId
        address.$person.id = personId
        address.street = trimmedStreet
        address.city = trimmedCity
        address.state = state?.trimmingCharacters(in: .whitespacesAndNewlines)
        address.zip = zip?.trimmingCharacters(in: .whitespacesAndNewlines)
        address.country = trimmedCountry
        address.isVerified = isVerified

        try await address.save(on: database)
        return address
    }

    /// Updates an address
    /// - Parameters:
    ///   - addressId: The UUID of the address to update
    ///   - entityId: The UUID of the entity (optional, mutually exclusive with personId)
    ///   - personId: The UUID of the person (optional, mutually exclusive with entityId)
    ///   - street: Street address
    ///   - city: City name
    ///   - state: State or province (optional)
    ///   - zip: Postal code (optional)
    ///   - country: Country name
    ///   - isVerified: Whether the address is verified
    /// - Returns: The updated address
    /// - Throws: ValidationError if address not found or input is invalid
    public func updateAddress(
        addressId: UUID,
        entityId: UUID?,
        personId: UUID?,
        street: String,
        city: String,
        state: String?,
        zip: String?,
        country: String,
        isVerified: Bool = false
    ) async throws -> Address {
        guard let address = try await Address.find(addressId, on: database) else {
            throw ValidationError("Address not found")
        }

        // Validate XOR constraint - exactly one of entityId or personId must be provided
        guard (entityId != nil) != (personId != nil) else {
            throw ValidationError("Address must belong to either an entity or a person, but not both")
        }

        // Validate input
        let trimmedStreet = street.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCountry = country.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedStreet.isEmpty else {
            throw ValidationError("Street address cannot be empty")
        }

        guard !trimmedCity.isEmpty else {
            throw ValidationError("City cannot be empty")
        }

        guard !trimmedCountry.isEmpty else {
            throw ValidationError("Country cannot be empty")
        }

        // Update the address
        address.$entity.id = entityId
        address.$person.id = personId
        address.street = trimmedStreet
        address.city = trimmedCity
        address.state = state?.trimmingCharacters(in: .whitespacesAndNewlines)
        address.zip = zip?.trimmingCharacters(in: .whitespacesAndNewlines)
        address.country = trimmedCountry
        address.isVerified = isVerified

        try await address.save(on: database)
        return address
    }

    /// Deletes an address
    /// - Parameter addressId: The UUID of the address to delete
    /// - Throws: ValidationError if the address is not found
    public func deleteAddress(addressId: UUID) async throws {
        guard let address = try await Address.find(addressId, on: database) else {
            throw ValidationError("Address not found")
        }

        try await address.delete(on: database)
    }
}
