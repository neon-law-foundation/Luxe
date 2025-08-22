import ArgumentParser
import Foundation
import Logging

/// Command for uploading multiple sites concurrently with intelligent resource management.
///
/// The `upload-all` command enables parallel deployment of multiple static sites to S3,
/// providing significant performance improvements for batch deployments while maintaining
/// reliability and detailed progress tracking.
struct UploadAllCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "upload-all",
        abstract: "Upload multiple static websites to S3 concurrently with intelligent resource management",
        discussion: """
            The upload-all command enables parallel deployment of multiple static sites with advanced optimization:

            PARALLEL PROCESSING:
              • Configurable concurrency limits to prevent AWS rate limiting
              • Intelligent resource sharing across concurrent uploads
              • Real-time progress tracking for all sites simultaneously
              • Graceful error handling with continuation of other uploads

            PERFORMANCE BENEFITS:
              • 3-5x faster deployment for multiple sites compared to sequential uploads
              • Shared AWS client connections for optimal resource utilization
              • Concurrent change detection and file processing
              • Parallel S3 upload streams with intelligent throttling

            SITE SELECTION:
              • Upload all available sites with --all flag
              • Select specific sites with --sites flag
              • Exclude specific sites with --exclude flag
              • Automatic validation of site names before upload starts

            RESOURCE MANAGEMENT:
              • Default concurrency limit of 3 sites (adjustable with --max-concurrent)
              • Shared HTTP client pools for AWS operations
              • Automatic cleanup of resources after completion
              • Memory-efficient progress tracking across all uploads

            MONITORING & REPORTING:
              • Per-site upload progress and statistics
              • Real-time success/failure reporting
              • Detailed timing information for performance analysis
              • Comprehensive final summary with aggregated statistics

            EXAMPLES:
              # Upload all available sites
              swift run Brochure upload-all --all

              # Upload specific sites in parallel
              swift run Brochure upload-all --sites "NeonLaw,HoshiHoshi,TarotSwift"

              # Upload all sites except specific ones
              swift run Brochure upload-all --all --exclude "NeonLaw,TarotSwift"

              # High-concurrency upload with specific AWS profile
              swift run Brochure upload-all --all --max-concurrent 5 --profile production

              # Dry run for all sites with detailed progress
              swift run Brochure upload-all --all --dry-run --verbose

              # Upload with file exclusions
              swift run Brochure upload-all --sites "NeonLaw,HoshiHoshi" \\
                --exclude-files "*.log,temp/**,**/node_modules/**" \\
                --max-concurrent 2

            PERFORMANCE NOTES:
              • Optimal concurrency is typically 3-5 sites for most AWS accounts
              • Higher concurrency may trigger AWS rate limits
              • Use --max-concurrent 1 for sequential uploads with shared resources
              • Monitor AWS CloudWatch for rate limiting metrics in production
            """
    )

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Specific sites to upload (comma-separated)",
            discussion: """
                Comma-separated list of site names to upload concurrently.
                Must be valid site names: NeonLaw, HoshiHoshi, TarotSwift, NLF, NVSciTech, 1337lawyers.

                Examples:
                  --sites "NeonLaw,HoshiHoshi"
                  --sites "TarotSwift,NLF,NVSciTech"
                """,
            valueName: "site-names"
        )
    )
    var sites: String?

    @Flag(
        name: .long,
        help: ArgumentHelp(
            "Upload all available sites",
            discussion: "Uploads all available sites concurrently. Cannot be used with --sites."
        )
    )
    var all = false

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Sites to exclude from upload (comma-separated)",
            discussion: """
                Comma-separated list of site names to exclude from upload when using --all.
                Only effective when used with --all flag.

                Examples:
                  --exclude "NeonLaw,TarotSwift"  (exclude these sites from --all)
                """,
            valueName: "site-names"
        )
    )
    var exclude: String?

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Maximum number of concurrent uploads",
            discussion: """
                Controls the maximum number of sites that can be uploaded simultaneously.

                Recommended values:
                  1 - Sequential uploads (no parallelism)
                  3 - Default balanced performance (recommended)
                  5 - High performance for large AWS accounts
                  8+ - May trigger AWS rate limits

                Higher values provide faster uploads but may hit AWS API rate limits.
                """,
            valueName: "count"
        )
    )
    var maxConcurrent: Int = 3

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Exclude files matching these patterns from all uploads",
            discussion: """
                Comma-separated glob patterns for excluding files and directories from all site uploads.
                Applied to every site being uploaded.

                Examples: "*.log" (log files), "temp/**" (temp directory), "**/node_modules/**" (node_modules anywhere).
                Patterns support * (any chars), ? (single char), and ** (recursive directories).
                """,
            valueName: "patterns"
        )
    )
    var excludeFiles: String?

    @Flag(
        name: .long,
        help: ArgumentHelp(
            "Preview operations without uploading",
            discussion:
                "Performs all analysis and shows what would be uploaded for all sites, but doesn't transfer any files to S3."
        )
    )
    var dryRun = false

    @Flag(
        name: .long,
        help: ArgumentHelp(
            "Suppress all output except errors",
            discussion:
                "Minimal output mode suitable for CI/CD pipelines. Only displays critical errors and final summary."
        )
    )
    var quiet = false

    @Flag(
        name: .long,
        help: ArgumentHelp(
            "Enable verbose output with detailed progress",
            discussion:
                "Shows detailed progress information for each site including file-by-file upload status and performance metrics."
        )
    )
    var verbose = false

    @Option(
        name: .long,
        help: ArgumentHelp(
            "AWS profile to use for authentication",
            discussion: """
                AWS profile to use for all site uploads. Applied to every concurrent upload operation.
                The profile must be configured in ~/.aws/credentials or ~/.aws/config.
                """,
            valueName: "profile-name"
        )
    )
    var profile: String?

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Deployment environment for multi-account scenarios",
            discussion: """
                Target deployment environment applied to all site uploads.
                Available environments: dev, staging, prod, test.
                """,
            valueName: "environment"
        )
    )
    var environment: String?

    func validate() throws {
        // Validate that either --sites or --all is specified
        guard sites != nil || all else {
            throw ArgumentParser.ValidationError("Must specify either --sites or --all")
        }

        // Validate that --sites and --all are not both specified
        if sites != nil && all {
            throw ArgumentParser.ValidationError("Cannot specify both --sites and --all")
        }

        // Validate concurrency limit
        guard maxConcurrent >= 1 && maxConcurrent <= 20 else {
            throw ArgumentParser.ValidationError("--max-concurrent must be between 1 and 20")
        }

        // Validate that --exclude is only used with --all
        if exclude != nil && !all {
            throw ArgumentParser.ValidationError("--exclude can only be used with --all")
        }
    }

    func run() async throws {
        // Set up logger with appropriate level based on flags
        var logger = Logger(label: "BrochureParallel")
        if quiet {
            logger.logLevel = .error
        } else if verbose {
            logger.logLevel = .debug
        } else {
            logger.logLevel = .info
        }

        // Determine which sites to upload
        let allAvailableSites = ["NeonLaw", "HoshiHoshi", "TarotSwift", "NLF", "NVSciTech", "1337lawyers"]
        let sitesToUpload: [String]

        if all {
            // Start with all sites and apply exclusions
            let excludedSites =
                exclude?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
            sitesToUpload = allAvailableSites.filter { !excludedSites.contains($0) }

            if !quiet {
                if !excludedSites.isEmpty {
                    logger.info("Uploading all sites except: \(excludedSites.joined(separator: ", "))")
                } else {
                    logger.info("Uploading all available sites")
                }
            }
        } else {
            // Parse specified sites
            sitesToUpload = sites!.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

            if !quiet {
                logger.info("Uploading specified sites: \(sitesToUpload.joined(separator: ", "))")
            }
        }

        // Validate that we have sites to upload
        guard !sitesToUpload.isEmpty else {
            throw CleanExit.message("No sites to upload after applying filters")
        }

        // Parse exclude patterns
        let excludePatterns = excludeFiles?.parseExcludePatterns() ?? []

        // Create parallel upload manager
        let uploadManager = ParallelUploadManager(
            maxConcurrentUploads: maxConcurrent,
            logger: logger
        )

        // Set up progress callback for real-time updates
        let progressCallback: (ParallelUploadProgress) -> Void = { progress in
            if !quiet {
                let percentage = String(format: "%.1f", progress.progressPercentage)
                logger.info(
                    "📊 Progress: \(progress.completedSites + progress.failedSites)/\(progress.totalSites) sites (\(percentage)%)"
                )
            }
        }

        do {
            // Start parallel uploads
            let results = try await uploadManager.uploadSites(
                sitesToUpload,
                profile: profile,
                environment: environment,
                dryRun: dryRun,
                excludePatterns: excludePatterns,
                progressCallback: quiet ? nil : progressCallback
            )

            // Analyze results and exit appropriately
            let failedUploads = results.filter { result in
                if case .failure = result.outcome { return true }
                return false
            }

            if !failedUploads.isEmpty {
                let failedSiteNames = failedUploads.map { $0.siteName }
                throw CleanExit.message(
                    "Upload failed for \(failedUploads.count) site(s): \(failedSiteNames.joined(separator: ", "))"
                )
            }

            if !quiet {
                let action = dryRun ? "validated" : "uploaded"
                logger.info("🎉 Successfully \(action) all \(results.count) sites!")
            }

        } catch {
            logger.error("Parallel upload operation failed: \(error)")
            throw error
        }
    }
}
