import Foundation
import Logging

/// Resolves AWS profiles from various sources in priority order.
public protocol ProfileResolverProtocol {
    func resolveProfile(
        explicit: String?,
        environment: [String: String],
        configFile: URL?,
        logger: Logger?
    ) -> ProfileResolution
}

/// Result of profile resolution with metadata about the source.
public struct ProfileResolution: Sendable {
    public let profileName: String?
    public let source: ProfileSource
    public let region: String?

    public init(profileName: String?, source: ProfileSource, region: String? = nil) {
        self.profileName = profileName
        self.source = source
        self.region = region
    }
}

/// Source of the profile configuration.
public enum ProfileSource: Sendable {
    case explicit  // --profile flag
    case environment  // AWS_PROFILE env var
    case configFile  // .brochure.yml
    case defaultChain  // AWS default credential chain
}

/// Concrete implementation of profile resolution logic.
public struct ProfileResolver: ProfileResolverProtocol, Sendable {
    /// Initializes the profile resolver.
    public init() {}
    public func resolveProfile(
        explicit: String?,
        environment: [String: String],
        configFile: URL?,
        logger: Logger? = nil
    ) -> ProfileResolution {
        logger?.debug("🔍 Starting AWS profile resolution")
        logger?.debug("📋 Profile resolution inputs:")
        logger?.debug("  • Explicit profile: \(explicit ?? "none")")
        logger?.debug("  • AWS_PROFILE env var: \(environment["AWS_PROFILE"] ?? "none")")
        logger?.debug("  • AWS_REGION env var: \(environment["AWS_REGION"] ?? "none")")
        logger?.debug("  • Config file: \(configFile?.path ?? "none")")

        // Priority order:
        // 1. Explicit --profile flag
        if let explicit = explicit {
            logger?.info("✅ Using explicit profile from CLI: \(explicit)")
            let resolution = ProfileResolution(
                profileName: explicit,
                source: .explicit,
                region: environment["AWS_REGION"]
            )
            logger?.debug("🌍 Region: \(resolution.region ?? "default")")
            return resolution
        }

        // 2. AWS_PROFILE environment variable
        if let envProfile = environment["AWS_PROFILE"] {
            logger?.info("✅ Using profile from AWS_PROFILE environment variable: \(envProfile)")
            let resolution = ProfileResolution(
                profileName: envProfile,
                source: .environment,
                region: environment["AWS_REGION"]
            )
            logger?.debug("🌍 Region: \(resolution.region ?? "default")")
            return resolution
        }

        // 3. Site-specific config file (future enhancement)
        if let config = configFile, loadConfig(from: config) != nil {
            logger?.debug("📂 Configuration file detected, but not yet implemented")
            // TODO: Implement config file loading in future version
            // For now, fall through to default chain
        }

        // 4. Default AWS credential chain
        logger?.info("🏠 Using AWS default credential chain")
        logger?.debug("ℹ️ This will use credentials from:")
        logger?.debug("  • Environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)")
        logger?.debug("  • Shared credentials file (~/.aws/credentials)")
        logger?.debug("  • EC2 instance metadata (if running on EC2)")
        logger?.debug("  • ECS task metadata (if running on ECS)")

        let resolution = ProfileResolution(
            profileName: nil,
            source: .defaultChain,
            region: environment["AWS_REGION"]
        )
        logger?.debug("🌍 Region: \(resolution.region ?? "will be auto-detected")")
        return resolution
    }

    private func loadConfig(from url: URL) -> BrochureConfig? {
        // Placeholder for future config file support
        // Will be implemented when adding .brochure.yml support
        nil
    }
}

/// Placeholder for future configuration file support.
private struct BrochureConfig {
    let defaultProfile: String?
    let defaultRegion: String?
}
