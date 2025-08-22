import Crypto
import Foundation
import Logging
import Testing

@testable import Brochure

@Suite("Integrity Checker")
struct IntegrityCheckerTests {

    @Test("SHA256 checksum calculation is correct")
    func testSHA256Calculation() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFilePath = tempDir.appendingPathComponent("test-binary").path
        let checksumPath = tempDir.appendingPathComponent("test-binary.sha256").path

        defer {
            try? FileManager.default.removeItem(atPath: testFilePath)
            try? FileManager.default.removeItem(atPath: checksumPath)
        }

        // Create a test file with known content
        let testContent = "Hello, Brochure CLI integrity testing!"
        try testContent.write(toFile: testFilePath, atomically: true, encoding: .utf8)

        // Calculate expected checksum manually
        let expectedHash = SHA256.hash(data: testContent.data(using: .utf8)!)
        let expectedChecksum = expectedHash.compactMap { String(format: "%02x", $0) }.joined()

        // Write checksum to file
        try expectedChecksum.write(toFile: checksumPath, atomically: true, encoding: .utf8)

        // Test verification
        let checker = IntegrityChecker()
        let result = try await checker.verifyFile(
            binaryPath: testFilePath,
            checksumPath: checksumPath
        )

        #expect(result.isValid)
        #expect(result.expectedChecksum == expectedChecksum)
        #expect(result.actualChecksum == expectedChecksum)
        #expect(result.binaryPath == testFilePath)
        #expect(result.errorMessage == nil)
    }

    @Test("Verification fails with incorrect checksum")
    func testVerificationFailure() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFilePath = tempDir.appendingPathComponent("test-binary-fail").path
        let checksumPath = tempDir.appendingPathComponent("test-binary-fail.sha256").path

        defer {
            try? FileManager.default.removeItem(atPath: testFilePath)
            try? FileManager.default.removeItem(atPath: checksumPath)
        }

        // Create test file
        let testContent = "Test content for failure case"
        try testContent.write(toFile: testFilePath, atomically: true, encoding: .utf8)

        // Write incorrect checksum
        let incorrectChecksum = "0000000000000000000000000000000000000000000000000000000000000000"
        try incorrectChecksum.write(toFile: checksumPath, atomically: true, encoding: .utf8)

        // Test verification
        let checker = IntegrityChecker()
        let result = try await checker.verifyFile(
            binaryPath: testFilePath,
            checksumPath: checksumPath
        )

        #expect(!result.isValid)
        #expect(result.expectedChecksum == incorrectChecksum)
        #expect(result.actualChecksum != incorrectChecksum)
        #expect(result.binaryPath == testFilePath)
    }

    @Test("File not found error is handled correctly")
    func testFileNotFoundError() async throws {
        let checker = IntegrityChecker()
        let nonExistentPath = "/tmp/non-existent-binary-12345"
        let checksumPath = "/tmp/non-existent-checksum-12345"

        await #expect(throws: IntegrityError.self) {
            try await checker.verifyFile(
                binaryPath: nonExistentPath,
                checksumPath: checksumPath
            )
        }
    }

    @Test("Invalid checksum file error is handled correctly")
    func testInvalidChecksumFileError() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFilePath = tempDir.appendingPathComponent("test-binary-valid").path
        let checksumPath = tempDir.appendingPathComponent("invalid-checksum").path

        defer {
            try? FileManager.default.removeItem(atPath: testFilePath)
            try? FileManager.default.removeItem(atPath: checksumPath)
        }

        // Create valid test file
        let testContent = "Valid test content"
        try testContent.write(toFile: testFilePath, atomically: true, encoding: .utf8)

        // Create invalid checksum file (empty or non-existent)
        try "".write(toFile: checksumPath, atomically: true, encoding: .utf8)

        let checker = IntegrityChecker()

        await #expect(throws: IntegrityError.self) {
            try await checker.verifyFile(
                binaryPath: testFilePath,
                checksumPath: checksumPath
            )
        }
    }

    @Test("Batch verification processes multiple files correctly")
    func testBatchVerification() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let file1Path = tempDir.appendingPathComponent("batch-test-1").path
        let file2Path = tempDir.appendingPathComponent("batch-test-2").path
        let checksum1Path = tempDir.appendingPathComponent("batch-test-1.sha256").path
        let checksum2Path = tempDir.appendingPathComponent("batch-test-2.sha256").path

        defer {
            try? FileManager.default.removeItem(atPath: file1Path)
            try? FileManager.default.removeItem(atPath: file2Path)
            try? FileManager.default.removeItem(atPath: checksum1Path)
            try? FileManager.default.removeItem(atPath: checksum2Path)
        }

        // Create first test file and its checksum
        let content1 = "First batch test file"
        try content1.write(toFile: file1Path, atomically: true, encoding: .utf8)
        let hash1 = SHA256.hash(data: content1.data(using: .utf8)!)
        let checksum1 = hash1.compactMap { String(format: "%02x", $0) }.joined()
        try checksum1.write(toFile: checksum1Path, atomically: true, encoding: .utf8)

        // Create second test file and its checksum
        let content2 = "Second batch test file"
        try content2.write(toFile: file2Path, atomically: true, encoding: .utf8)
        let hash2 = SHA256.hash(data: content2.data(using: .utf8)!)
        let checksum2 = hash2.compactMap { String(format: "%02x", $0) }.joined()
        try checksum2.write(toFile: checksum2Path, atomically: true, encoding: .utf8)

        // Prepare batch verification requests
        let verifications = [
            BatchVerificationRequest(
                binaryPath: file1Path,
                method: .localFile(checksum1Path)
            ),
            BatchVerificationRequest(
                binaryPath: file2Path,
                method: .localFile(checksum2Path)
            ),
        ]

        // Test batch verification
        let checker = IntegrityChecker()
        let results = try await checker.verifyBatch(verifications)

        #expect(results.count == 2)
        #expect(results[0].isValid)
        #expect(results[1].isValid)
        #expect(results[0].binaryPath == file1Path)
        #expect(results[1].binaryPath == file2Path)
    }

    @Test("Batch verification handles partial failures gracefully")
    func testBatchVerificationWithFailures() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let validFilePath = tempDir.appendingPathComponent("valid-batch-file").path
        let invalidFilePath = "/tmp/non-existent-batch-file-12345"
        let validChecksumPath = tempDir.appendingPathComponent("valid-batch-file.sha256").path
        let invalidChecksumPath = "/tmp/non-existent-checksum-12345"

        defer {
            try? FileManager.default.removeItem(atPath: validFilePath)
            try? FileManager.default.removeItem(atPath: validChecksumPath)
        }

        // Create valid file and checksum
        let validContent = "Valid batch file content"
        try validContent.write(toFile: validFilePath, atomically: true, encoding: .utf8)
        let validHash = SHA256.hash(data: validContent.data(using: .utf8)!)
        let validChecksum = validHash.compactMap { String(format: "%02x", $0) }.joined()
        try validChecksum.write(toFile: validChecksumPath, atomically: true, encoding: .utf8)

        // Prepare batch with one valid and one invalid verification
        let verifications = [
            BatchVerificationRequest(
                binaryPath: validFilePath,
                method: .localFile(validChecksumPath)
            ),
            BatchVerificationRequest(
                binaryPath: invalidFilePath,
                method: .localFile(invalidChecksumPath)
            ),
        ]

        // Test batch verification
        let checker = IntegrityChecker()
        let results = try await checker.verifyBatch(verifications)

        #expect(results.count == 2)
        #expect(results[0].isValid)  // First should succeed
        #expect(!results[1].isValid)  // Second should fail
        #expect(results[1].errorMessage != nil)  // Should have error message
    }

    @Test("Verification method descriptions are correct")
    func testVerificationMethodDescriptions() {
        let localMethod = VerificationMethod.localFile("/tmp/test.sha256")
        let remoteMethod = VerificationMethod.remoteURL("https://example.com/test.sha256")

        #expect(localMethod.description == "Local file: /tmp/test.sha256")
        #expect(remoteMethod.description == "Remote URL: https://example.com/test.sha256")
    }

    @Test("Integrity errors provide helpful descriptions")
    func testIntegrityErrorDescriptions() {
        let fileNotFoundError = IntegrityError.fileNotFound("/tmp/missing")
        let invalidChecksumError = IntegrityError.invalidChecksumFile("/tmp/bad.sha256")
        let invalidURLError = IntegrityError.invalidURL("not-a-url")

        #expect(fileNotFoundError.errorDescription == "File not found: /tmp/missing")
        #expect(invalidChecksumError.errorDescription == "Invalid checksum file: /tmp/bad.sha256")
        #expect(invalidURLError.errorDescription == "Invalid URL: not-a-url")

        #expect(fileNotFoundError.recoverySuggestion != nil)
        #expect(invalidChecksumError.recoverySuggestion != nil)
        #expect(invalidURLError.recoverySuggestion != nil)
    }

    @Test("VerificationResult captures all required information")
    func testVerificationResultStructure() {
        let result = VerificationResult(
            binaryPath: "/usr/local/bin/test",
            expectedChecksum: "abc123",
            actualChecksum: "def456",
            isValid: false,
            verificationMethod: .localFile("/tmp/test.sha256"),
            errorMessage: "Checksum mismatch"
        )

        #expect(result.binaryPath == "/usr/local/bin/test")
        #expect(result.expectedChecksum == "abc123")
        #expect(result.actualChecksum == "def456")
        #expect(!result.isValid)
        #expect(result.errorMessage == "Checksum mismatch")
        #expect(result.verificationTime <= Date())  // Should be recent
    }
}
