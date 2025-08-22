import Dali
import Fluent
import FluentPostgresDriver
import TestUtilities
import Testing
import Vapor

@Suite("Admin Address Service Tests", .serialized)
struct AdminAddressRoutesTests {

    @Test("AdminAddressService can list all addresses")
    func adminServiceCanListAllAddresses() async throws {
        try await TestUtilities.withApp { app, db in
            // Create test entities and people
            let entityId = try await TestUtilities.createTestPerson(
                db,
                name: "Test Corporation",
                email: "corp@example.com"
            )
            let personId = try await TestUtilities.createTestPerson(db, name: "John Doe", email: "john.doe@example.com")

            // Create test addresses using AdminAddressService
            let addressService = AdminAddressService(database: db)

            let corporateAddress = try await addressService.createAddress(
                entityId: nil,
                personId: entityId,
                street: "123 Corporate Plaza",
                city: "Las Vegas",
                state: "NV",
                zip: "89123",
                country: "USA",
                isVerified: true
            )

            let personalAddress = try await addressService.createAddress(
                entityId: nil,
                personId: personId,
                street: "456 Oak Avenue",
                city: "Reno",
                state: "NV",
                zip: "89501",
                country: "USA",
                isVerified: false
            )

            // Test listing addresses
            let addresses = try await addressService.listAddresses()

            #expect(addresses.count >= 2)

            let corporateFound = addresses.contains { $0.street == "123 Corporate Plaza" }
            let personalFound = addresses.contains { $0.street == "456 Oak Avenue" }

            #expect(corporateFound)
            #expect(personalFound)

            // Verify address details
            if let corporate = addresses.first(where: { $0.street == "123 Corporate Plaza" }) {
                #expect(corporate.city == "Las Vegas")
                #expect(corporate.state == "NV")
                #expect(corporate.zip == "89123")
                #expect(corporate.country == "USA")
                #expect(corporate.isVerified == true)
            }

            if let personal = addresses.first(where: { $0.street == "456 Oak Avenue" }) {
                #expect(personal.city == "Reno")
                #expect(personal.state == "NV")
                #expect(personal.zip == "89501")
                #expect(personal.country == "USA")
                #expect(personal.isVerified == false)
            }
        }
    }

    @Test("AdminAddressService can list entities and people for dropdowns")
    func adminServiceCanListEntitiesAndPeople() async throws {
        try await TestUtilities.withApp { app, db in
            // Create test entities and people using test utilities
            let entityId = try await TestUtilities.createTestPerson(
                db,
                name: "Test Entity Corp",
                email: "entity@example.com"
            )
            let personId = try await TestUtilities.createTestPerson(
                db,
                name: "Jane Smith",
                email: "jane.smith@example.com"
            )

            let addressService = AdminAddressService(database: db)

            // Test listing people for dropdown options
            let people = try await addressService.listPeople()

            #expect(people.count >= 2)

            let entityFound = people.contains { $0.name == "Test Entity Corp" }
            let personFound = people.contains { $0.name == "Jane Smith" }

            #expect(entityFound)
            #expect(personFound)
        }
    }

    @Test("AdminAddressService can create new address for person")
    func adminServiceCanCreateNewAddressForPerson() async throws {
        try await TestUtilities.withApp { app, db in
            let personId = try await TestUtilities.createTestPerson(
                db,
                name: "Test Entity Corp",
                email: "entity@example.com"
            )

            let addressService = AdminAddressService(database: db)

            let address = try await addressService.createAddress(
                entityId: nil,
                personId: personId,
                street: "789 Business Street",
                city: "Henderson",
                state: "NV",
                zip: "89052",
                country: "USA",
                isVerified: true
            )

            // Verify address was created correctly
            #expect(address.street == "789 Business Street")
            #expect(address.city == "Henderson")
            #expect(address.state == "NV")
            #expect(address.zip == "89052")
            #expect(address.country == "USA")
            #expect(address.isVerified == true)
            #expect(address.$person.id == personId)
            #expect(address.$entity.id == nil)
        }
    }

    @Test("AdminAddressService can get specific address by ID")
    func adminServiceCanGetAddressByID() async throws {
        try await TestUtilities.withApp { app, db in
            let personId = try await TestUtilities.createTestPerson(
                db,
                name: "Bob Johnson",
                email: "bob.johnson@example.com"
            )

            let addressService = AdminAddressService(database: db)

            let createdAddress = try await addressService.createAddress(
                entityId: nil,
                personId: personId,
                street: "321 Residential Lane",
                city: "Carson City",
                state: "NV",
                zip: "89701",
                country: "USA",
                isVerified: false
            )

            // Test getting the address by ID
            let retrievedAddress = try await addressService.getAddress(addressId: createdAddress.id!)

            #expect(retrievedAddress != nil)
            #expect(retrievedAddress?.street == "321 Residential Lane")
            #expect(retrievedAddress?.city == "Carson City")
            #expect(retrievedAddress?.state == "NV")
            #expect(retrievedAddress?.zip == "89701")
            #expect(retrievedAddress?.country == "USA")
            #expect(retrievedAddress?.isVerified == false)
        }
    }

    @Test("AdminAddressService validates address creation input")
    func adminServiceValidatesAddressInput() async throws {
        try await TestUtilities.withApp { app, db in
            let addressService = AdminAddressService(database: db)

            // Test that both entityId and personId cannot be provided
            do {
                let personId = try await TestUtilities.createTestPerson(
                    db,
                    name: "Test Person",
                    email: "test@example.com"
                )
                let entityId = UUID()

                _ = try await addressService.createAddress(
                    entityId: entityId,
                    personId: personId,
                    street: "Test Street",
                    city: "Test City",
                    state: nil,
                    zip: nil,
                    country: "USA"
                )

                #expect(Bool(false), "Should have thrown validation error for both entityId and personId")
            } catch {
                #expect(error is ValidationError)
            }

            // Test that neither entityId nor personId cannot be provided
            do {
                _ = try await addressService.createAddress(
                    entityId: nil,
                    personId: nil,
                    street: "Test Street",
                    city: "Test City",
                    state: nil,
                    zip: nil,
                    country: "USA"
                )

                #expect(Bool(false), "Should have thrown validation error for neither entityId nor personId")
            } catch {
                #expect(error is ValidationError)
            }
        }
    }
}
