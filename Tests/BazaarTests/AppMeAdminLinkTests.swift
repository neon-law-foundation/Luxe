import Bouncer
import Dali
import Fluent
import FluentPostgresDriver
import TestUtilities
import Testing
import Vapor

@testable import Bazaar

@Suite("App Me Admin Link Tests", .serialized)
struct AppMeAdminLinkTests {

    @Test(
        "GET /app/me returns admin link for admin user",
        .disabled("HTTP authentication not working with transaction database")
    )
    func appMeReturnsAdminLinkForAdminUser() async throws {
        try await TestUtilities.withApp { app, database in
            try configureAdminApp(app)

            // Create the admin user in the test database
            try await createTestAdminUser(database)

            let adminToken = "admin@neonlaw.com:valid.test.token"

            try await app.test(.GET, "/app/me", headers: ["Authorization": "Bearer \(adminToken)"]) {
                response in
                #expect(response.status == .ok)

                let html = response.body.string
                #expect(html.contains("Admin Dashboard"))
                #expect(html.contains("/admin"))
            }
        }
    }

    @Test(
        "GET /app/me does not return admin link for non-admin user",
        .disabled("HTTP authentication not working with transaction database")
    )
    func appMeDoesNotReturnAdminLinkForNonAdminUser() async throws {
        try await TestUtilities.withApp { app, database in
            try configureAdminApp(app)

            // Create a staff user (non-admin)
            try await createTestStaffUser(database)

            let staffToken = "teststaff@example.com:valid.test.token"

            try await app.test(.GET, "/app/me", headers: ["Authorization": "Bearer \(staffToken)"]) {
                response in
                #expect(response.status == .ok)

                let html = response.body.string
                #expect(!html.contains("Admin Dashboard"))
                #expect(!html.contains("/admin"))
            }
        }
    }

    @Test(
        "GET /app/me returns 401 for unauthenticated user",
        .disabled("HTTP authentication not working with transaction database")
    )
    func appMeReturns401ForUnauthenticatedUser() async throws {
        try await TestUtilities.withApp { app, database in
            try configureAdminApp(app)

            try await app.test(.GET, "/app/me") { response in
                #expect(response.status == .unauthorized)
            }
        }
    }
}
