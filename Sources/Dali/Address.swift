import Fluent
import Foundation
import Vapor

/// Represents a physical address linked to either an entity or person in the directory schema.
///
/// The `Address` model stores physical address information for either entities (companies,
/// organizations) or people. Each address must be tied to exactly one entity OR one person,
/// but not both and not neither (XOR constraint).
///
/// ## Database Schema
/// This model maps to the `directory.address` table with the following structure:
/// - `id`: UUID primary key
/// - `entity_id`: Optional foreign key to `directory.entities` (mutually exclusive with person_id)
/// - `person_id`: Optional foreign key to `directory.people` (mutually exclusive with entity_id)
/// - `street`: Street address including number and name
/// - `city`: City name
/// - `state`: Optional state or province
/// - `zip`: Optional postal/zip code
/// - `country`: Country name
/// - `is_verified`: Boolean indicating address verification status
/// - `created_at`: Timestamp of creation
/// - `updated_at`: Timestamp of last update
///
/// ## Usage
/// ```swift
/// let entityAddress = Address(
///     entityID: entity.id!,
///     street: "123 Main Street",
///     city: "Las Vegas",
///     state: "NV",
///     zip: "89123",
///     country: "USA",
///     isVerified: true
/// )
/// try await entityAddress.create(on: app.db)
///
/// let personAddress = Address(
///     personID: person.id!,
///     street: "456 Oak Avenue",
///     city: "Reno",
///     state: "NV",
///     zip: "89501",
///     country: "USA",
///     isVerified: false
/// )
/// try await personAddress.create(on: app.db)
/// ```
public final class Address: Model, @unchecked Sendable {
    public static let schema = "addresses"
    public static let space = "directory"

    @ID(custom: .id, generatedBy: .database)
    public var id: UUID?

    @OptionalParent(key: "entity_id")
    public var entity: Entity?

    @OptionalParent(key: "person_id")
    public var person: Person?

    @Field(key: "street")
    public var street: String

    @Field(key: "city")
    public var city: String

    @Field(key: "state")
    public var state: String?

    @Field(key: "zip")
    public var zip: String?

    @Field(key: "country")
    public var country: String

    @Field(key: "is_verified")
    public var isVerified: Bool

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    /// Creates a new Address for an entity.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the address. If nil, a UUID will be generated.
    ///   - entityID: The UUID of the directory.entities that this address belongs to.
    ///   - street: Street address including number and street name.
    ///   - city: City name.
    ///   - state: State or province (optional for international addresses).
    ///   - zip: Postal code (optional for some countries).
    ///   - country: Country name.
    ///   - isVerified: Whether the address has been verified as valid.
    public init(
        id: UUID? = nil,
        entityID: UUID,
        street: String,
        city: String,
        state: String? = nil,
        zip: String? = nil,
        country: String,
        isVerified: Bool = false
    ) {
        self.id = id
        self.$entity.id = entityID
        self.$person.id = nil
        self.street = street
        self.city = city
        self.state = state
        self.zip = zip
        self.country = country
        self.isVerified = isVerified
    }

    /// Creates a new Address for a person.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the address. If nil, a UUID will be generated.
    ///   - personID: The UUID of the directory.people that this address belongs to.
    ///   - street: Street address including number and street name.
    ///   - city: City name.
    ///   - state: State or province (optional for international addresses).
    ///   - zip: Postal code (optional for some countries).
    ///   - country: Country name.
    ///   - isVerified: Whether the address has been verified as valid.
    public init(
        id: UUID? = nil,
        personID: UUID,
        street: String,
        city: String,
        state: String? = nil,
        zip: String? = nil,
        country: String,
        isVerified: Bool = false
    ) {
        self.id = id
        self.$entity.id = nil
        self.$person.id = personID
        self.street = street
        self.city = city
        self.state = state
        self.zip = zip
        self.country = country
        self.isVerified = isVerified
    }
}

extension Address: Content {}
