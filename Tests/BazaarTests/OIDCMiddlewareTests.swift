import Bouncer
import Dali
import Fluent
import FluentPostgresDriver
import TestUtilities
import Testing
import VaporTesting

@testable import Bazaar
@testable import Palette

@Suite("OIDC Middleware Tests", .serialized)
struct OIDCMiddlewareTests {

    @Test(
        "OIDC middleware authenticates admin@neonlaw.com user",
        .disabled("HTTP authentication not working with transaction database")
    )
    func oidcMiddlewareAuthenticatesAdminUser() async throws {
        try await TestUtilities.withApp { app, database in
            try await configureApp(app)

            let adminToken = "admin@neonlaw.com:valid.test.token"

            var headers: HTTPHeaders = ["Authorization": "Bearer \(adminToken)"]
            headers.add(name: .accept, value: "application/json")

            try await app.test(.GET, "/app/me", headers: headers) { response in
                #expect(response.status == .ok)

                let meResponse = try response.content.decode(Bazaar.MeResponse.self)
                #expect(meResponse.user.username == "admin@neonlaw.com")
                #expect(!meResponse.user.id.isEmpty)
            }
        }
    }

    @Test(
        "OIDC middleware handles invalid token",
        .disabled("HTTP authentication not working with transaction database")
    )
    func oidcMiddlewareHandlesInvalidToken() async throws {
        try await TestUtilities.withApp { app, database in
            try await configureApp(app)

            let invalidToken = "invalid"

            var headers: HTTPHeaders = ["Authorization": "Bearer \(invalidToken)"]
            headers.add(name: .accept, value: "application/json")

            try await app.test(.GET, "/app/me", headers: headers) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }
}
