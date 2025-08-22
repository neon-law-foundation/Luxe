import Foundation
import SotoS3
import Testing

@testable import Brochure

@Suite("Error handling and retry logic", .serialized)
struct ErrorHandlingTests {

    @Test("S3Uploader retries transient errors")
    func retryTransientErrors() async throws {
        let mockClient = MockS3Client()
        let config = UploadConfiguration(
            bucketName: "test-bucket",
            keyPrefix: "test-prefix",
            maxRetries: 3,
            retryBaseDelay: 0.001  // Very short delay for testing
        )
        let uploader = S3Uploader(configuration: config, s3Client: mockClient)

        // Create a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test.txt")
        try "Hello, World!".write(to: testFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: testFile)
        }

        // Mock transient failures followed by success
        mockClient.putObjectResults.append(.failure(MockS3Error.uploadFailed))
        mockClient.putObjectResults.append(.failure(MockS3Error.uploadFailed))
        mockClient.putObjectResults.append(.failure(MockS3Error.uploadFailed))
        mockClient.putObjectResults.append(.success(()))

        // Test upload (should succeed after max retries)
        try await uploader.uploadFile(
            localPath: testFile.path,
            remotePath: "test/test.txt",
            contentType: "text/plain",
            skipUnchanged: false
        )

        // Verify 4 attempts were made (initial + 3 retries)
        #expect(mockClient.putObjectRequests.count == 4)

        try await uploader.shutdown()
    }

    @Test("S3Uploader fails after exceeding max retries")
    func failAfterMaxRetries() async throws {
        let mockClient = MockS3Client()
        let config = UploadConfiguration(
            bucketName: "test-bucket",
            keyPrefix: "test-prefix",
            maxRetries: 2,
            retryBaseDelay: 0.001
        )
        let uploader = S3Uploader(configuration: config, s3Client: mockClient)

        // Create a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test.txt")
        try "Hello, World!".write(to: testFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: testFile)
        }

        // Mock continuous failures
        mockClient.putObjectResults.append(.failure(MockS3Error.uploadFailed))
        mockClient.putObjectResults.append(.failure(MockS3Error.uploadFailed))
        mockClient.putObjectResults.append(.failure(MockS3Error.uploadFailed))

        // Test upload (should fail after retries)
        await #expect(throws: MockS3Error.uploadFailed) {
            try await uploader.uploadFile(
                localPath: testFile.path,
                remotePath: "test/test.txt",
                contentType: "text/plain",
                skipUnchanged: false
            )
        }

        // Verify 3 attempts were made (initial + 2 retries)
        #expect(mockClient.putObjectRequests.count == 3)

        try await uploader.shutdown()
    }

    @Test("S3Uploader handles head object errors during skip check")
    func handleHeadObjectErrors() async throws {
        let mockClient = MockS3Client()
        let config = UploadConfiguration(
            bucketName: "test-bucket",
            keyPrefix: "test-prefix",
            skipUnchangedFiles: true,
            maxRetries: 1  // Limit retries for faster test
        )
        let uploader = S3Uploader(configuration: config, s3Client: mockClient)

        // Create a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test.txt")
        try "Hello, World!".write(to: testFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: testFile)
        }

        // Mock head object error (not file not found) - Add enough failures for retries
        mockClient.headObjectResults.append(.failure(MockS3Error.uploadFailed))
        mockClient.headObjectResults.append(.failure(MockS3Error.uploadFailed))

        // Test upload (should propagate the error)
        await #expect(throws: MockS3Error.uploadFailed) {
            try await uploader.uploadFile(
                localPath: testFile.path,
                remotePath: "test/test.txt",
                contentType: "text/plain"
            )
        }

        try await uploader.shutdown()
    }

    @Test("S3Uploader handles multipart upload initiation failure")
    func handleMultipartInitFailure() async throws {
        let mockClient = MockS3Client()
        let config = UploadConfiguration(
            bucketName: "test-bucket",
            keyPrefix: "test-prefix",
            multipartChunkSize: 10,  // Very small chunk size for testing
            maxRetries: 1  // Limit retries for faster test
        )
        let uploader = S3Uploader(configuration: config, s3Client: mockClient)

        // Create a large file
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("large.txt")
        let largeContent = String(repeating: "A", count: 50)  // Larger than chunk size
        try largeContent.write(to: testFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: testFile)
        }

        // Mock multipart upload initiation failure - Add enough failures for retries
        mockClient.createMultipartUploadResults.append(.failure(MockS3Error.uploadFailed))
        mockClient.createMultipartUploadResults.append(.failure(MockS3Error.uploadFailed))

        // Test upload (should fail)
        await #expect(throws: MockS3Error.uploadFailed) {
            try await uploader.uploadFile(
                localPath: testFile.path,
                remotePath: "test/large.txt",
                contentType: "text/plain",
                skipUnchanged: false
            )
        }

        try await uploader.shutdown()
    }

    @Test("S3Uploader handles multipart upload part failure")
    func handleMultipartPartFailure() async throws {
        let mockClient = MockS3Client()
        let config = UploadConfiguration(
            bucketName: "test-bucket",
            keyPrefix: "test-prefix",
            multipartChunkSize: 10,
            maxRetries: 0  // No retries for this test
        )
        let uploader = S3Uploader(configuration: config, s3Client: mockClient)

        // Create a large file
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("large.txt")
        let largeContent = String(repeating: "A", count: 50)
        try largeContent.write(to: testFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: testFile)
        }

        // Mock successful initiation but part upload failure
        mockClient.createMultipartUploadResults.append(.success("test-upload-id"))
        mockClient.uploadPartResults.append(.failure(MockS3Error.uploadFailed))

        // Test upload (should fail)
        await #expect(throws: MockS3Error.uploadFailed) {
            try await uploader.uploadFile(
                localPath: testFile.path,
                remotePath: "test/large.txt",
                contentType: "text/plain",
                skipUnchanged: false
            )
        }

        try await uploader.shutdown()
    }

    @Test("S3Uploader handles directory not found error")
    func handleDirectoryNotFound() async throws {
        let config = UploadConfiguration(
            bucketName: "test-bucket",
            keyPrefix: "test-prefix"
        )
        let uploader = S3Uploader(configuration: config, s3Client: MockS3Client())

        // Test upload with non-existent directory
        await #expect(throws: S3UploaderError.directoryNotFound("/non/existent/directory")) {
            try await uploader.uploadDirectory(
                localDirectory: "/non/existent/directory",
                sitePrefix: "test"
            )
        }

        try await uploader.shutdown()
    }

    @Test("Progress tracking handles failed uploads")
    func progressTrackingWithFailures() async throws {
        let mockClient = MockS3Client()
        let config = UploadConfiguration(
            bucketName: "test-bucket",
            keyPrefix: "test-prefix",
            skipUnchangedFiles: false,  // Disable skip logic to simplify test
            maxRetries: 0  // No retries
        )
        let uploader = S3Uploader(configuration: config, s3Client: mockClient)
        let progress = UploadProgress()

        // Create test files
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("test-site-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        let file1 = testDir.appendingPathComponent("file1.txt")
        let file2 = testDir.appendingPathComponent("file2.txt")
        try "Content 1".write(to: file1, atomically: true, encoding: .utf8)
        try "Content 2".write(to: file2, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: testDir)
        }

        // Mock first file success, second file failure
        mockClient.putObjectResults.append(.success(()))
        mockClient.putObjectResults.append(.failure(MockS3Error.uploadFailed))

        // Test upload (should fail on second file)
        await #expect(throws: MockS3Error.uploadFailed) {
            try await uploader.uploadDirectory(
                localDirectory: testDir.path,
                sitePrefix: "test",
                progress: progress
            )
        }

        // Verify progress shows one success and one failure
        let stats = await progress.getStats()
        #expect(stats.uploadedFiles == 1)
        #expect(stats.failedFiles == 1)
        #expect(stats.totalFiles == 2)

        try await uploader.shutdown()
    }

    @Test("Retry logic uses exponential backoff")
    func retryExponentialBackoff() async throws {
        let mockClient = MockS3Client()
        let config = UploadConfiguration(
            bucketName: "test-bucket",
            keyPrefix: "test-prefix",
            maxRetries: 2,
            retryBaseDelay: 0.01  // 10ms base delay
        )
        let uploader = S3Uploader(configuration: config, s3Client: mockClient)

        // Create a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test.txt")
        try "Hello, World!".write(to: testFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: testFile)
        }

        // Mock failures followed by success
        mockClient.putObjectResults.append(.failure(MockS3Error.uploadFailed))
        mockClient.putObjectResults.append(.failure(MockS3Error.uploadFailed))
        mockClient.putObjectResults.append(.success(()))

        let startTime = Date()

        // Test upload with timing
        try await uploader.uploadFile(
            localPath: testFile.path,
            remotePath: "test/test.txt",
            contentType: "text/plain",
            skipUnchanged: false
        )

        let elapsedTime = Date().timeIntervalSince(startTime)

        // Verify exponential backoff occurred (10ms + 20ms = 30ms minimum)
        // Allow some margin for execution time
        #expect(elapsedTime >= 0.025)  // At least 25ms

        try await uploader.shutdown()
    }
}
