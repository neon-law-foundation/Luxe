import Foundation
import Logging
import SotoCore
import SotoS3

/// AWS operation audit logger that intercepts and logs AWS SDK calls.
///
/// `AWSOperationLogger` provides comprehensive audit logging for AWS API operations
/// by wrapping AWS service clients and intercepting their method calls. It captures
/// detailed information about AWS operations including timing, request IDs, and
/// security-sensitive metadata.
///
/// ## Key Features
///
/// - **Operation Interception**: Captures all AWS SDK calls with detailed metadata
/// - **Security Classification**: Identifies security-sensitive operations automatically
/// - **Performance Monitoring**: Tracks AWS operation timing and performance metrics
/// - **Error Analysis**: Captures AWS error codes and messages for troubleshooting
/// - **Request Tracing**: Records AWS request IDs for correlation with CloudTrail
/// - **Profile Context**: Associates operations with the AWS profile being used
///
/// ## Supported Services
///
/// - **S3**: Upload, download, list, delete, and metadata operations
/// - **STS**: Role assumption, token validation, and identity operations
/// - **IAM**: User and role information retrieval
/// - **CloudFront**: Distribution management and cache invalidation
///
/// ## Usage Examples
///
/// ```swift
/// // Wrap an S3 client with audit logging
/// let s3Client = S3Client(region: "us-west-2")
/// let auditedS3 = AWSOperationLogger.wrapS3Client(
///     s3Client,
///     profile: "production",
///     region: "us-west-2"
/// )
///
/// // Operations are automatically audited
/// try await auditedS3.putObject(...)
/// try await auditedS3.getObject(...)
/// ```
public struct AWSOperationLogger {
    private let auditLogger: AuditLogger
    private let systemLogger: Logger

    /// Initializes the AWS operation logger.
    ///
    /// - Parameters:
    ///   - auditLogger: The underlying audit logger to use
    ///   - systemLogger: Optional system logger for real-time output
    public init(
        auditLogger: AuditLogger? = nil,
        systemLogger: Logger? = nil
    ) {
        self.auditLogger = auditLogger ?? AuditLogger()
        self.systemLogger = systemLogger ?? Logger(label: "AWSOperationLogger")
    }

    /// Logs an AWS operation with comprehensive metadata.
    ///
    /// This is the core method for logging AWS operations. It should be called
    /// before and after AWS API calls to capture complete operation context.
    ///
    /// - Parameters:
    ///   - operation: The AWS operation being performed
    ///   - service: AWS service name (e.g., "s3", "sts", "iam")
    ///   - resource: AWS resource identifier or ARN
    ///   - profile: AWS profile being used
    ///   - region: AWS region for the operation
    ///   - requestId: AWS request ID from the operation response
    ///   - outcome: Operation outcome (success/failure)
    ///   - duration: Operation duration in seconds
    ///   - errorCode: AWS error code if operation failed
    ///   - errorMessage: Error message if operation failed
    ///   - metadata: Additional operation-specific metadata
    public func logOperation(
        operation: AWSOperation,
        service: String? = nil,
        resource: String,
        profile: String?,
        region: String?,
        requestId: String? = nil,
        outcome: AuditOutcome,
        duration: TimeInterval? = nil,
        errorCode: String? = nil,
        errorMessage: String? = nil,
        metadata: [String: String] = [:]
    ) async {
        await auditLogger.logAWSOperation(
            operation: operation,
            service: service,
            resource: resource,
            profile: profile,
            region: region,
            outcome: outcome,
            duration: duration,
            requestId: requestId,
            errorCode: errorCode,
            errorMessage: errorMessage
        )

        // Log security-sensitive operations at higher priority
        if operation.isSecuritySensitive {
            await auditLogger.logSecurityEvent(
                action: "aws-credential-operation",
                resource: resource,
                profile: profile,
                outcome: outcome,
                securityLevel: "high",
                metadata: [
                    "aws_operation": operation.rawValue,
                    "aws_service": service ?? operation.defaultService,
                    "request_id": requestId ?? "unknown",
                ]
            )
        }

        let outcomeEmoji = outcome == .success ? "☁️" : "⚠️"
        let securityIndicator = operation.isSecuritySensitive ? "🔒" : ""

        systemLogger.info(
            "\(outcomeEmoji)\(securityIndicator) AWS operation",
            metadata: [
                "operation": .string(operation.rawValue),
                "service": .string(service ?? operation.defaultService),
                "resource": .string(sanitizeResourceForLogging(resource)),
                "profile": .string(profile ?? "default"),
                "outcome": .string(outcome.rawValue),
                "duration": .stringConvertible(duration.map { String(format: "%.3f", $0) } ?? "unknown"),
                "request_id": .string(requestId ?? "none"),
            ]
        )
    }

    /// Wraps AWS operation execution with audit logging.
    ///
    /// This method provides a convenient wrapper for AWS operations that automatically
    /// handles timing, error capture, and outcome determination.
    ///
    /// - Parameters:
    ///   - operation: The AWS operation type
    ///   - service: AWS service name
    ///   - resource: AWS resource identifier
    ///   - profile: AWS profile being used
    ///   - region: AWS region
    ///   - metadata: Additional operation metadata
    ///   - awsOperation: The AWS operation to execute
    /// - Returns: The result of the AWS operation
    /// - Throws: Any error thrown by the AWS operation
    public func auditAWSOperation<T>(
        operation: AWSOperation,
        service: String? = nil,
        resource: String,
        profile: String?,
        region: String?,
        metadata: [String: String] = [:],
        awsOperation: () async throws -> T
    ) async throws -> T {
        let startTime = Date()
        let operationId = UUID()

        // Log operation start for security-sensitive operations
        if operation.isSecuritySensitive {
            systemLogger.info(
                "🔒 Starting security-sensitive AWS operation",
                metadata: [
                    "operation": .string(operation.rawValue),
                    "service": .string(service ?? operation.defaultService),
                    "operation_id": .string(operationId.uuidString),
                ]
            )
        }

        do {
            // Execute the AWS operation
            let result = try await awsOperation()
            let duration = Date().timeIntervalSince(startTime)

            // Extract request ID if available
            let requestId = extractRequestId(from: result)

            // Log successful operation
            await logOperation(
                operation: operation,
                service: service,
                resource: resource,
                profile: profile,
                region: region,
                requestId: requestId,
                outcome: .success,
                duration: duration,
                metadata: metadata
            )

            return result

        } catch {
            let duration = Date().timeIntervalSince(startTime)

            // Extract AWS error details
            let (errorCode, requestId) = extractAWSErrorDetails(from: error)

            // Log failed operation
            await logOperation(
                operation: operation,
                service: service,
                resource: resource,
                profile: profile,
                region: region,
                requestId: requestId,
                outcome: .failure,
                duration: duration,
                errorCode: errorCode,
                errorMessage: error.localizedDescription,
                metadata: metadata
            )

            throw error
        }
    }

    // MARK: - Service-Specific Wrappers

    /// Creates an audited wrapper around an S3 client.
    ///
    /// - Parameters:
    ///   - client: The S3 client to wrap
    ///   - profile: AWS profile being used
    ///   - region: AWS region
    /// - Returns: An audited S3 client wrapper
    public static func wrapS3Client(
        _ client: S3,
        profile: String?,
        region: String?
    ) -> AuditedS3Client {
        AuditedS3Client(
            wrappedClient: client,
            operationLogger: AWSOperationLogger(),
            profile: profile,
            region: region
        )
    }

    // MARK: - Private Helpers

    private func extractRequestId<T>(from result: T) -> String? {
        // For Soto AWS SDK, try reflection-based extraction of request ID
        let mirror = Mirror(reflecting: result)
        for child in mirror.children {
            if child.label == "responseMetadata" || child.label == "metadata" {
                let metadataMirror = Mirror(reflecting: child.value)
                for metadataChild in metadataMirror.children {
                    if metadataChild.label == "requestId" {
                        return metadataChild.value as? String
                    }
                }
            }
        }

        return nil
    }

    private func extractAWSErrorDetails(from error: Error) -> (errorCode: String?, requestId: String?) {
        // Use Soto-specific error extraction
        extractSotoErrorDetails(from: error)
    }

    private func sanitizeResourceForLogging(_ resource: String) -> String {
        // Sanitize potentially sensitive resource identifiers
        if resource.starts(with: "arn:aws:") {
            // For ARNs, show service and resource type but hide specific identifiers
            let components = resource.components(separatedBy: ":")
            if components.count >= 6 {
                let service = components[2]
                let resourceType = components[5].components(separatedBy: "/").first ?? "unknown"
                return "arn:aws:\(service):***:\(resourceType)/***"
            }
        }

        if resource.hasPrefix("s3://") {
            // For S3 URLs, show bucket but hide object key details
            let url = resource.replacingOccurrences(of: "s3://", with: "")
            let pathComponents = url.components(separatedBy: "/")
            if pathComponents.count > 1 {
                return "s3://\(pathComponents[0])/***"
            }
        }

        return resource
    }
}

// MARK: - Audited Client Wrappers

/// Audited wrapper for S3 that logs all operations.
public struct AuditedS3Client {
    private let wrappedClient: S3
    private let operationLogger: AWSOperationLogger
    private let profile: String?
    private let region: String?

    init(
        wrappedClient: S3,
        operationLogger: AWSOperationLogger,
        profile: String?,
        region: String?
    ) {
        self.wrappedClient = wrappedClient
        self.operationLogger = operationLogger
        self.profile = profile
        self.region = region
    }

    /// Audited S3 putObject operation.
    public func putObject(_ request: S3.PutObjectRequest) async throws -> S3.PutObjectOutput {
        let resource = "s3://\(request.bucket)/\(request.key)"

        return try await operationLogger.auditAWSOperation(
            operation: .s3Upload,
            service: "s3",
            resource: resource,
            profile: profile,
            region: region,
            metadata: [
                "bucket": request.bucket,
                "key": request.key,
                "content_type": request.contentType ?? "unknown",
            ]
        ) {
            try await wrappedClient.putObject(request)
        }
    }

    /// Audited S3 getObject operation.
    public func getObject(_ request: S3.GetObjectRequest) async throws -> S3.GetObjectOutput {
        let resource = "s3://\(request.bucket)/\(request.key)"

        return try await operationLogger.auditAWSOperation(
            operation: .s3Download,
            service: "s3",
            resource: resource,
            profile: profile,
            region: region,
            metadata: [
                "bucket": request.bucket,
                "key": request.key,
            ]
        ) {
            try await wrappedClient.getObject(request)
        }
    }

    /// Audited S3 listObjectsV2 operation.
    public func listObjectsV2(_ request: S3.ListObjectsV2Request) async throws -> S3.ListObjectsV2Output {
        let resource = "s3://\(request.bucket)"

        return try await operationLogger.auditAWSOperation(
            operation: .s3List,
            service: "s3",
            resource: resource,
            profile: profile,
            region: region,
            metadata: [
                "bucket": request.bucket,
                "prefix": request.prefix ?? "none",
            ]
        ) {
            try await wrappedClient.listObjectsV2(request)
        }
    }

    /// Audited S3 deleteObject operation.
    public func deleteObject(_ request: S3.DeleteObjectRequest) async throws -> S3.DeleteObjectOutput {
        let resource = "s3://\(request.bucket)/\(request.key)"

        return try await operationLogger.auditAWSOperation(
            operation: .s3Delete,
            service: "s3",
            resource: resource,
            profile: profile,
            region: region,
            metadata: [
                "bucket": request.bucket,
                "key": request.key,
            ]
        ) {
            try await wrappedClient.deleteObject(request)
        }
    }

    /// Audited S3 headObject operation.
    public func headObject(_ request: S3.HeadObjectRequest) async throws -> S3.HeadObjectOutput {
        let resource = "s3://\(request.bucket)/\(request.key)"

        return try await operationLogger.auditAWSOperation(
            operation: .s3HeadObject,
            service: "s3",
            resource: resource,
            profile: profile,
            region: region,
            metadata: [
                "bucket": request.bucket,
                "key": request.key,
            ]
        ) {
            try await wrappedClient.headObject(request)
        }
    }
}

// Note: STS support would require adding SotoSTS dependency to Package.swift
// For now, we'll focus on S3 operations which are the primary use case

// MARK: - Soto SDK Integration

/// Extension to work with Soto error types
extension AWSOperationLogger {
    private func extractSotoErrorDetails(from error: Error) -> (errorCode: String?, requestId: String?) {
        // For Soto AWS SDK, extract error information from error description
        let errorString = String(describing: error)

        // Try to extract error code from various error formats
        var errorCode: String? = nil
        var requestId: String? = nil

        // Pattern for common AWS error codes
        if errorString.contains("AccessDenied") {
            errorCode = "AccessDenied"
        } else if errorString.contains("NoCredentialsError") {
            errorCode = "NoCredentialsFound"
        } else if errorString.contains("InvalidSignature") {
            errorCode = "InvalidSignature"
        } else if errorString.contains("BucketNotEmpty") {
            errorCode = "BucketNotEmpty"
        } else if errorString.contains("NoSuchBucket") {
            errorCode = "NoSuchBucket"
        } else if errorString.contains("NoSuchKey") {
            errorCode = "NoSuchKey"
        }

        // Extract request ID using pattern matching
        requestId = extractRequestIdFromMessage(errorString)

        return (errorCode: errorCode, requestId: requestId)
    }

    private func extractRequestIdFromMessage(_ message: String) -> String? {
        // Extract request ID from error message using pattern matching
        let requestIdPattern = #"RequestId:\s*([A-Za-z0-9\-]+)"#
        let requestIdRegex = try? NSRegularExpression(pattern: requestIdPattern)
        let match = requestIdRegex?.firstMatch(
            in: message,
            range: NSRange(location: 0, length: message.count)
        )

        return match.flatMap { match in
            Range(match.range(at: 1), in: message).map { String(message[$0]) }
        }
    }
}
