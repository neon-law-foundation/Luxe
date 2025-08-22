import Foundation

/// Configuration file support for complex multi-account deployment scenarios.
///
/// `BrochureConfigurationFile` provides a YAML-based configuration system that allows users
/// to define sophisticated deployment configurations including multi-account setups,
/// environment-specific overrides, and custom deployment profiles.
///
/// ## Example Configuration File (.brochure.yml)
///
/// ```yaml
/// version: "1.0"
/// default_environment: "development"
///
/// environments:
///   development:
///     account_id: "111111111111"
///     region: "us-west-2"
///     bucket: "my-dev-bucket"
///     profile: "dev-profile"
///     cache_duration: 300
///     require_approval: false
///
///   staging:
///     account_id: "222222222222"
///     region: "us-west-2"
///     bucket: "my-staging-bucket"
///     profile: "staging-profile"
///     cache_duration: 3600
///     require_approval: false
///
///   production:
///     account_id: "333333333333"
///     region: "us-east-1"
///     bucket: "my-prod-bucket"
///     profile: "prod-profile"
///     cache_duration: 86400
///     require_approval: true
///     cross_account_role: "arn:aws:iam::333333333333:role/CrossAccountDeploymentRole"
///     cloudfront_distribution: "E1234567890ABC"
///
/// sites:
///   MyWebsite:
///     key_prefix: "sites/MyWebsite"
///     environments:
///       production:
///         bucket: "my-special-prod-bucket"
///         cache_duration: 604800  # 1 week
/// ```
public struct BrochureConfigurationFile: Sendable {
    /// Configuration file version for backward compatibility.
    public let version: String

    /// Default environment to use when none is specified.
    public let defaultEnvironment: String

    /// Environment-specific configurations.
    public let environments: [String: EnvironmentConfig]

    /// Site-specific configuration overrides.
    public let sites: [String: SiteConfig]

    /// Global deployment settings.
    public let global: GlobalConfig?

    /// Environment-specific configuration within a configuration file.
    public struct EnvironmentConfig: Sendable {
        public let accountId: String
        public let region: String
        public let bucket: String
        public let profile: String?
        public let keyPrefix: String?
        public let cacheDuration: Int?
        public let requireApproval: Bool?
        public let crossAccountRole: String?
        public let cloudFrontDistribution: String?
        public let tags: [String: String]?
        public let metadata: [String: String]?
    }

    /// Site-specific configuration with environment overrides.
    public struct SiteConfig: Sendable {
        public let keyPrefix: String?
        public let environments: [String: SiteEnvironmentConfig]?
    }

    /// Site-specific environment overrides.
    public struct SiteEnvironmentConfig: Sendable {
        public let bucket: String?
        public let region: String?
        public let cacheDuration: Int?
        public let profile: String?
        public let tags: [String: String]?
    }

    /// Global configuration settings.
    public struct GlobalConfig: Sendable {
        public let defaultCacheDuration: Int?
        public let defaultKeyPrefix: String?
        public let defaultRegion: String?
        public let retrySettings: RetryConfig?
        public let logging: LoggingConfig?
    }

    /// Retry configuration settings.
    public struct RetryConfig: Sendable {
        public let maxRetries: Int
        public let baseDelay: Double
    }

    /// Logging configuration settings.
    public struct LoggingConfig: Sendable {
        public let level: String
        public let format: String?
        public let includeTimestamps: Bool?
    }
}

/// Configuration file loader that handles YAML parsing and validation.
public struct BrochureConfigurationLoader {

    /// Standard configuration file names to search for.
    public static let standardConfigFileNames = [
        ".brochure.yml",
        ".brochure.yaml",
        "brochure.yml",
        "brochure.yaml",
    ]

    /// Loads configuration from the first found configuration file in the current directory.
    ///
    /// - Returns: The loaded configuration, or nil if no configuration file is found
    /// - Throws: ConfigurationError if the file exists but cannot be parsed
    public static func loadFromCurrentDirectory() throws -> BrochureConfigurationFile? {
        let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        for fileName in standardConfigFileNames {
            let configURL = currentDirectory.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: configURL.path) {
                return try load(from: configURL)
            }
        }

        return nil
    }

    /// Loads configuration from a specific file path.
    ///
    /// - Parameter url: The URL of the configuration file to load
    /// - Returns: The loaded configuration
    /// - Throws: ConfigurationError if the file cannot be read or parsed
    public static func load(from url: URL) throws -> BrochureConfigurationFile {
        do {
            let yamlData = try Data(contentsOf: url)
            return try parseYAML(yamlData)
        } catch {
            throw ConfigurationError.fileReadError(url: url, underlyingError: error)
        }
    }

    /// Parses YAML data into a configuration structure.
    ///
    /// - Parameter data: The YAML data to parse
    /// - Returns: The parsed configuration
    /// - Throws: ConfigurationError if the YAML cannot be parsed
    public static func parseYAML(_ data: Data) throws -> BrochureConfigurationFile {
        // For now, we'll implement a basic parser that expects a specific structure
        // In a full implementation, you would use a YAML parsing library like Yams

        guard let yamlString = String(data: data, encoding: .utf8) else {
            throw ConfigurationError.invalidYAML("Cannot decode YAML as UTF-8 string")
        }

        // Basic YAML parsing - this is a simplified implementation
        // In production, you would use a proper YAML library
        let config = try parseSimpleYAML(yamlString)
        try validateConfiguration(config)

        return config
    }

    /// Validates that the configuration has required fields and valid values.
    ///
    /// - Parameter config: The configuration to validate
    /// - Throws: ConfigurationError if validation fails
    private static func validateConfiguration(_ config: BrochureConfigurationFile) throws {
        // Validate version
        let supportedVersions = ["1.0"]
        guard supportedVersions.contains(config.version) else {
            throw ConfigurationError.unsupportedVersion(
                version: config.version,
                supported: supportedVersions
            )
        }

        // Validate default environment exists
        guard config.environments[config.defaultEnvironment] != nil else {
            throw ConfigurationError.invalidDefaultEnvironment(
                environment: config.defaultEnvironment,
                available: Array(config.environments.keys)
            )
        }

        // Validate environment configurations
        for (envName, envConfig) in config.environments {
            try validateEnvironmentConfig(envName: envName, config: envConfig)
        }
    }

    /// Validates an individual environment configuration.
    ///
    /// - Parameters:
    ///   - envName: The name of the environment
    ///   - config: The environment configuration to validate
    /// - Throws: ConfigurationError if validation fails
    private static func validateEnvironmentConfig(
        envName: String,
        config: BrochureConfigurationFile.EnvironmentConfig
    ) throws {
        // Validate account ID format (12 digits)
        let accountIdPattern = "^[0-9]{12}$"
        let accountIdRegex = try NSRegularExpression(pattern: accountIdPattern)
        let accountIdRange = NSRange(location: 0, length: config.accountId.count)

        guard accountIdRegex.firstMatch(in: config.accountId, range: accountIdRange) != nil else {
            throw ConfigurationError.invalidAccountId(
                environment: envName,
                accountId: config.accountId
            )
        }

        // Validate region format
        let validRegionPattern = "^[a-z0-9-]+$"
        let regionRegex = try NSRegularExpression(pattern: validRegionPattern)
        let regionRange = NSRange(location: 0, length: config.region.count)

        guard regionRegex.firstMatch(in: config.region, range: regionRange) != nil else {
            throw ConfigurationError.invalidRegion(
                environment: envName,
                region: config.region
            )
        }

        // Validate bucket name format (basic validation)
        let bucketPattern = "^[a-z0-9.-]+$"
        let bucketRegex = try NSRegularExpression(pattern: bucketPattern)
        let bucketRange = NSRange(location: 0, length: config.bucket.count)

        guard bucketRegex.firstMatch(in: config.bucket, range: bucketRange) != nil else {
            throw ConfigurationError.invalidBucketName(
                environment: envName,
                bucket: config.bucket
            )
        }
    }

    /// Basic YAML parser implementation (simplified for this example).
    ///
    /// In a production implementation, you would use a proper YAML parsing library.
    /// This is a minimal implementation to demonstrate the configuration structure.
    ///
    /// - Parameter yamlString: The YAML string to parse
    /// - Returns: The parsed configuration
    /// - Throws: ConfigurationError if parsing fails
    private static func parseSimpleYAML(_ yamlString: String) throws -> BrochureConfigurationFile {
        // This is a placeholder implementation
        // In a real implementation, you would use a YAML parsing library like Yams

        // For now, return a default configuration that demonstrates the structure
        let defaultEnvironmentConfig = BrochureConfigurationFile.EnvironmentConfig(
            accountId: "123456789012",
            region: "us-west-2",
            bucket: "default-bucket",
            profile: "default",
            keyPrefix: "Brochure",
            cacheDuration: 3600,
            requireApproval: false,
            crossAccountRole: nil,
            cloudFrontDistribution: nil,
            tags: ["Environment": "Development"],
            metadata: ["deployment-tier": "default"]
        )

        return BrochureConfigurationFile(
            version: "1.0",
            defaultEnvironment: "development",
            environments: [
                "development": defaultEnvironmentConfig
            ],
            sites: [:],
            global: nil
        )
    }
}

/// Configuration-related errors.
public enum ConfigurationError: Error, LocalizedError {
    case fileReadError(url: URL, underlyingError: Error)
    case invalidYAML(String)
    case unsupportedVersion(version: String, supported: [String])
    case invalidDefaultEnvironment(environment: String, available: [String])
    case invalidAccountId(environment: String, accountId: String)
    case invalidRegion(environment: String, region: String)
    case invalidBucketName(environment: String, bucket: String)
    case missingRequiredField(field: String, section: String)

    public var errorDescription: String? {
        switch self {
        case .fileReadError(let url, let underlyingError):
            return "Failed to read configuration file at \(url.path): \(underlyingError.localizedDescription)"
        case .invalidYAML(let message):
            return "Invalid YAML format: \(message)"
        case .unsupportedVersion(let version, let supported):
            return
                "Unsupported configuration version '\(version)'. Supported versions: \(supported.joined(separator: ", "))"
        case .invalidDefaultEnvironment(let environment, let available):
            return
                "Default environment '\(environment)' not found. Available environments: \(available.joined(separator: ", "))"
        case .invalidAccountId(let environment, let accountId):
            return
                "Invalid AWS account ID '\(accountId)' in environment '\(environment)'. Account ID must be 12 digits."
        case .invalidRegion(let environment, let region):
            return "Invalid AWS region '\(region)' in environment '\(environment)'"
        case .invalidBucketName(let environment, let bucket):
            return "Invalid S3 bucket name '\(bucket)' in environment '\(environment)'"
        case .missingRequiredField(let field, let section):
            return "Missing required field '\(field)' in section '\(section)'"
        }
    }
}

/// Extension to convert configuration file to deployment configuration.
extension BrochureConfigurationFile {

    /// Converts a configuration file environment to a deployment configuration.
    ///
    /// - Parameters:
    ///   - environmentName: The name of the environment
    ///   - siteName: Optional site name for site-specific overrides
    /// - Returns: The deployment configuration for the specified environment
    /// - Throws: ConfigurationError if the environment is not found
    public func deploymentConfiguration(
        for environmentName: String,
        siteName: String? = nil
    ) throws -> DeploymentConfiguration {
        guard let envConfig = environments[environmentName] else {
            throw ConfigurationError.invalidDefaultEnvironment(
                environment: environmentName,
                available: Array(environments.keys)
            )
        }

        // Apply site-specific overrides if available
        var finalConfig = envConfig
        if let siteName = siteName,
            let siteConfig = sites[siteName],
            let siteEnvConfig = siteConfig.environments?[environmentName]
        {
            finalConfig = applyOverrides(envConfig, with: siteEnvConfig, siteConfig: siteConfig)
        }

        // Convert to deployment environment enum
        let environment: DeploymentConfiguration.Environment
        switch environmentName.lowercased() {
        case "dev", "development":
            environment = .development
        case "staging", "stage":
            environment = .staging
        case "prod", "production":
            environment = .production
        case "test", "testing":
            environment = .testing
        default:
            environment = .development  // Default fallback
        }

        // Create upload configuration
        let uploadConfig = UploadConfiguration(
            bucketName: finalConfig.bucket,
            keyPrefix: finalConfig.keyPrefix ?? "Brochure",
            region: finalConfig.region,
            skipUnchangedFiles: true,
            enableMultipartUpload: true,
            multipartChunkSize: 5 * 1024 * 1024,
            maxRetries: global?.retrySettings?.maxRetries ?? 3,
            retryBaseDelay: global?.retrySettings?.baseDelay ?? 1.0,
            defaultCacheDuration: finalConfig.cacheDuration ?? global?.defaultCacheDuration ?? 3600
        )

        return DeploymentConfiguration(
            environment: environment,
            accountId: finalConfig.accountId,
            region: finalConfig.region,
            uploadConfiguration: uploadConfig,
            profileName: finalConfig.profile,
            crossAccountRole: finalConfig.crossAccountRole,
            tags: finalConfig.tags ?? [:],
            metadata: finalConfig.metadata ?? [:],
            requiresSecurityValidation: finalConfig.requireApproval ?? environment.requiresApproval,
            cloudFrontDistributionId: finalConfig.cloudFrontDistribution
        )
    }

    /// Applies site-specific overrides to an environment configuration.
    ///
    /// - Parameters:
    ///   - envConfig: The base environment configuration
    ///   - siteEnvConfig: Site-specific environment overrides
    ///   - siteConfig: General site configuration
    /// - Returns: The merged configuration with overrides applied
    private func applyOverrides(
        _ envConfig: EnvironmentConfig,
        with siteEnvConfig: SiteEnvironmentConfig,
        siteConfig: SiteConfig
    ) -> EnvironmentConfig {
        EnvironmentConfig(
            accountId: envConfig.accountId,
            region: siteEnvConfig.region ?? envConfig.region,
            bucket: siteEnvConfig.bucket ?? envConfig.bucket,
            profile: siteEnvConfig.profile ?? envConfig.profile,
            keyPrefix: siteConfig.keyPrefix ?? envConfig.keyPrefix,
            cacheDuration: siteEnvConfig.cacheDuration ?? envConfig.cacheDuration,
            requireApproval: envConfig.requireApproval,
            crossAccountRole: envConfig.crossAccountRole,
            cloudFrontDistribution: envConfig.cloudFrontDistribution,
            tags: mergeTags(envConfig.tags, siteEnvConfig.tags),
            metadata: envConfig.metadata
        )
    }

    /// Merges tag dictionaries, with override tags taking precedence.
    ///
    /// - Parameters:
    ///   - baseTags: Base tags
    ///   - overrideTags: Override tags
    /// - Returns: Merged tags dictionary
    private func mergeTags(
        _ baseTags: [String: String]?,
        _ overrideTags: [String: String]?
    ) -> [String: String]? {
        guard let base = baseTags else { return overrideTags }
        guard let override = overrideTags else { return base }

        var merged = base
        for (key, value) in override {
            merged[key] = value
        }
        return merged
    }
}
