// Import required for MD5 calculation
import Crypto
import Foundation
import SotoS3
import Testing

@testable import Brochure

@Suite("S3Uploader functionality", .serialized)
struct S3UploaderTests {

    @Test("S3Uploader successfully uploads a small file")
    func uploadSmallFile() async throws {
        let mockClient = MockS3Client()
        let config = UploadConfiguration(bucketName: "test-bucket", keyPrefix: "test-prefix")
        let uploader = S3Uploader(configuration: config, s3Client: mockClient)

        // Mock successful upload
        mockClient.putObjectResults.append(.success(()))

        // Create a temporary file with unique name
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("upload-small-\(UUID().uuidString).txt")
        try "Hello, World!".write(to: testFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: testFile)
        }

        // Test upload with skipUnchanged=false to avoid headObject call
        try await uploader.uploadFile(
            localPath: testFile.path,
            remotePath: "test/test.txt",
            contentType: "text/plain",
            skipUnchanged: false
        )

        // Verify the request was made correctly
        #expect(mockClient.putObjectRequests.count == 1)
        let request = mockClient.putObjectRequests[0]
        #expect(request.bucket == "test-bucket")
        #expect(request.key == "test-prefix/test/test.txt")
        #expect(request.contentType == "text/plain")

        try await uploader.shutdown()
    }

    @Test("S3Uploader skips unchanged files based on ETag")
    func skipUnchangedFiles() async throws {
        let mockClient = MockS3Client()
        let config = UploadConfiguration(bucketName: "test-bucket", keyPrefix: "test-prefix")
        let uploader = S3Uploader(configuration: config, s3Client: mockClient)

        // Create a temporary file with unique name
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("skip-unchanged-\(UUID().uuidString).txt")
        let testContent = "Hello, World!"
        try testContent.write(to: testFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: testFile)
        }

        // Calculate expected MD5
        let expectedMD5 = try calculateMD5(for: testContent)

        // Mock head object response with matching ETag
        mockClient.headObjectResults.append(.success("\"\(expectedMD5)\""))

        // Test upload (should be skipped)
        try await uploader.uploadFile(
            localPath: testFile.path,
            remotePath: "test/test.txt",
            contentType: "text/plain",
            skipUnchanged: true
        )

        // Verify only head object was called, not put object
        #expect(mockClient.headObjectRequests.count == 1)
        #expect(mockClient.putObjectRequests.count == 0)

        try await uploader.shutdown()
    }

    @Test("S3Uploader uploads changed files")
    func uploadChangedFiles() async throws {
        let mockClient = MockS3Client()
        let config = UploadConfiguration(bucketName: "test-bucket", keyPrefix: "test-prefix")
        let uploader = S3Uploader(configuration: config, s3Client: mockClient)

        // Create a temporary file with unique name
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("upload-changed-\(UUID().uuidString).txt")
        try "Hello, World!".write(to: testFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: testFile)
        }

        // Mock head object response with different ETag
        mockClient.headObjectResults.append(.success("\"different-etag\""))
        mockClient.putObjectResults.append(.success(()))

        // Test upload (should proceed because file changed)
        try await uploader.uploadFile(
            localPath: testFile.path,
            remotePath: "test/test.txt",
            contentType: "text/plain",
            skipUnchanged: true
        )

        // Verify both head object and put object were called
        #expect(mockClient.headObjectRequests.count == 1)
        #expect(mockClient.putObjectRequests.count == 1)

        try await uploader.shutdown()
    }

    @Test("S3Uploader handles file not found in S3")
    func handleFileNotFoundInS3() async throws {
        let mockClient = MockS3Client()
        let config = UploadConfiguration(bucketName: "test-bucket", keyPrefix: "test-prefix")
        let uploader = S3Uploader(configuration: config, s3Client: mockClient)

        // Create a temporary file with unique name
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("file-not-found-\(UUID().uuidString).txt")
        try "Hello, World!".write(to: testFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: testFile)
        }

        // Mock head object response with NoSuchKey error
        // No retries for fileNotFound as it's expected
        mockClient.headObjectResults.append(.failure(MockS3Error.fileNotFound))
        mockClient.putObjectResults.append(.success(()))

        // Test upload (should proceed because file doesn't exist)
        try await uploader.uploadFile(
            localPath: testFile.path,
            remotePath: "test/test.txt",
            contentType: "text/plain",
            skipUnchanged: true
        )

        // Verify both head object and put object were called
        #expect(mockClient.headObjectRequests.count == 1)
        #expect(mockClient.putObjectRequests.count == 1)

        try await uploader.shutdown()
    }

    @Test("S3Uploader retries failed operations")
    func retryFailedOperations() async throws {
        let mockClient = MockS3Client()
        let config = UploadConfiguration(
            bucketName: "test-bucket",
            keyPrefix: "test-prefix",
            maxRetries: 2,
            retryBaseDelay: 0.001  // Very short delay for testing
        )
        let uploader = S3Uploader(configuration: config, s3Client: mockClient)

        // Create a temporary file with unique name
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("retry-failed-\(UUID().uuidString).txt")
        try "Hello, World!".write(to: testFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: testFile)
        }

        // Mock failures followed by success
        mockClient.putObjectResults.append(.failure(MockS3Error.uploadFailed))
        mockClient.putObjectResults.append(.failure(MockS3Error.uploadFailed))
        mockClient.putObjectResults.append(.success(()))

        // Test upload (should succeed after retries)
        try await uploader.uploadFile(
            localPath: testFile.path,
            remotePath: "test/test.txt",
            contentType: "text/plain",
            skipUnchanged: false
        )

        // Verify 3 attempts were made (initial + 2 retries)
        #expect(mockClient.putObjectRequests.count == 3)

        try await uploader.shutdown()
    }

    @Test("S3Uploader handles large file with multipart upload")
    func handleLargeFileMultipartUpload() async throws {
        let mockClient = MockS3Client()
        let config = UploadConfiguration(
            bucketName: "test-bucket",
            keyPrefix: "test-prefix",
            multipartChunkSize: 100  // Very small chunk size for testing
        )
        let uploader = S3Uploader(configuration: config, s3Client: mockClient)

        // Create a large temporary file (larger than chunk size) with unique name
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("large-multipart-\(UUID().uuidString).txt")
        let largeContent = String(repeating: "A", count: 250)  // 250 bytes > 100 byte chunk size
        try largeContent.write(to: testFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: testFile)
        }

        // Mock multipart upload responses
        mockClient.createMultipartUploadResults.append(.success("test-upload-id"))

        // Mock upload part responses (3 parts for 250 bytes with 100 byte chunks)
        mockClient.uploadPartResults.append(.success("\"part1-etag\""))
        mockClient.uploadPartResults.append(.success("\"part2-etag\""))
        mockClient.uploadPartResults.append(.success("\"part3-etag\""))

        mockClient.completeMultipartUploadResults.append(.success(()))

        // Test upload
        try await uploader.uploadFile(
            localPath: testFile.path,
            remotePath: "test/large-test.txt",
            contentType: "text/plain",
            skipUnchanged: false
        )

        // Verify multipart upload was used
        #expect(mockClient.createMultipartUploadRequests.count == 1)
        #expect(mockClient.uploadPartRequests.count == 3)
        #expect(mockClient.completeMultipartUploadRequests.count == 1)
        #expect(mockClient.putObjectRequests.count == 0)  // Should not use regular upload

        try await uploader.shutdown()
    }

    // Helper function to calculate MD5
    private func calculateMD5(for content: String) throws -> String {
        let data = content.data(using: .utf8)!
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
}
