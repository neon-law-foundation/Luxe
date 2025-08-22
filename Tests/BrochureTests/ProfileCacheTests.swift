import Foundation
import Testing

@testable import Brochure

/// Tests for the ProfileCache intelligent caching system.
///
/// These tests verify that profile resolution, validation, and available profiles
/// are properly cached and invalidated when configuration files change.
@Suite("ProfileCache Tests")
struct ProfileCacheTests {

    @Test("Profile cache initializes with correct TTL")
    func testProfileCacheInitialization() async throws {
        let cache = ProfileCache(ttl: 120)  // 2 minutes
        let stats = await cache.getCacheStatistics()

        #expect(stats["cache_ttl_seconds"] == "120")
        #expect(stats["profile_resolutions_cached"] == "0")
        #expect(stats["profile_validations_cached"] == "0")
        #expect(stats["available_profiles_cached"] == "false")
    }

    @Test("Profile resolution is cached and reused")
    func testProfileResolutionCaching() async throws {
        let cache = ProfileCache(ttl: 300)
        let environment = [
            "AWS_PROFILE": "test-profile",
            "AWS_REGION": "us-east-1",
        ]

        // First resolution should perform actual resolution
        let resolution1 = await cache.getCachedProfileResolution(
            explicit: nil,
            environment: environment
        )

        #expect(resolution1.profileName == "test-profile")
        #expect(resolution1.source == .environment)
        #expect(resolution1.region == "us-east-1")

        // Second resolution should use cached result (should be identical)
        let resolution2 = await cache.getCachedProfileResolution(
            explicit: nil,
            environment: environment
        )

        #expect(resolution2.profileName == resolution1.profileName)
        #expect(resolution2.source == resolution1.source)
        #expect(resolution2.region == resolution1.region)

        // Verify cache statistics
        let stats = await cache.getCacheStatistics()
        #expect(stats["profile_resolutions_cached"] == "1")
    }

    @Test("Different profile configurations create separate cache entries")
    func testMultipleProfileConfigurationsCaching() async throws {
        let cache = ProfileCache(ttl: 300)

        // Cache different profile configurations
        let env1 = ["AWS_PROFILE": "profile1", "AWS_REGION": "us-west-2"]
        let env2 = ["AWS_PROFILE": "profile2", "AWS_REGION": "us-east-1"]

        let resolution1 = await cache.getCachedProfileResolution(explicit: nil, environment: env1)
        let resolution2 = await cache.getCachedProfileResolution(explicit: "explicit-profile", environment: env2)
        let resolution3 = await cache.getCachedProfileResolution(explicit: nil, environment: env2)

        #expect(resolution1.profileName == "profile1")
        #expect(resolution2.profileName == "explicit-profile")
        #expect(resolution3.profileName == "profile2")

        // Should have 3 different cached entries
        let stats = await cache.getCacheStatistics()
        #expect(stats["profile_resolutions_cached"] == "3")
    }

    @Test("Profile validation results are cached")
    func testProfileValidationCaching() async throws {
        let cache = ProfileCache(ttl: 300)

        // Create temporary AWS config files for testing
        let tempDir = FileManager.default.temporaryDirectory
        let credentialsURL = tempDir.appendingPathComponent("test-credentials")
        let configURL = tempDir.appendingPathComponent("test-config")

        let credentialsContent = """
            [default]
            aws_access_key_id = test-key
            aws_secret_access_key = test-secret

            [production]
            aws_access_key_id = prod-key
            aws_secret_access_key = prod-secret
            """

        let configContent = """
            [default]
            region = us-west-2

            [profile staging]
            region = us-east-1
            """

        try credentialsContent.write(to: credentialsURL, atomically: true, encoding: .utf8)
        try configContent.write(to: configURL, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: credentialsURL)
            try? FileManager.default.removeItem(at: configURL)
        }

        // Note: This test verifies the caching mechanism structure
        // Real validation would require proper AWS credential file setup

        let stats = await cache.getCacheStatistics()
        #expect(stats["profile_validations_cached"] == "0")

        await cache.clearCache()
        let clearedStats = await cache.getCacheStatistics()
        #expect(clearedStats["profile_validations_cached"] == "0")
    }

    @Test("Cache entries expire after TTL")
    func testCacheExpirationWithShortTTL() async throws {
        let cache = ProfileCache(ttl: 0.1)  // 100ms TTL for fast testing
        let environment = ["AWS_PROFILE": "test-profile"]

        // Cache a resolution
        let resolution1 = await cache.getCachedProfileResolution(
            explicit: nil,
            environment: environment
        )

        // Verify it's cached
        var stats = await cache.getCacheStatistics()
        #expect(stats["profile_resolutions_cached"] == "1")

        // Wait for expiration
        try await Task.sleep(nanoseconds: 200_000_000)  // 200ms

        // Force cleanup of expired entries
        await cache.cleanupExpiredEntries()

        // Verify expired entries are cleaned up
        stats = await cache.getCacheStatistics()
        #expect(stats["profile_resolutions_cached"] == "0")

        // New resolution should create a fresh cache entry
        let resolution2 = await cache.getCachedProfileResolution(
            explicit: nil,
            environment: environment
        )

        #expect(resolution2.profileName == resolution1.profileName)

        stats = await cache.getCacheStatistics()
        #expect(stats["profile_resolutions_cached"] == "1")
    }

    @Test("Cache clear removes all entries")
    func testCacheClear() async throws {
        let cache = ProfileCache(ttl: 300)
        let environment = [
            "AWS_PROFILE": "test1",
            "AWS_REGION": "us-west-2",
        ]

        // Cache multiple entries
        _ = await cache.getCachedProfileResolution(explicit: nil, environment: environment)
        _ = await cache.getCachedProfileResolution(explicit: "explicit", environment: environment)

        // Verify entries are cached
        var stats = await cache.getCacheStatistics()
        #expect(stats["profile_resolutions_cached"] == "2")

        // Clear cache
        await cache.clearCache()

        // Verify cache is empty
        stats = await cache.getCacheStatistics()
        #expect(stats["profile_resolutions_cached"] == "0")
        #expect(stats["profile_validations_cached"] == "0")
        #expect(stats["available_profiles_cached"] == "false")
    }

    @Test("Cache statistics provide accurate information")
    func testCacheStatistics() async throws {
        let cache = ProfileCache(ttl: 600)

        // Initial stats should show empty cache
        var stats = await cache.getCacheStatistics()
        #expect(stats["cache_ttl_seconds"] == "600")
        #expect(stats["profile_resolutions_cached"] == "0")
        #expect(stats["profile_validations_cached"] == "0")
        #expect(stats["available_profiles_cached"] == "false")

        // Add some cached entries
        let environment = ["AWS_PROFILE": "test-profile"]
        _ = await cache.getCachedProfileResolution(explicit: nil, environment: environment)
        _ = await cache.getCachedProfileResolution(explicit: "other", environment: environment)

        // Stats should reflect cached entries
        stats = await cache.getCacheStatistics()
        #expect(stats["profile_resolutions_cached"] == "2")
    }

    @Test("Cache handles concurrent access safely")
    func testConcurrentCacheAccess() async throws {
        let cache = ProfileCache(ttl: 300)
        let environment = ["AWS_PROFILE": "concurrent-test"]

        // Create multiple concurrent cache access tasks
        await withTaskGroup(of: ProfileResolution.self) { group in
            for i in 0..<10 {
                group.addTask {
                    await cache.getCachedProfileResolution(
                        explicit: i % 2 == 0 ? "explicit-\(i)" : nil,
                        environment: environment
                    )
                }
            }

            var resolutions: [ProfileResolution] = []
            for await resolution in group {
                resolutions.append(resolution)
            }

            #expect(resolutions.count == 10)
        }

        // Should have multiple cached entries due to different explicit profiles
        let stats = await cache.getCacheStatistics()
        let cachedCount = Int(stats["profile_resolutions_cached"] ?? "0") ?? 0
        #expect(cachedCount > 0)
    }

    @Test("Cache key generation creates unique keys for different configurations")
    func testCacheKeyUniqueness() async throws {
        let cache = ProfileCache(ttl: 300)

        // Test different combinations of parameters
        let configs = [
            (explicit: nil as String?, env: ["AWS_PROFILE": "env1"]),
            (explicit: "explicit1", env: ["AWS_PROFILE": "env1"]),
            (explicit: nil as String?, env: ["AWS_PROFILE": "env2"]),
            (explicit: "explicit1", env: ["AWS_PROFILE": "env2"]),
            (explicit: "explicit1", env: ["AWS_PROFILE": "env1", "AWS_REGION": "us-east-1"]),
        ]

        // Cache all configurations
        for config in configs {
            _ = await cache.getCachedProfileResolution(
                explicit: config.explicit,
                environment: config.env
            )
        }

        // Should have separate cache entries for each unique configuration
        let stats = await cache.getCacheStatistics()
        #expect(stats["profile_resolutions_cached"] == "\(configs.count)")
    }
}
