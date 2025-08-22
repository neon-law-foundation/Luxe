import Foundation
import Testing

@testable import Brochure

@Suite("Version Information")
struct VersionTests {

    @Test("VersionInfo parses semantic version correctly")
    func testSemanticVersionParsing() {
        // Test basic semantic version
        let version1 = VersionInfo(
            version: "1.2.3",
            gitCommit: "abc123",
            platform: "darwin",
            architecture: "arm64"
        )

        #expect(version1.majorVersion == 1)
        #expect(version1.minorVersion == 2)
        #expect(version1.patchVersion == 3)
        #expect(version1.preRelease == nil)
        #expect(version1.buildMetadata == nil)
        #expect(version1.fullVersion == "1.2.3")
        #expect(version1.shortVersion == "1.2.3")

        // Test version with pre-release
        let version2 = VersionInfo(
            version: "2.0.0-beta.1",
            gitCommit: "def456",
            platform: "linux",
            architecture: "x64"
        )

        #expect(version2.majorVersion == 2)
        #expect(version2.minorVersion == 0)
        #expect(version2.patchVersion == 0)
        #expect(version2.preRelease == "beta.1")
        #expect(version2.buildMetadata == nil)
        #expect(version2.fullVersion == "2.0.0-beta.1")
        #expect(version2.shortVersion == "2.0.0-beta.1")

        // Test version with build metadata
        let version3 = VersionInfo(
            version: "1.0.0+20130313144700",
            gitCommit: "ghi789",
            platform: "darwin",
            architecture: "x64"
        )

        #expect(version3.majorVersion == 1)
        #expect(version3.minorVersion == 0)
        #expect(version3.patchVersion == 0)
        #expect(version3.preRelease == nil)
        #expect(version3.buildMetadata == "20130313144700")
        #expect(version3.fullVersion == "1.0.0+20130313144700")
        #expect(version3.shortVersion == "1.0.0")

        // Test version with both pre-release and build metadata
        let version4 = VersionInfo(
            version: "1.0.0-alpha.1+beta",
            gitCommit: "jkl012",
            platform: "linux",
            architecture: "arm64"
        )

        #expect(version4.majorVersion == 1)
        #expect(version4.minorVersion == 0)
        #expect(version4.patchVersion == 0)
        #expect(version4.preRelease == "alpha.1")
        #expect(version4.buildMetadata == "beta")
        #expect(version4.fullVersion == "1.0.0-alpha.1+beta")
        #expect(version4.shortVersion == "1.0.0-alpha.1")

        // Test version with 'v' prefix
        let version5 = VersionInfo(
            version: "v3.1.4",
            gitCommit: "mno345",
            platform: "darwin",
            architecture: "arm64"
        )

        #expect(version5.majorVersion == 3)
        #expect(version5.minorVersion == 1)
        #expect(version5.patchVersion == 4)
        #expect(version5.fullVersion == "3.1.4")
    }

    @Test("VersionInfo generates correct derived fields")
    func testDerivedFields() {
        let version = VersionInfo(
            version: "1.0.0",
            gitCommit: "abcdef1234567890",
            gitBranch: "feature/test",
            gitDirty: true,
            platform: "darwin",
            architecture: "arm64",
            buildConfiguration: "release",
            swiftVersion: "6.0",
            compiler: "Swift 6.0"
        )

        #expect(version.gitShortCommit == "abcdef12")
        #expect(version.platformArch == "darwin-arm64")
        #expect(version.detailedVersion.contains("1.0.0-dirty"))
        #expect(version.detailedVersion.contains("(abcdef12)"))
        #expect(version.detailedVersion.contains("on feature/test"))
    }

    @Test("VersionInfo provides comprehensive build info")
    func testBuildInfo() {
        let version = VersionInfo(
            version: "2.1.0",
            gitCommit: "1234567890abcdef",
            platform: "linux",
            architecture: "x64",
            buildConfiguration: "release",
            swiftVersion: "6.0.1",
            compiler: "Swift 6.0.1"
        )

        let buildInfo = version.buildInfo
        #expect(buildInfo.contains("Platform: linux-x64"))
        #expect(buildInfo.contains("Config: release"))
        #expect(buildInfo.contains("Swift: 6.0.1"))
        #expect(buildInfo.contains("Compiler: Swift 6.0.1"))
    }

    @Test("VersionInfo CLI output is properly formatted")
    func testCLIOutput() {
        let version = VersionInfo(
            version: "1.2.3",
            gitCommit: "abcdef123456",
            gitBranch: "main",
            gitDirty: false,
            platform: "darwin",
            architecture: "arm64",
            buildConfiguration: "release"
        )

        let output = version.cliOutput
        #expect(output.contains("Brochure CLI"))
        #expect(output.contains("1.2.3"))
        #expect(output.contains("(abcdef12)"))
        #expect(output.contains("Platform: darwin-arm64"))
    }

    @Test("VersionInfo handles edge cases")
    func testEdgeCases() {
        // Test minimal version
        let minimalVersion = VersionInfo(
            version: "1",
            gitCommit: "abc",
            platform: "test",
            architecture: "test"
        )

        #expect(minimalVersion.majorVersion == 1)
        #expect(minimalVersion.minorVersion == 0)
        #expect(minimalVersion.patchVersion == 0)

        // Test empty pre-release/build metadata
        let emptyVersion = VersionInfo(
            version: "1.0.0-",
            gitCommit: "def",
            platform: "test",
            architecture: "test"
        )

        #expect(emptyVersion.preRelease == "")
        #expect(emptyVersion.buildMetadata == nil)

        // Test invalid version numbers
        let invalidVersion = VersionInfo(
            version: "invalid.version.string",
            gitCommit: "ghi",
            platform: "test",
            architecture: "test"
        )

        #expect(invalidVersion.majorVersion == 0)
        #expect(invalidVersion.minorVersion == 0)
        #expect(invalidVersion.patchVersion == 0)
    }

    @Test("VersionInfo JSON encoding works correctly")
    func testJSONEncoding() throws {
        let version = VersionInfo(
            version: "1.0.0-alpha.1+build.123",
            gitCommit: "abcdef1234567890",
            gitBranch: "develop",
            gitDirty: true,
            platform: "darwin",
            architecture: "arm64",
            buildConfiguration: "debug",
            swiftVersion: "6.0",
            compiler: "Swift 6.0"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let jsonData = try encoder.encode(version)
        let jsonString = String(data: jsonData, encoding: .utf8)

        #expect(jsonString != nil)
        #expect(jsonString!.contains("\"version\" : \"1.0.0-alpha.1+build.123\""))
        #expect(jsonString!.contains("\"majorVersion\" : 1"))
        #expect(jsonString!.contains("\"preRelease\" : \"alpha.1\""))
        #expect(jsonString!.contains("\"buildMetadata\" : \"build.123\""))
        #expect(jsonString!.contains("\"gitDirty\" : true"))
        #expect(jsonString!.contains("\"platformArch\" : \"darwin-arm64\""))
    }

    @Test("VersionInfo environment parsing works")
    func testEnvironmentParsing() {
        // Note: This test doesn't actually set environment variables
        // It just tests that the fromEnvironment method handles missing variables gracefully

        let envVersion = VersionInfo.fromEnvironment()
        // Should return nil when required environment variables are missing
        #expect(envVersion == nil)
    }

    @Test("Current version is accessible")
    func testCurrentVersion() {
        // Test that currentVersion is accessible and has reasonable defaults
        let version = currentVersion

        #expect(version.version.count > 0)
        #expect(version.gitCommit.count > 0)
        #expect(version.platform.count > 0)
        #expect(version.architecture.count > 0)
        #expect(version.majorVersion >= 0)
        #expect(version.minorVersion >= 0)
        #expect(version.patchVersion >= 0)
    }
}
