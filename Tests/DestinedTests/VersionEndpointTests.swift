import Foundation
import TestUtilities
import Testing
import TouchMenu
import VaporTesting

@testable import Destined

@Suite("Destined Version Endpoint Tests", .serialized)
struct VersionEndpointTests {

    @Test("Version endpoint returns OK status and version information")
    func versionEndpoint() async throws {
        try await TestUtilities.withWebApp { app in
            try configureApp(app)

            try await app.test(.GET, "/version", headers: ["Accept": "application/json"]) { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType?.subType == "json")

                // Verify the response contains version information
                let body = response.body.string
                #expect(body.contains("serviceName"))
                #expect(body.contains("Destined"))
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
        setenv("GIT_COMMIT", "def5678", 1)
        setenv("GIT_TAG", "v2.0.0", 1)
        setenv("BUILD_DATE", "2025-01-10T13:00:00Z", 1)

        try await TestUtilities.withWebApp { app in
            try configureApp(app)

            try await app.test(.GET, "/version", headers: ["Accept": "application/json"]) { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType?.subType == "json")

                let body = response.body.string
                #expect(body.contains("def5678"))
                #expect(body.contains("v2.0.0"))
                #expect(body.contains("2025-01-10"))
            }
        }

        // Clean up environment variables
        unsetenv("GIT_COMMIT")
        unsetenv("GIT_TAG")
        unsetenv("BUILD_DATE")
    }

    @Test("Version endpoint returns proper JSON structure")
    func versionEndpointJSONStructure() async throws {
        try await TestUtilities.withWebApp { app in
            try configureApp(app)

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

                #expect(json?["serviceName"] as? String == "Destined")
                #expect(json?["gitCommit"] is String)
                #expect(json?["gitTag"] is String)
                #expect(json?["buildDate"] is String)
                #expect(json?["swiftVersion"] is String)
            }
        }
    }

    @Test("Version endpoint uses TouchMenu Version utility")
    func versionEndpointUsesTouchMenuVersion() async throws {
        // Test that the endpoint behavior matches TouchMenu.Version directly
        let directVersion = Version(serviceName: "Destined")

        try await TestUtilities.withWebApp { app in
            try configureApp(app)

            try await app.test(.GET, "/version", headers: ["Accept": "application/json"]) { response in
                #expect(response.status == .ok)

                let body = response.body.string
                guard let data = body.data(using: .utf8) else {
                    #expect(Bool(false), "Response body should be valid UTF-8")
                    return
                }

                // Parse the response JSON
                let responseJson = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                #expect(responseJson != nil)

                // Parse the direct Version JSON
                let directJson = try JSONSerialization.jsonObject(with: directVersion.toJSON()) as? [String: Any]
                #expect(directJson != nil)

                // Compare key fields (values may differ due to environment, but structure should match)
                #expect(responseJson?["serviceName"] as? String == directJson?["serviceName"] as? String)
                #expect(responseJson?["swiftVersion"] as? String == directJson?["swiftVersion"] as? String)

                // Both should have the same fields
                if let responseJson = responseJson, let directJson = directJson {
                    let responseKeys = Set(responseJson.keys)
                    let directKeys = Set(directJson.keys)
                    #expect(responseKeys == directKeys)
                }
            }
        }
    }
}
