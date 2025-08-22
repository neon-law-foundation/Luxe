import Foundation

/// Configuration settings for S3 upload operations.
///
/// `UploadConfiguration` provides comprehensive settings for customizing how files are uploaded to S3,
/// including retry behavior, caching policies, and multipart upload settings.
///
/// ## Example Usage
///
/// ```swift
/// // Use default configuration
/// let defaultConfig = UploadConfiguration.default
///
/// // Create custom configuration
/// let customConfig = UploadConfiguration(
///     bucketName: "my-bucket",
///     keyPrefix: "static-sites",
///     maxRetries: 5,
///     multipartChunkSize: 10 * 1024 * 1024 // 10MB
/// )
/// ```
///
/// ## Cache Control Strategies
///
/// The configuration provides three different cache control strategies:
/// - **HTML files**: No caching for dynamic content updates
/// - **Asset files**: Long-term caching for static resources
/// - **Moderate files**: Short-term caching for semi-dynamic content
public struct UploadConfiguration: Sendable {
    /// The name of the S3 bucket where files will be uploaded.
    public let bucketName: String

    /// The key prefix to prepend to all uploaded file paths.
    public let keyPrefix: String

    /// The AWS region where the S3 bucket is located.
    public let region: String

    /// Whether to skip uploading files that haven't changed based on MD5 hash comparison.
    public let skipUnchangedFiles: Bool

    /// Whether to enable multipart upload for large files.
    public let enableMultipartUpload: Bool

    /// The chunk size in bytes for multipart uploads.
    public let multipartChunkSize: Int

    /// The maximum number of retry attempts for failed operations.
    public let maxRetries: Int

    /// The base delay in seconds between retry attempts (uses exponential backoff).
    public let retryBaseDelay: TimeInterval

    /// The default cache duration in seconds.
    public let defaultCacheDuration: Int

    /// Cache control header for HTML files (typically no-cache).
    public let htmlCacheControl: String

    /// Cache control header for static assets (typically long-term cache).
    public let assetCacheControl: String

    /// Cache control header for moderately cacheable files.
    public let moderateCacheControl: String

    /// The default configuration optimized for serving static websites via CloudFront.
    ///
    /// This configuration uses:
    /// - Production S3 bucket (`sagebrush-public`)
    /// - CloudFront-optimized cache headers
    /// - Multipart uploads for files over 5MB
    /// - MD5-based file change detection
    /// - Exponential backoff retry logic
    public static let `default` = UploadConfiguration(
        bucketName: "sagebrush-public",
        keyPrefix: "Brochure",
        region: "us-west-2",
        skipUnchangedFiles: true,
        enableMultipartUpload: true,
        multipartChunkSize: 5 * 1024 * 1024,  // 5MB
        maxRetries: 3,
        retryBaseDelay: 1.0,
        defaultCacheDuration: 3600,  // 1 hour
        htmlCacheControl: "no-cache, must-revalidate",
        assetCacheControl: "public, max-age=31536000, immutable",  // 1 year
        moderateCacheControl: "public, max-age=3600"  // 1 hour
    )

    /// Creates a new upload configuration with the specified settings.
    ///
    /// - Parameters:
    ///   - bucketName: The S3 bucket name for uploads
    ///   - keyPrefix: The prefix to add to all S3 object keys
    ///   - region: The AWS region containing the S3 bucket
    ///   - skipUnchangedFiles: Whether to skip uploading unchanged files
    ///   - enableMultipartUpload: Whether to use multipart uploads for large files
    ///   - multipartChunkSize: The size of each multipart upload chunk in bytes
    ///   - maxRetries: Maximum number of retry attempts for failed operations
    ///   - retryBaseDelay: Base delay between retries (exponential backoff applies)
    ///   - defaultCacheDuration: Default cache duration in seconds
    ///   - htmlCacheControl: Cache control header for HTML files
    ///   - assetCacheControl: Cache control header for static assets
    ///   - moderateCacheControl: Cache control header for semi-static files
    public init(
        bucketName: String = "sagebrush-public",
        keyPrefix: String = "Brochure",
        region: String = "us-west-2",
        skipUnchangedFiles: Bool = true,
        enableMultipartUpload: Bool = true,
        multipartChunkSize: Int = 5 * 1024 * 1024,
        maxRetries: Int = 3,
        retryBaseDelay: TimeInterval = 1.0,
        defaultCacheDuration: Int = 3600,
        htmlCacheControl: String = "no-cache, must-revalidate",
        assetCacheControl: String = "public, max-age=31536000, immutable",
        moderateCacheControl: String = "public, max-age=3600"
    ) {
        self.bucketName = bucketName
        self.keyPrefix = keyPrefix
        self.region = region
        self.skipUnchangedFiles = skipUnchangedFiles
        self.enableMultipartUpload = enableMultipartUpload
        self.multipartChunkSize = multipartChunkSize
        self.maxRetries = maxRetries
        self.retryBaseDelay = retryBaseDelay
        self.defaultCacheDuration = defaultCacheDuration
        self.htmlCacheControl = htmlCacheControl
        self.assetCacheControl = assetCacheControl
        self.moderateCacheControl = moderateCacheControl
    }

    /// A mapping of file extensions to their appropriate cache control headers.
    ///
    /// This computed property returns a dictionary mapping file extensions to cache control
    /// strategies based on the file type's typical update frequency and caching requirements.
    public var cacheControlForFileType: [String: String] {
        [
            "html": htmlCacheControl,
            "htm": htmlCacheControl,
            "css": assetCacheControl,
            "js": assetCacheControl,
            "png": assetCacheControl,
            "jpg": assetCacheControl,
            "jpeg": assetCacheControl,
            "gif": assetCacheControl,
            "svg": assetCacheControl,
            "webp": assetCacheControl,
            "ico": assetCacheControl,
            "woff": assetCacheControl,
            "woff2": assetCacheControl,
            "ttf": assetCacheControl,
            "otf": assetCacheControl,
            "eot": assetCacheControl,
            "json": moderateCacheControl,
            "webmanifest": moderateCacheControl,
            "manifest": moderateCacheControl,
            "pdf": "public, max-age=86400",  // 1 day
            "txt": moderateCacheControl,
            "md": moderateCacheControl,
        ]
    }

    /// Returns the appropriate cache control header for the given file extension.
    ///
    /// - Parameter fileExtension: The file extension (without the dot)
    /// - Returns: The cache control header string for the file type
    ///
    /// ## Example
    ///
    /// ```swift
    /// let config = UploadConfiguration.default
    /// let htmlCache = config.cacheControl(for: "html") // "no-cache, must-revalidate"
    /// let cssCache = config.cacheControl(for: "css")   // "public, max-age=31536000, immutable"
    /// ```
    public func cacheControl(for fileExtension: String) -> String {
        let lowercaseExtension = fileExtension.lowercased()
        return cacheControlForFileType[lowercaseExtension] ?? moderateCacheControl
    }
}
