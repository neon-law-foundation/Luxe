import Fluent
import FluentPostgresDriver
import Foundation
import Logging
import PostgresNIO
import TestUtilities
import Testing
import Vapor
import VaporTesting

@testable import Bazaar
@testable import Dali
@testable import Palette

@Suite("Legal Jurisdictions Endpoint Tests", .serialized)
struct LegalJurisdictionsEndpointTests {

    @Test(
        "GET /api/legal-jurisdictions returns list of jurisdictions",
        .disabled("HTTP authentication not working with transaction database")
    )
    func getLegalJurisdictionsReturnsJurisdictions() async throws {
        try await TestUtilities.withApp { app, database in
            // Configure the Bazaar app
            try await configureApp(app)

            try await app.test(.GET, "/api/legal-jurisdictions") { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .json)

                // Decode the response as an array of jurisdictions
                let jurisdictions = try response.content.decode([LegalJurisdictionResponse].self)

                // Should have at least the Nevada jurisdiction from migrations
                #expect(jurisdictions.count >= 1)

                // Check that Nevada exists (from migration)
                let nevada = jurisdictions.first { $0.code == "NV" }
                #expect(nevada != nil)
                #expect(nevada?.name == "Nevada")
            }
        }
    }

    @Test(
        "Legal jurisdictions response has correct structure",
        .disabled("HTTP authentication not working with transaction database")
    )
    func legalJurisdictionsResponseHasCorrectStructure() async throws {
        try await TestUtilities.withApp { app, database in
            // Configure the Bazaar app
            try await configureApp(app)

            try await app.test(.GET, "/api/legal-jurisdictions") { response in
                #expect(response.status == .ok)

                let jurisdictions = try response.content.decode([LegalJurisdictionResponse].self)

                // Each jurisdiction should have name and code
                for jurisdiction in jurisdictions {
                    #expect(!jurisdiction.name.isEmpty)
                    #expect(!jurisdiction.code.isEmpty)
                }
            }
        }
    }
}

// Response model for the API endpoint
struct LegalJurisdictionResponse: Codable {
    let name: String
    let code: String
}
