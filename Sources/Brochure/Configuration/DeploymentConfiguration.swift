import Foundation
import Logging

/// Environment-specific deployment configurations for different AWS accounts.
///
/// `DeploymentConfiguration` provides predefined configurations for different deployment environments
/// (development, staging, production) across multiple AWS accounts, enabling seamless multi-account deployments.
///
/// ## Example Usage
///
/// ```swift
/// // Use environment-specific configuration
/// let prodConfig = DeploymentConfiguration.production
/// let stagingConfig = DeploymentConfiguration.staging
///
/// // Create custom configuration
/// let customConfig = DeploymentConfiguration(
///     environment: .production,
///     accountId: "123456789012",
///     bucketName: "my-prod-bucket"
/// )
/// ```
public struct DeploymentConfiguration: Sendable {
    /// The deployment environment type.
    public let environment: Environment

    /// The AWS account ID where resources are deployed.
    public let accountId: String

    /// The AWS region for this deployment.
    public let region: String

    /// The upload configuration for this deployment.
    public let uploadConfiguration: UploadConfiguration

    /// The AWS profile to use for this deployment.
    public let profileName: String?

    /// Cross-account role ARN for assume role scenarios.
    public let crossAccountRole: String?

    /// Tags to apply to uploaded objects.
    public let tags: [String: String]

    /// Deployment-specific metadata.
    public let metadata: [String: String]

    /// Whether this deployment requires additional security validation.
    public let requiresSecurityValidation: Bool

    /// CloudFront distribution ID for cache invalidation.
    public let cloudFrontDistributionId: String?

    /// Deployment environment types.
    public enum Environment: String, CaseIterable, Sendable {
        case development = "dev"
        case staging = "staging"
        case production = "prod"
        case testing = "test"

        public var displayName: String {
            switch self {
            case .development:
                return "Development"
            case .staging:
                return "Staging"
            case .production:
                return "Production"
            case .testing:
                return "Testing"
            }
        }

        public var requiresApproval: Bool {
            switch self {
            case .production:
                return true
            case .staging, .development, .testing:
                return false
            }
        }
    }

    /// Production deployment configuration.
    ///
    /// Uses production AWS account with strict security requirements and CloudFront distribution.
    public static let production = DeploymentConfiguration(
        environment: .production,
        accountId: "123456789012",  // Replace with actual production account ID
        region: "us-west-2",
        uploadConfiguration: UploadConfiguration(
            bucketName: "sagebrush-public",
            keyPrefix: "Brochure",
            region: "us-west-2",
            maxRetries: 5,
            defaultCacheDuration: 86400  // 24 hours for production
        ),
        profileName: "production",
        crossAccountRole: nil,
        tags: [
            "Environment": "Production",
            "Team": "Engineering",
            "Project": "Brochure-CLI",
        ],
        metadata: [
            "deployment-tier": "production",
            "backup-strategy": "enabled",
            "monitoring": "enhanced",
        ],
        requiresSecurityValidation: true,
        cloudFrontDistributionId: "E1234567890ABC"
    )

    /// Staging deployment configuration.
    ///
    /// Uses staging AWS account with moderate security requirements.
    public static let staging = DeploymentConfiguration(
        environment: .staging,
        accountId: "123456789012",  // Replace with actual staging account ID
        region: "us-west-2",
        uploadConfiguration: UploadConfiguration(
            bucketName: "sagebrush-staging",
            keyPrefix: "Brochure",
            region: "us-west-2",
            maxRetries: 3,
            defaultCacheDuration: 3600  // 1 hour for staging
        ),
        profileName: "staging",
        crossAccountRole: nil,
        tags: [
            "Environment": "Staging",
            "Team": "Engineering",
            "Project": "Brochure-CLI",
        ],
        metadata: [
            "deployment-tier": "staging",
            "backup-strategy": "basic",
        ],
        requiresSecurityValidation: false,
        cloudFrontDistributionId: "E0987654321DEF"
    )

    /// Development deployment configuration.
    ///
    /// Uses development AWS account with minimal security requirements for rapid iteration.
    public static let development = DeploymentConfiguration(
        environment: .development,
        accountId: "123456789012",  // Replace with actual development account ID
        region: "us-west-2",
        uploadConfiguration: UploadConfiguration(
            bucketName: "sagebrush-dev",
            keyPrefix: "Brochure",
            region: "us-west-2",
            maxRetries: 2,
            defaultCacheDuration: 300,  // 5 minutes for development
            htmlCacheControl: "no-cache",
            assetCacheControl: "public, max-age=3600"  // 1 hour for dev assets
        ),
        profileName: "development",
        crossAccountRole: nil,
        tags: [
            "Environment": "Development",
            "Team": "Engineering",
            "Project": "Brochure-CLI",
        ],
        metadata: [
            "deployment-tier": "development",
            "backup-strategy": "disabled",
        ],
        requiresSecurityValidation: false,
        cloudFrontDistributionId: nil
    )

    /// Testing deployment configuration.
    ///
    /// Uses testing AWS account for automated testing scenarios.
    public static let testing = DeploymentConfiguration(
        environment: .testing,
        accountId: "123456789012",  // Replace with actual testing account ID
        region: "us-east-1",  // Different region for testing isolation
        uploadConfiguration: UploadConfiguration(
            bucketName: "sagebrush-test",
            keyPrefix: "Brochure-Test",
            region: "us-east-1",
            maxRetries: 1,
            defaultCacheDuration: 60,  // 1 minute for testing
            htmlCacheControl: "no-cache",
            assetCacheControl: "no-cache"  // No caching for tests
        ),
        profileName: "testing",
        crossAccountRole: nil,
        tags: [
            "Environment": "Testing",
            "Team": "Engineering",
            "Project": "Brochure-CLI",
            "AutoDelete": "true",
        ],
        metadata: [
            "deployment-tier": "testing",
            "backup-strategy": "disabled",
            "lifecycle": "temporary",
        ],
        requiresSecurityValidation: false,
        cloudFrontDistributionId: nil
    )

    /// Creates a deployment configuration with the specified settings.
    ///
    /// - Parameters:
    ///   - environment: The deployment environment
    ///   - accountId: The AWS account ID
    ///   - region: The AWS region
    ///   - uploadConfiguration: Upload configuration settings
    ///   - profileName: AWS profile name to use
    ///   - crossAccountRole: Cross-account role ARN if needed
    ///   - tags: Tags to apply to resources
    ///   - metadata: Additional deployment metadata
    ///   - requiresSecurityValidation: Whether security validation is required
    ///   - cloudFrontDistributionId: CloudFront distribution ID for invalidation
    public init(
        environment: Environment,
        accountId: String,
        region: String = "us-west-2",
        uploadConfiguration: UploadConfiguration,
        profileName: String? = nil,
        crossAccountRole: String? = nil,
        tags: [String: String] = [:],
        metadata: [String: String] = [:],
        requiresSecurityValidation: Bool = false,
        cloudFrontDistributionId: String? = nil
    ) {
        self.environment = environment
        self.accountId = accountId
        self.region = region
        self.uploadConfiguration = uploadConfiguration
        self.profileName = profileName ?? environment.rawValue
        self.crossAccountRole = crossAccountRole
        self.tags = tags
        self.metadata = metadata
        self.requiresSecurityValidation = requiresSecurityValidation
        self.cloudFrontDistributionId = cloudFrontDistributionId
    }

    /// Returns a deployment configuration for the specified environment.
    ///
    /// - Parameter environment: The target environment
    /// - Returns: The deployment configuration for that environment
    public static func configuration(for environment: Environment) -> DeploymentConfiguration {
        switch environment {
        case .production:
            return .production
        case .staging:
            return .staging
        case .development:
            return .development
        case .testing:
            return .testing
        }
    }

    /// Returns a deployment configuration based on environment variable.
    ///
    /// Looks for `DEPLOYMENT_ENV` environment variable and returns the appropriate configuration.
    /// Falls back to development if not specified.
    ///
    /// - Returns: The deployment configuration based on environment
    public static func fromEnvironment() -> DeploymentConfiguration {
        let envString = ProcessInfo.processInfo.environment["DEPLOYMENT_ENV"] ?? "dev"
        let environment = Environment(rawValue: envString) ?? .development
        return configuration(for: environment)
    }

    /// Validates that the current AWS configuration can access this deployment's resources.
    ///
    /// - Parameter profileResolver: The profile resolver to use for validation
    /// - Returns: Whether the deployment configuration is accessible
    public func validateAccess(using profileResolver: ProfileResolver) -> Bool {
        // Resolve the profile for this deployment
        let resolution = profileResolver.resolveProfile(
            explicit: profileName,
            environment: ProcessInfo.processInfo.environment,
            configFile: nil,
            logger: nil
        )

        // Basic validation that we have some form of credentials
        return resolution.profileName != nil || resolution.source == .defaultChain
    }

    /// Validates that the current deployment configuration meets security requirements.
    ///
    /// - Parameter logger: Logger for detailed validation messages
    /// - Returns: Result with success or validation errors
    public func validateAccess(logger: Logger) -> Result<Void, ValidationError> {
        logger.debug("🔍 Validating deployment configuration access")

        // Validate account ID format
        if accountId.count != 12 || !CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: accountId)) {
            return .failure(.configurationError(message: "Invalid AWS account ID format: \(accountId)"))
        }

        // Validate region format
        let validRegions = [
            "us-east-1", "us-west-1", "us-west-2", "eu-west-1", "eu-central-1", "ap-southeast-1", "ap-northeast-1",
        ]
        if !validRegions.contains(region) {
            logger.warning("⚠️ Non-standard AWS region: \(region)")
        }

        // Production-specific validation
        if environment == .production {
            if profileName?.contains("prod") != true && profileName?.contains("production") != true {
                logger.warning("⚠️ Production environment using non-production profile: \(profileName ?? "default")")
            }

            if !requiresSecurityValidation {
                return .failure(.configurationError(message: "Production environment must require security validation"))
            }
        }

        // Validate CloudFront distribution ID format if present
        if let distributionId = cloudFrontDistributionId {
            if !distributionId.hasPrefix("E") || distributionId.count < 10 {
                return .failure(
                    .configurationError(message: "Invalid CloudFront distribution ID format: \(distributionId)")
                )
            }
        }

        logger.debug("✅ Deployment configuration validation complete")

        return .success(())
    }

    /// Returns the complete set of tags including environment-specific defaults.
    ///
    /// - Returns: Merged tags with environment defaults
    public var allTags: [String: String] {
        var allTags = tags
        allTags["Environment"] = environment.displayName
        allTags["Deployment-Tier"] = environment.rawValue
        allTags["Managed-By"] = "Brochure-CLI"
        return allTags
    }

    /// Returns a user-friendly description of this deployment configuration.
    public var description: String {
        let profile = profileName ?? "default"
        let account = String(accountId.suffix(4))  // Last 4 digits for security
        return "\(environment.displayName) (***\(account), \(profile)@\(region))"
    }
}

/// Configuration resolver for determining deployment settings based on various inputs.
public struct DeploymentConfigurationResolver {
    /// Initializes the deployment configuration resolver.
    public init() {}
    /// Resolves deployment configuration based on command line arguments, configuration files, and environment.
    ///
    /// - Parameters:
    ///   - explicitEnvironment: Explicitly specified environment via CLI
    ///   - profile: AWS profile specified
    ///   - environmentVariables: Current environment variables
    ///   - siteName: Optional site name for site-specific configuration
    ///   - logger: Optional logger for detailed resolution logging
    /// - Returns: The resolved deployment configuration
    public static func resolve(
        explicitEnvironment: String? = nil,
        profile: String? = nil,
        environmentVariables: [String: String] = ProcessInfo.processInfo.environment,
        siteName: String? = nil,
        logger: Logger? = nil
    ) -> DeploymentConfiguration {
        // Priority order:
        // 1. Configuration file settings
        // 2. Explicit environment from CLI
        // 3. Environment variable DEPLOYMENT_ENV
        // 4. Infer from AWS profile name
        // 5. Default to development

        logger?.debug("🔍 Starting deployment configuration resolution")
        logger?.debug("📋 Input parameters:")
        logger?.debug("  • Explicit environment: \(explicitEnvironment ?? "none")")
        logger?.debug("  • AWS profile: \(profile ?? "none")")
        logger?.debug("  • Site name: \(siteName ?? "none")")

        // First, try to load configuration from file
        logger?.debug("📂 Checking for configuration file...")
        if let configFile = try? BrochureConfigurationLoader.loadFromCurrentDirectory() {
            logger?.info("✅ Found configuration file with \(configFile.environments.count) environment(s)")
            logger?.debug("📝 Available environments: \(Array(configFile.environments.keys).joined(separator: ", "))")

            if let targetEnvironment = explicitEnvironment ?? environmentVariables["DEPLOYMENT_ENV"] {
                logger?.debug("🎯 Target environment: \(targetEnvironment)")

                // Use configuration file for this environment
                if let deploymentConfig = try? configFile.deploymentConfiguration(
                    for: targetEnvironment,
                    siteName: siteName
                ) {
                    logger?.info("✅ Using configuration from file for environment: \(targetEnvironment)")
                    logger?.debug("🏢 Account ID: ***\(String(deploymentConfig.accountId.suffix(4)))")
                    logger?.debug("🌍 Region: \(deploymentConfig.region)")
                    logger?.debug("🪣 Bucket: \(deploymentConfig.uploadConfiguration.bucketName)")

                    // Override profile if explicitly specified
                    if let explicitProfile = profile {
                        logger?.info("🔄 Overriding profile from file config with explicit profile: \(explicitProfile)")
                        return DeploymentConfiguration(
                            environment: deploymentConfig.environment,
                            accountId: deploymentConfig.accountId,
                            region: deploymentConfig.region,
                            uploadConfiguration: deploymentConfig.uploadConfiguration,
                            profileName: explicitProfile,
                            crossAccountRole: deploymentConfig.crossAccountRole,
                            tags: deploymentConfig.tags,
                            metadata: deploymentConfig.metadata,
                            requiresSecurityValidation: deploymentConfig.requiresSecurityValidation,
                            cloudFrontDistributionId: deploymentConfig.cloudFrontDistributionId
                        )
                    }

                    logger?.debug("🔐 Profile: \(deploymentConfig.profileName ?? "default")")
                    return deploymentConfig
                } else {
                    logger?.warning("⚠️ Environment '\(targetEnvironment)' not found in configuration file")
                }
            } else {
                logger?.debug("ℹ️ No target environment specified, using default from file")
            }
        } else {
            logger?.debug("📂 No configuration file found, using hardcoded configurations")
        }

        // If no configuration file or environment not found, fall back to hardcoded configurations
        logger?.debug("🔧 Using hardcoded configuration fallback")
        var environment: DeploymentConfiguration.Environment = .development
        var resolutionSource = "default"

        // 1. Check explicit environment
        if let explicit = explicitEnvironment,
            let env = DeploymentConfiguration.Environment(rawValue: explicit)
        {
            environment = env
            resolutionSource = "explicit CLI argument"
            logger?.info("🎯 Environment resolved from explicit CLI argument: \(explicit)")
        }
        // 2. Check environment variable
        else if let envVar = environmentVariables["DEPLOYMENT_ENV"],
            let env = DeploymentConfiguration.Environment(rawValue: envVar)
        {
            environment = env
            resolutionSource = "DEPLOYMENT_ENV environment variable"
            logger?.info("🌍 Environment resolved from DEPLOYMENT_ENV: \(envVar)")
        }
        // 3. Infer from profile name
        else if let profile = profile {
            let originalEnvironment = environment
            if profile.contains("prod") {
                environment = .production
                resolutionSource = "AWS profile name pattern (contains 'prod')"
            } else if profile.contains("stag") {
                environment = .staging
                resolutionSource = "AWS profile name pattern (contains 'stag')"
            } else if profile.contains("test") {
                environment = .testing
                resolutionSource = "AWS profile name pattern (contains 'test')"
            } else if profile.contains("dev") {
                environment = .development
                resolutionSource = "AWS profile name pattern (contains 'dev')"
            } else {
                resolutionSource = "default (profile name didn't match patterns)"
            }

            if environment != originalEnvironment {
                logger?.info("🔍 Environment inferred from AWS profile '\(profile)': \(environment.rawValue)")
            } else {
                logger?.debug("🔍 AWS profile '\(profile)' didn't match known patterns, using default")
            }
        } else {
            logger?.debug("🏠 No environment specified, using default: development")
        }

        // Get base configuration and customize profile if specified
        logger?.debug("📦 Creating deployment configuration for environment: \(environment.rawValue)")
        var config = DeploymentConfiguration.configuration(for: environment)

        logger?.info("✅ Deployment configuration resolved via: \(resolutionSource)")
        logger?.debug("📋 Configuration details:")
        logger?.debug("  • Environment: \(config.environment.displayName)")
        logger?.debug("  • Account ID: ***\(String(config.accountId.suffix(4)))")
        logger?.debug("  • Region: \(config.region)")
        logger?.debug("  • Bucket: \(config.uploadConfiguration.bucketName)")
        logger?.debug("  • Key Prefix: \(config.uploadConfiguration.keyPrefix)")
        logger?.debug("  • Default Profile: \(config.profileName ?? "default")")

        // Override profile if explicitly specified
        if let explicitProfile = profile {
            logger?.info("🔄 Overriding default profile with explicit profile: \(explicitProfile)")
            config = DeploymentConfiguration(
                environment: config.environment,
                accountId: config.accountId,
                region: config.region,
                uploadConfiguration: config.uploadConfiguration,
                profileName: explicitProfile,
                crossAccountRole: config.crossAccountRole,
                tags: config.tags,
                metadata: config.metadata,
                requiresSecurityValidation: config.requiresSecurityValidation,
                cloudFrontDistributionId: config.cloudFrontDistributionId
            )
            logger?.debug("🔐 Final profile: \(explicitProfile)")
        }

        // Log security requirements
        if config.requiresSecurityValidation {
            logger?.warning("🔒 Security validation required for \(config.environment.displayName) environment")
        }

        // Log cross-account setup if configured
        if let crossAccountRole = config.crossAccountRole {
            logger?.debug("🔄 Cross-account role configured: \(crossAccountRole)")
        }

        // Log CloudFront distribution if configured
        if let distributionId = config.cloudFrontDistributionId {
            logger?.debug("☁️ CloudFront distribution: \(distributionId)")
        }

        logger?.debug("✅ Deployment configuration resolution complete")
        return config
    }
}
