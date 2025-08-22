import Fluent
import FluentPostgresDriver
import Logging
import PostgresNIO
import TestUtilities
import Testing
import Vapor

@testable import Dali
@testable import Palette

@Suite("Admin Address Service Tests", .serialized)
struct AdminAddressServiceTests {

    @Test("AdminAddressService can list addresses")
    func adminAddressServiceCanListAddresses() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminAddressService(database: database)

            // Create a test address first
            let testPerson = Person(
                name: "Test Person \(UniqueCodeGenerator.generateISOCode(prefix: "ADDR"))",
                email: "addr_test_\(UniqueCodeGenerator.generateISOCode(prefix: "ADDR"))@example.com"
            )
            try await testPerson.save(on: database)

            let testAddress = Address(
                personID: testPerson.id!,
                street: "123 Test Street \(UniqueCodeGenerator.generateISOCode(prefix: "STREET"))",
                city: "Test City",
                state: "TS",
                zip: "12345",
                country: "Test Country",
                isVerified: false
            )
            try await testAddress.save(on: database)

            // Test listing addresses
            let addresses = try await service.listAddresses()

            #expect(addresses.count >= 1)
            #expect(addresses.contains { $0.street == testAddress.street })
        }
    }

    @Test("AdminAddressService can create address for person")
    func adminAddressServiceCanCreateAddressForPerson() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminAddressService(database: database)

            // Create a test person
            let testPerson = Person(
                name: "Address Person \(UniqueCodeGenerator.generateISOCode(prefix: "PERSON"))",
                email: "address_person_\(UniqueCodeGenerator.generateISOCode(prefix: "PERSON"))@example.com"
            )
            try await testPerson.save(on: database)

            let uniqueStreet = "456 Person Street \(UniqueCodeGenerator.generateISOCode(prefix: "PERSON"))"

            let createdAddress = try await service.createAddress(
                entityId: nil,
                personId: testPerson.id!,
                street: uniqueStreet,
                city: "Person City",
                state: "PC",
                zip: "67890",
                country: "Person Country",
                isVerified: true
            )

            #expect(createdAddress.street == uniqueStreet)
            #expect(createdAddress.$person.id == testPerson.id!)
            #expect(createdAddress.$entity.id == nil)
            #expect(createdAddress.isVerified == true)
            #expect(createdAddress.id != nil)
        }
    }

    @Test("AdminAddressService can create address for entity")
    func adminAddressServiceCanCreateAddressForEntity() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminAddressService(database: database)
            let adminEntitiesService = AdminEntitiesService(database: database)

            // Create or find Nevada jurisdiction (should exist from seed data)
            let existingJurisdiction = try await LegalJurisdiction.query(on: database)
                .filter(\.$code == "NV")
                .first()

            let jurisdiction: LegalJurisdiction
            if let existing = existingJurisdiction {
                jurisdiction = existing
            } else {
                let newJurisdiction = LegalJurisdiction(name: "Nevada", code: "NV")
                try await newJurisdiction.save(on: database)
                jurisdiction = newJurisdiction
            }

            // Create or find LLC entity type for Nevada
            let existingEntityType = try await EntityType.query(on: database)
                .filter(\.$legalJurisdiction.$id == jurisdiction.id!)
                .filter(\.$name == "LLC")
                .first()

            let entityType: EntityType
            if let existing = existingEntityType {
                entityType = existing
            } else {
                let newEntityType = EntityType(
                    legalJurisdictionID: jurisdiction.id!,
                    name: "LLC"
                )
                try await newEntityType.save(on: database)
                entityType = newEntityType
            }

            // Create test entity using AdminEntitiesService
            let entityName = "Address Entity \(UniqueCodeGenerator.generateISOCode(prefix: "ENTITY"))"
            let testEntity = try await adminEntitiesService.createEntity(
                name: entityName,
                legalEntityTypeId: entityType.id!
            )

            let uniqueStreet = "789 Entity Street \(UniqueCodeGenerator.generateISOCode(prefix: "ENTITY"))"

            let createdAddress = try await service.createAddress(
                entityId: testEntity.id!,
                personId: nil,
                street: uniqueStreet,
                city: "Entity City",
                state: "EC",
                zip: "11111",
                country: "Entity Country",
                isVerified: false
            )

            #expect(createdAddress.street == uniqueStreet)
            #expect(createdAddress.$entity.id == testEntity.id!)
            #expect(createdAddress.$person.id == nil)
            #expect(createdAddress.isVerified == false)
        }
    }

    @Test("AdminAddressService can get address by ID")
    func adminAddressServiceCanGetAddressById() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminAddressService(database: database)

            // Create a test person and address
            let testPerson = Person(
                name: "Get Person \(UniqueCodeGenerator.generateISOCode(prefix: "GET"))",
                email: "get_person_\(UniqueCodeGenerator.generateISOCode(prefix: "GET"))@example.com"
            )
            try await testPerson.save(on: database)

            let uniqueStreet = "Get Street \(UniqueCodeGenerator.generateISOCode(prefix: "GET"))"
            let testAddress = Address(
                personID: testPerson.id!,
                street: uniqueStreet,
                city: "Get City",
                state: "GC",
                zip: "99999",
                country: "Get Country",
                isVerified: true
            )
            try await testAddress.save(on: database)

            // Test getting address by ID
            let retrievedAddress = try await service.getAddress(addressId: testAddress.id!)

            #expect(retrievedAddress != nil)
            #expect(retrievedAddress?.street == uniqueStreet)
            #expect(retrievedAddress?.$person.id == testPerson.id!)
        }
    }

    @Test("AdminAddressService validates required fields")
    func adminAddressServiceValidatesRequiredFields() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminAddressService(database: database)

            let testPerson = Person(
                name: "Validation Person \(UniqueCodeGenerator.generateISOCode(prefix: "VAL"))",
                email: "validation_\(UniqueCodeGenerator.generateISOCode(prefix: "VAL"))@example.com"
            )
            try await testPerson.save(on: database)

            // Test with empty street
            do {
                _ = try await service.createAddress(
                    entityId: nil,
                    personId: testPerson.id!,
                    street: "",
                    city: "Test City",
                    state: "TS",
                    zip: "12345",
                    country: "Test Country",
                    isVerified: false
                )
                #expect(Bool(false), "Should throw ValidationError for empty street")
            } catch let error as ValidationError {
                #expect(error.message.contains("Street address cannot be empty"))
            }

            // Test with empty city
            do {
                _ = try await service.createAddress(
                    entityId: nil,
                    personId: testPerson.id!,
                    street: "Test Street",
                    city: "",
                    state: "TS",
                    zip: "12345",
                    country: "Test Country",
                    isVerified: false
                )
                #expect(Bool(false), "Should throw ValidationError for empty city")
            } catch let error as ValidationError {
                #expect(error.message.contains("City cannot be empty"))
            }
        }
    }

    @Test("AdminAddressService can list entities and people")
    func adminAddressServiceCanListEntitiesAndPeople() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminAddressService(database: database)

            // Create test person
            let testPerson = Person(
                name: "List Person \(UniqueCodeGenerator.generateISOCode(prefix: "LIST"))",
                email: "list_person_\(UniqueCodeGenerator.generateISOCode(prefix: "LIST"))@example.com"
            )
            try await testPerson.save(on: database)

            // Test listing people
            let people = try await service.listPeople()
            #expect(people.count >= 1)
            #expect(people.contains { $0.id == testPerson.id })

            // Test listing entities
            let entities = try await service.listEntities()
            #expect(entities.count >= 0)  // May be empty, that's ok
        }
    }

    @Test("AdminAddressService handles non-existent address gracefully")
    func adminAddressServiceHandlesNonExistentAddress() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminAddressService(database: database)

            let nonExistentId = UUID()
            let retrievedAddress = try await service.getAddress(addressId: nonExistentId)

            #expect(retrievedAddress == nil)
        }
    }
}
