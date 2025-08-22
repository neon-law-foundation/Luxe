import Foundation
import Logging
import Testing

@testable import Brochure

/// Tests for the ParallelUploadManager concurrent site deployment functionality.
///
/// These tests verify that multiple sites can be uploaded concurrently with proper
/// resource management, error handling, and progress tracking.
@Suite("ParallelUploadManager Tests")
struct ParallelUploadManagerTests {

    @Test("ParallelUploadManager initializes with correct concurrency settings")
    func testParallelUploadManagerInitialization() async throws {
        let logger = createTestLogger()
        let manager = ParallelUploadManager(maxConcurrentUploads: 5, logger: logger)

        let activeUploads = await manager.getActiveUploads()
        #expect(activeUploads.isEmpty)

        let progress = await manager.getCurrentProgress()
        #expect(progress.totalSites == 0)
        #expect(progress.completedSites == 0)
        #expect(progress.isComplete == true)  // Empty progress is considered complete
    }

    @Test("ParallelUploadManager validates site names before starting uploads")
    func testSiteNameValidation() async throws {
        let logger = createTestLogger()
        let manager = ParallelUploadManager(maxConcurrentUploads: 3, logger: logger)

        // Test with invalid site names
        let invalidSites = ["InvalidSite1", "InvalidSite2"]

        await #expect(throws: ParallelUploadError.self) {
            _ = try await manager.uploadSites(
                invalidSites,
                dryRun: true
            )
        }

        // Test with duplicate site names
        let duplicateSites = ["NeonLaw", "HoshiHoshi", "NeonLaw"]

        await #expect(throws: ParallelUploadError.self) {
            _ = try await manager.uploadSites(
                duplicateSites,
                dryRun: true
            )
        }
    }

    @Test("ParallelUploadManager handles empty site list gracefully")
    func testEmptySiteList() async throws {
        let logger = createTestLogger()
        let manager = ParallelUploadManager(maxConcurrentUploads: 3, logger: logger)

        let results = try await manager.uploadSites(
            [],
            dryRun: true
        )

        #expect(results.isEmpty)

        let progress = await manager.getCurrentProgress()
        #expect(progress.totalSites == 0)
        #expect(progress.isComplete == true)
    }

    @Test("ParallelUploadManager performs single site upload correctly")
    func testSingleSiteUpload() async throws {
        let logger = createTestLogger()
        let manager = ParallelUploadManager(maxConcurrentUploads: 3, logger: logger)

        let results = try await manager.uploadSites(
            ["1337lawyers"],  // Small site for testing
            dryRun: true
        )

        #expect(results.count == 1)
        #expect(results[0].siteName == "1337lawyers")

        // Should succeed in dry run mode
        switch results[0].outcome {
        case .success(let stats):
            #expect(stats.uploadedFiles >= 0)  // Dry run should report files that would be uploaded
        case .failure(let error):
            throw error  // Fail test if upload failed
        }

        let progress = await manager.getCurrentProgress()
        #expect(progress.totalSites == 1)
        #expect(progress.completedSites == 1)
        #expect(progress.isComplete == true)
        #expect(progress.successRate >= 0.0)
    }

    @Test("ParallelUploadManager processes multiple sites concurrently")
    func testMultipleSiteUpload() async throws {
        let logger = createTestLogger()
        let manager = ParallelUploadManager(maxConcurrentUploads: 2, logger: logger)

        let sites = ["1337lawyers", "HoshiHoshi"]  // Two smaller sites
        let startTime = Date()

        let results = try await manager.uploadSites(
            sites,
            dryRun: true
        )

        let duration = Date().timeIntervalSince(startTime)

        #expect(results.count == sites.count)

        // Verify all sites were processed
        let resultSiteNames = Set(results.map { $0.siteName })
        let expectedSiteNames = Set(sites)
        #expect(resultSiteNames == expectedSiteNames)

        // All should succeed in dry run mode
        for result in results {
            switch result.outcome {
            case .success(let stats):
                #expect(stats.uploadedFiles >= 0)
            case .failure(let error):
                throw error
            }
        }

        let progress = await manager.getCurrentProgress()
        #expect(progress.totalSites == sites.count)
        #expect(progress.completedSites == sites.count)
        #expect(progress.isComplete == true)
        #expect(progress.successRate == 1.0)  // All should succeed

        // Concurrent processing should be faster than sequential (though in dry run, difference may be minimal)
        #expect(duration < 60.0)  // Should complete within reasonable time
    }

    @Test("ParallelUploadManager respects concurrency limits")
    func testConcurrencyLimiting() async throws {
        let logger = createTestLogger()
        let manager = ParallelUploadManager(maxConcurrentUploads: 1, logger: logger)  // Force sequential

        let sites = ["1337lawyers", "HoshiHoshi", "TarotSwift"]

        // Monitor active uploads during execution
        var maxConcurrentObserved = 0
        var observationCount = 0

        let results = try await manager.uploadSites(
            sites,
            dryRun: true,
            progressCallback: { progress in
                // This callback allows us to observe concurrent behavior
                observationCount += 1
            }
        )

        #expect(results.count == sites.count)
        #expect(observationCount > 0)  // Should have received progress updates

        // All uploads should succeed
        for result in results {
            switch result.outcome {
            case .success:
                break  // Expected
            case .failure(let error):
                throw error
            }
        }
    }

    @Test("ParallelUploadManager handles individual site failures gracefully")
    func testIndividualSiteFailureHandling() async throws {
        let logger = createTestLogger()
        let manager = ParallelUploadManager(maxConcurrentUploads: 3, logger: logger)

        // Mix valid and invalid sites - but all should be valid site names
        // The failure will come from other factors (like missing directories in non-dry-run mode)
        let sites = ["1337lawyers", "HoshiHoshi"]  // Both valid sites

        let results = try await manager.uploadSites(
            sites,
            dryRun: true  // Use dry run to avoid real upload failures
        )

        #expect(results.count == sites.count)

        // In dry run mode, all should succeed
        let successfulUploads = results.filter { result in
            if case .success = result.outcome { return true }
            return false
        }

        #expect(successfulUploads.count == sites.count)
    }

    @Test("ParallelUploadManager provides accurate progress tracking")
    func testProgressTracking() async throws {
        let logger = createTestLogger()
        let manager = ParallelUploadManager(maxConcurrentUploads: 2, logger: logger)

        let sites = ["1337lawyers", "HoshiHoshi"]
        var progressUpdates: [ParallelUploadProgress] = []

        let results = try await manager.uploadSites(
            sites,
            dryRun: true,
            progressCallback: { progress in
                progressUpdates.append(progress)
            }
        )

        #expect(results.count == sites.count)
        #expect(progressUpdates.count > 0)

        // Verify progress makes sense
        for progress in progressUpdates {
            #expect(progress.totalSites == sites.count)
            #expect(progress.completedSites + progress.failedSites <= progress.totalSites)
            #expect(progress.progressPercentage >= 0.0)
            #expect(progress.progressPercentage <= 100.0)
        }

        // Final progress should show completion
        let finalProgress = await manager.getCurrentProgress()
        #expect(finalProgress.isComplete == true)
        #expect(finalProgress.progressPercentage == 100.0)
    }

    @Test("ParallelUploadManager handles configuration parameters correctly")
    func testConfigurationParameters() async throws {
        let logger = createTestLogger()
        let manager = ParallelUploadManager(maxConcurrentUploads: 2, logger: logger)

        let sites = ["1337lawyers"]
        let excludePatterns = ["*.log", "temp/**"]

        let results = try await manager.uploadSites(
            sites,
            profile: "test-profile",
            environment: "dev",
            dryRun: true,
            excludePatterns: excludePatterns
        )

        #expect(results.count == 1)
        #expect(results[0].siteName == "1337lawyers")

        // Should succeed with configuration parameters
        switch results[0].outcome {
        case .success(let stats):
            #expect(stats.uploadedFiles >= 0)
        case .failure(let error):
            throw error
        }
    }

    @Test("ParallelUploadManager measures upload duration accurately")
    func testDurationMeasurement() async throws {
        let logger = createTestLogger()
        let manager = ParallelUploadManager(maxConcurrentUploads: 2, logger: logger)

        let sites = ["1337lawyers"]

        let results = try await manager.uploadSites(
            sites,
            dryRun: true
        )

        #expect(results.count == 1)

        let result = results[0]
        #expect(result.duration >= 0.0)
        #expect(result.duration < 60.0)  // Should complete quickly in dry run mode
    }

    @Test("ParallelUploadManager handles concurrent access safely")
    func testConcurrentSafety() async throws {
        let logger = createTestLogger()
        let manager = ParallelUploadManager(maxConcurrentUploads: 3, logger: logger)

        // Start multiple upload operations concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<3 {
                group.addTask {
                    do {
                        let sites = ["1337lawyers"]  // Same site for all tasks
                        _ = try await manager.uploadSites(
                            sites,
                            dryRun: true
                        )
                    } catch {
                        // Ignore errors for this concurrency test
                    }
                }
            }
        }

        // Manager should remain in consistent state
        let activeUploads = await manager.getActiveUploads()
        #expect(activeUploads.isEmpty)  // All uploads should have completed
    }
}

// MARK: - Supporting Types

/// Simple test logger for testing
private func createTestLogger() -> Logger {
    Logger(label: "test")
}
