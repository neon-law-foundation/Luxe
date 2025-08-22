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

@Suite("Address Tests", .serialized)
struct AddressTests {

    @Test("Address has required fields for entity")
    func addressHasRequiredFieldsForEntity() async throws {
        let entityId = UUID()
        let address = Address(
            entityID: entityId,
            street: "123 Main Street",
            city: "Las Vegas",
            state: "NV",
            zip: "89123",
            country: "USA",
            isVerified: true
        )

        #expect(address.$entity.id == entityId)
        #expect(address.$person.id == nil)
        #expect(address.street == "123 Main Street")
        #expect(address.city == "Las Vegas")
        #expect(address.state == "NV")
        #expect(address.zip == "89123")
        #expect(address.country == "USA")
        #expect(address.isVerified == true)
    }

    @Test("Address has required fields for person")
    func addressHasRequiredFieldsForPerson() async throws {
        let personId = UUID()
        let address = Address(
            personID: personId,
            street: "456 Oak Avenue",
            city: "Reno",
            state: "NV",
            zip: "89501",
            country: "USA",
            isVerified: false
        )

        #expect(address.$entity.id == nil)
        #expect(address.$person.id == personId)
        #expect(address.street == "456 Oak Avenue")
        #expect(address.city == "Reno")
        #expect(address.state == "NV")
        #expect(address.zip == "89501")
        #expect(address.country == "USA")
        #expect(address.isVerified == false)
    }

    @Test("Address can be saved with valid entity reference")
    func addressCanBeSavedWithValidEntityReference() async throws {
        try await TestUtilities.withApp { app, database in
            // Get Nevada jurisdiction ID
            let nevadaResult = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT id FROM legal.jurisdictions WHERE code = 'NV'")
                .first()

            guard let nevada = nevadaResult,
                let nevadaJurisdictionId = try? nevada.decode(column: "id", as: UUID.self)
            else {
                Issue.record("Nevada jurisdiction not found")
                return
            }

            // Create Nevada LLC entity type if it doesn't exist
            let entityTypeId: UUID
            let existingResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    SELECT id FROM legal.entity_types
                    WHERE legal_jurisdiction_id = \(bind: nevadaJurisdictionId) AND name = 'LLC'
                    """
                )
                .first()

            if let existing = existingResult {
                entityTypeId = try existing.decode(column: "id", as: UUID.self)
            } else {
                let insertResult = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        INSERT INTO legal.entity_types (legal_jurisdiction_id, name, created_at, updated_at)
                        VALUES (\(bind: nevadaJurisdictionId), 'LLC', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        RETURNING id
                        """
                    )
                    .first()

                entityTypeId = try insertResult!.decode(column: "id", as: UUID.self)
            }

            // Create entity with unique name
            let uniqueEntityName = "Test Company LLC \(UUID().uuidString)"
            let entity = Entity(name: uniqueEntityName, legalEntityTypeID: entityTypeId)
            try await entity.save(on: app.db)

            // Create address for entity
            let address = Address(
                entityID: entity.id!,
                street: "123 Business Blvd",
                city: "Las Vegas",
                state: "NV",
                zip: "89123",
                country: "USA"
            )

            try await address.save(on: app.db)

            #expect(address.id != nil)
            #expect(address.$entity.id == entity.id!)
            #expect(address.$person.id == nil)
            #expect(address.createdAt != nil)
            #expect(address.updatedAt != nil)
        }
    }

    @Test("Address can be saved with valid person reference")
    func addressCanBeSavedWithValidPersonReference() async throws {
        try await TestUtilities.withApp { app, database in

            // Create person with unique email to avoid conflicts
            let uniqueEmail = "john.doe.\(UUID().uuidString)@example.com"
            let person = Person(name: "John Doe", email: uniqueEmail)
            try await person.save(on: app.db)

            // Create address for person
            let address = Address(
                personID: person.id!,
                street: "789 Residential Ave",
                city: "Reno",
                state: "NV",
                zip: "89501",
                country: "USA"
            )

            try await address.save(on: app.db)

            #expect(address.id != nil)
            #expect(address.$entity.id == nil)
            #expect(address.$person.id == person.id!)
            #expect(address.createdAt != nil)
            #expect(address.updatedAt != nil)
        }
    }

    @Test("Address creation fails when both entity_id and person_id are set")
    func addressCreationFailsWhenBothIdsAreSet() async throws {
        try await TestUtilities.withApp { app, database in
            // Get Nevada jurisdiction ID and create entity type/entity
            let nevadaResult = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT id FROM legal.jurisdictions WHERE code = 'NV'")
                .first()

            guard let nevada = nevadaResult,
                let nevadaJurisdictionId = try? nevada.decode(column: "id", as: UUID.self)
            else {
                Issue.record("Nevada jurisdiction not found")
                return
            }

            let entityTypeId: UUID
            let existingResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    SELECT id FROM legal.entity_types
                    WHERE legal_jurisdiction_id = \(bind: nevadaJurisdictionId) AND name = 'LLC'
                    """
                )
                .first()

            if let existing = existingResult {
                entityTypeId = try existing.decode(column: "id", as: UUID.self)
            } else {
                let insertResult = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        INSERT INTO legal.entity_types (legal_jurisdiction_id, name, created_at, updated_at)
                        VALUES (\(bind: nevadaJurisdictionId), 'LLC', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        RETURNING id
                        """
                    )
                    .first()

                entityTypeId = try insertResult!.decode(column: "id", as: UUID.self)
            }

            let uniqueEntityName = "Test Company LLC \(UUID().uuidString)"
            let entity = Entity(name: uniqueEntityName, legalEntityTypeID: entityTypeId)
            try await entity.save(on: app.db)

            // Create person with unique email to avoid conflicts
            let uniqueEmail = "john.doe.\(UUID().uuidString)@example.com"
            let person = Person(name: "John Doe", email: uniqueEmail)
            try await person.save(on: app.db)

            // Manually create address with both IDs set (violating XOR constraint)
            let address = Address()
            address.$entity.id = entity.id!
            address.$person.id = person.id!
            address.street = "Invalid Address"
            address.city = "Las Vegas"
            address.country = "USA"
            address.isVerified = false

            // This should fail due to XOR constraint
            await #expect(throws: Error.self) {
                try await address.save(on: app.db)
            }
        }
    }

    @Test("Address creation fails when neither entity_id nor person_id are set")
    func addressCreationFailsWhenNeitherIdIsSet() async throws {
        try await TestUtilities.withApp { app, database in
            // Create address with neither entity nor person
            let address = Address()
            address.street = "Invalid Address"
            address.city = "Las Vegas"
            address.country = "USA"
            address.isVerified = false

            // This should fail due to XOR constraint
            await #expect(throws: Error.self) {
                try await address.save(on: app.db)
            }
        }
    }

    @Test("Address XOR constraint allows exactly one relationship")
    func addressXORConstraintAllowsExactlyOneRelationship() async throws {
        try await TestUtilities.withApp { app, database in
            // Optimize by reducing database operations - create minimal test data
            // Get Nevada jurisdiction ID (reuse existing seed data)
            let nevadaResult = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT id FROM legal.jurisdictions WHERE code = 'NV'")
                .first()

            guard let nevada = nevadaResult,
                let nevadaJurisdictionId = try? nevada.decode(column: "id", as: UUID.self)
            else {
                Issue.record("Nevada jurisdiction not found")
                return
            }

            // Use existing entity type or create minimal one
            let entityTypeId: UUID
            let existingResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    SELECT id FROM legal.entity_types
                    WHERE legal_jurisdiction_id = \(bind: nevadaJurisdictionId) AND name = 'LLC'
                    """
                )
                .first()

            if let existing = existingResult {
                entityTypeId = try existing.decode(column: "id", as: UUID.self)
            } else {
                let insertResult = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        INSERT INTO legal.entity_types (legal_jurisdiction_id, name, created_at, updated_at)
                        VALUES (\(bind: nevadaJurisdictionId), 'LLC', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        RETURNING id
                        """
                    )
                    .first()

                entityTypeId = try insertResult!.decode(column: "id", as: UUID.self)
            }

            // Create minimal entity and person
            let uniqueEntityName = "XOR Test \(UUID().uuidString.prefix(8))"
            let entity = Entity(name: uniqueEntityName, legalEntityTypeID: entityTypeId)
            try await entity.save(on: app.db)

            let uniqueEmail = "xor.\(UUID().uuidString.prefix(8))@test.com"
            let person = Person(name: "XOR Test", email: uniqueEmail)
            try await person.save(on: app.db)

            // Test XOR constraint: Create one address for entity, one for person
            let entityAddress = Address(
                entityID: entity.id!,
                street: "Entity St",
                city: "LV",
                country: "USA"
            )
            try await entityAddress.save(on: app.db)

            let personAddress = Address(
                personID: person.id!,
                street: "Person Ave",
                city: "Reno",
                country: "USA"
            )
            try await personAddress.save(on: app.db)

            // Verify XOR constraint works (minimal verification)
            #expect(entityAddress.id != nil)
            #expect(personAddress.id != nil)
            #expect(entityAddress.$entity.id == entity.id!)
            #expect(entityAddress.$person.id == nil)
            #expect(personAddress.$entity.id == nil)
            #expect(personAddress.$person.id == person.id!)
        }
    }

    @Test("Address query by entity works correctly")
    func addressQueryByEntityWorksCorrectly() async throws {
        try await TestUtilities.withApp { app, database in
            // Get Nevada jurisdiction ID and create entity type/entity
            let nevadaResult = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT id FROM legal.jurisdictions WHERE code = 'NV'")
                .first()

            guard let nevada = nevadaResult,
                let nevadaJurisdictionId = try? nevada.decode(column: "id", as: UUID.self)
            else {
                Issue.record("Nevada jurisdiction not found")
                return
            }

            let entityTypeId: UUID
            let existingResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    SELECT id FROM legal.entity_types
                    WHERE legal_jurisdiction_id = \(bind: nevadaJurisdictionId) AND name = 'C-Corp'
                    """
                )
                .first()

            if let existing = existingResult {
                entityTypeId = try existing.decode(column: "id", as: UUID.self)
            } else {
                let insertResult = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        INSERT INTO legal.entity_types (legal_jurisdiction_id, name, created_at, updated_at)
                        VALUES (\(bind: nevadaJurisdictionId), 'C-Corp', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        RETURNING id
                        """
                    )
                    .first()

                entityTypeId = try insertResult!.decode(column: "id", as: UUID.self)
            }

            let uniqueEntityName = "Query Test Corp \(UUID().uuidString)"
            let entity = Entity(name: uniqueEntityName, legalEntityTypeID: entityTypeId)
            try await entity.save(on: app.db)

            // Create address for entity
            let address = Address(
                entityID: entity.id!,
                street: "999 Query Street",
                city: "Henderson",
                state: "NV",
                country: "USA"
            )
            try await address.save(on: app.db)

            // Query addresses by entity
            let entityAddresses = try await Address.query(on: app.db)
                .filter(\.$entity.$id == entity.id!)
                .all()

            #expect(entityAddresses.count == 1)
            #expect(entityAddresses.first?.street == "999 Query Street")
            #expect(entityAddresses.first?.$entity.id == entity.id!)
            #expect(entityAddresses.first?.$person.id == nil)
        }
    }

    @Test("Address query by person works correctly")
    func addressQueryByPersonWorksCorrectly() async throws {
        try await TestUtilities.withApp { app, database in
            // Create person
            let uniqueEmail = "query.\(UUID().uuidString)@example.com"
            let person = Person(name: "Query Test Person", email: uniqueEmail)
            try await person.save(on: app.db)

            // Create address for person
            let address = Address(
                personID: person.id!,
                street: "888 Query Lane",
                city: "Carson City",
                state: "NV",
                country: "USA"
            )
            try await address.save(on: app.db)

            // Query addresses by person
            let personAddresses = try await Address.query(on: app.db)
                .filter(\.$person.$id == person.id!)
                .all()

            #expect(personAddresses.count == 1)
            #expect(personAddresses.first?.street == "888 Query Lane")
            #expect(personAddresses.first?.$entity.id == nil)
            #expect(personAddresses.first?.$person.id == person.id!)
        }
    }
}
