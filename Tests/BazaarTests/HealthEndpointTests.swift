import TestUtilities
import Testing
import VaporTesting

@testable import Bazaar

@Suite("Health Endpoint Status Tests", .serialized)
struct HealthEndpointTests {
    @Test("Health endpoint returns OK status", .disabled("HTTP authentication not working with transaction database"))
    func healthEndpoint() async throws {
        try await TestUtilities.withApp { app, database in
            try await configureApp(app)

            try await app.test(.GET, "/health") { response in
                #expect(response.status == .ok)
                #expect(response.body.string == "OK")
            }
        }
    }
}
