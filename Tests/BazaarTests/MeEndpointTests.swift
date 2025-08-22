import Fluent
import FluentPostgresDriver
import FluentSQL
import Foundation
import Logging
import PostgresNIO
import TestUtilities
import Testing
import Vapor
import VaporTesting

@testable import Bazaar
@testable import Bouncer
@testable import Dali
@testable import Palette

@Suite("Me Endpoint Tests", .serialized)
struct MeEndpointTests {

    @Test(
        "GET /api/me returns 401 without authentication",
        .disabled("HTTP authentication not working with transaction database")
    )
    func getMeReturns401WithoutAuthentication() async throws {
        try await TestUtilities.withApp { app, database in
            // Configure the Bazaar app
            try await configureApp(app)

            try await app.test(.GET, "/api/me") { response in
                #expect(response.status == .unauthorized)
            }
        }
    }

    @Test(
        "GET /api/me returns current user with valid bearer token",
        .disabled("HTTP authentication not working with transaction database")
    )
    func getMeReturnsCurrentUserWithValidToken() async throws {
        try await TestUtilities.withApp { app, database in
            // Create the admin user that the mock token expects
            try await TestUtilities.createAdminUser(database)

            // Configure the Bazaar app
            try await configureApp(app)

            // Create a valid token that maps to admin@neonlaw.com user
            let validToken = "Bearer admin@neonlaw.com:valid.jwt.token"

            try await app.test(.GET, "/api/me", headers: ["Authorization": validToken]) { response in
                #expect(response.status == .ok)

                let meResponse = try response.content.decode(MeResponse.self)
                #expect(meResponse.user.username == "admin@neonlaw.com")
            }
        }
    }

    @Test(
        "GET /api/me returns user and person data with valid authentication",
        .disabled("HTTP authentication not working with transaction database")
    )
    func getMeReturnsUserAndPersonData() async throws {
        try await TestUtilities.withApp { app, database in
            // Create the admin user that the mock token expects
            try await TestUtilities.createAdminUser(database)

            // Configure the Bazaar app
            try await configureApp(app)

            // Create a valid token that maps to admin@neonlaw.com user
            let validToken = "Bearer admin@neonlaw.com:valid.jwt.token"

            try await app.test(.GET, "/api/me", headers: ["Authorization": validToken]) { response in
                #expect(response.status == .ok)

                let meResponse = try response.content.decode(MeResponse.self)
                #expect(meResponse.user.username == "admin@neonlaw.com")
                #expect(meResponse.person.name == "Admin User")
                #expect(meResponse.person.email == "admin@neonlaw.com")
            }
        }
    }
}

// Response models for the API endpoint
struct MeResponse: Codable {
    let user: UserResponse
    let person: PersonResponse
}

struct UserResponse: Codable {
    let id: String
    let username: String
}

struct PersonResponse: Codable {
    let id: String
    let name: String
    let email: String
}
