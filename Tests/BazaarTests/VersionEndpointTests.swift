import TestUtilities
import Testing
import TouchMenu
import VaporTesting

@testable import Bazaar
@testable import Dali

@Suite("Version Endpoint Response Tests", .serialized)
struct VersionEndpointTests {
    @Test("Version endpoint returns OK status and version information")
    func versionEndpoint() async throws {
        try await TestUtilities.withApp { app, database in
            try configureVersionEndpointApp(app)

            // Test the /version endpoint (public endpoint, no auth required)
            try await app.test(.GET, "/version", headers: ["Accept": "application/json"]) { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType?.subType == "json")

                // Verify the response contains version information
                let body = response.body.string
                #expect(body.contains("serviceName"))
                #expect(body.contains("Bazaar"))
                #expect(body.contains("gitCommit"))
                #expect(body.contains("gitTag"))
                #expect(body.contains("buildDate"))
                #expect(body.contains("swiftVersion"))
            }
        }
    }

    @Test("Version endpoint with environment variables")
    func versionEndpointWithEnvironmentVariables() async throws {
        // Set test environment variables
        setenv("GIT_COMMIT", "abc1234", 1)
        setenv("GIT_TAG", "v1.2.3", 1)
        setenv("BUILD_DATE", "2024-01-01T12:00:00Z", 1)

        try await TestUtilities.withApp { app, database in
            try configureVersionEndpointApp(app)

            // Test with environment variables set
            try await app.test(.GET, "/version", headers: ["Accept": "application/json"]) { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType?.subType == "json")

                let body = response.body.string
                #expect(body.contains("abc1234"))
                #expect(body.contains("v1.2.3"))
                #expect(body.contains("2024-01-01"))
            }
        }

        // Clean up environment variables
        unsetenv("GIT_COMMIT")
        unsetenv("GIT_TAG")
        unsetenv("BUILD_DATE")
    }

    @Test("Version endpoint returns proper JSON structure")
    func versionEndpointJSONStructure() async throws {
        try await TestUtilities.withApp { app, database in
            try configureVersionEndpointApp(app)

            try await app.test(.GET, "/version", headers: ["Accept": "application/json"]) { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType?.subType == "json")

                // Parse JSON to verify structure
                let body = response.body.string
                guard let data = body.data(using: .utf8) else {
                    #expect(Bool(false), "Response body should be valid UTF-8")
                    return
                }

                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                #expect(json != nil, "Response should be valid JSON object")

                #expect(json?["serviceName"] as? String == "Bazaar")
                #expect(json?["gitCommit"] is String)
                #expect(json?["gitTag"] is String)
                #expect(json?["buildDate"] is String)
                #expect(json?["swiftVersion"] is String)
            }
        }
    }
}

/// Minimal app configuration for version endpoint tests
/// This avoids the complex OIDC and OpenAPI setup that can fail in tests
func configureVersionEndpointApp(_ app: Application) throws {
    // Configure DALI models (required for basic app setup)
    try configureDali(app)

    // Configure the version endpoint route
    app.get("version") { req async throws -> Response in
        let version = TouchMenu.Version(serviceName: "Bazaar")
        let jsonData = try version.toJSON()
        let response = Response(status: .ok, body: .init(data: jsonData))
        response.headers.contentType = .json
        return response
    }

    // Configure health endpoint for completeness
    app.get("health") { _ in
        "OK"
    }
}
