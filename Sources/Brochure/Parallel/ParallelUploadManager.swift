import Foundation
import Logging

/// Manages parallel uploads for multiple sites with intelligent resource management and progress tracking.
///
/// `ParallelUploadManager` enables concurrent deployment of multiple static sites to S3 while:
/// - Limiting concurrent uploads to prevent AWS rate limiting and resource exhaustion
/// - Providing real-time progress tracking across all upload operations
/// - Handling failures gracefully with detailed error reporting per site
/// - Optimizing resource usage with shared AWS client connections
///
/// ## Key Features
///
/// - **Concurrent Processing**: Upload multiple sites simultaneously with configurable concurrency limits
/// - **Progress Tracking**: Real-time progress updates across all concurrent uploads
/// - **Resource Management**: Efficient AWS client reuse and cleanup
/// - **Error Handling**: Per-site error reporting with continuation of other uploads
/// - **Performance Monitoring**: Detailed timing and throughput metrics
///
/// ## Example Usage
///
/// ```swift
/// let manager = ParallelUploadManager(
///     maxConcurrentUploads: 3,
///     logger: logger
/// )
///
/// let sites = ["NeonLaw", "HoshiHoshi", "TarotSwift"]
/// let results = try await manager.uploadSites(
///     sites,
///     profile: "production",
///     dryRun: false
/// )
///
/// // Handle results for each site
/// for result in results {
///     switch result.outcome {
///     case .success(let stats):
///         print("✅ \(result.siteName): \(stats.uploadedFiles) files")
///     case .failure(let error):
///         print("❌ \(result.siteName): \(error)")
///     }
/// }
/// ```
public actor ParallelUploadManager {
    private let maxConcurrentUploads: Int
    private let logger: Logger
    private var activeUploads: Set<String> = []
    private var totalProgress: ParallelUploadProgress

    /// Initializes the parallel upload manager with concurrency limits.
    ///
    /// - Parameters:
    ///   - maxConcurrentUploads: Maximum number of concurrent uploads (default: 3)
    ///   - logger: Logger instance for progress and error reporting
    public init(
        maxConcurrentUploads: Int = 3,
        logger: Logger
    ) {
        self.maxConcurrentUploads = maxConcurrentUploads
        self.logger = logger
        self.totalProgress = ParallelUploadProgress()
    }

    /// Uploads multiple sites concurrently with intelligent resource management.
    ///
    /// - Parameters:
    ///   - siteNames: Array of site names to upload
    ///   - profile: AWS profile to use for authentication
    ///   - environment: Deployment environment (optional)
    ///   - dryRun: Whether to perform a dry run without actual uploads
    ///   - excludePatterns: Glob patterns for excluding files
    ///   - progressCallback: Optional callback for progress updates
    ///
    /// - Returns: Array of upload results for each site
    /// - Throws: Critical errors that prevent any uploads from starting
    public func uploadSites(
        _ siteNames: [String],
        profile: String? = nil,
        environment: String? = nil,
        dryRun: Bool = false,
        excludePatterns: [String] = [],
        progressCallback: ((ParallelUploadProgress) -> Void)? = nil
    ) async throws -> [SiteUploadResult] {
        logger.info("🚀 Starting parallel upload for \(siteNames.count) sites")
        logger.info("📊 Concurrency limit: \(maxConcurrentUploads) simultaneous uploads")

        if dryRun {
            logger.info("🔍 DRY RUN MODE - No files will be uploaded")
        }

        // Initialize progress tracking
        totalProgress.initializeForSites(siteNames)

        // Validate all sites exist before starting any uploads
        try validateSites(siteNames)

        let startTime = Date()

        // Use TaskGroup for structured concurrency with limited parallelism
        return try await withThrowingTaskGroup(of: SiteUploadResult.self) { group in
            var results: [SiteUploadResult] = []
            var currentIndex = 0

            // Start initial batch of uploads (up to concurrency limit)
            let initialBatchSize = min(maxConcurrentUploads, siteNames.count)
            for i in 0..<initialBatchSize {
                let siteName = siteNames[i]
                await addActiveUpload(siteName)
                group.addTask {
                    await self.uploadSingleSite(
                        siteName: siteName,
                        profile: profile,
                        environment: environment,
                        dryRun: dryRun,
                        excludePatterns: excludePatterns
                    )
                }
                currentIndex = i + 1
            }

            // Process completed uploads and start new ones
            while let result = try await group.next() {
                results.append(result)
                await removeActiveUpload(result.siteName)

                // Update progress and notify callback
                totalProgress.completeSite(result.siteName, result: result.outcome)
                if let callback = progressCallback {
                    callback(totalProgress.getCurrentProgress())
                }

                // Start next upload if there are more sites
                if currentIndex < siteNames.count {
                    let nextSite = siteNames[currentIndex]
                    await addActiveUpload(nextSite)
                    group.addTask {
                        await self.uploadSingleSite(
                            siteName: nextSite,
                            profile: profile,
                            environment: environment,
                            dryRun: dryRun,
                            excludePatterns: excludePatterns
                        )
                    }
                    currentIndex += 1
                }
            }

            let totalDuration = Date().timeIntervalSince(startTime)
            await logFinalResults(results, duration: totalDuration, dryRun: dryRun)

            return results
        }
    }

    /// Gets current progress information for all uploads.
    ///
    /// - Returns: Current parallel upload progress
    public func getCurrentProgress() async -> ParallelUploadProgress {
        totalProgress.getCurrentProgress()
    }

    /// Gets list of currently active uploads.
    ///
    /// - Returns: Set of site names currently being uploaded
    public func getActiveUploads() async -> Set<String> {
        activeUploads
    }

    // MARK: - Private Implementation

    private func addActiveUpload(_ siteName: String) async {
        activeUploads.insert(siteName)
        logger.debug("📤 Started upload for site: \(siteName) (active: \(activeUploads.count))")
    }

    private func removeActiveUpload(_ siteName: String) async {
        activeUploads.remove(siteName)
        logger.debug("✅ Completed upload for site: \(siteName) (active: \(activeUploads.count))")
    }

    private func validateSites(_ siteNames: [String]) throws {
        let validSites = ["NeonLaw", "HoshiHoshi", "TarotSwift", "NLF", "NVSciTech", "1337lawyers"]
        let invalidSites = siteNames.filter { !validSites.contains($0) }

        if !invalidSites.isEmpty {
            throw ParallelUploadError.invalidSites(
                invalidSites,
                validSites: validSites
            )
        }

        // Check for duplicates
        let uniqueSites = Set(siteNames)
        if uniqueSites.count != siteNames.count {
            throw ParallelUploadError.duplicateSites(siteNames)
        }

        logger.info("✅ Validated \(siteNames.count) sites for upload")
    }

    private func uploadSingleSite(
        siteName: String,
        profile: String?,
        environment: String?,
        dryRun: Bool,
        excludePatterns: [String]
    ) async -> SiteUploadResult {
        let startTime = Date()

        do {
            // Resolve deployment configuration for this site
            let deploymentConfig = DeploymentConfigurationResolver.resolve(
                explicitEnvironment: environment,
                profile: profile,
                environmentVariables: ProcessInfo.processInfo.environment,
                siteName: siteName,
                logger: logger
            )

            // Validate deployment access if required
            if deploymentConfig.requiresSecurityValidation {
                let validationResult = await deploymentConfig.validateAccess(logger: logger)
                switch validationResult {
                case .failure(let errors):
                    throw ParallelUploadError.securityValidationFailed(siteName, errors: errors)
                case .success:
                    break
                }
            }

            // Find site directory
            guard let resourceURL = Bundle.module.url(forResource: "Public", withExtension: nil) else {
                throw ParallelUploadError.publicDirectoryNotFound
            }

            let siteDirectory = resourceURL.appendingPathComponent(siteName)
            guard FileManager.default.fileExists(atPath: siteDirectory.path) else {
                throw ParallelUploadError.siteDirectoryNotFound(siteName)
            }

            // Create uploader for this site
            let uploader = LazyS3Uploader(
                bucketName: deploymentConfig.uploadConfiguration.bucketName,
                keyPrefix: deploymentConfig.uploadConfiguration.keyPrefix,
                profile: deploymentConfig.profileName
            )
            defer {
                Task {
                    try? await uploader.shutdown()
                }
            }

            let progress = UploadProgress()

            // Perform the upload
            try await uploader.uploadDirectory(
                localDirectory: siteDirectory.path,
                sitePrefix: siteName,
                dryRun: dryRun,
                progress: progress,
                excludePatterns: excludePatterns
            )

            let finalStats = await progress.getStats()
            let duration = Date().timeIntervalSince(startTime)

            logger.info("✅ \(siteName): \(finalStats.uploadedFiles) files in \(String(format: "%.1f", duration))s")

            return SiteUploadResult(
                siteName: siteName,
                outcome: .success(finalStats),
                duration: duration
            )

        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.error("❌ \(siteName) failed after \(String(format: "%.1f", duration))s: \(error)")

            return SiteUploadResult(
                siteName: siteName,
                outcome: .failure(error),
                duration: duration
            )
        }
    }

    private func logFinalResults(
        _ results: [SiteUploadResult],
        duration: TimeInterval,
        dryRun: Bool
    ) async {
        let successful = results.filter { result in
            if case .success = result.outcome { return true }
            return false
        }
        let failed = results.filter { result in
            if case .failure = result.outcome { return true }
            return false
        }

        logger.info("🎯 Parallel upload completed in \(String(format: "%.1f", duration))s")
        logger.info("📊 Results: \(successful.count) successful, \(failed.count) failed")

        if !successful.isEmpty {
            logger.info("✅ Successful uploads:")
            for result in successful {
                if case .success(let stats) = result.outcome {
                    let action = dryRun ? "Would upload" : "Uploaded"
                    logger.info("  • \(result.siteName): \(action) \(stats.uploadedFiles) files")
                }
            }
        }

        if !failed.isEmpty {
            logger.error("❌ Failed uploads:")
            for result in failed {
                if case .failure(let error) = result.outcome {
                    logger.error("  • \(result.siteName): \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Supporting Types

/// Result of uploading a single site in a parallel operation.
public struct SiteUploadResult: Sendable {
    public let siteName: String
    public let outcome: Result<UploadStats, Error>
    public let duration: TimeInterval

    public init(siteName: String, outcome: Result<UploadStats, Error>, duration: TimeInterval) {
        self.siteName = siteName
        self.outcome = outcome
        self.duration = duration
    }
}

/// Progress tracking for parallel upload operations.
public struct ParallelUploadProgress: Sendable {
    public private(set) var totalSites: Int = 0
    public private(set) var completedSites: Int = 0
    public private(set) var failedSites: Int = 0
    public private(set) var siteResults: [String: Result<UploadStats, Error>] = [:]

    public var isComplete: Bool {
        totalSites == 0 || completedSites + failedSites >= totalSites
    }

    public var successRate: Double {
        guard totalSites > 0 else { return 0.0 }
        return Double(completedSites) / Double(totalSites)
    }

    public var progressPercentage: Double {
        guard totalSites > 0 else { return 0.0 }
        return Double(completedSites + failedSites) / Double(totalSites) * 100.0
    }

    fileprivate mutating func initializeForSites(_ sites: [String]) {
        totalSites = sites.count
        completedSites = 0
        failedSites = 0
        siteResults.removeAll()
    }

    fileprivate mutating func completeSite(_ siteName: String, result: Result<UploadStats, Error>) {
        siteResults[siteName] = result

        switch result {
        case .success:
            completedSites += 1
        case .failure:
            failedSites += 1
        }
    }

    fileprivate func getCurrentProgress() -> ParallelUploadProgress {
        self
    }

    // Internal methods for testing
    internal mutating func initializeForSitesInternal(_ sites: [String]) {
        initializeForSites(sites)
    }

    internal mutating func completeSiteInternal(_ siteName: String, result: Result<UploadStats, Error>) {
        completeSite(siteName, result: result)
    }
}

/// Errors specific to parallel upload operations.
public enum ParallelUploadError: Error, LocalizedError {
    case invalidSites([String], validSites: [String])
    case duplicateSites([String])
    case publicDirectoryNotFound
    case siteDirectoryNotFound(String)
    case securityValidationFailed(String, errors: [Error])

    public var errorDescription: String? {
        switch self {
        case .invalidSites(let invalid, let valid):
            return
                "Invalid site names: \(invalid.joined(separator: ", ")). Valid sites: \(valid.joined(separator: ", "))"
        case .duplicateSites(let sites):
            return "Duplicate sites detected in list: \(sites.joined(separator: ", "))"
        case .publicDirectoryNotFound:
            return "Public directory not found in bundle resources"
        case .siteDirectoryNotFound(let siteName):
            return "Site directory not found for: \(siteName)"
        case .securityValidationFailed(let siteName, let errors):
            return
                "Security validation failed for \(siteName): \(errors.map { $0.localizedDescription }.joined(separator: ", "))"
        }
    }
}
