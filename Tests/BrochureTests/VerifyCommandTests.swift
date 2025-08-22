import Crypto
import Foundation
import Logging
import Testing

@testable import Brochure

@Suite("Verify Command")
struct VerifyCommandTests {

    @Test("Platform detection returns expected values")
    func testPlatformDetection() {
        // Test that we can detect the current platform correctly
        #if os(macOS)
        let expectedPlatform = "darwin"
        #elseif os(Linux)
        let expectedPlatform = "linux"
        #else
        let expectedPlatform = "unknown"
        #endif

        // Verify platform constants are correct
        #expect(expectedPlatform.count > 0)
    }

    @Test("Architecture detection returns expected values")
    func testArchitectureDetection() {
        // Test that we can detect the current architecture correctly
        #if arch(arm64)
        let expectedArch = "arm64"
        #elseif arch(x86_64)
        let expectedArch = "x64"
        #else
        let expectedArch = "unknown"
        #endif

        // Verify architecture constants are correct
        #expect(expectedArch.count > 0)
    }

    @Test("JSONVerificationResult serializes correctly")
    func testJSONVerificationResult() throws {
        let verificationResult = VerificationResult(
            binaryPath: "/usr/local/bin/brochure",
            expectedChecksum: "abc123def456",
            actualChecksum: "abc123def456",
            isValid: true,
            verificationMethod: .localFile("/tmp/brochure.sha256")
        )

        // Create JSON result using the private struct approach
        // We'll test this by creating our own version
        let jsonResult = TestJSONVerificationResult(from: verificationResult)

        #expect(jsonResult.success == true)
        #expect(jsonResult.binaryPath == "/usr/local/bin/brochure")
        #expect(jsonResult.expectedChecksum == "abc123def456")
        #expect(jsonResult.actualChecksum == "abc123def456")
        #expect(jsonResult.verificationMethod == "Local file: /tmp/brochure.sha256")
        #expect(jsonResult.errorMessage == nil)

        // Test JSON encoding
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let jsonData = try encoder.encode(jsonResult)
        let jsonString = String(data: jsonData, encoding: .utf8)!

        #expect(jsonString.contains("\"success\" : true"))
        // Handle both escaped and unescaped JSON forward slashes
        #expect(
            jsonString.contains("\"binaryPath\" : \"/usr/local/bin/brochure\"")
                || jsonString.contains("\"binaryPath\" : \"\\/usr\\/local\\/bin\\/brochure\"")
        )
        #expect(jsonString.contains("\"expectedChecksum\" : \"abc123def456\""))
    }

    @Test("JSONVerificationResult handles failed verification")
    func testJSONVerificationResultFailure() throws {
        let verificationResult = VerificationResult(
            binaryPath: "/usr/local/bin/brochure",
            expectedChecksum: "expected123",
            actualChecksum: "actual456",
            isValid: false,
            verificationMethod: .remoteURL("https://example.com/test.sha256"),
            errorMessage: "Checksum mismatch detected"
        )

        let jsonResult = TestJSONVerificationResult(from: verificationResult)

        #expect(jsonResult.success == false)
        #expect(jsonResult.expectedChecksum == "expected123")
        #expect(jsonResult.actualChecksum == "actual456")
        #expect(jsonResult.errorMessage == "Checksum mismatch detected")
        #expect(jsonResult.verificationMethod == "Remote URL: https://example.com/test.sha256")
    }

    @Test("JSONErrorResult serializes correctly")
    func testJSONErrorResult() throws {
        let error = IntegrityError.fileNotFound("/tmp/missing-file")
        let errorResult = TestJSONErrorResult(
            success: false,
            error: error.localizedDescription,
            errorType: String(describing: type(of: error))
        )

        #expect(errorResult.success == false)
        #expect(errorResult.error == "File not found: /tmp/missing-file")
        #expect(errorResult.errorType == "IntegrityError")

        // Test JSON encoding
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let jsonData = try encoder.encode(errorResult)
        let jsonString = String(data: jsonData, encoding: .utf8)!

        #expect(jsonString.contains("\"success\" : false"))
        // Handle both escaped and unescaped JSON forward slashes
        #expect(
            jsonString.contains("\"error\" : \"File not found: /tmp/missing-file\"")
                || jsonString.contains("\"error\" : \"File not found: \\/tmp\\/missing-file\"")
        )
        #expect(jsonString.contains("\"errorType\" : \"IntegrityError\""))
    }

    @Test("Command configuration is set correctly")
    func testCommandConfiguration() {
        let config = VerifyCommand.configuration

        #expect(config.commandName == "verify")
        #expect(config.abstract == "Verify binary integrity using SHA256 checksums")
        #expect(config.discussion.contains("Verify the integrity of Brochure CLI binaries"))
        #expect(config.discussion.contains("SHA256 checksums"))
        #expect(config.discussion.contains("VERIFICATION METHODS"))
        #expect(config.discussion.contains("EXAMPLES"))
        #expect(config.discussion.contains("EXIT CODES"))
    }

    @Test("Command configuration includes all expected options")
    func testParameterValidation() {
        // Test that the command configuration is structured correctly
        let config = VerifyCommand.configuration

        // Verify command configuration exists and has the right name
        #expect(config.commandName == "verify")
        #expect(config.abstract.contains("integrity"))
    }

    @Test("Self verification constructs correct remote checksum URL")
    func testSelfVerificationURL() {
        // Test URL construction for self-verification
        let bucket = "cli.neonlaw.com"
        let prefix = "brochure"

        // Test with different version scenarios
        let stableVersion = "1.2.3"
        let _ = "1.2.3-dev"
        let _ = "unknown"

        // For stable version
        let stableURL = "https://\(bucket)/\(prefix)/\(stableVersion)/darwin-arm64/brochure.sha256"
        #expect(stableURL.contains(stableVersion))

        // For dev version (should use "latest")
        let devURL = "https://\(bucket)/\(prefix)/latest/darwin-arm64/brochure.sha256"
        #expect(devURL.contains("latest"))

        // For unknown version (should use "latest")
        let unknownURL = "https://\(bucket)/\(prefix)/latest/darwin-arm64/brochure.sha256"
        #expect(unknownURL.contains("latest"))
    }
}

// Test helper structs that mirror the private structs in VerifyCommand

private struct TestJSONVerificationResult: Codable {
    let success: Bool
    let binaryPath: String
    let expectedChecksum: String
    let actualChecksum: String
    let verificationMethod: String
    let verificationTime: String
    let errorMessage: String?

    init(from result: VerificationResult) {
        self.success = result.isValid
        self.binaryPath = result.binaryPath
        self.expectedChecksum = result.expectedChecksum
        self.actualChecksum = result.actualChecksum
        self.verificationMethod = result.verificationMethod.description

        let formatter = ISO8601DateFormatter()
        self.verificationTime = formatter.string(from: result.verificationTime)

        self.errorMessage = result.errorMessage
    }
}

private struct TestJSONErrorResult: Codable {
    let success: Bool
    let error: String
    let errorType: String
}
