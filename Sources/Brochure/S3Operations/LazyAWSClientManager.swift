import AsyncHTTPClient
import Foundation
import Logging
import SotoCore
import SotoS3

/// Manages lazy initialization of AWS SDK components to optimize CLI startup time.
///
/// `LazyAWSClientManager` defers the creation of AWS clients, HTTP clients, and related
/// components until they are actually needed. This significantly reduces CLI startup
/// time by avoiding the overhead of AWS SDK initialization for commands that don't
/// require AWS operations.
///
/// ## Key Features
///
/// - **Lazy Initialization**: AWS clients are only created when first accessed
/// - **Thread Safety**: Safe for concurrent access using actor pattern
/// - **Resource Management**: Proper cleanup of HTTP clients and AWS resources
/// - **Profile Support**: Handles AWS profile configuration and credential providers
/// - **Error Handling**: Graceful fallback for invalid profiles or missing credentials
///
/// ## Example Usage
///
/// ```swift
/// let manager = LazyAWSClientManager()
///
/// // This doesn't create any AWS clients yet
/// let s3Client = try await manager.getS3Client(
///     profile: "production",
///     region: "us-west-2"
/// )
///
/// // AWS client is created only on first access
/// let result = try await s3Client.listBuckets(S3.ListBucketsRequest())
///
/// // Cleanup when done
/// try await manager.shutdown()
/// ```
public actor LazyAWSClientManager {
    private var awsClient: AWSClient?
    private var httpClient: HTTPClient?
    private var s3Clients: [String: S3ClientProtocol] = [:]
    private let logger: Logger
    private let profileCache: ProfileCache

    public init() {
        self.logger = Logger(label: "LazyAWSClientManager")
        self.profileCache = ProfileCache()
    }

    /// Gets an S3 client for the specified profile and region, creating it lazily if needed.
    ///
    /// - Parameters:
    ///   - profile: AWS profile name (optional, uses default chain if nil)
    ///   - region: AWS region (defaults to us-west-2)
    ///   - bucketName: S3 bucket name for configuration
    ///   - keyPrefix: Key prefix for S3 operations
    ///
    /// - Returns: S3 client wrapper that implements S3ClientProtocol
    /// - Throws: AWS configuration or initialization errors
    ///
    /// The client is cached based on profile and region combination to avoid
    /// recreating expensive resources for repeated operations.
    public func getS3Client(
        profile: String? = nil,
        region: String = "us-west-2",
        bucketName: String,
        keyPrefix: String
    ) async throws -> S3ClientProtocol {
        let clientKey = "\(profile ?? "default"):\(region)"

        // Return cached client if available
        if let existingClient = s3Clients[clientKey] {
            logger.debug("Reusing cached S3 client for profile: \(profile ?? "default"), region: \(region)")
            return existingClient
        }

        logger.info("Creating S3 client for profile: \(profile ?? "default"), region: \(region)")

        // Initialize HTTP client if not already created
        if httpClient == nil {
            logger.debug("Initializing HTTP client")
            httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        }

        // Use cached profile resolution for improved performance
        let profileResolution = await profileCache.getCachedProfileResolution(
            explicit: profile,
            environment: ProcessInfo.processInfo.environment,
            configFile: nil  // Config file support will be added later
        )

        // Validate profile using cache if explicitly specified
        if let profileName = profileResolution.profileName, profileResolution.source == .explicit {
            do {
                let isValid = try await profileCache.isProfileValid(profileName)
                if isValid {
                    logger.debug("Cached profile validation passed for: \(profileName)")
                } else {
                    logger.error("Profile validation failed: Profile '\(profileName)' not found")
                    // For now, we'll continue with default credentials if validation fails
                    // In the future, this should throw the error
                }
            } catch {
                logger.error("Profile validation failed: \(error)")
                // For now, we'll continue with default credentials if validation fails
                // In the future, this should throw the error
            }
        }

        // Create credential provider based on resolution
        let credentialProvider: CredentialProviderFactory
        if let profileName = profileResolution.profileName {
            // TODO: Implement proper profile-based credential provider
            // For now, fall back to default to maintain functionality while we develop the feature
            credentialProvider = .default
            logger.info("Using AWS profile: \(profileName) (falling back to default credentials temporarily)")
        } else {
            // Use default credential chain
            credentialProvider = .default
            logger.debug("Using default AWS credential chain")
        }

        // Initialize AWS client if not already created
        if awsClient == nil {
            logger.debug("Initializing AWS client with exponential retry policy")
            awsClient = AWSClient(
                credentialProvider: credentialProvider,
                retryPolicy: .exponential(base: .seconds(1), maxRetries: 3),
                httpClient: httpClient!
            )
        }

        // Parse region from string to Region enum
        let awsRegion: Region
        switch region {
        case "us-west-2":
            awsRegion = .uswest2
        case "us-east-1":
            awsRegion = .useast1
        case "us-east-2":
            awsRegion = .useast2
        case "eu-west-1":
            awsRegion = .euwest1
        case "ap-southeast-1":
            awsRegion = .apsoutheast1
        default:
            logger.warning("Unknown region '\(region)', defaulting to us-west-2")
            awsRegion = .uswest2
        }

        // Create S3 client and wrapper
        let s3 = S3(client: awsClient!, region: awsRegion)
        let s3ClientWrapper = S3ClientWrapper(s3: s3)

        // Cache the client for reuse
        s3Clients[clientKey] = s3ClientWrapper

        logger.info("S3 client created and cached for bucket: \(bucketName), prefix: \(keyPrefix)")
        return s3ClientWrapper
    }

    /// Shuts down all AWS clients and releases resources.
    ///
    /// This method should be called when the manager is no longer needed to properly
    /// clean up HTTP connections and AWS client resources.
    ///
    /// - Throws: AWS client shutdown errors
    ///
    /// ## Example
    ///
    /// ```swift
    /// let manager = LazyAWSClientManager()
    /// defer {
    ///     try await manager.shutdown()
    /// }
    /// // ... use manager
    /// ```
    public func shutdown() async throws {
        logger.debug("Shutting down LazyAWSClientManager")

        // Clear client cache
        s3Clients.removeAll()

        // Clear profile cache
        await profileCache.clearCache()

        // Shutdown AWS client
        if let client = awsClient {
            logger.debug("Shutting down AWS client")
            try await client.shutdown()
            awsClient = nil
        }

        // Shutdown HTTP client to prevent memory leaks
        if let httpClient = httpClient {
            logger.debug("Shutting down HTTP client")
            try await httpClient.shutdown()
            self.httpClient = nil
        }

        logger.info("LazyAWSClientManager shutdown completed")
    }

    /// Gets usage statistics for monitoring and debugging.
    ///
    /// - Returns: Dictionary containing client count, initialization status, and cache statistics
    public func getUsageStats() async -> [String: String] {
        var stats: [String: String] = [
            "cached_s3_clients": String(s3Clients.count),
            "aws_client_initialized": String(awsClient != nil),
            "http_client_initialized": String(httpClient != nil),
            "profiles": Array(s3Clients.keys).joined(separator: ", "),
        ]

        // Add profile cache statistics
        let cacheStats = await profileCache.getCacheStatistics()
        for (key, value) in cacheStats {
            stats["profile_cache_\(key)"] = value
        }

        return stats
    }
}

/// Configuration for lazy AWS client initialization.
public struct LazyAWSConfiguration: Sendable {
    /// Maximum number of cached clients to retain
    public let maxCachedClients: Int

    /// Default retry policy settings
    public let defaultMaxRetries: Int
    public let defaultRetryBaseDelay: TimeInterval

    /// Whether to enable detailed logging for client creation
    public let enableVerboseLogging: Bool

    public init(
        maxCachedClients: Int = 10,
        defaultMaxRetries: Int = 3,
        defaultRetryBaseDelay: TimeInterval = 1.0,
        enableVerboseLogging: Bool = false
    ) {
        self.maxCachedClients = maxCachedClients
        self.defaultMaxRetries = defaultMaxRetries
        self.defaultRetryBaseDelay = defaultRetryBaseDelay
        self.enableVerboseLogging = enableVerboseLogging
    }

    public static let `default` = LazyAWSConfiguration()
}
