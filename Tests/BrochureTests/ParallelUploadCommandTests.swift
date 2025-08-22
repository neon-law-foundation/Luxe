import Foundation
import Testing

@testable import Brochure

/// Tests for parallel upload functionality in UploadCommand and UploadAllCommand.
///
/// These tests verify that the CLI commands properly handle multiple site uploads
/// with concurrent processing, argument validation, and error handling.
@Suite("Parallel Upload Command Tests")
struct ParallelUploadCommandTests {

    @Test("UploadCommand validates single site and multiple sites arguments correctly")
    func testUploadCommandArgumentValidation() throws {
        // Test valid single site
        var command = try UploadCommand.parse(["NeonLaw"])
        #expect(command.siteName == "NeonLaw")
        #expect(command.sites == nil)

        // Test valid multiple sites
        command = try UploadCommand.parse(["--sites", "NeonLaw,HoshiHoshi"])
        #expect(command.siteName == nil)
        #expect(command.sites == "NeonLaw,HoshiHoshi")

        // Test that both arguments cannot be specified
        #expect(throws: Error.self) {
            _ = try UploadCommand.parse(["NeonLaw", "--sites", "HoshiHoshi"])
        }

        // Test that at least one argument must be specified
        #expect(throws: Error.self) {
            _ = try UploadCommand.parse([])
        }
    }

    @Test("UploadAllCommand validates argument combinations correctly")
    func testUploadAllCommandArgumentValidation() throws {
        // Test valid --all flag
        var command = try UploadAllCommand.parse(["--all"])
        #expect(command.all == true)
        #expect(command.sites == nil)

        // Test valid --sites argument
        command = try UploadAllCommand.parse(["--sites", "NeonLaw,HoshiHoshi"])
        #expect(command.all == false)
        #expect(command.sites == "NeonLaw,HoshiHoshi")

        // Test --exclude with --all (should be valid)
        command = try UploadAllCommand.parse(["--all", "--exclude", "NeonLaw"])
        #expect(command.all == true)
        #expect(command.exclude == "NeonLaw")

        // Test that --exclude without --all should be invalid
        #expect(throws: Error.self) {
            _ = try UploadAllCommand.parse(["--sites", "NeonLaw", "--exclude", "HoshiHoshi"])
        }

        // Test that both --all and --sites cannot be specified
        #expect(throws: Error.self) {
            _ = try UploadAllCommand.parse(["--all", "--sites", "NeonLaw"])
        }

        // Test that either --all or --sites must be specified
        #expect(throws: Error.self) {
            _ = try UploadAllCommand.parse([])
        }

        // Test concurrency validation
        #expect(throws: Error.self) {
            _ = try UploadAllCommand.parse(["--all", "--max-concurrent", "0"])
        }

        #expect(throws: Error.self) {
            _ = try UploadAllCommand.parse(["--all", "--max-concurrent", "25"])
        }
    }

    @Test("UploadAllCommand parses concurrency and file exclusion options correctly")
    func testUploadAllCommandOptions() throws {
        let command = try UploadAllCommand.parse([
            "--sites", "NeonLaw,HoshiHoshi",
            "--max-concurrent", "5",
            "--exclude-files", "*.log,temp/**",
            "--dry-run",
            "--verbose",
            "--profile", "production",
        ])

        #expect(command.sites == "NeonLaw,HoshiHoshi")
        #expect(command.maxConcurrent == 5)
        #expect(command.excludeFiles == "*.log,temp/**")
        #expect(command.dryRun == true)
        #expect(command.verbose == true)
        #expect(command.profile == "production")
    }

    @Test("UploadCommand supports multiple sites via --sites option")
    func testUploadCommandMultipleSitesSupport() throws {
        let command = try UploadCommand.parse([
            "--sites", "NeonLaw,HoshiHoshi,TarotSwift",
            "--dry-run",
            "--profile", "staging",
        ])

        #expect(command.siteName == nil)
        #expect(command.sites == "NeonLaw,HoshiHoshi,TarotSwift")
        #expect(command.dryRun == true)
        #expect(command.profile == "staging")
    }

    @Test("String extension parses exclude patterns correctly")
    func testExcludePatternParsing() {
        let patterns1 = "*.log,temp/**,**/node_modules/**".parseExcludePatterns()
        #expect(patterns1.count == 3)
        #expect(patterns1.contains("*.log"))
        #expect(patterns1.contains("temp/**"))
        #expect(patterns1.contains("**/node_modules/**"))

        let patterns2 = "  *.txt  ,  cache/  ,  build/**  ".parseExcludePatterns()
        #expect(patterns2.count == 3)
        #expect(patterns2.contains("*.txt"))
        #expect(patterns2.contains("cache/"))
        #expect(patterns2.contains("build/**"))

        let singlePattern = "*.log".parseExcludePatterns()
        #expect(singlePattern.count == 1)
        #expect(singlePattern[0] == "*.log")

        let emptyPattern = "".parseExcludePatterns()
        #expect(emptyPattern.isEmpty)
    }

    @Test("ParallelUploadError provides meaningful error messages")
    func testParallelUploadErrorMessages() {
        let invalidSitesError = ParallelUploadError.invalidSites(
            ["InvalidSite1", "InvalidSite2"],
            validSites: ["NeonLaw", "HoshiHoshi"]
        )
        let invalidSitesMessage = invalidSitesError.errorDescription
        #expect(invalidSitesMessage?.contains("InvalidSite1") == true)
        #expect(invalidSitesMessage?.contains("InvalidSite2") == true)
        #expect(invalidSitesMessage?.contains("NeonLaw") == true)
        #expect(invalidSitesMessage?.contains("HoshiHoshi") == true)

        let duplicateSitesError = ParallelUploadError.duplicateSites(["NeonLaw", "HoshiHoshi", "NeonLaw"])
        let duplicateSitesMessage = duplicateSitesError.errorDescription
        #expect(duplicateSitesMessage?.contains("Duplicate") == true)

        let siteNotFoundError = ParallelUploadError.siteDirectoryNotFound("TestSite")
        let siteNotFoundMessage = siteNotFoundError.errorDescription
        #expect(siteNotFoundMessage?.contains("TestSite") == true)
        #expect(siteNotFoundMessage?.contains("directory not found") == true)
    }

    @Test("SiteUploadResult tracks upload outcomes correctly")
    func testSiteUploadResult() {
        let mockStats = UploadStats(
            totalFiles: 15,
            processedFiles: 15,
            uploadedFiles: 10,
            skippedFiles: 5,
            failedFiles: 0,
            totalBytes: 1024,
            uploadedBytes: 1024,
            percentageComplete: 100.0,
            isComplete: true
        )

        let successResult = SiteUploadResult(
            siteName: "TestSite",
            outcome: .success(mockStats),
            duration: 2.5
        )

        #expect(successResult.siteName == "TestSite")
        #expect(successResult.duration == 2.5)

        switch successResult.outcome {
        case .success(let stats):
            #expect(stats.uploadedFiles == 10)
            #expect(stats.totalBytes == 1024)
        case .failure:
            #expect(Bool(false), "Expected success, got failure")
        }

        let testError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let failureResult = SiteUploadResult(
            siteName: "TestSite",
            outcome: .failure(testError),
            duration: 1.0
        )

        switch failureResult.outcome {
        case .success:
            #expect(Bool(false), "Expected failure, got success")
        case .failure(let error):
            #expect(error.localizedDescription == "Test error")
        }
    }

    @Test("ParallelUploadProgress calculates metrics correctly")
    func testParallelUploadProgress() {
        var progress = ParallelUploadProgress()

        // Test initial state
        #expect(progress.totalSites == 0)
        #expect(progress.completedSites == 0)
        #expect(progress.failedSites == 0)
        #expect(progress.isComplete == true)  // Empty list is complete
        #expect(progress.successRate == 0.0)
        #expect(progress.progressPercentage == 0.0)

        // Initialize for sites
        progress.initializeForSitesInternal(["Site1", "Site2", "Site3"])
        #expect(progress.totalSites == 3)
        #expect(progress.isComplete == false)  // Now that sites are initialized, it's not complete
        #expect(progress.progressPercentage == 0.0)

        // Complete one site successfully
        let mockStats = UploadStats(
            totalFiles: 7,
            processedFiles: 7,
            uploadedFiles: 5,
            skippedFiles: 2,
            failedFiles: 0,
            totalBytes: 512,
            uploadedBytes: 512,
            percentageComplete: 100.0,
            isComplete: true
        )
        progress.completeSiteInternal("Site1", result: .success(mockStats))

        #expect(progress.completedSites == 1)
        #expect(progress.failedSites == 0)
        #expect(abs(progress.progressPercentage - 100.0 / 3.0) < 0.01)  // ~33.33%
        #expect(progress.successRate == 1.0 / 3.0)  // 1 success out of 3 total

        // Complete one site with failure
        let testError = NSError(domain: "test", code: 1, userInfo: nil)
        progress.completeSiteInternal("Site2", result: .failure(testError))

        #expect(progress.completedSites == 1)  // Still 1 successful
        #expect(progress.failedSites == 1)
        #expect(abs(progress.progressPercentage - 200.0 / 3.0) < 0.01)  // ~66.67% (1 success + 1 failure out of 3)
        #expect(progress.successRate == 1.0 / 3.0)  // 1 success out of 3 total

        // Complete final site successfully
        progress.completeSiteInternal("Site3", result: .success(mockStats))

        #expect(progress.completedSites == 2)  // 2 successful
        #expect(progress.failedSites == 1)  // 1 failed
        #expect(progress.isComplete == true)
        #expect(progress.progressPercentage == 100.0)
        #expect(progress.successRate == 2.0 / 3.0)  // 2 successes out of 3 total

        // Verify site results are stored
        #expect(progress.siteResults.count == 3)
        #expect(progress.siteResults["Site1"] != nil)
        #expect(progress.siteResults["Site2"] != nil)
        #expect(progress.siteResults["Site3"] != nil)
    }

    @Test("UploadAllCommand builds correct site lists with --all and --exclude")
    func testUploadAllCommandSiteListBuilding() throws {
        // Test parsing site names from --sites
        let sitesCommand = try UploadAllCommand.parse(["--sites", "NeonLaw,HoshiHoshi,TarotSwift"])
        let parsedSites = sitesCommand.sites!.components(separatedBy: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        #expect(parsedSites.count == 3)
        #expect(parsedSites.contains("NeonLaw"))
        #expect(parsedSites.contains("HoshiHoshi"))
        #expect(parsedSites.contains("TarotSwift"))

        // Test exclusion parsing
        let excludeCommand = try UploadAllCommand.parse(["--all", "--exclude", "NeonLaw,TarotSwift"])
        let excludedSites = excludeCommand.exclude!.components(separatedBy: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        #expect(excludedSites.count == 2)
        #expect(excludedSites.contains("NeonLaw"))
        #expect(excludedSites.contains("TarotSwift"))
    }
}
