import AsyncHTTPClient
import Foundation
import ServiceLifecycle
import SotoCore
import SotoS3

/// Centralized AWS client configuration for Holiday operations with LocalStack support.
///
/// ## Overview
/// This struct provides a unified way to configure AWS clients for both production
/// and local development environments. It automatically detects the environment
/// and configures the appropriate endpoints and credentials.
public struct AWSClientConfiguration: Sendable {
    /// The AWS client instance configured for the current environment.
    public let client: AWSClient

    /// The AWS region to use for operations.
    public let region: Region

    /// The S3 bucket name for holiday operations.
    public let bucketName: String

    /// Environment detection based on ENV variable.
    public static var isLocalDevelopment: Bool {
        ProcessInfo.processInfo.environment["ENV"] != "PRODUCTION"
    }

    /// Initializes the AWS client configuration.
    ///
    /// ## Environment Detection
    /// - **Local Development**: Uses LocalStack endpoint (http://localhost:4566)
    /// - **Production**: Uses default AWS endpoints
    ///
    /// ## Credentials
    /// - **Local Development**: Uses "test" credentials for LocalStack
    /// - **Production**: Uses default credential provider chain
    ///
    /// - Parameters:
    ///   - bucketName: The S3 bucket name to use (defaults to "luxe-holiday-bucket")
    ///   - region: The AWS region to use (defaults to us-west-2)
    public init(bucketName: String = "luxe-holiday-bucket", region: Region = .uswest2) {
        self.bucketName = bucketName
        self.region = region

        if Self.isLocalDevelopment {
            // Configure for LocalStack
            self.client = AWSClient(
                credentialProvider: .static(
                    accessKeyId: "test",
                    secretAccessKey: "test"
                ),
                httpClient: HTTPClient.shared
            )
        } else {
            // Configure for production AWS
            self.client = AWSClient(
                credentialProvider: .default,
                retryPolicy: .exponential(base: .seconds(1), maxRetries: 3),
                httpClient: HTTPClient.shared
            )
        }
    }

    /// Creates an S3 service client using the configured client and region.
    ///
    /// - Returns: An S3 client ready for operations
    public func s3Client() -> S3 {
        S3(client: client, region: region)
    }

    /// Gets the S3 endpoint URL for the current configuration.
    ///
    /// - Returns: The S3 endpoint URL string
    public func s3EndpointURL() -> String {
        if Self.isLocalDevelopment {
            return "http://localhost:4566"
        } else {
            return "https://s3.\(region.rawValue).amazonaws.com"
        }
    }

    /// Gets the public URL for an S3 object.
    ///
    /// - Parameter key: The S3 object key
    /// - Returns: The public URL for the object
    public func publicURL(for key: String) -> String {
        if Self.isLocalDevelopment {
            return "http://localhost:4566/\(bucketName)/\(key)"
        } else {
            return "https://\(bucketName).s3.\(region.rawValue).amazonaws.com/\(key)"
        }
    }
}

/// Service wrapper for AWS client lifecycle management
public struct AWSClientService: Service {
    let config: AWSClientConfiguration

    public init(config: AWSClientConfiguration) {
        self.config = config
    }

    public func run() async throws {
        try await cancelWhenGracefulShutdown {
            // Keep the service running until shutdown is requested
            // Use a very long but reasonable duration (1 year in seconds)
            try await Task.sleep(for: .seconds(365 * 24 * 60 * 60))
        }

        // Shutdown the AWS client when the service is stopped
        try await config.client.shutdown()
    }
}
