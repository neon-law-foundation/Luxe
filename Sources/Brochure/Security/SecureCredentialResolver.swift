import Foundation
import Logging

/// Secure credential resolution with keychain integration and fallback strategies.
///
/// `SecureCredentialResolver` extends the standard profile resolution system with secure
/// credential storage capabilities. It provides a layered approach to credential resolution:
///
/// 1. **Keychain Storage**: Primary secure storage for AWS credentials
/// 2. **Traditional Sources**: Fallback to standard AWS credential files and environment variables
/// 3. **Security Validation**: Comprehensive security checks and audit logging
/// 4. **Migration Support**: Automatic migration from insecure to secure storage
///
/// ## Resolution Priority
///
/// 1. Explicit profile from keychain (if available)
/// 2. Environment variables (AWS_PROFILE with keychain lookup)
/// 3. Configuration file with keychain integration
/// 4. Fallback to traditional AWS credential chain
/// 5. Default AWS credential provider
///
/// ## Security Features
///
/// - **Encrypted Storage**: All credentials encrypted using system keychain
/// - **Access Auditing**: Comprehensive logging of all credential access
/// - **Expiration Handling**: Automatic detection of expired temporary credentials
/// - **Migration Assistance**: Prompts to migrate insecure credentials to keychain
/// - **Fallback Strategy**: Graceful degradation to traditional credential sources
///
/// ## Usage Examples
///
/// ```swift
/// let resolver = SecureCredentialResolver(logger: logger)
///
/// // Resolve with keychain integration
/// let result = await resolver.resolveSecureCredentials(
///     explicit: "production",
///     environment: ProcessInfo.processInfo.environment,
///     enableKeychain: true
/// )
///
/// switch result.source {
/// case .keychain:
///     print("✅ Using secure keychain credentials")
/// case .traditional(let source):
///     print("⚠️ Using traditional credentials from \(source)")
/// }
/// ```
public actor SecureCredentialResolver {
    private let keychainManager: KeychainManager
    private let traditionalResolver: ProfileResolverProtocol
    private let logger: Logger

    /// Initializes the secure credential resolver.
    ///
    /// - Parameters:
    ///   - keychainManager: Keychain manager for secure credential storage
    ///   - traditionalResolver: Fallback resolver for traditional credential sources
    ///   - logger: Logger for security audit trail
    public init(
        keychainManager: KeychainManager? = nil,
        traditionalResolver: ProfileResolverProtocol = ProfileResolver(),
        logger: Logger = Logger(label: "SecureCredentialResolver")
    ) {
        self.keychainManager = keychainManager ?? KeychainManager(logger: logger)
        self.traditionalResolver = traditionalResolver
        self.logger = logger
        logger.debug("🔐 SecureCredentialResolver initialized with keychain integration")
    }

    /// Resolves credentials using secure storage with traditional fallback.
    ///
    /// - Parameters:
    ///   - explicit: Explicit profile name from CLI arguments
    ///   - environment: Environment variables dictionary
    ///   - configFile: Optional configuration file URL
    ///   - enableKeychain: Whether to use keychain storage (default: true)
    /// - Returns: Secure credential resolution result
    public func resolveSecureCredentials(
        explicit: String?,
        environment: [String: String],
        configFile: URL? = nil,
        enableKeychain: Bool = true
    ) async -> SecureCredentialResolution {
        logger.info("🔍 Starting secure credential resolution")
        logger.debug("📋 Resolution parameters:")
        logger.debug("  • Explicit profile: \(explicit ?? "none")")
        logger.debug("  • Keychain enabled: \(enableKeychain)")
        logger.debug("  • Environment AWS_PROFILE: \(environment["AWS_PROFILE"] ?? "none")")

        if enableKeychain {
            // Try keychain resolution first
            if let keychainResult = await resolveFromKeychain(
                explicit: explicit,
                environment: environment
            ) {
                return keychainResult
            }
        }

        // Fall back to traditional resolution
        let traditionalResult = traditionalResolver.resolveProfile(
            explicit: explicit,
            environment: environment,
            configFile: configFile,
            logger: logger
        )

        logger.info("🔄 Using traditional credential resolution: \(traditionalResult.source)")

        // Check if we should suggest keychain migration
        if enableKeychain, let profileName = traditionalResult.profileName {
            await suggestKeychainMigration(profileName: profileName)
        }

        return SecureCredentialResolution(
            profileName: traditionalResult.profileName,
            source: .traditional(traditionalResult.source),
            region: traditionalResult.region,
            credentials: nil,
            securityLevel: .standard
        )
    }

    /// Stores AWS credentials securely in the keychain.
    ///
    /// - Parameters:
    ///   - profile: AWS profile name
    ///   - accessKeyId: AWS access key ID
    ///   - secretAccessKey: AWS secret access key
    ///   - sessionToken: Optional session token for temporary credentials
    ///   - region: Optional default region
    /// - Throws: `KeychainError` if storage fails
    public func storeSecureCredentials(
        profile: String,
        accessKeyId: String,
        secretAccessKey: String,
        sessionToken: String? = nil,
        region: String? = nil
    ) async throws {
        logger.info("🔐 Storing secure credentials for profile: \(profile)")

        try await keychainManager.storeAWSCredentials(
            profile: profile,
            accessKeyId: accessKeyId,
            secretAccessKey: secretAccessKey,
            sessionToken: sessionToken,
            region: region
        )

        logger.info("✅ Successfully stored secure credentials for profile: \(profile)")

        // Store metadata about security level
        try await keychainManager.storeConfiguration(
            key: "profile.\(profile).security_level",
            value: sessionToken != nil ? "temporary" : "permanent"
        )

        try await keychainManager.storeConfiguration(
            key: "profile.\(profile).created_at",
            value: ISO8601DateFormatter().string(from: Date())
        )
    }

    /// Retrieves secure credentials from the keychain.
    ///
    /// - Parameter profile: AWS profile name
    /// - Returns: Secure credentials if found
    /// - Throws: `KeychainError` if retrieval fails
    public func getSecureCredentials(profile: String) async throws -> AWSCredentials {
        logger.debug("🔍 Retrieving secure credentials for profile: \(profile)")

        let credentials = try await keychainManager.getAWSCredentials(profile: profile)

        // Check for expired temporary credentials
        if credentials.isPotentiallyExpired {
            logger.warning("⚠️ Temporary credentials may be expired for profile: \(profile)")
            logger.warning("⚠️ Credential age: \(String(format: "%.1f", credentials.age))s")
        }

        return credentials
    }

    /// Removes secure credentials from the keychain.
    ///
    /// - Parameter profile: AWS profile name
    /// - Throws: `KeychainError` if removal fails
    public func removeSecureCredentials(profile: String) async throws {
        logger.info("🗑️ Removing secure credentials for profile: \(profile)")

        try await keychainManager.removeAWSCredentials(profile: profile)

        // Clean up metadata
        try? await keychainManager.removeConfiguration(key: "profile.\(profile).security_level")
        try? await keychainManager.removeConfiguration(key: "profile.\(profile).created_at")

        logger.info("✅ Successfully removed secure credentials for profile: \(profile)")
    }

    /// Lists all secure profiles available in the keychain.
    ///
    /// - Returns: Array of secure profile names with metadata
    public func listSecureProfiles() async throws -> [SecureProfileInfo] {
        logger.debug("📋 Listing all secure profiles")

        let profileNames = try await keychainManager.listAWSProfiles()
        var profiles: [SecureProfileInfo] = []

        for profileName in profileNames {
            do {
                let credentials = try await keychainManager.getAWSCredentials(profile: profileName)
                let securityLevel = try? await keychainManager.getConfiguration(
                    key: "profile.\(profileName).security_level"
                )
                let createdAtString = try? await keychainManager.getConfiguration(
                    key: "profile.\(profileName).created_at"
                )

                let createdAt =
                    createdAtString
                    .flatMap { ISO8601DateFormatter().date(from: $0) }
                    ?? credentials.storedAt

                let profile = SecureProfileInfo(
                    name: profileName,
                    region: credentials.region,
                    isTemporary: credentials.isTemporary,
                    securityLevel: securityLevel ?? "unknown",
                    createdAt: createdAt,
                    lastAccessed: credentials.storedAt,
                    isPotentiallyExpired: credentials.isPotentiallyExpired
                )

                profiles.append(profile)
            } catch {
                logger.warning("⚠️ Failed to load metadata for profile \(profileName): \(error)")
            }
        }

        logger.info("📋 Found \(profiles.count) secure profiles")
        return profiles.sorted { $0.name < $1.name }
    }

    /// Migrates traditional credentials to secure keychain storage.
    ///
    /// - Parameters:
    ///   - profile: Profile name to migrate
    ///   - accessKeyId: AWS access key ID from traditional source
    ///   - secretAccessKey: AWS secret access key from traditional source
    ///   - region: Optional default region
    /// - Throws: `KeychainError` if migration fails
    public func migrateToSecureStorage(
        profile: String,
        accessKeyId: String,
        secretAccessKey: String,
        region: String? = nil
    ) async throws {
        logger.info("🔄 Migrating profile to secure storage: \(profile)")

        try await storeSecureCredentials(
            profile: profile,
            accessKeyId: accessKeyId,
            secretAccessKey: secretAccessKey,
            region: region
        )

        // Mark as migrated
        try await keychainManager.storeConfiguration(
            key: "profile.\(profile).migrated_at",
            value: ISO8601DateFormatter().string(from: Date())
        )

        logger.info("✅ Successfully migrated profile to secure storage: \(profile)")
    }

    // MARK: - Private Implementation

    private func resolveFromKeychain(
        explicit: String?,
        environment: [String: String]
    ) async -> SecureCredentialResolution? {
        logger.debug("🔍 Attempting keychain credential resolution")

        // Determine profile name using standard priority
        let profileName: String? = explicit ?? environment["AWS_PROFILE"]

        guard let profileName = profileName else {
            logger.debug("🔍 No specific profile requested, skipping keychain lookup")
            return nil
        }

        do {
            let credentials = try await keychainManager.getAWSCredentials(profile: profileName)

            logger.info("✅ Found secure credentials in keychain for profile: \(profileName)")

            let securityLevel: SecurityLevel = credentials.isTemporary ? .enhanced : .high

            if credentials.isPotentiallyExpired {
                logger.warning("⚠️ Keychain credentials may be expired: \(profileName)")
            }

            return SecureCredentialResolution(
                profileName: profileName,
                source: .keychain,
                region: credentials.region ?? environment["AWS_REGION"],
                credentials: credentials,
                securityLevel: securityLevel
            )

        } catch KeychainError.itemNotFound {
            logger.debug("🔍 Profile not found in keychain: \(profileName)")
            return nil
        } catch {
            logger.warning("⚠️ Failed to retrieve keychain credentials for \(profileName): \(error)")
            return nil
        }
    }

    private func suggestKeychainMigration(profileName: String) async {
        // Check if we've already suggested migration recently
        let suggestionKey = "migration_suggested.\(profileName)"

        do {
            let lastSuggestion = try await keychainManager.getConfiguration(key: suggestionKey)
            if let lastSuggestion = lastSuggestion,
                let date = ISO8601DateFormatter().date(from: lastSuggestion),
                Date().timeIntervalSince(date) < 86400
            {  // 24 hours
                return  // Already suggested recently
            }
        } catch {
            // No previous suggestion recorded
        }

        logger.info("💡 Consider migrating profile '\(profileName)' to secure keychain storage:")
        logger.info("💡 Run: swift run Brochure profiles migrate --profile \(profileName)")

        // Record that we suggested migration
        try? await keychainManager.storeConfiguration(
            key: suggestionKey,
            value: ISO8601DateFormatter().string(from: Date())
        )
    }
}

// MARK: - Supporting Types

/// Result of secure credential resolution with security metadata.
public struct SecureCredentialResolution: Sendable {
    public let profileName: String?
    public let source: SecureCredentialSource
    public let region: String?
    public let credentials: AWSCredentials?
    public let securityLevel: SecurityLevel

    public init(
        profileName: String?,
        source: SecureCredentialSource,
        region: String?,
        credentials: AWSCredentials?,
        securityLevel: SecurityLevel
    ) {
        self.profileName = profileName
        self.source = source
        self.region = region
        self.credentials = credentials
        self.securityLevel = securityLevel
    }
}

/// Source of secure credential resolution.
public enum SecureCredentialSource: Sendable {
    case keychain
    case traditional(ProfileSource)
}

/// Security level of resolved credentials.
public enum SecurityLevel: String, Sendable {
    case high = "high"  // Permanent credentials in keychain
    case enhanced = "enhanced"  // Temporary credentials in keychain
    case standard = "standard"  // Traditional credential sources
    case low = "low"  // Environment variables or unencrypted files
}

/// Information about a secure profile stored in the keychain.
public struct SecureProfileInfo: Sendable {
    public let name: String
    public let region: String?
    public let isTemporary: Bool
    public let securityLevel: String
    public let createdAt: Date
    public let lastAccessed: Date
    public let isPotentiallyExpired: Bool

    /// Human-readable security status.
    public var securityStatus: String {
        if isPotentiallyExpired {
            return "⚠️ Potentially Expired"
        } else if isTemporary {
            return "🔑 Temporary Credentials"
        } else {
            return "🔐 Secure Storage"
        }
    }

    /// Age of the profile in human-readable format.
    public var ageDescription: String {
        let interval = Date().timeIntervalSince(createdAt)
        let days = Int(interval / 86400)

        if days == 0 {
            return "Created today"
        } else if days == 1 {
            return "Created yesterday"
        } else if days < 7 {
            return "Created \(days) days ago"
        } else if days < 30 {
            return "Created \(days / 7) weeks ago"
        } else {
            return "Created \(days / 30) months ago"
        }
    }
}
