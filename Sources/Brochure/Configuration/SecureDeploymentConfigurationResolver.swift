import Foundation
import Logging

/// Enhanced deployment configuration resolver with secure credential integration.
///
/// `SecureDeploymentConfigurationResolver` extends the standard deployment configuration
/// system with secure credential management and enhanced security features:
///
/// ## Key Features
///
/// - **Secure Credential Integration**: Automatic keychain credential resolution
/// - **Security Validation**: Comprehensive access validation for deployment targets
/// - **Multi-Account Support**: Seamless cross-account deployment with role assumption
/// - **Audit Trail**: Detailed logging of all configuration and credential operations
/// - **Fallback Strategy**: Graceful degradation to traditional credential sources
///
/// ## Resolution Priority
///
/// 1. Secure keychain credentials (if available)
/// 2. Traditional AWS credential sources
/// 3. Environment-based configuration
/// 4. Default deployment settings
///
/// ## Usage Examples
///
/// ```swift
/// let resolver = SecureDeploymentConfigurationResolver(logger: logger)
///
/// // Resolve with secure credentials
/// let config = try await resolver.resolveSecureConfiguration(
///     explicitEnvironment: "production",
///     profile: "prod-deployment",
///     siteName: "NeonLaw"
/// )
///
/// print("Security Level: \(config.securityLevel)")
/// print("Credential Source: \(config.credentialSource)")
/// ```
public struct SecureDeploymentConfigurationResolver {
    private let secureResolver: SecureCredentialResolver
    private let traditionalResolver: DeploymentConfigurationResolver
    private let logger: Logger

    /// Initializes the secure deployment configuration resolver.
    ///
    /// - Parameters:
    ///   - secureResolver: Secure credential resolver for keychain integration
    ///   - traditionalResolver: Traditional deployment configuration resolver
    ///   - logger: Logger for audit trail and debugging
    public init(
        secureResolver: SecureCredentialResolver? = nil,
        traditionalResolver: DeploymentConfigurationResolver = DeploymentConfigurationResolver(),
        logger: Logger = Logger(label: "SecureDeploymentResolver")
    ) {
        self.secureResolver = secureResolver ?? SecureCredentialResolver(logger: logger)
        self.traditionalResolver = traditionalResolver
        self.logger = logger
    }

    /// Resolves deployment configuration with secure credential integration.
    ///
    /// - Parameters:
    ///   - explicitEnvironment: Explicit environment override (e.g., "prod", "staging")
    ///   - profile: AWS profile name for credential resolution
    ///   - environmentVariables: System environment variables
    ///   - siteName: Target site name for deployment
    ///   - enableKeychain: Whether to use secure keychain credentials (default: true)
    /// - Returns: Enhanced deployment configuration with security metadata
    public func resolveSecureConfiguration(
        explicitEnvironment: String? = nil,
        profile: String? = nil,
        environmentVariables: [String: String] = ProcessInfo.processInfo.environment,
        siteName: String,
        enableKeychain: Bool = true
    ) async throws -> SecureDeploymentConfiguration {
        logger.info("🔍 Resolving secure deployment configuration for site: \(siteName)")
        logger.debug("📋 Resolution parameters:")
        logger.debug("  • Explicit environment: \(explicitEnvironment ?? "none")")
        logger.debug("  • Profile: \(profile ?? "none")")
        logger.debug("  • Keychain enabled: \(enableKeychain)")
        logger.debug("  • Site name: \(siteName)")

        // Resolve base deployment configuration using traditional resolver
        let baseConfig = DeploymentConfigurationResolver.resolve(
            explicitEnvironment: explicitEnvironment,
            profile: profile,
            environmentVariables: environmentVariables,
            siteName: siteName,
            logger: logger
        )

        logger.debug("✅ Base configuration resolved: \(baseConfig.environment.displayName)")

        // Resolve secure credentials
        let credentialResolution = await secureResolver.resolveSecureCredentials(
            explicit: profile,
            environment: environmentVariables,
            enableKeychain: enableKeychain
        )

        logger.info("🔐 Credential resolution: \(credentialSourceDescription(credentialResolution.source))")
        logger.debug("🛡️ Security level: \(credentialResolution.securityLevel.rawValue)")

        // Create enhanced configuration
        let enhancedConfig = SecureDeploymentConfiguration(
            baseConfiguration: baseConfig,
            credentialResolution: credentialResolution,
            securityEnhancements: try await resolveSecurityEnhancements(
                baseConfig: baseConfig,
                credentialResolution: credentialResolution
            )
        )

        // Validate security requirements
        try await validateSecurityRequirements(configuration: enhancedConfig)

        logger.info("✅ Secure deployment configuration resolved successfully")
        logger.debug("📊 Final security level: \(enhancedConfig.securityLevel.rawValue)")

        return enhancedConfig
    }

    /// Validates that the configuration meets security requirements.
    ///
    /// - Parameter configuration: Configuration to validate
    /// - Throws: Security validation errors
    private func validateSecurityRequirements(configuration: SecureDeploymentConfiguration) async throws {
        logger.debug("🔍 Validating security requirements")

        // Check if production environment requires secure credentials
        if configuration.baseConfiguration.environment == .production
            && configuration.credentialResolution.securityLevel == .standard
        {
            logger.warning("⚠️ Production environment using non-secure credentials")
            logger.warning("💡 Consider using: swift run Brochure profiles store --profile production")
        }

        // Validate expired credentials
        if let credentials = configuration.credentialResolution.credentials,
            credentials.isPotentiallyExpired
        {
            logger.warning("⚠️ Credentials may be expired (age: \(String(format: "%.1f", credentials.age))s)")
            logger.warning("💡 Consider refreshing temporary credentials")
        }

        // Validate cross-account access if required
        if configuration.baseConfiguration.requiresSecurityValidation {
            logger.debug("🔍 Performing enhanced security validation")

            let validationResult: Result<Void, ValidationError> = configuration.baseConfiguration.validateAccess(
                logger: logger
            )
            switch validationResult {
            case .failure(let error):
                logger.error("❌ Security validation failed: \(error.localizedDescription)")
                throw SecureDeploymentError.securityValidationFailed([error])
            case .success:
                logger.debug("✅ Security validation passed")
            }
        }

        logger.debug("✅ Security requirements validation completed")
    }

    /// Resolves security enhancements based on configuration and credentials.
    ///
    /// - Parameters:
    ///   - baseConfig: Base deployment configuration
    ///   - credentialResolution: Resolved credential information
    /// - Returns: Security enhancement configuration
    private func resolveSecurityEnhancements(
        baseConfig: DeploymentConfiguration,
        credentialResolution: SecureCredentialResolution
    ) async throws -> SecurityEnhancements {
        logger.debug("🔍 Resolving security enhancements")

        var auditTags: [String: String] = [:]
        var securityMetadata: [String: String] = [:]

        // Add credential source information to audit tags
        switch credentialResolution.source {
        case .keychain:
            auditTags["credential_source"] = "keychain"
            auditTags["security_level"] = "high"
        case .traditional(let source):
            auditTags["credential_source"] = "traditional_\(source)"
            auditTags["security_level"] = "standard"
        }

        // Add environment metadata
        auditTags["environment"] = baseConfig.environment.rawValue
        auditTags["deployment_time"] = ISO8601DateFormatter().string(from: Date())
        auditTags["tool_version"] = "brochure-cli"

        // Security metadata
        if let credentials = credentialResolution.credentials {
            securityMetadata["credential_age"] = String(format: "%.0f", credentials.age)
            securityMetadata["is_temporary"] = String(credentials.isTemporary)

            if credentials.isTemporary {
                securityMetadata["potentially_expired"] = String(credentials.isPotentiallyExpired)
            }
        }

        securityMetadata["keychain_enabled"] = "true"
        securityMetadata["security_validation_required"] = String(baseConfig.requiresSecurityValidation)

        logger.debug("✅ Security enhancements resolved")

        return SecurityEnhancements(
            auditTags: auditTags,
            securityMetadata: securityMetadata,
            requiresEnhancedLogging: credentialResolution.securityLevel == .high,
            enableCredentialRotationHints: credentialResolution.credentials?.isTemporary == false
        )
    }

    /// Provides human-readable description of credential source.
    ///
    /// - Parameter source: Credential source to describe
    /// - Returns: Human-readable description
    private func credentialSourceDescription(_ source: SecureCredentialSource) -> String {
        switch source {
        case .keychain:
            return "Secure keychain storage"
        case .traditional(let profileSource):
            switch profileSource {
            case .explicit:
                return "Explicit profile (traditional)"
            case .environment:
                return "Environment variables"
            case .configFile:
                return "Configuration file"
            case .defaultChain:
                return "AWS default credential chain"
            }
        }
    }
}

// MARK: - Supporting Types

/// Enhanced deployment configuration with secure credential integration.
public struct SecureDeploymentConfiguration: Sendable {
    /// Base deployment configuration.
    public let baseConfiguration: DeploymentConfiguration

    /// Resolved credential information with security metadata.
    public let credentialResolution: SecureCredentialResolution

    /// Security enhancements and audit information.
    public let securityEnhancements: SecurityEnhancements

    /// Overall security level for this deployment.
    public var securityLevel: SecurityLevel {
        credentialResolution.securityLevel
    }

    /// Source of credentials for this deployment.
    public var credentialSource: SecureCredentialSource {
        credentialResolution.source
    }

    /// Whether this deployment uses secure keychain credentials.
    public var usesSecureCredentials: Bool {
        switch credentialSource {
        case .keychain:
            return true
        case .traditional:
            return false
        }
    }

    /// AWS profile name for this deployment.
    public var profileName: String? {
        credentialResolution.profileName ?? baseConfiguration.profileName
    }

    /// AWS region for this deployment.
    public var region: String {
        credentialResolution.region ?? baseConfiguration.region
    }

    /// Tags to apply to uploaded objects (including security audit tags).
    public var enhancedTags: [String: String] {
        var combinedTags = baseConfiguration.tags
        combinedTags.merge(securityEnhancements.auditTags) { _, new in new }
        return combinedTags
    }

    /// Enhanced metadata including security information.
    public var enhancedMetadata: [String: String] {
        var combinedMetadata = baseConfiguration.metadata
        combinedMetadata.merge(securityEnhancements.securityMetadata) { _, new in new }
        return combinedMetadata
    }
}

/// Security enhancements applied to deployment configuration.
public struct SecurityEnhancements: Sendable {
    /// Audit tags to apply to uploaded objects for tracking.
    public let auditTags: [String: String]

    /// Security metadata for logging and monitoring.
    public let securityMetadata: [String: String]

    /// Whether enhanced logging is required for this deployment.
    public let requiresEnhancedLogging: Bool

    /// Whether to provide credential rotation hints to the user.
    public let enableCredentialRotationHints: Bool
}

/// Errors specific to secure deployment configuration.
public enum SecureDeploymentError: Error, LocalizedError {
    case securityValidationFailed([Error])
    case unsupportedSecurityLevel(SecurityLevel)
    case credentialExpired(String)
    case keychainAccessDenied

    public var errorDescription: String? {
        switch self {
        case .securityValidationFailed(let errors):
            return "Security validation failed: \(errors.map { $0.localizedDescription }.joined(separator: ", "))"
        case .unsupportedSecurityLevel(let level):
            return "Unsupported security level for this deployment: \(level.rawValue)"
        case .credentialExpired(let profile):
            return "Credentials expired for profile: \(profile)"
        case .keychainAccessDenied:
            return "Access denied to keychain. Please unlock your keychain and try again."
        }
    }
}
