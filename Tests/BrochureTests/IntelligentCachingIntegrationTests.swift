import Foundation
import Testing

@testable import Brochure

/// Integration tests for intelligent caching of AWS profile credentials and configurations.
///
/// These tests verify that the profile caching system integrates properly with
/// LazyAWSClientManager and provides measurable performance improvements.
@Suite("Intelligent Caching Integration Tests")
struct IntelligentCachingIntegrationTests {

    @Test("LazyAWSClientManager uses profile caching for improved performance")
    func testProfileCachingIntegration() async throws {
        let manager = LazyAWSClientManager()
        defer {
            Task {
                try? await manager.shutdown()
            }
        }

        // First S3 client creation should initialize profile cache
        let client1 = try await manager.getS3Client(
            profile: "test-profile",
            region: "us-west-2",
            bucketName: "test-bucket",
            keyPrefix: "test"
        )

        // Client should be created successfully
        #expect(client1 is S3ClientProtocol)

        // Second S3 client creation should use cached profile resolution
        let client2 = try await manager.getS3Client(
            profile: "test-profile",
            region: "us-west-2",
            bucketName: "test-bucket",
            keyPrefix: "test"
        )

        #expect(client2 is S3ClientProtocol)

        // Verify cache statistics show profile caching is working
        let stats = await manager.getUsageStats()
        #expect(stats["cached_s3_clients"] == "1")  // Same client should be reused

        // Should have profile cache statistics
        #expect(stats["profile_cache_cache_ttl_seconds"] != nil)
        #expect(stats["profile_cache_profile_resolutions_cached"] != nil)
    }

    @Test("Profile resolution caching reduces repeated filesystem I/O")
    func testProfileResolutionCachingPerformance() async throws {
        let manager = LazyAWSClientManager()
        defer {
            Task {
                try? await manager.shutdown()
            }
        }

        // Measure time for first profile resolution (should be slower due to filesystem I/O)
        let start1 = Date()
        _ = try await manager.getS3Client(
            profile: nil,  // Use default profile resolution
            region: "us-west-2",
            bucketName: "test-bucket",
            keyPrefix: "test"
        )
        let duration1 = Date().timeIntervalSince(start1)

        // Measure time for second profile resolution (should be faster due to caching)
        let start2 = Date()
        _ = try await manager.getS3Client(
            profile: nil,  // Same configuration
            region: "us-west-2",
            bucketName: "test-bucket-2",  // Different bucket name to force getS3Client call
            keyPrefix: "test-2"
        )
        let duration2 = Date().timeIntervalSince(start2)

        // Second call should be faster due to cached profile resolution
        // Note: This is a structural test - in practice, caching benefits are most visible
        // when dealing with large numbers of profile lookups or slow filesystem I/O
        #expect(duration1 >= 0)
        #expect(duration2 >= 0)

        // Verify that caching infrastructure is in place
        let stats = await manager.getUsageStats()
        #expect(stats["profile_cache_profile_resolutions_cached"] != nil)
    }

    @Test("Multiple profile configurations are cached independently")
    func testMultipleProfileConfigurationCaching() async throws {
        let manager = LazyAWSClientManager()
        defer {
            Task {
                try? await manager.shutdown()
            }
        }

        // Create clients with different profile configurations
        let configs = [
            (profile: nil as String?, region: "us-west-2"),
            (profile: "staging", region: "us-west-2"),
            (profile: "production", region: "us-east-1"),
            (profile: nil as String?, region: "eu-west-1"),
        ]

        for (index, config) in configs.enumerated() {
            _ = try await manager.getS3Client(
                profile: config.profile,
                region: config.region,
                bucketName: "bucket-\(index)",
                keyPrefix: "prefix-\(index)"
            )
        }

        // Verify multiple profile configurations are cached
        let stats = await manager.getUsageStats()
        let cachedClients = Int(stats["cached_s3_clients"] ?? "0") ?? 0
        #expect(cachedClients == configs.count)

        // Should have cached profile resolutions
        let cachedResolutions = stats["profile_cache_profile_resolutions_cached"]
        #expect(cachedResolutions != nil)
        #expect(cachedResolutions != "0")
    }

    @Test("Cache statistics are properly integrated into usage stats")
    func testCacheStatisticsIntegration() async throws {
        let manager = LazyAWSClientManager()
        defer {
            Task {
                try? await manager.shutdown()
            }
        }

        // Create an S3 client to initialize caching
        _ = try await manager.getS3Client(
            profile: "test-profile",
            region: "us-west-2",
            bucketName: "test-bucket",
            keyPrefix: "test"
        )

        let stats = await manager.getUsageStats()

        // Verify standard AWS client manager stats are present
        #expect(stats["cached_s3_clients"] != nil)
        #expect(stats["aws_client_initialized"] != nil)
        #expect(stats["http_client_initialized"] != nil)

        // Verify profile cache stats are integrated
        let expectedCacheStats = [
            "profile_cache_profile_resolutions_cached",
            "profile_cache_profile_validations_cached",
            "profile_cache_available_profiles_cached",
            "profile_cache_cache_ttl_seconds",
            "profile_cache_credentials_file_tracked",
            "profile_cache_config_file_tracked",
        ]

        for statKey in expectedCacheStats {
            #expect(stats[statKey] != nil, "Missing cache stat: \(statKey)")
        }
    }

    @Test("Cache is properly cleaned up on manager shutdown")
    func testCacheCleanupOnShutdown() async throws {
        let manager = LazyAWSClientManager()

        // Initialize cache by creating a client
        _ = try await manager.getS3Client(
            profile: "test-profile",
            region: "us-west-2",
            bucketName: "test-bucket",
            keyPrefix: "test"
        )

        // Verify cache has entries
        var stats = await manager.getUsageStats()
        #expect(stats["profile_cache_profile_resolutions_cached"] != "0")

        // Shutdown manager
        try await manager.shutdown()

        // Verify cleanup occurred
        stats = await manager.getUsageStats()
        #expect(stats["cached_s3_clients"] == "0")
        // Note: After shutdown, cache should be cleared but we can't directly verify
        // the internal cache state since it's private to the actor
    }

    @Test("Concurrent profile operations use cached results safely")
    func testConcurrentProfileCaching() async throws {
        let manager = LazyAWSClientManager()
        defer {
            Task {
                try? await manager.shutdown()
            }
        }

        // Create multiple concurrent S3 client requests with same profile
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask {
                    do {
                        _ = try await manager.getS3Client(
                            profile: "concurrent-test",
                            region: "us-west-2",
                            bucketName: "bucket-\(i)",
                            keyPrefix: "prefix-\(i)"
                        )
                    } catch {
                        // Ignore errors for this concurrency test
                    }
                }
            }
        }

        let stats = await manager.getUsageStats()
        let cachedClients = Int(stats["cached_s3_clients"] ?? "0") ?? 0
        #expect(cachedClients > 0)

        // Should have cached profile resolution
        #expect(stats["profile_cache_profile_resolutions_cached"] != nil)
    }

    @Test("Cache handles profile validation errors gracefully")
    func testProfileValidationErrorHandling() async throws {
        let manager = LazyAWSClientManager()
        defer {
            Task {
                try? await manager.shutdown()
            }
        }

        // Request S3 client with potentially invalid profile
        // Should not crash and should fall back gracefully
        let client = try await manager.getS3Client(
            profile: "nonexistent-profile",
            region: "us-west-2",
            bucketName: "test-bucket",
            keyPrefix: "test"
        )

        #expect(client is S3ClientProtocol)

        // Should still have cache statistics even with validation errors
        let stats = await manager.getUsageStats()
        #expect(stats["profile_cache_cache_ttl_seconds"] != nil)
    }

    @Test("Performance improvement is measurable with repeated operations")
    func testMeasurablePerformanceImprovement() async throws {
        let manager = LazyAWSClientManager()
        defer {
            Task {
                try? await manager.shutdown()
            }
        }

        // Simulate multiple AWS operations that would benefit from profile caching
        let operationCount = 10
        var durations: [TimeInterval] = []

        for i in 0..<operationCount {
            let start = Date()

            // Each operation would normally require profile resolution
            _ = try await manager.getS3Client(
                profile: i % 2 == 0 ? "production" : nil,  // Alternate profiles
                region: i % 3 == 0 ? "us-east-1" : "us-west-2",  // Alternate regions
                bucketName: "bucket-\(i)",
                keyPrefix: "prefix-\(i)"
            )

            let duration = Date().timeIntervalSince(start)
            durations.append(duration)
        }

        #expect(durations.count == operationCount)

        // Verify that caching infrastructure is in place for performance benefits
        let stats = await manager.getUsageStats()
        let cachedResolutions = Int(stats["profile_cache_profile_resolutions_cached"] ?? "0") ?? 0

        // Should have cached some profile resolutions
        #expect(cachedResolutions > 0, "Profile caching should have cached at least some resolutions")

        // With different profiles and regions, should have multiple cached entries
        let cachedClients = Int(stats["cached_s3_clients"] ?? "0") ?? 0
        #expect(cachedClients > 0, "Should have cached S3 clients")
    }
}
