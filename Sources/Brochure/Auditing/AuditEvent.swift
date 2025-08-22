import Foundation

/// Structured audit event for comprehensive logging and compliance tracking.
///
/// `AuditEvent` provides a standardized format for all audit-worthy activities
/// in the Brochure CLI, including command execution, AWS operations, security
/// events, and file system operations.
public struct AuditEvent: Codable, Sendable {
    /// Unique identifier for this audit event.
    public let id: UUID

    /// Timestamp when the event occurred.
    public let timestamp: Date

    /// Category of the audit event.
    public let category: AuditCategory

    /// Specific action that was performed.
    public let action: String

    /// Outcome of the operation.
    public let outcome: AuditOutcome

    /// Detailed information specific to the event type.
    public let details: AuditEventDetails

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        category: AuditCategory,
        action: String,
        outcome: AuditOutcome,
        details: AuditEventDetails
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.action = action
        self.outcome = outcome
        self.details = details
    }
}

/// Category of audit events for organizational purposes.
public enum AuditCategory: String, Codable, CaseIterable, Sendable {
    case command = "command"
    case awsOperation = "aws_operation"
    case security = "security"
    case fileSystem = "file_system"
}

/// Outcome of an audited operation.
public enum AuditOutcome: String, Codable, CaseIterable, Sendable {
    case success = "success"
    case failure = "failure"
    case warning = "warning"
    case partial = "partial"
}

/// Type-erased container for audit event details.
public enum AuditEventDetails: Codable, Sendable {
    case command(AuditEvent.CommandDetails)
    case awsOperation(AuditEvent.AWSOperationDetails)
    case security(AuditEvent.SecurityDetails)
    case fileSystem(AuditEvent.FileSystemDetails)

    private enum CodingKeys: String, CodingKey {
        case type, data
    }

    private enum DetailType: String, Codable {
        case command, awsOperation, security, fileSystem
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(DetailType.self, forKey: .type)

        switch type {
        case .command:
            let details = try container.decode(AuditEvent.CommandDetails.self, forKey: .data)
            self = .command(details)
        case .awsOperation:
            let details = try container.decode(AuditEvent.AWSOperationDetails.self, forKey: .data)
            self = .awsOperation(details)
        case .security:
            let details = try container.decode(AuditEvent.SecurityDetails.self, forKey: .data)
            self = .security(details)
        case .fileSystem:
            let details = try container.decode(AuditEvent.FileSystemDetails.self, forKey: .data)
            self = .fileSystem(details)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .command(let details):
            try container.encode(DetailType.command, forKey: .type)
            try container.encode(details, forKey: .data)
        case .awsOperation(let details):
            try container.encode(DetailType.awsOperation, forKey: .type)
            try container.encode(details, forKey: .data)
        case .security(let details):
            try container.encode(DetailType.security, forKey: .type)
            try container.encode(details, forKey: .data)
        case .fileSystem(let details):
            try container.encode(DetailType.fileSystem, forKey: .type)
            try container.encode(details, forKey: .data)
        }
    }
}

// MARK: - Audit Event Details

extension AuditEvent {
    /// Details for CLI command execution events.
    public struct CommandDetails: Codable, Sendable {
        public let command: String
        public let arguments: [String]
        public let user: String
        public let workingDirectory: String
        public let relevantEnvironment: [String: String]
        public let duration: TimeInterval?
        public let errorMessage: String?

        public init(
            command: String,
            arguments: [String],
            user: String,
            workingDirectory: String,
            relevantEnvironment: [String: String],
            duration: TimeInterval? = nil,
            errorMessage: String? = nil
        ) {
            self.command = command
            self.arguments = arguments
            self.user = user
            self.workingDirectory = workingDirectory
            self.relevantEnvironment = relevantEnvironment
            self.duration = duration
            self.errorMessage = errorMessage
        }
    }

    /// Details for AWS API operation events.
    public struct AWSOperationDetails: Codable, Sendable {
        public let operation: AWSOperation
        public let service: String
        public let resource: String
        public let profile: String?
        public let region: String?
        public let duration: TimeInterval?
        public let requestId: String?
        public let errorCode: String?
        public let errorMessage: String?

        public init(
            operation: AWSOperation,
            service: String,
            resource: String,
            profile: String?,
            region: String?,
            duration: TimeInterval? = nil,
            requestId: String? = nil,
            errorCode: String? = nil,
            errorMessage: String? = nil
        ) {
            self.operation = operation
            self.service = service
            self.resource = resource
            self.profile = profile
            self.region = region
            self.duration = duration
            self.requestId = requestId
            self.errorCode = errorCode
            self.errorMessage = errorMessage
        }
    }

    /// Details for security-sensitive events.
    public struct SecurityDetails: Codable, Sendable {
        public let action: String
        public let resource: String
        public let profile: String?
        public let securityLevel: String?
        public let metadata: [String: String]

        public init(
            action: String,
            resource: String,
            profile: String?,
            securityLevel: String? = nil,
            metadata: [String: String] = [:]
        ) {
            self.action = action
            self.resource = resource
            self.profile = profile
            self.securityLevel = securityLevel
            self.metadata = metadata
        }
    }

    /// Details for file system operation events.
    public struct FileSystemDetails: Codable, Sendable {
        public let operation: String
        public let path: String
        public let metadata: [String: String]

        public init(
            operation: String,
            path: String,
            metadata: [String: String] = [:]
        ) {
            self.operation = operation
            self.path = path
            self.metadata = metadata
        }
    }
}

/// AWS operation types for audit logging.
public enum AWSOperation: String, Codable, CaseIterable, Sendable {
    // S3 Operations
    case s3Upload = "s3:PutObject"
    case s3Download = "s3:GetObject"
    case s3List = "s3:ListBucket"
    case s3Delete = "s3:DeleteObject"
    case s3HeadObject = "s3:HeadObject"
    case s3GetBucketLocation = "s3:GetBucketLocation"

    // STS Operations
    case stsAssumeRole = "sts:AssumeRole"
    case stsGetCallerIdentity = "sts:GetCallerIdentity"
    case stsGetSessionToken = "sts:GetSessionToken"

    // IAM Operations
    case iamGetUser = "iam:GetUser"
    case iamListAccessKeys = "iam:ListAccessKeys"
    case iamGetRole = "iam:GetRole"

    // CloudFront Operations
    case cloudFrontCreateInvalidation = "cloudfront:CreateInvalidation"
    case cloudFrontGetDistribution = "cloudfront:GetDistribution"

    // Generic operations
    case awsConfigQuery = "aws:Config"
    case awsCredentialValidation = "aws:ValidateCredentials"

    /// Default AWS service for this operation.
    public var defaultService: String {
        switch self {
        case .s3Upload, .s3Download, .s3List, .s3Delete, .s3HeadObject, .s3GetBucketLocation:
            return "s3"
        case .stsAssumeRole, .stsGetCallerIdentity, .stsGetSessionToken:
            return "sts"
        case .iamGetUser, .iamListAccessKeys, .iamGetRole:
            return "iam"
        case .cloudFrontCreateInvalidation, .cloudFrontGetDistribution:
            return "cloudfront"
        case .awsConfigQuery, .awsCredentialValidation:
            return "aws"
        }
    }

    /// Whether this operation is considered security-sensitive.
    public var isSecuritySensitive: Bool {
        switch self {
        case .stsAssumeRole, .stsGetCallerIdentity, .stsGetSessionToken,
            .iamGetUser, .iamListAccessKeys, .iamGetRole,
            .awsCredentialValidation:
            return true
        case .s3Upload, .s3Download, .s3List, .s3Delete, .s3HeadObject, .s3GetBucketLocation,
            .cloudFrontCreateInvalidation, .cloudFrontGetDistribution,
            .awsConfigQuery:
            return false
        }
    }
}

/// Audit event creation convenience extensions.
extension AuditEventDetails {
    public static func command(
        command: String,
        arguments: [String] = [],
        user: String,
        workingDirectory: String,
        relevantEnvironment: [String: String] = [:],
        duration: TimeInterval? = nil,
        errorMessage: String? = nil
    ) -> AuditEventDetails {
        .command(
            AuditEvent.CommandDetails(
                command: command,
                arguments: arguments,
                user: user,
                workingDirectory: workingDirectory,
                relevantEnvironment: relevantEnvironment,
                duration: duration,
                errorMessage: errorMessage
            )
        )
    }

    public static func awsOperation(
        operation: AWSOperation,
        service: String? = nil,
        resource: String,
        profile: String?,
        region: String?,
        duration: TimeInterval? = nil,
        requestId: String? = nil,
        errorCode: String? = nil,
        errorMessage: String? = nil
    ) -> AuditEventDetails {
        .awsOperation(
            AuditEvent.AWSOperationDetails(
                operation: operation,
                service: service ?? operation.defaultService,
                resource: resource,
                profile: profile,
                region: region,
                duration: duration,
                requestId: requestId,
                errorCode: errorCode,
                errorMessage: errorMessage
            )
        )
    }

    public static func security(
        action: String,
        resource: String,
        profile: String?,
        securityLevel: String? = nil,
        metadata: [String: String] = [:]
    ) -> AuditEventDetails {
        .security(
            AuditEvent.SecurityDetails(
                action: action,
                resource: resource,
                profile: profile,
                securityLevel: securityLevel,
                metadata: metadata
            )
        )
    }

    public static func fileSystem(
        operation: String,
        path: String,
        metadata: [String: String] = [:]
    ) -> AuditEventDetails {
        .fileSystem(
            AuditEvent.FileSystemDetails(
                operation: operation,
                path: path,
                metadata: metadata
            )
        )
    }
}
