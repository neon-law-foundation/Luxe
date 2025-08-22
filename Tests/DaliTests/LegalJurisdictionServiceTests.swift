import Fluent
import FluentPostgresDriver
import Logging
import PostgresNIO
import TestUtilities
import Testing
import Vapor

@testable import Dali
@testable import Palette

@Suite("Legal Jurisdiction Service Tests", .serialized)
struct LegalJurisdictionServiceTests {

    @Test("LegalJurisdictionService can list jurisdictions")
    func legalJurisdictionServiceCanListJurisdictions() async throws {
        try await TestUtilities.withApp { app, database in
            let service = LegalJurisdictionService(database: database)

            // Create a test jurisdiction first
            let uniqueName = "Test Jurisdiction \(UniqueCodeGenerator.generateISOCode(prefix: "JURIS"))"
            let uniqueCode = "TJ_\(UniqueCodeGenerator.generateISOCode(prefix: "CODE"))"
            let testJurisdiction = LegalJurisdiction(name: uniqueName, code: uniqueCode)
            try await testJurisdiction.save(on: database)

            // Test listing jurisdictions
            let jurisdictions = try await service.listJurisdictions()

            #expect(jurisdictions.count >= 1)
            #expect(jurisdictions.contains { $0.name == uniqueName })
        }
    }

    @Test("LegalJurisdictionService can get jurisdiction by ID")
    func legalJurisdictionServiceCanGetJurisdictionById() async throws {
        try await TestUtilities.withApp { app, database in
            let service = LegalJurisdictionService(database: database)

            // Create a test jurisdiction
            let uniqueName = "Get Jurisdiction \(UniqueCodeGenerator.generateISOCode(prefix: "GET"))"
            let uniqueCode = "GET_\(UniqueCodeGenerator.generateISOCode(prefix: "GET"))"
            let testJurisdiction = LegalJurisdiction(name: uniqueName, code: uniqueCode)
            try await testJurisdiction.save(on: database)

            // Test getting jurisdiction by ID
            guard let jurisdictionId = testJurisdiction.id else {
                throw ValidationError("Jurisdiction ID not available after save")
            }

            let retrievedJurisdiction = try await service.getJurisdiction(jurisdictionId: jurisdictionId)

            #expect(retrievedJurisdiction != nil)
            #expect(retrievedJurisdiction?.name == uniqueName)
            #expect(retrievedJurisdiction?.code == uniqueCode)
        }
    }

    @Test("LegalJurisdictionService can list jurisdictions for API")
    func legalJurisdictionServiceCanListJurisdictionsForAPI() async throws {
        try await TestUtilities.withApp { app, database in
            let service = LegalJurisdictionService(database: database)

            // Create a test jurisdiction
            let uniqueName = "API Jurisdiction \(UniqueCodeGenerator.generateISOCode(prefix: "API"))"
            let uniqueCode = "API_\(UniqueCodeGenerator.generateISOCode(prefix: "API"))"
            let testJurisdiction = LegalJurisdiction(name: uniqueName, code: uniqueCode)
            try await testJurisdiction.save(on: database)

            // Test API listing (returns dictionaries)
            let apiJurisdictions = try await service.listJurisdictionsForAPI()

            #expect(apiJurisdictions.count >= 1)

            // Check that our test jurisdiction appears in the API results
            let matchingJurisdiction = apiJurisdictions.first { dict in
                dict["name"] == uniqueName && dict["code"] == uniqueCode
            }
            #expect(matchingJurisdiction != nil)
        }
    }

    @Test("LegalJurisdictionService handles non-existent jurisdiction gracefully")
    func legalJurisdictionServiceHandlesNonExistentJurisdiction() async throws {
        try await TestUtilities.withApp { app, database in
            let service = LegalJurisdictionService(database: database)

            let nonExistentId = UUID()
            let retrievedJurisdiction = try await service.getJurisdiction(jurisdictionId: nonExistentId)

            #expect(retrievedJurisdiction == nil)
        }
    }

    @Test("LegalJurisdictionService sorts jurisdictions by name")
    func legalJurisdictionServiceSortsJurisdictionsByName() async throws {
        try await TestUtilities.withApp { app, database in
            let service = LegalJurisdictionService(database: database)

            // Create multiple test jurisdictions with different names
            let uniqueId = UniqueCodeGenerator.generateISOCode(prefix: "SORT")
            let jurisdictionA = LegalJurisdiction(name: "A Jurisdiction \(uniqueId)", code: "A\(uniqueId)")
            let jurisdictionZ = LegalJurisdiction(name: "Z Jurisdiction \(uniqueId)", code: "Z\(uniqueId)")
            let jurisdictionM = LegalJurisdiction(name: "M Jurisdiction \(uniqueId)", code: "M\(uniqueId)")

            try await jurisdictionZ.save(on: database)
            try await jurisdictionA.save(on: database)
            try await jurisdictionM.save(on: database)

            // Test listing (should be sorted by name)
            let jurisdictions = try await service.listJurisdictions()

            // Find our test jurisdictions in the results
            guard let indexA = jurisdictions.firstIndex(where: { $0.name == "A Jurisdiction \(uniqueId)" }),
                let indexM = jurisdictions.firstIndex(where: { $0.name == "M Jurisdiction \(uniqueId)" }),
                let indexZ = jurisdictions.firstIndex(where: { $0.name == "Z Jurisdiction \(uniqueId)" })
            else {
                throw ValidationError("Test jurisdictions not found in results")
            }

            // Should be in alphabetical order
            #expect(indexA < indexM)
            #expect(indexM < indexZ)
        }
    }

    @Test("LegalJurisdictionService API endpoint maintains raw SQL compatibility")
    func legalJurisdictionServiceAPIEndpointMaintainsRawSQLCompatibility() async throws {
        try await TestUtilities.withApp { app, database in
            let service = LegalJurisdictionService(database: database)

            // Create test jurisdictions
            let jurisdiction1 = LegalJurisdiction(
                name: "SQL Test 1 \(UniqueCodeGenerator.generateISOCode(prefix: "SQL1"))",
                code: "SQL1"
            )
            let jurisdiction2 = LegalJurisdiction(
                name: "SQL Test 2 \(UniqueCodeGenerator.generateISOCode(prefix: "SQL2"))",
                code: "SQL2"
            )

            try await jurisdiction1.save(on: database)
            try await jurisdiction2.save(on: database)

            // Test API response format matches what the frontend expects
            let apiResults = try await service.listJurisdictionsForAPI()

            // Verify structure - each item should be a dictionary with name and code
            for item in apiResults {
                #expect(item.keys.contains("name"))
                #expect(item.keys.contains("code"))
                #expect(item.keys.count == 2)  // Only name and code keys

                // Verify values are strings
                #expect(item["name"] != nil)
                #expect(item["code"] != nil)
            }

            // Verify our test jurisdictions are present
            let hasJuris1 = apiResults.contains { $0["name"] == jurisdiction1.name }
            let hasJuris2 = apiResults.contains { $0["name"] == jurisdiction2.name }

            #expect(hasJuris1)
            #expect(hasJuris2)
        }
    }
}
