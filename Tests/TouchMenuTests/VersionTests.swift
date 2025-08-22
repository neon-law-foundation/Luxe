import Foundation
import Testing

@testable import TouchMenu

@Suite("Version Utility", .serialized)
struct VersionTests {

    @Test("version initializes with service name and default unknown values")
    func createVersionWithServiceName() async throws {
        // Use empty environment to ensure unknown values
        let version = Version(serviceName: "TestService", environment: [:])

        #expect(version.serviceName == "TestService")
        #expect(version.gitCommit == "unknown")
        #expect(version.gitTag == "unknown")
        #expect(version.buildDate == "unknown")
        #expect(version.swiftVersion.contains("6"))
    }

    @Test("version reads git commit, tag, and build date from environment variables")
    func readVersionFromEnvironment() async throws {
        // Use explicit environment for testing
        let testEnvironment = [
            "GIT_COMMIT": "abc1234",
            "GIT_TAG": "v1.2.3",
            "BUILD_DATE": "2024-01-01T12:00:00Z",
        ]

        let version = Version(serviceName: "TestService", environment: testEnvironment)

        #expect(version.serviceName == "TestService")
        #expect(version.gitCommit == "abc1234")
        #expect(version.gitTag == "v1.2.3")
        #expect(version.buildDate == "2024-01-01T12:00:00Z")
    }

    @Test("version encodes to valid JSON data preserving all properties")
    func convertToJSON() async throws {
        let version = Version(serviceName: "TestService")

        let jsonData = try version.toJSON()
        #expect(jsonData.count > 0)

        // Verify it's valid JSON by decoding
        let decoder = JSONDecoder()
        let decodedVersion = try decoder.decode(Version.self, from: jsonData)
        #expect(decodedVersion.serviceName == "TestService")
    }

    @Test("version formats as JSON string containing all version properties")
    func convertToJSONString() async throws {
        let version = Version(serviceName: "TestService")

        let jsonString = try version.toJSONString()
        #expect(jsonString.contains("TestService"))
        #expect(jsonString.contains("serviceName"))
        #expect(jsonString.contains("gitCommit"))
        #expect(jsonString.contains("gitTag"))
        #expect(jsonString.contains("buildDate"))
        #expect(jsonString.contains("swiftVersion"))
    }

    @Test("unknown static version has all properties set to unknown")
    func providesUnknownStaticVersion() async throws {
        // Use empty environment to ensure unknown values
        let unknownVersion = Version(serviceName: "unknown", environment: [:])

        #expect(unknownVersion.serviceName == "unknown")
        #expect(unknownVersion.gitCommit == "unknown")
        #expect(unknownVersion.gitTag == "unknown")
        #expect(unknownVersion.buildDate == "unknown")
    }

    @Test("JSON output includes pretty printing and alphabetical property ordering")
    func formatsJSONProperly() async throws {
        let version = Version(serviceName: "TestService")

        let jsonString = try version.toJSONString()

        // Should be pretty printed (contains newlines and indentation)
        #expect(jsonString.contains("\n"))
        #expect(jsonString.contains("  "))

        // Should be sorted (buildDate should come before gitCommit alphabetically)
        let buildDateIndex = jsonString.range(of: "buildDate")
        let gitCommitIndex = jsonString.range(of: "gitCommit")

        #expect(buildDateIndex != nil)
        #expect(gitCommitIndex != nil)

        if let buildDate = buildDateIndex, let gitCommit = gitCommitIndex {
            #expect(buildDate.lowerBound < gitCommit.lowerBound)
        }
    }
}
