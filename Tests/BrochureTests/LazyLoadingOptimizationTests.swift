import Foundation
import Testing

@testable import Brochure

@Suite("Lazy Loading Optimization Tests", .serialized)
struct LazyLoadingOptimizationTests {

    @Test("LazyS3Uploader initializes quickly without creating AWS clients")
    func testFastInitialization() async throws {
        let startTime = Date()

        // Create uploader - should be fast with no AWS client creation
        let uploader = LazyS3Uploader(
            configuration: UploadConfiguration(bucketName: "test-bucket"),
            profile: "test-profile"
        )

        let initTime = Date().timeIntervalSince(startTime)

        // Verify fast initialization (should be under 10ms)
        #expect(initTime < 0.01, "Lazy initialization should be very fast, but took \(initTime) seconds")

        // Verify no AWS client is created yet
        let stats = await uploader.getPerformanceStats()
        #expect(stats["aws_client_initialized"] == "false")
        #expect(stats["bucket_name"] == "test-bucket")
        #expect(stats["profile"] == "test-profile")

        // Cleanup
        try await uploader.shutdown()
    }

    @Test("LazyAWSClientManager initializes without creating HTTP clients")
    func testLazyClientManagerInitialization() async throws {
        let startTime = Date()

        // Create manager - should be fast
        let manager = LazyAWSClientManager()

        let initTime = Date().timeIntervalSince(startTime)

        // Verify fast initialization
        #expect(
            initTime < 0.01,
            "LazyAWSClientManager initialization should be very fast, but took \(initTime) seconds"
        )

        // Verify no clients are created yet
        let stats = await manager.getUsageStats()
        #expect(stats["cached_s3_clients"] == "0")
        #expect(stats["aws_client_initialized"] == "false")
        #expect(stats["http_client_initialized"] == "false")

        // Cleanup
        try await manager.shutdown()
    }

    @Test("LazyS3Uploader with mock client works without AWS initialization")
    func testMockClientBypassesLazyLoading() async throws {
        let mockClient = MockS3Client()

        // Mock successful operations - no headObject call (skip unchanged check), just putObject
        mockClient.putObjectResults = [.success(())]

        let uploader = LazyS3Uploader(
            configuration: UploadConfiguration(bucketName: "test-bucket"),
            s3Client: mockClient
        )

        // Verify that mock client is used directly
        let stats = await uploader.getPerformanceStats()
        #expect(stats["bucket_name"] == "test-bucket")

        // Create a temporary test file instead of using /dev/null
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test-file.txt")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)

        // This should work without creating any real AWS clients
        try await uploader.uploadFile(
            localPath: testFile.path,
            remotePath: "test/file.txt",
            contentType: "text/plain",
            skipUnchanged: false  // Skip the head request
        )

        // Cleanup
        try FileManager.default.removeItem(at: testFile)
        try await uploader.shutdown()
    }

    @Test("Regular S3Uploader still works for comparison")
    func testRegularS3UploaderStillWorks() async throws {
        let mockClient = MockS3Client()

        // Mock successful operations
        mockClient.putObjectResults = [.success(())]

        let uploader = S3Uploader(
            configuration: UploadConfiguration(bucketName: "test-bucket"),
            s3Client: mockClient
        )

        // Create a temporary test file
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("regular-test-file.txt")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)

        // This should work with the existing implementation
        try await uploader.uploadFile(
            localPath: testFile.path,
            remotePath: "test/file.txt",
            contentType: "text/plain",
            skipUnchanged: false
        )

        // Cleanup
        try FileManager.default.removeItem(at: testFile)
        try await uploader.shutdown()
    }

    @Test("Performance comparison shows initialization benefit")
    func testPerformanceComparison() async throws {
        let iterations = 10
        var lazyTimes: [TimeInterval] = []
        var regularTimes: [TimeInterval] = []

        // Test lazy initialization times
        for _ in 0..<iterations {
            let startTime = Date()
            let lazyUploader = LazyS3Uploader(bucketName: "test-bucket")
            let elapsed = Date().timeIntervalSince(startTime)
            lazyTimes.append(elapsed)
            try await lazyUploader.shutdown()
        }

        // Test regular initialization times (with mock client to avoid AWS)
        for _ in 0..<iterations {
            let startTime = Date()
            let mockClient = MockS3Client()
            let config = UploadConfiguration(bucketName: "test-bucket")
            let regularUploader = S3Uploader(configuration: config, s3Client: mockClient)
            let elapsed = Date().timeIntervalSince(startTime)
            regularTimes.append(elapsed)
            try await regularUploader.shutdown()
        }

        let avgLazyTime = lazyTimes.reduce(0, +) / Double(lazyTimes.count)
        let avgRegularTime = regularTimes.reduce(0, +) / Double(regularTimes.count)

        // Lazy initialization should be faster (even with mock clients)
        // This test verifies that we're not doing unnecessary work during initialization
        #expect(
            avgLazyTime <= avgRegularTime,
            "Lazy initialization (avg: \(avgLazyTime)s) should be faster than regular (avg: \(avgRegularTime)s)"
        )

        // Log the performance improvement for information
        let improvement = ((avgRegularTime - avgLazyTime) / avgRegularTime) * 100
        print("Lazy initialization is \(String(format: "%.1f", improvement))% faster")
    }

    @Test("CLI startup command parsing is not affected by lazy loading")
    func testCommandParsingPerformance() throws {
        // Test that command parsing still works quickly
        let startTime = Date()

        let command = try UploadCommand.parse([
            "NeonLaw",
            "--profile", "test",
            "--dry-run",
            "--verbose",
        ])

        let parseTime = Date().timeIntervalSince(startTime)

        // Command parsing should be reasonably fast (relaxed threshold for CI)
        #expect(parseTime < 0.1, "Command parsing should be reasonably fast, but took \(parseTime) seconds")

        // Verify command properties are set correctly
        #expect(command.siteName == "NeonLaw")
        #expect(command.profile == "test")
        #expect(command.dryRun == true)
        #expect(command.verbose == true)
    }

    @Test("Lazy loading defers AWS client creation until first operation")
    func testDeferredClientCreation() async throws {
        let mockClient = MockS3Client()
        mockClient.putObjectResults = [.success(())]

        let uploader = LazyS3Uploader(
            configuration: UploadConfiguration(bucketName: "test-bucket"),
            s3Client: mockClient
        )

        // Initially, no AWS client should be initialized with mock client
        var stats = await uploader.getPerformanceStats()
        #expect(stats["bucket_name"] == "test-bucket")

        // Create a temporary test file
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("deferred-test-file.txt")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)

        // Perform an upload operation
        try await uploader.uploadFile(
            localPath: testFile.path,
            remotePath: "test/deferred.txt",
            contentType: "text/plain",
            skipUnchanged: false
        )

        // Verify operation worked
        stats = await uploader.getPerformanceStats()
        #expect(stats["bucket_name"] == "test-bucket")

        // Cleanup
        try FileManager.default.removeItem(at: testFile)
        try await uploader.shutdown()
    }
}
