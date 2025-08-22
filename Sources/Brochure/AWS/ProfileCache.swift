import Foundation
import Logging

/// Intelligent caching system for AWS profile credentials and configurations.
///
/// `ProfileCache` caches profile resolution results and validation outcomes to avoid
/// repeated file I/O operations when accessing AWS credentials and config files.
/// This significantly improves CLI performance for commands that perform multiple
/// AWS operations or profile validations.
///
/// ## Key Features
///
/// - **Profile Resolution Caching**: Caches ProfileResolution results with TTL
/// - **Validation Caching**: Caches profile validation outcomes and available profile lists
/// - **File Change Detection**: Invalidates cache when AWS config files are modified
/// - **Thread Safety**: Safe for concurrent access using actor pattern
/// - **Memory Efficiency**: Automatic cleanup of expired cache entries
///
/// ## Example Usage
///
/// ```swift
/// let cache = ProfileCache()
///
/// // First call reads from filesystem
/// let profiles = try await cache.getAvailableProfiles()
///
/// // Subsequent calls use cached results (unless files changed)
/// let profilesAgain = try await cache.getAvailableProfiles()  // Fast!
///
/// // Resolve and cache profile configuration
/// let resolution = await cache.getCachedProfileResolution(
///     explicit: "production",
///     environment: ProcessInfo.processInfo.environment
/// )
/// ```
public actor ProfileCache {
    private let logger: Logger
    private let defaultTTL: TimeInterval

    // Cache entries with timestamps
    private var profileResolutionCache: [String: CachedProfileResolution] = [:]
    private var availableProfilesCache: CachedProfileList?
    private var profileValidationCache: [String: CachedValidationResult] = [:]

    // File modification tracking for cache invalidation
    private var credentialsFileModTime: Date?
    private var configFileModTime: Date?

    /// Initializes the profile cache with configurable TTL.
    ///
    /// - Parameter ttl: Time-to-live for cached entries in seconds (default: 300 = 5 minutes)
    public init(ttl: TimeInterval = 300) {
        self.logger = Logger(label: "ProfileCache")
        self.defaultTTL = ttl
        logger.debug("ProfileCache initialized with TTL: \(ttl)s")
    }

    /// Gets cached available profiles, reading from filesystem only if cache is invalid.
    ///
    /// - Returns: Array of available profile names sorted alphabetically
    /// - Throws: ProfileError if AWS configuration files cannot be read
    ///
    /// This method caches the result of parsing ~/.aws/credentials and ~/.aws/config files.
    /// The cache is invalidated when either file is modified or after the TTL expires.
    public func getAvailableProfiles() throws -> [String] {
        // Check if cache is valid
        if let cached = availableProfilesCache,
            cached.isValid(ttl: defaultTTL),
            !hasConfigFilesChanged(since: cached.timestamp)
        {
            logger.debug("Using cached available profiles (\(cached.profiles.count) profiles)")
            return cached.profiles
        }

        // Cache miss or invalid - read from filesystem
        logger.debug("Cache miss for available profiles, reading from filesystem")
        let validator = ProfileValidator()
        let profiles = try validator.listAvailableProfiles()

        // Update file modification times for future cache invalidation
        updateFileModificationTimes()

        // Cache the result
        availableProfilesCache = CachedProfileList(
            profiles: profiles,
            timestamp: Date()
        )

        logger.info("Cached \(profiles.count) available profiles")
        return profiles
    }

    /// Gets cached profile validation result.
    ///
    /// - Parameter profileName: The profile name to validate
    /// - Returns: True if the profile is valid and available
    /// - Throws: ProfileError if validation fails or profiles cannot be read
    public func isProfileValid(_ profileName: String) throws -> Bool {
        let cacheKey = profileName

        // Check cached validation result
        if let cached = profileValidationCache[cacheKey],
            cached.isValid(ttl: defaultTTL),
            !hasConfigFilesChanged(since: cached.timestamp)
        {
            logger.debug("Using cached validation result for profile: \(profileName)")
            return cached.isValid
        }

        // Cache miss - perform validation
        logger.debug("Cache miss for profile validation: \(profileName)")
        let availableProfiles = try getAvailableProfiles()
        let isValid = availableProfiles.contains(profileName)

        // Cache the result
        profileValidationCache[cacheKey] = CachedValidationResult(
            isValid: isValid,
            timestamp: Date()
        )

        logger.debug("Cached validation result for profile \(profileName): \(isValid)")
        return isValid
    }

    /// Gets cached profile resolution, performing resolution only if cache is invalid.
    ///
    /// - Parameters:
    ///   - explicit: Explicit profile name from CLI arguments
    ///   - environment: Environment variables dictionary
    ///   - configFile: Optional configuration file URL
    /// - Returns: Cached or newly resolved ProfileResolution
    public func getCachedProfileResolution(
        explicit: String?,
        environment: [String: String],
        configFile: URL? = nil
    ) -> ProfileResolution {
        let cacheKey = createResolutionCacheKey(
            explicit: explicit,
            environment: environment,
            configFile: configFile
        )

        // Check cached resolution
        if let cached = profileResolutionCache[cacheKey],
            cached.isValid(ttl: defaultTTL)
        {
            logger.debug("Using cached profile resolution for key: \(cacheKey)")
            return cached.resolution
        }

        // Cache miss - perform resolution
        logger.debug("Cache miss for profile resolution, resolving...")
        let resolver = ProfileResolver()
        let resolution = resolver.resolveProfile(
            explicit: explicit,
            environment: environment,
            configFile: configFile,
            logger: logger
        )

        // Cache the result
        profileResolutionCache[cacheKey] = CachedProfileResolution(
            resolution: resolution,
            timestamp: Date()
        )

        logger.info("Cached profile resolution: \(resolution.profileName ?? "default") from \(resolution.source)")
        return resolution
    }

    /// Clears all cached data, forcing fresh reads from filesystem.
    ///
    /// This method is useful when you know the AWS configuration has changed
    /// and want to ensure fresh data is loaded.
    public func clearCache() {
        profileResolutionCache.removeAll()
        availableProfilesCache = nil
        profileValidationCache.removeAll()
        credentialsFileModTime = nil
        configFileModTime = nil
        logger.info("All profile cache data cleared")
    }

    /// Clears expired cache entries to free memory.
    ///
    /// This method is called automatically but can be invoked manually
    /// for memory-sensitive applications.
    public func cleanupExpiredEntries() {
        let now = Date()

        // Clean expired profile resolutions
        let expiredResolutions = profileResolutionCache.filter { _, cached in
            !cached.isValid(ttl: defaultTTL, currentTime: now)
        }
        for (key, _) in expiredResolutions {
            profileResolutionCache.removeValue(forKey: key)
        }

        // Clean expired validation results
        let expiredValidations = profileValidationCache.filter { _, cached in
            !cached.isValid(ttl: defaultTTL, currentTime: now)
        }
        for (key, _) in expiredValidations {
            profileValidationCache.removeValue(forKey: key)
        }

        // Clean expired profile list
        if let cached = availableProfilesCache,
            !cached.isValid(ttl: defaultTTL, currentTime: now)
        {
            availableProfilesCache = nil
        }

        let cleanedCount = expiredResolutions.count + expiredValidations.count
        if cleanedCount > 0 {
            logger.debug("Cleaned up \(cleanedCount) expired cache entries")
        }
    }

    /// Gets cache statistics for monitoring and debugging.
    ///
    /// - Returns: Dictionary containing cache hit counts and memory usage information
    public func getCacheStatistics() -> [String: String] {
        cleanupExpiredEntries()  // Clean up before reporting stats

        return [
            "profile_resolutions_cached": String(profileResolutionCache.count),
            "profile_validations_cached": String(profileValidationCache.count),
            "available_profiles_cached": String(availableProfilesCache != nil),
            "cache_ttl_seconds": String(Int(defaultTTL)),
            "credentials_file_tracked": String(credentialsFileModTime != nil),
            "config_file_tracked": String(configFileModTime != nil),
        ]
    }

    // MARK: - Private Implementation

    private func createResolutionCacheKey(
        explicit: String?,
        environment: [String: String],
        configFile: URL?
    ) -> String {
        let envProfile = environment["AWS_PROFILE"] ?? ""
        let envRegion = environment["AWS_REGION"] ?? ""
        let configPath = configFile?.path ?? ""
        return "\(explicit ?? "")|\(envProfile)|\(envRegion)|\(configPath)"
    }

    private func hasConfigFilesChanged(since timestamp: Date) -> Bool {
        let credentialsPath = NSString(string: "~/.aws/credentials").expandingTildeInPath
        let configPath = NSString(string: "~/.aws/config").expandingTildeInPath

        return hasFileChanged(path: credentialsPath, since: timestamp)
            || hasFileChanged(path: configPath, since: timestamp)
    }

    private func hasFileChanged(path: String, since timestamp: Date) -> Bool {
        guard FileManager.default.fileExists(atPath: path) else {
            return false  // File doesn't exist, no change
        }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            let modificationDate = attributes[.modificationDate] as? Date ?? Date.distantPast
            return modificationDate > timestamp
        } catch {
            logger.warning("Failed to check modification time for \(path): \(error)")
            return true  // Assume changed if we can't check
        }
    }

    private func updateFileModificationTimes() {
        let credentialsPath = NSString(string: "~/.aws/credentials").expandingTildeInPath
        let configPath = NSString(string: "~/.aws/config").expandingTildeInPath

        credentialsFileModTime = getFileModificationTime(path: credentialsPath)
        configFileModTime = getFileModificationTime(path: configPath)
    }

    private func getFileModificationTime(path: String) -> Date? {
        guard FileManager.default.fileExists(atPath: path) else {
            return nil
        }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            return attributes[.modificationDate] as? Date
        } catch {
            logger.warning("Failed to get modification time for \(path): \(error)")
            return nil
        }
    }
}

// MARK: - Cache Entry Types

/// Cached profile resolution with timestamp for TTL validation.
private struct CachedProfileResolution {
    let resolution: ProfileResolution
    let timestamp: Date

    func isValid(ttl: TimeInterval, currentTime: Date = Date()) -> Bool {
        currentTime.timeIntervalSince(timestamp) < ttl
    }
}

/// Cached available profiles list with timestamp for TTL validation.
private struct CachedProfileList {
    let profiles: [String]
    let timestamp: Date

    func isValid(ttl: TimeInterval, currentTime: Date = Date()) -> Bool {
        currentTime.timeIntervalSince(timestamp) < ttl
    }
}

/// Cached validation result with timestamp for TTL validation.
private struct CachedValidationResult {
    let isValid: Bool
    let timestamp: Date

    func isValid(ttl: TimeInterval, currentTime: Date = Date()) -> Bool {
        currentTime.timeIntervalSince(timestamp) < ttl
    }
}
