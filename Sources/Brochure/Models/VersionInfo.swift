import Foundation

/// Version information for the Brochure CLI binary.
///
/// Provides compile-time and runtime version information including semantic versioning,
/// git metadata, and build information for distribution and debugging purposes.
public struct VersionInfo: Codable, Sendable {
    /// Semantic version (e.g., "1.2.3")
    public let version: String

    /// Major version number
    public let majorVersion: Int

    /// Minor version number
    public let minorVersion: Int

    /// Patch version number
    public let patchVersion: Int

    /// Pre-release identifier (e.g., "alpha.1", "beta.2", "rc.1")
    public let preRelease: String?

    /// Build metadata (e.g., "+20130313144700")
    public let buildMetadata: String?

    /// Full git commit hash
    public let gitCommit: String

    /// Short git commit hash (8 characters)
    public let gitShortCommit: String

    /// Git branch name
    public let gitBranch: String?

    /// Whether the working directory was dirty during build
    public let gitDirty: Bool

    /// Build date (ISO 8601 format)
    public let buildDate: String

    /// Build timestamp (ISO 8601 format with time)
    public let buildTimestamp: String

    /// Target platform (darwin, linux)
    public let platform: String

    /// Target architecture (x64, arm64)
    public let architecture: String

    /// Platform-architecture combination
    public let platformArch: String

    /// Swift version used for compilation
    public let swiftVersion: String?

    /// Compiler name and version
    public let compiler: String?

    /// Build configuration (debug, release)
    public let buildConfiguration: String

    /// Creates version info from environment and build parameters.
    ///
    /// - Parameters:
    ///   - version: Semantic version string
    ///   - gitCommit: Git commit hash
    ///   - gitBranch: Git branch name
    ///   - gitDirty: Whether working directory was dirty
    ///   - platform: Target platform
    ///   - architecture: Target architecture
    ///   - buildConfiguration: Build configuration
    ///   - swiftVersion: Swift compiler version
    ///   - compiler: Compiler information
    public init(
        version: String,
        gitCommit: String,
        gitBranch: String? = nil,
        gitDirty: Bool = false,
        platform: String,
        architecture: String,
        buildConfiguration: String = "release",
        swiftVersion: String? = nil,
        compiler: String? = nil
    ) {
        self.version = version
        self.gitCommit = gitCommit
        self.gitBranch = gitBranch
        self.gitDirty = gitDirty
        self.platform = platform
        self.architecture = architecture
        self.buildConfiguration = buildConfiguration
        self.swiftVersion = swiftVersion
        self.compiler = compiler

        // Parse semantic version components
        let versionComponents = Self.parseSemanticVersion(version)
        self.majorVersion = versionComponents.major
        self.minorVersion = versionComponents.minor
        self.patchVersion = versionComponents.patch
        self.preRelease = versionComponents.preRelease
        self.buildMetadata = versionComponents.buildMetadata

        // Generate derived fields
        self.gitShortCommit = String(gitCommit.prefix(8))
        self.platformArch = "\(platform)-\(architecture)"

        // Generate timestamps
        let now = Date()
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")

        formatter.dateFormat = "yyyy-MM-dd"
        self.buildDate = formatter.string(from: now)

        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        self.buildTimestamp = formatter.string(from: now)
    }

    /// Parse semantic version string into components.
    ///
    /// Supports the full semantic versioning specification:
    /// MAJOR.MINOR.PATCH[-PRERELEASE][+BUILDMETADATA]
    ///
    /// - Parameter version: Semantic version string
    /// - Returns: Parsed version components
    private static func parseSemanticVersion(
        _ version: String
    ) -> (
        major: Int, minor: Int, patch: Int, preRelease: String?, buildMetadata: String?
    ) {
        // Remove 'v' prefix if present
        let cleanVersion = version.hasPrefix("v") ? String(version.dropFirst()) : version

        // Split on '+' to separate build metadata
        let parts = cleanVersion.split(separator: "+", maxSplits: 1)
        let versionPart = String(parts[0])
        let buildMetadata = parts.count > 1 ? String(parts[1]) : nil

        // Split on '-' to separate pre-release
        let versionParts = versionPart.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let coreVersion = String(versionParts[0])
        let preRelease = versionParts.count > 1 ? String(versionParts[1]) : nil

        // Parse core version numbers
        let coreComponents = coreVersion.split(separator: ".")
        let major = Int(coreComponents.first ?? "0") ?? 0
        let minor = coreComponents.count > 1 ? (Int(coreComponents[1]) ?? 0) : 0
        let patch = coreComponents.count > 2 ? (Int(coreComponents[2]) ?? 0) : 0

        return (major: major, minor: minor, patch: patch, preRelease: preRelease, buildMetadata: buildMetadata)
    }

    /// Returns the full semantic version string.
    public var fullVersion: String {
        var result = "\(majorVersion).\(minorVersion).\(patchVersion)"

        if let preRelease = preRelease {
            result += "-\(preRelease)"
        }

        if let buildMetadata = buildMetadata {
            result += "+\(buildMetadata)"
        }

        return result
    }

    /// Returns a short version string suitable for display.
    public var shortVersion: String {
        var result = "\(majorVersion).\(minorVersion).\(patchVersion)"

        if let preRelease = preRelease {
            result += "-\(preRelease)"
        }

        return result
    }

    /// Returns a detailed version string with git information.
    public var detailedVersion: String {
        var result = shortVersion

        if gitDirty {
            result += "-dirty"
        }

        result += " (\(gitShortCommit))"

        if let gitBranch = gitBranch, gitBranch != "main" && gitBranch != "master" {
            result += " on \(gitBranch)"
        }

        return result
    }

    /// Returns build information as a formatted string.
    public var buildInfo: String {
        var info: [String] = []

        info.append("Platform: \(platformArch)")
        info.append("Built: \(buildDate)")
        info.append("Config: \(buildConfiguration)")

        if let swiftVersion = swiftVersion {
            info.append("Swift: \(swiftVersion)")
        }

        if let compiler = compiler {
            info.append("Compiler: \(compiler)")
        }

        return info.joined(separator: ", ")
    }

    /// Returns version information suitable for CLI --version output.
    public var cliOutput: String {
        """
        Brochure CLI \(detailedVersion)
        \(buildInfo)
        """
    }

    /// Creates version info from environment variables (typically set by build script).
    ///
    /// Expected environment variables:
    /// - BUILD_VERSION: Semantic version
    /// - GIT_COMMIT: Full git commit hash
    /// - GIT_BRANCH: Git branch name
    /// - GIT_DIRTY: "true" if working directory was dirty
    /// - BUILD_PLATFORM: Target platform
    /// - BUILD_ARCHITECTURE: Target architecture
    /// - BUILD_CONFIGURATION: Build configuration
    /// - SWIFT_VERSION: Swift compiler version
    /// - COMPILER_VERSION: Compiler information
    ///
    /// - Returns: VersionInfo instance or nil if required variables are missing
    public static func fromEnvironment() -> VersionInfo? {
        let env = ProcessInfo.processInfo.environment

        guard let version = env["BUILD_VERSION"],
            let gitCommit = env["GIT_COMMIT"],
            let platform = env["BUILD_PLATFORM"],
            let architecture = env["BUILD_ARCHITECTURE"]
        else {
            return nil
        }

        let gitBranch = env["GIT_BRANCH"]
        let gitDirty = env["GIT_DIRTY"] == "true"
        let buildConfiguration = env["BUILD_CONFIGURATION"] ?? "release"
        let swiftVersion = env["SWIFT_VERSION"]
        let compiler = env["COMPILER_VERSION"]

        return VersionInfo(
            version: version,
            gitCommit: gitCommit,
            gitBranch: gitBranch,
            gitDirty: gitDirty,
            platform: platform,
            architecture: architecture,
            buildConfiguration: buildConfiguration,
            swiftVersion: swiftVersion,
            compiler: compiler
        )
    }
}

/// Current version information for this build.
/// This will be populated by the build system with actual values.
public let currentVersion: VersionInfo = {
    // Try to get version from environment (set by build script)
    if let envVersion = VersionInfo.fromEnvironment() {
        return envVersion
    }

    // Fallback for development builds
    return VersionInfo(
        version: "0.1.0-dev",
        gitCommit: "unknown",
        gitBranch: "development",
        gitDirty: true,
        platform: "unknown",
        architecture: "unknown",
        buildConfiguration: "debug"
    )
}()
