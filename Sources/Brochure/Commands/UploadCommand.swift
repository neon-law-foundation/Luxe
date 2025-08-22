import ArgumentParser
import Foundation
import Logging

struct UploadCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "upload",
        abstract: "Upload a static website to S3 with intelligent change detection and optimized caching",
        discussion: """
            The upload command deploys static websites to Amazon S3 with advanced optimization features:

            CHANGE DETECTION:
              • Uses MD5 hash comparison to skip uploading unchanged files
              • Dramatically reduces upload time for incremental deployments
              • Provides detailed reporting of uploaded, skipped, and failed files

            PERFORMANCE FEATURES:
              • Automatic multipart uploads for files over 5MB
              • Concurrent file processing for faster uploads
              • Exponential backoff retry logic for handling AWS rate limits
              • Progress tracking with real-time percentage completion

            CACHING OPTIMIZATION:
              • HTML files: no-cache headers for dynamic content updates
              • CSS/JS/Images: 1-year cache headers with immutable flag
              • Fonts: Long-term caching for optimal performance
              • Manifests: Moderate caching for configuration files

            FILE EXCLUSION:
              Supports glob patterns for excluding files:
              • *.log - Exclude all log files
              • temp/** - Exclude entire temp directory
              • **/node_modules/** - Exclude node_modules anywhere
              • test?.js - Exclude test1.js, testA.js, etc.

            EXAMPLES:
              # Basic upload
              swift run Brochure upload NeonLaw

              # Upload using specific AWS profile
              swift run Brochure upload NeonLaw --profile production

              # Preview changes without uploading
              swift run Brochure upload HoshiHoshi --dry-run

              # Upload with exclusions and detailed progress
              swift run Brochure upload HoshiHoshi \\
                --exclude "*.log,temp/**,**/node_modules/**" \\
                --verbose

              # Silent upload for CI/CD pipelines with staging profile
              swift run Brochure upload NeonLaw --quiet --profile staging

            OUTPUT DESTINATION:
              Files upload to: s3://sagebrush-public/Brochure/{SiteName}/
              CloudFront serves files with optimized caching and global distribution
            """
    )

    @Argument(
        help: ArgumentHelp(
            "The site name to upload",
            discussion:
                "Must be one of: NeonLaw, HoshiHoshi, TarotSwift, NLF, NVSciTech, 1337lawyers. Each site has its own directory structure and content. Cannot be used with --sites.",
            valueName: "site-name"
        )
    )
    var siteName: String?

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Multiple sites to upload concurrently (comma-separated)",
            discussion: """
                Comma-separated list of site names to upload in parallel. Enables concurrent processing
                for faster deployment of multiple sites. Cannot be used with positional site-name argument.

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
            "Preview operations without uploading",
            discussion:
                "Performs all analysis and shows what would be uploaded, but doesn't transfer any files to S3. Useful for validating changes before deployment."
        )
    )
    var dryRun = false

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Exclude files matching these patterns",
            discussion: """
                Comma-separated glob patterns for excluding files and directories.
                Examples: "*.log" (log files), "temp/**" (temp directory), "**/node_modules/**" (node_modules anywhere).
                Patterns support * (any chars), ? (single char), and ** (recursive directories).
                """,
            valueName: "patterns"
        )
    )
    var exclude: String?

    @Flag(
        name: .long,
        help: ArgumentHelp(
            "Suppress all output except errors",
            discussion:
                "Minimal output mode suitable for CI/CD pipelines. Only displays critical errors and upload failures."
        )
    )
    var quiet = false

    @Flag(
        name: .long,
        help: ArgumentHelp(
            "Enable verbose output with detailed progress",
            discussion:
                "Shows detailed progress information including file-by-file upload status, byte counts, cache headers, and performance metrics."
        )
    )
    var verbose = false

    @Option(
        name: .long,
        help: ArgumentHelp(
            "AWS profile to use for authentication",
            discussion: """
                Specify the AWS profile to use for S3 operations. The profile must be configured in ~/.aws/credentials or ~/.aws/config.
                If not specified, uses the default AWS credential chain (environment variables, default profile, EC2 instance metadata).

                Examples:
                  --profile production  (use production profile)
                  --profile staging     (use staging profile)
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
                Specify the target deployment environment to use predefined configurations for different AWS accounts.
                Each environment has optimized settings for bucket names, caching policies, and security requirements.

                Available environments:
                  dev        - Development environment with minimal caching
                  staging    - Staging environment with moderate caching
                  prod       - Production environment with full caching and validation
                  test       - Testing environment for automated tests

                If not specified, infers environment from AWS profile name or uses development as default.
                """,
            valueName: "environment"
        )
    )
    var environment: String?

    func validate() throws {
        // Validate that either siteName or sites is specified
        guard siteName != nil || sites != nil else {
            throw ArgumentParser.ValidationError("Must specify either a site name or --sites")
        }

        // Validate that siteName and sites are not both specified
        if siteName != nil && sites != nil {
            throw ArgumentParser.ValidationError("Cannot specify both site name and --sites")
        }
    }

    func run() async throws {
        // Set up logger with appropriate level based on flags
        var logger = Logger(label: "Brochure")
        if quiet {
            logger.logLevel = .error
        } else if verbose {
            logger.logLevel = .debug
        } else {
            logger.logLevel = .info
        }

        // Initialize command audit logger
        let commandLogger = CommandAuditLogger(systemLogger: logger)

        // Determine which sites to upload
        let sitesToUpload: [String]
        if let singleSite = siteName {
            // Single site upload
            let validSites = ["NeonLaw", "HoshiHoshi", "TarotSwift", "NLF", "NVSciTech", "1337lawyers"]
            guard validSites.contains(singleSite) else {
                throw CleanExit.message(
                    "Invalid site name. Must be one of: \(validSites.joined(separator: ", "))"
                )
            }
            sitesToUpload = [singleSite]
        } else {
            // Multiple sites upload
            sitesToUpload = sites!.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }

        // Audit the upload operation
        try await commandLogger.auditUpload(
            siteName: sitesToUpload.joined(separator: ","),
            profile: profile,
            environment: environment
        ) {
            // Handle single vs multiple site uploads
            if sitesToUpload.count == 1 {
                // Use existing single-site upload logic
                try await uploadSingleSite(sitesToUpload[0], logger: logger, commandLogger: commandLogger)
            } else {
                // Use parallel upload for multiple sites
                try await uploadMultipleSites(sitesToUpload, logger: logger, commandLogger: commandLogger)
            }
        }
    }

    // MARK: - Single Site Upload

    private func uploadSingleSite(_ siteName: String, logger: Logger, commandLogger: CommandAuditLogger) async throws {
        // Resolve deployment configuration
        let deploymentConfig = DeploymentConfigurationResolver.resolve(
            explicitEnvironment: environment,
            profile: profile,
            environmentVariables: ProcessInfo.processInfo.environment,
            siteName: siteName,
            logger: logger
        )

        if !quiet {
            logger.info("Starting upload for site: \(siteName)")
            logger.info("Using deployment configuration: \(deploymentConfig.description)")

            if dryRun {
                logger.info("DRY RUN MODE - No files will be uploaded")
            }

            if deploymentConfig.requiresSecurityValidation {
                logger.warning("⚠️  Production deployment detected - ensuring security validation")
            }
        }

        // Validate deployment access if required
        if deploymentConfig.requiresSecurityValidation {
            if !quiet {
                logger.info(
                    "🔍 Performing security validation for \(deploymentConfig.environment.displayName) environment"
                )
            }

            // Audit security validation attempt
            await commandLogger.logSecurityEvent(
                action: "deployment-security-validation",
                resource: "deployment-config:\(deploymentConfig.environment.rawValue)",
                profile: deploymentConfig.profileName,
                outcome: .success,
                securityLevel: "high",
                metadata: [
                    "environment": deploymentConfig.environment.displayName,
                    "account_id": String(deploymentConfig.accountId.suffix(4)),
                    "validation_type": "pre-deployment",
                ]
            )

            let validationResult = await deploymentConfig.validateAccess(logger: logger)
            switch validationResult {
            case .success:
                if !quiet {
                    logger.info("✅ Security validation passed")
                }

                // Audit successful security validation
                await commandLogger.logSecurityEvent(
                    action: "security-validation-success",
                    resource: "deployment-config:\(deploymentConfig.environment.rawValue)",
                    profile: deploymentConfig.profileName,
                    outcome: .success,
                    securityLevel: "high"
                )

            case .failure(let errors):
                logger.error("❌ Security validation failed:")
                for error in errors {
                    logger.error("  • \(error.localizedDescription)")
                    if verbose {
                        logger.info("    \(error.userFriendlyDescription)")
                    }
                }

                // Audit failed security validation
                await commandLogger.logSecurityEvent(
                    action: "security-validation-failure",
                    resource: "deployment-config:\(deploymentConfig.environment.rawValue)",
                    profile: deploymentConfig.profileName,
                    outcome: .failure,
                    securityLevel: "critical",
                    metadata: [
                        "error_count": String(errors.count),
                        "environment": deploymentConfig.environment.displayName,
                    ]
                )

                throw CleanExit.message(
                    "Security validation failed for \(deploymentConfig.environment.displayName) environment. Use --verbose for detailed remediation steps."
                )
            }
        } else {
            // Still perform basic configuration validation
            guard deploymentConfig.isConfigurationValid() else {
                throw CleanExit.message(
                    "Invalid deployment configuration for \(deploymentConfig.environment.displayName) environment. Please check your settings."
                )
            }
        }

        // Find the Public directory using Bundle resources
        guard let resourceURL = Bundle.module.url(forResource: "Public", withExtension: nil) else {
            throw UploadError.publicDirectoryNotFound
        }

        let siteDirectory = resourceURL.appendingPathComponent(siteName)

        guard FileManager.default.fileExists(atPath: siteDirectory.path) else {
            throw UploadError.siteDirectoryNotFound(siteName)
        }

        if verbose {
            logger.debug("Found site directory: \(siteDirectory.path)")
        } else if !quiet {
            logger.info("Found site directory: \(siteDirectory.path)")
        }

        let uploader = LazyS3Uploader(
            bucketName: deploymentConfig.uploadConfiguration.bucketName,
            keyPrefix: deploymentConfig.uploadConfiguration.keyPrefix,
            profile: deploymentConfig.profileName
        )
        let progress = UploadProgress()

        do {
            let excludePatterns = exclude?.parseExcludePatterns() ?? []
            try await uploader.uploadDirectory(
                localDirectory: siteDirectory.path,
                sitePrefix: siteName,
                dryRun: dryRun,
                progress: progress,
                excludePatterns: excludePatterns
            )

            let finalStats = await progress.getStats()
            if !quiet {
                if dryRun {
                    logger.info("DRY RUN completed for site: \(siteName)")
                    if verbose {
                        logger.debug(
                            "Would upload \(finalStats.uploadedFiles) files (\(finalStats.formattedBytes))"
                        )
                    } else {
                        logger.info("Would upload \(finalStats.uploadedFiles) files")
                    }
                } else {
                    logger.info("Upload completed successfully for site: \(siteName)")
                    if verbose {
                        logger.debug("Final stats: \(finalStats.summary)")
                        logger.debug("Site available at: https://d1234567890.cloudfront.net/\(siteName)/")
                    } else {
                        logger.info("Uploaded \(finalStats.uploadedFiles) files")
                    }
                }
            }

            // Shutdown the AWS client
            try await uploader.shutdown()
        } catch {
            logger.error("Upload failed: \(error)")
            throw error
        }
    }

    // MARK: - Multiple Sites Upload

    private func uploadMultipleSites(
        _ siteNames: [String],
        logger: Logger,
        commandLogger: CommandAuditLogger
    ) async throws {
        if !quiet {
            logger.info("🚀 Starting parallel upload for \(siteNames.count) sites: \(siteNames.joined(separator: ", "))")
            if dryRun {
                logger.info("🔍 DRY RUN MODE - No files will be uploaded")
            }
        }

        // Create parallel upload manager with default concurrency
        let uploadManager = ParallelUploadManager(
            maxConcurrentUploads: 3,  // Conservative default for UploadCommand
            logger: logger
        )

        // Set up progress callback for real-time updates
        let progressCallback: (ParallelUploadProgress) -> Void = { progress in
            if !self.quiet {
                let percentage = String(format: "%.1f", progress.progressPercentage)
                logger.info(
                    "📊 Progress: \(progress.completedSites + progress.failedSites)/\(progress.totalSites) sites (\(percentage)%)"
                )
            }
        }

        do {
            let excludePatterns = exclude?.parseExcludePatterns() ?? []

            // Start parallel uploads
            let results = try await uploadManager.uploadSites(
                siteNames,
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

public enum UploadError: Error, LocalizedError {
    case publicDirectoryNotFound
    case siteDirectoryNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .publicDirectoryNotFound:
            return "Public directory not found in bundle resources"
        case .siteDirectoryNotFound(let siteName):
            return "Site directory not found for: \(siteName)"
        }
    }
}
