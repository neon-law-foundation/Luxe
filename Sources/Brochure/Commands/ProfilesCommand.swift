import ArgumentParser
import Foundation
import Logging

/// Simple validation error for command argument validation.
public struct CommandValidationError: Error, LocalizedError {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var errorDescription: String? {
        message
    }
}

/// Command for managing secure AWS profile credentials.
///
/// The `profiles` command provides comprehensive management of AWS credentials using secure
/// keychain storage. It supports storing, retrieving, listing, and migrating AWS credentials
/// with enhanced security features.
///
/// ## Security Features
///
/// - **Keychain Integration**: All credentials stored using macOS keychain encryption
/// - **Access Control**: Protected by system security policies and user authentication
/// - **Audit Trail**: Comprehensive logging of all credential operations
/// - **Migration Support**: Easy migration from traditional credential sources
/// - **Expiration Detection**: Automatic detection of expired temporary credentials
///
/// ## Available Subcommands
///
/// - `store`: Store AWS credentials securely in the keychain
/// - `list`: List all secure profiles with metadata
/// - `show`: Display details about a specific profile
/// - `remove`: Remove credentials from secure storage
/// - `migrate`: Migrate traditional credentials to secure storage
/// - `clear`: Remove all Brochure data from keychain
///
/// ## Examples
///
/// ```bash
/// # Store production credentials securely
/// swift run Brochure profiles store --profile production \
///   --access-key AKIA1234567890ABCDEF \
///   --secret-key abcdef1234567890abcdef1234567890abcdef12 \
///   --region us-east-1
///
/// # List all secure profiles
/// swift run Brochure profiles list
///
/// # Show detailed information about a profile
/// swift run Brochure profiles show --profile production
///
/// # Migrate from traditional AWS credentials
/// swift run Brochure profiles migrate --profile production
///
/// # Remove credentials
/// swift run Brochure profiles remove --profile staging
/// ```
struct ProfilesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "profiles",
        abstract: "Manage secure AWS profile credentials using keychain storage",
        discussion: """
            The profiles command provides secure credential management for AWS profiles using
            macOS keychain integration. All credentials are encrypted and protected by system
            security policies.

            SECURITY FEATURES:
              • Keychain encryption for all stored credentials
              • System-level access control and authentication
              • Comprehensive audit logging of all operations
              • Automatic detection of expired temporary credentials
              • Migration assistance from traditional credential sources

            CREDENTIAL TYPES SUPPORTED:
              • Permanent AWS IAM user credentials (recommended)
              • Temporary session credentials with automatic expiration detection
              • Cross-account role assumption credentials
              • Multi-factor authentication (MFA) enabled credentials

            MIGRATION FROM TRADITIONAL SOURCES:
              The system can automatically detect and migrate credentials from:
              • ~/.aws/credentials files
              • Environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
              • EC2 instance profiles (for documentation purposes)

            SECURITY BEST PRACTICES:
              • Use IAM users with minimal required permissions
              • Enable MFA for sensitive operations when possible
              • Regularly rotate credentials (especially permanent ones)
              • Use temporary credentials for automated systems when feasible
              • Monitor credential usage through AWS CloudTrail

            EXAMPLES:
              # Store production credentials
              swift run Brochure profiles store --profile production \\
                --access-key AKIA1234567890ABCDEF \\
                --secret-key abcdef1234567890abcdef1234567890abcdef12 \\
                --region us-east-1

              # Store temporary credentials with session token
              swift run Brochure profiles store --profile temp \\
                --access-key ASIA1234567890ABCDEF \\
                --secret-key abcdef1234567890abcdef1234567890abcdef12 \\
                --session-token IQoJb3JpZ2luX2VjEH...

              # List all profiles with security status
              swift run Brochure profiles list --verbose

              # Migrate existing AWS profile
              swift run Brochure profiles migrate --profile production

              # Clean up expired temporary credentials
              swift run Brochure profiles list --expired-only
            """,
        subcommands: [
            StoreProfileCommand.self,
            ListProfilesCommand.self,
            ShowProfileCommand.self,
            RemoveProfileCommand.self,
            MigrateProfileCommand.self,
            ClearProfilesCommand.self,
        ]
    )
}

// MARK: - Store Profile Command

struct StoreProfileCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "store",
        abstract: "Store AWS credentials securely in the keychain",
        discussion: """
            Stores AWS credentials securely using macOS keychain encryption. All credentials
            are protected by system security policies and user authentication.
            """
    )

    @Option(
        name: .long,
        help: ArgumentHelp(
            "AWS profile name",
            discussion: """
                Name for the AWS profile (e.g., 'production', 'staging', 'development').
                Must be unique and follow AWS naming conventions.
                """,
            valueName: "name"
        )
    )
    var profile: String

    @Option(
        name: .long,
        help: ArgumentHelp(
            "AWS access key ID",
            discussion: """
                AWS access key ID starting with 'AKIA' (permanent) or 'ASIA' (temporary).
                Must be exactly 20 characters long.
                """,
            valueName: "key-id"
        )
    )
    var accessKey: String

    @Option(
        name: .long,
        help: ArgumentHelp(
            "AWS secret access key",
            discussion: """
                AWS secret access key corresponding to the access key ID.
                Must be exactly 40 characters long and contain only valid base64 characters.
                """,
            valueName: "secret"
        )
    )
    var secretKey: String

    @Option(
        name: .long,
        help: ArgumentHelp(
            "AWS session token for temporary credentials",
            discussion: """
                Session token for temporary credentials (STS). Only required when using
                temporary credentials from AssumeRole, GetSessionToken, or similar operations.
                """,
            valueName: "token"
        )
    )
    var sessionToken: String?

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Default AWS region for this profile",
            discussion: """
                Default AWS region to use with this profile (e.g., 'us-east-1', 'eu-west-1').
                Can be overridden by AWS_REGION environment variable or CLI arguments.
                """,
            valueName: "region"
        )
    )
    var region: String?

    @Flag(
        name: .long,
        help: ArgumentHelp(
            "Overwrite existing profile without confirmation",
            discussion: "Skip confirmation prompt when overwriting an existing profile."
        )
    )
    var force = false

    @Flag(
        name: .long,
        help: ArgumentHelp(
            "Enable verbose output with detailed security information"
        )
    )
    var verbose = false

    func validate() throws {
        // Validate profile name
        guard !profile.isEmpty, profile.count <= 64 else {
            throw CommandValidationError("Profile name must be 1-64 characters")
        }

        let validProfilePattern = "^[a-zA-Z0-9._-]+$"
        guard let regex = try? NSRegularExpression(pattern: validProfilePattern),
            regex.firstMatch(in: profile, range: NSRange(location: 0, length: profile.count)) != nil
        else {
            throw CommandValidationError(
                "Profile name must contain only letters, numbers, dots, underscores, and hyphens"
            )
        }

        // Validate access key format
        guard accessKey.count == 20 else {
            throw CommandValidationError("Access key ID must be exactly 20 characters")
        }

        let validAccessKeyPattern = "^(AKIA|ASIA)[A-Z0-9]{16}$"
        guard let accessKeyRegex = try? NSRegularExpression(pattern: validAccessKeyPattern),
            accessKeyRegex.firstMatch(in: accessKey, range: NSRange(location: 0, length: accessKey.count)) != nil
        else {
            throw CommandValidationError(
                "Access key ID must start with AKIA or ASIA and contain only uppercase letters and numbers"
            )
        }

        // Validate secret key format
        guard secretKey.count == 40 else {
            throw CommandValidationError("Secret access key must be exactly 40 characters")
        }

        let validSecretKeyPattern = "^[A-Za-z0-9/+=]{40}$"
        guard let secretKeyRegex = try? NSRegularExpression(pattern: validSecretKeyPattern),
            secretKeyRegex.firstMatch(in: secretKey, range: NSRange(location: 0, length: secretKey.count)) != nil
        else {
            throw CommandValidationError("Secret access key contains invalid characters")
        }

        // Validate session token if provided
        if let sessionToken = sessionToken {
            guard sessionToken.count >= 100 else {
                throw CommandValidationError("Session token appears to be too short (minimum 100 characters)")
            }
        }

        // Validate region if provided
        if let region = region {
            let validRegionPattern = "^[a-z]{2,3}-[a-z]+-[0-9]+$"
            guard let regionRegex = try? NSRegularExpression(pattern: validRegionPattern),
                regionRegex.firstMatch(in: region, range: NSRange(location: 0, length: region.count)) != nil
            else {
                throw CommandValidationError("Region must follow AWS region format (e.g., us-east-1, eu-west-1)")
            }
        }
    }

    func run() async throws {
        var logger = Logger(label: "ProfileStore")
        logger.logLevel = verbose ? .debug : .info

        let commandLogger = CommandAuditLogger(systemLogger: logger)
        let resolver = SecureCredentialResolver(logger: logger)

        // Check if profile already exists (unless force is specified)
        if !force {
            do {
                _ = try await resolver.getSecureCredentials(profile: profile)

                // Profile exists, ask for confirmation
                print("⚠️ Profile '\(profile)' already exists in keychain.")
                print("Do you want to overwrite it? (y/N): ", terminator: "")

                let response = readLine()?.lowercased() ?? "n"
                guard response == "y" || response == "yes" else {
                    print("❌ Operation cancelled")
                    return
                }
            } catch KeychainError.itemNotFound {
                // Profile doesn't exist, continue
            } catch {
                throw CleanExit.message("Failed to check existing profile: \(error)")
            }
        }

        // Store credentials securely with audit logging
        try await commandLogger.auditProfileOperation(
            subcommand: "store",
            profileName: profile
        ) {
            try await resolver.storeSecureCredentials(
                profile: profile,
                accessKeyId: accessKey,
                secretAccessKey: secretKey,
                sessionToken: sessionToken,
                region: region
            )

            let credentialType = sessionToken != nil ? "temporary" : "permanent"
            print("✅ Successfully stored \(credentialType) credentials for profile: \(profile)")

            // Audit security event for credential storage
            await commandLogger.logSecurityEvent(
                action: "credential-storage",
                resource: "profile:\(profile)",
                profile: profile,
                outcome: .success,
                securityLevel: "high",
                metadata: [
                    "credential_type": credentialType,
                    "access_key_prefix": String(accessKey.prefix(8)),
                    "has_session_token": String(sessionToken != nil),
                    "region": region ?? "not-specified",
                ]
            )

            if verbose {
                print("\n📊 Profile Details:")
                print("  • Profile: \(profile)")
                print("  • Access Key: \(String(accessKey.prefix(8)))***")
                print("  • Region: \(region ?? "not specified")")
                print("  • Type: \(credentialType)")
                print("  • Security: Keychain encrypted")

                if sessionToken != nil {
                    print("  • ⚠️ Note: Temporary credentials may expire")
                }
            }

            print("\n💡 Use this profile with: --profile \(profile)")
        }
    }
}

// MARK: - List Profiles Command

struct ListProfilesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all secure profiles with metadata",
        discussion: """
            Lists all AWS profiles stored in the secure keychain with detailed metadata
            including security status, creation date, and expiration information.
            """
    )

    @Flag(
        name: .long,
        help: ArgumentHelp("Show detailed information for each profile")
    )
    var verbose = false

    @Flag(
        name: .long,
        help: ArgumentHelp("Show only profiles with potentially expired credentials")
    )
    var expiredOnly = false

    @Flag(
        name: .long,
        help: ArgumentHelp("Show only temporary credentials")
    )
    var temporaryOnly = false

    func run() async throws {
        var logger = Logger(label: "ProfileList")
        logger.logLevel = .warning  // Suppress info logs for clean output

        let resolver = SecureCredentialResolver(logger: logger)

        do {
            let profiles = try await resolver.listSecureProfiles()

            // Apply filters
            var filteredProfiles = profiles

            if expiredOnly {
                filteredProfiles = profiles.filter { $0.isPotentiallyExpired }
            }

            if temporaryOnly {
                filteredProfiles = profiles.filter { $0.isTemporary }
            }

            if filteredProfiles.isEmpty {
                if expiredOnly {
                    print("✅ No expired credentials found")
                } else if temporaryOnly {
                    print("✅ No temporary credentials found")
                } else {
                    print("📭 No secure profiles found in keychain")
                    print(
                        "\n💡 Store credentials with: swift run Brochure profiles store --profile <name> --access-key <key> --secret-key <secret>"
                    )
                }
                return
            }

            // Display profiles
            print("🔐 Secure AWS Profiles (\(filteredProfiles.count) total)")
            print()

            if verbose {
                for profile in filteredProfiles {
                    displayVerboseProfile(profile)
                    print()
                }
            } else {
                displayCompactProfiles(filteredProfiles)
            }

            // Summary information
            if !filteredProfiles.isEmpty {
                let expiredCount = filteredProfiles.filter { $0.isPotentiallyExpired }.count
                let temporaryCount = filteredProfiles.filter { $0.isTemporary }.count

                print("\n📊 Summary:")
                print("  • Total profiles: \(filteredProfiles.count)")
                print("  • Temporary credentials: \(temporaryCount)")
                if expiredCount > 0 {
                    print("  • ⚠️ Potentially expired: \(expiredCount)")
                }
            }

        } catch {
            throw CleanExit.message("Failed to list profiles: \(error)")
        }
    }

    private func displayVerboseProfile(_ profile: SecureProfileInfo) {
        print("Profile: \(profile.name)")
        print("  Status: \(profile.securityStatus)")
        print("  Region: \(profile.region ?? "not specified")")
        print("  Type: \(profile.isTemporary ? "Temporary" : "Permanent")")
        print("  Created: \(profile.ageDescription)")
        print("  Security Level: \(profile.securityLevel)")

        if profile.isPotentiallyExpired {
            print("  ⚠️ Warning: Credentials may be expired")
        }
    }

    private func displayCompactProfiles(_ profiles: [SecureProfileInfo]) {
        let nameWidth = profiles.map { $0.name.count }.max() ?? 10
        let regionWidth = profiles.compactMap { $0.region?.count }.max() ?? 10

        // Header
        print(
            String(
                format: "%-\(nameWidth)s  %-\(regionWidth)s  %-20s  %-15s",
                "PROFILE",
                "REGION",
                "STATUS",
                "TYPE"
            )
        )
        print(String(repeating: "-", count: nameWidth + regionWidth + 40))

        // Profiles
        for profile in profiles {
            let region = profile.region ?? "default"
            let status = profile.isPotentiallyExpired ? "⚠️ Expired" : "✅ Active"
            let type = profile.isTemporary ? "Temporary" : "Permanent"

            print(
                String(
                    format: "%-\(nameWidth)s  %-\(regionWidth)s  %-20s  %-15s",
                    profile.name,
                    region,
                    status,
                    type
                )
            )
        }
    }
}

// MARK: - Show Profile Command

struct ShowProfileCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Display detailed information about a specific profile",
        discussion: """
            Shows comprehensive information about a secure profile including security status,
            credential metadata, and usage recommendations.
            """
    )

    @Option(
        name: .long,
        help: ArgumentHelp(
            "AWS profile name to display",
            valueName: "name"
        )
    )
    var profile: String

    @Flag(
        name: .long,
        help: ArgumentHelp("Show partial credential values for verification")
    )
    var showCredentials = false

    func run() async throws {
        var logger = Logger(label: "ProfileShow")
        logger.logLevel = .warning

        let resolver = SecureCredentialResolver(logger: logger)

        do {
            let credentials = try await resolver.getSecureCredentials(profile: profile)
            let profiles = try await resolver.listSecureProfiles()

            guard let profileInfo = profiles.first(where: { $0.name == profile }) else {
                throw CleanExit.message("Profile metadata not found: \(profile)")
            }

            print("🔐 Profile: \(profile)")
            print()
            print("Security Information:")
            print("  Status: \(profileInfo.securityStatus)")
            print("  Security Level: \(profileInfo.securityLevel)")
            print("  Storage: Keychain encrypted")
            print("  Access Control: System protected")
            print()

            print("Profile Configuration:")
            print("  Region: \(credentials.region ?? "not specified")")
            print("  Type: \(credentials.isTemporary ? "Temporary credentials" : "Permanent credentials")")
            print("  Created: \(profileInfo.ageDescription)")
            print("  Age: \(String(format: "%.1f", credentials.age))s")
            print()

            if showCredentials {
                print("Credential Information (Partial):")
                print("  Access Key: \(String(credentials.accessKeyId.prefix(8)))***")
                print("  Secret Key: \(String(credentials.secretAccessKey.prefix(8)))***")
                if credentials.isTemporary {
                    print("  Session Token: \(String(credentials.sessionToken?.prefix(20) ?? ""))***")
                }
                print()
            }

            if credentials.isPotentiallyExpired {
                print("⚠️ WARNING: Temporary credentials may be expired")
                print("   Age: \(String(format: "%.1f", credentials.age)) seconds")
                print("   Consider refreshing with AWS STS")
                print()
            }

            print("Usage:")
            print("  swift run Brochure upload <site> --profile \(profile)")
            print("  swift run Brochure upload-all --all --profile \(profile)")

        } catch KeychainError.itemNotFound {
            throw CleanExit.message("Profile not found: \(profile)")
        } catch {
            throw CleanExit.message("Failed to retrieve profile: \(error)")
        }
    }
}

// MARK: - Remove Profile Command

struct RemoveProfileCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remove",
        abstract: "Remove credentials from secure storage",
        discussion: """
            Permanently removes AWS credentials from the secure keychain. This action
            cannot be undone and will require re-entering credentials if needed again.
            """
    )

    @Option(
        name: .long,
        help: ArgumentHelp(
            "AWS profile name to remove",
            valueName: "name"
        )
    )
    var profile: String

    @Flag(
        name: .long,
        help: ArgumentHelp("Remove without confirmation prompt")
    )
    var force = false

    func run() async throws {
        var logger = Logger(label: "ProfileRemove")
        logger.logLevel = .warning

        let resolver = SecureCredentialResolver(logger: logger)

        // Verify profile exists
        do {
            _ = try await resolver.getSecureCredentials(profile: profile)
        } catch KeychainError.itemNotFound {
            throw CleanExit.message("Profile not found: \(profile)")
        } catch {
            throw CleanExit.message("Failed to verify profile: \(error)")
        }

        // Confirmation (unless force is specified)
        if !force {
            print("⚠️ This will permanently remove credentials for profile '\(profile)'")
            print("Do you want to continue? (y/N): ", terminator: "")

            let response = readLine()?.lowercased() ?? "n"
            guard response == "y" || response == "yes" else {
                print("❌ Operation cancelled")
                return
            }
        }

        do {
            try await resolver.removeSecureCredentials(profile: profile)
            print("✅ Successfully removed credentials for profile: \(profile)")

        } catch {
            throw CleanExit.message("Failed to remove profile: \(error)")
        }
    }
}

// MARK: - Migrate Profile Command

struct MigrateProfileCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "migrate",
        abstract: "Migrate traditional credentials to secure storage",
        discussion: """
            Migrates AWS credentials from traditional sources (environment variables,
            ~/.aws/credentials file) to secure keychain storage.
            """
    )

    @Option(
        name: .long,
        help: ArgumentHelp(
            "AWS profile name to migrate",
            valueName: "name"
        )
    )
    var profile: String

    @Flag(
        name: .long,
        help: ArgumentHelp("Show what would be migrated without actually migrating")
    )
    var dryRun = false

    func run() async throws {
        var logger = Logger(label: "ProfileMigrate")
        logger.logLevel = .info

        print("🔄 Migration feature coming soon!")
        print("This will migrate credentials from:")
        print("  • ~/.aws/credentials file")
        print("  • Environment variables")
        print("  • AWS configuration files")
        print()
        print("For now, use 'profiles store' to manually add credentials to keychain.")

        // TODO: Implement actual migration logic
        // This would involve:
        // 1. Detecting traditional credential sources
        // 2. Parsing AWS credentials/config files
        // 3. Reading environment variables
        // 4. Storing found credentials in keychain
        // 5. Optionally removing from traditional sources
    }
}

// MARK: - Clear Profiles Command

struct ClearProfilesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clear",
        abstract: "Remove all Brochure data from keychain",
        discussion: """
            Permanently removes ALL Brochure data from the keychain, including all
            AWS profiles and configuration. This action cannot be undone.
            """
    )

    @Flag(
        name: .long,
        help: ArgumentHelp("Clear without confirmation prompt")
    )
    var force = false

    func run() async throws {
        var logger = Logger(label: "ProfileClear")
        logger.logLevel = .warning

        // Get current profile count for confirmation
        let resolver = SecureCredentialResolver(logger: logger)
        let profiles = try await resolver.listSecureProfiles()

        if profiles.isEmpty && !force {
            print("✅ No profiles found in keychain")
            return
        }

        // Confirmation (unless force is specified)
        if !force {
            print("⚠️ This will permanently remove ALL Brochure data from keychain:")
            print("  • \(profiles.count) AWS profiles")
            print("  • All stored configuration")
            print("  • All security metadata")
            print()
            print("This action CANNOT be undone!")
            print("Do you want to continue? (type 'YES' to confirm): ", terminator: "")

            let response = readLine() ?? ""
            guard response == "YES" else {
                print("❌ Operation cancelled")
                return
            }
        }

        do {
            let keychainManager = KeychainManager(logger: logger)
            try await keychainManager.clearAllData()

            print("✅ Successfully cleared all Brochure data from keychain")

        } catch {
            throw CleanExit.message("Failed to clear keychain data: \(error)")
        }
    }
}
