import Foundation
import Logging

/// Centralized audit logging manager for all CLI operations and AWS API calls.
///
/// `AuditLogger` provides comprehensive audit trail functionality with structured logging,
/// compliance reporting, and security monitoring capabilities. All security-sensitive
/// operations are logged with appropriate detail levels and metadata.
///
/// ## Key Features
///
/// - **Structured Audit Events**: Type-safe audit event definitions
/// - **Security Compliance**: SOC2/GDPR-compatible audit trails
/// - **Performance Monitoring**: Operation timing and resource usage tracking
/// - **Security Analysis**: Credential usage and access pattern monitoring
/// - **File-Based Persistence**: Local audit log storage with rotation
/// - **JSON Format**: Machine-readable structured audit logs
///
/// ## Usage Examples
///
/// ```swift
/// let auditLogger = AuditLogger()
///
/// // Audit CLI command execution
/// await auditLogger.logCommand(
///     command: "upload",
///     arguments: ["--profile", "production", "NeonLaw"],
///     user: ProcessInfo.processInfo.environment["USER"],
///     outcome: .success
/// )
///
/// // Audit AWS API calls
/// await auditLogger.logAWSOperation(
///     operation: .s3Upload,
///     resource: "s3://bucket/key",
///     profile: "production",
///     region: "us-east-1",
///     outcome: .success,
///     duration: 1.23
/// )
/// ```
public actor AuditLogger {
    private let logger: Logger
    private let auditFilePath: URL
    private let dateFormatter = ISO8601DateFormatter()
    private let jsonEncoder = JSONEncoder()

    /// Initializes the audit logger with file-based persistence.
    ///
    /// - Parameters:
    ///   - logger: Underlying logger for real-time output
    ///   - auditDirectory: Directory for audit log files (defaults to ~/.brochure/audit)
    public init(
        logger: Logger = Logger(label: "AuditLogger"),
        auditDirectory: URL? = nil
    ) {
        self.logger = logger

        // Setup audit file path
        let baseDirectory = auditDirectory ?? Self.defaultAuditDirectory()
        let dateString = DateFormatter.auditFileDate.string(from: Date())
        self.auditFilePath = baseDirectory.appendingPathComponent("brochure-\(dateString).audit.jsonl")

        // Ensure audit directory exists
        try? FileManager.default.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]  // Owner-only access
        )

        jsonEncoder.outputFormatting = [.sortedKeys]
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        logger.info(
            "🔍 Audit logging initialized",
            metadata: [
                "audit_file": .string(auditFilePath.path),
                "pid": .stringConvertible(ProcessInfo.processInfo.processIdentifier),
            ]
        )
    }

    /// Logs CLI command execution with full context.
    ///
    /// - Parameters:
    ///   - command: Command name that was executed
    ///   - arguments: Command-line arguments provided
    ///   - user: System user executing the command
    ///   - workingDirectory: Current working directory
    ///   - environment: Relevant environment variables
    ///   - outcome: Execution outcome (success/failure)
    ///   - duration: Command execution duration in seconds
    ///   - errorMessage: Error details if command failed
    public func logCommand(
        command: String,
        arguments: [String] = [],
        user: String? = nil,
        workingDirectory: String? = nil,
        environment: [String: String] = [:],
        outcome: AuditOutcome,
        duration: TimeInterval? = nil,
        errorMessage: String? = nil
    ) async {
        let event = AuditEvent(
            id: UUID(),
            timestamp: Date(),
            category: .command,
            action: command,
            outcome: outcome,
            details: .command(
                command: command,
                arguments: sanitizeArguments(arguments),
                user: user ?? ProcessInfo.processInfo.environment["USER"] ?? "unknown",
                workingDirectory: workingDirectory ?? FileManager.default.currentDirectoryPath,
                relevantEnvironment: sanitizeEnvironment(environment),
                duration: duration,
                errorMessage: errorMessage
            )
        )

        await writeAuditEvent(event)
        logToConsole(event)
    }

    /// Logs AWS API operations with security context.
    ///
    /// - Parameters:
    ///   - operation: Type of AWS operation performed
    ///   - service: AWS service name (e.g., "s3", "sts", "iam")
    ///   - resource: AWS resource identifier
    ///   - profile: AWS profile used for authentication
    ///   - region: AWS region for the operation
    ///   - outcome: Operation outcome
    ///   - duration: Operation duration in seconds
    ///   - requestId: AWS request ID for tracing
    ///   - errorCode: AWS error code if operation failed
    ///   - errorMessage: Error details if operation failed
    public func logAWSOperation(
        operation: AWSOperation,
        service: String? = nil,
        resource: String,
        profile: String?,
        region: String?,
        outcome: AuditOutcome,
        duration: TimeInterval? = nil,
        requestId: String? = nil,
        errorCode: String? = nil,
        errorMessage: String? = nil
    ) async {
        let event = AuditEvent(
            id: UUID(),
            timestamp: Date(),
            category: .awsOperation,
            action: operation.rawValue,
            outcome: outcome,
            details: .awsOperation(
                operation: operation,
                service: service ?? operation.defaultService,
                resource: sanitizeResourceIdentifier(resource),
                profile: profile,
                region: region,
                duration: duration,
                requestId: requestId,
                errorCode: errorCode,
                errorMessage: errorMessage
            )
        )

        await writeAuditEvent(event)
        logToConsole(event)
    }

    /// Logs security-sensitive events like credential access.
    ///
    /// - Parameters:
    ///   - action: Security action performed
    ///   - resource: Resource being accessed
    ///   - profile: Profile name involved
    ///   - outcome: Security operation outcome
    ///   - securityLevel: Security level of the operation
    ///   - metadata: Additional security metadata
    public func logSecurityEvent(
        action: String,
        resource: String,
        profile: String?,
        outcome: AuditOutcome,
        securityLevel: String? = nil,
        metadata: [String: String] = [:]
    ) async {
        let event = AuditEvent(
            id: UUID(),
            timestamp: Date(),
            category: .security,
            action: action,
            outcome: outcome,
            details: .security(
                action: action,
                resource: resource,
                profile: profile,
                securityLevel: securityLevel,
                metadata: metadata
            )
        )

        await writeAuditEvent(event)
        logToConsole(event)
    }

    /// Logs file system operations for compliance tracking.
    ///
    /// - Parameters:
    ///   - operation: File operation type
    ///   - path: File or directory path
    ///   - outcome: Operation outcome
    ///   - metadata: Additional file operation metadata
    public func logFileOperation(
        operation: String,
        path: String,
        outcome: AuditOutcome,
        metadata: [String: String] = [:]
    ) async {
        let event = AuditEvent(
            id: UUID(),
            timestamp: Date(),
            category: .fileSystem,
            action: operation,
            outcome: outcome,
            details: .fileSystem(
                operation: operation,
                path: sanitizeFilePath(path),
                metadata: metadata
            )
        )

        await writeAuditEvent(event)
        logToConsole(event)
    }

    /// Retrieves audit log entries within a date range.
    ///
    /// - Parameters:
    ///   - startDate: Start of date range
    ///   - endDate: End of date range
    ///   - category: Optional category filter
    /// - Returns: Array of audit events matching criteria
    public func getAuditEvents(
        from startDate: Date,
        to endDate: Date,
        category: AuditCategory? = nil
    ) async throws -> [AuditEvent] {
        var events: [AuditEvent] = []

        // Get list of audit files that might contain events in range
        let auditFiles = try getAuditFiles(covering: startDate...endDate)

        for file in auditFiles {
            let content = try String(contentsOf: file, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)

            for line in lines {
                guard !line.isEmpty else { continue }

                do {
                    let event = try JSONDecoder().decode(AuditEvent.self, from: line.data(using: .utf8)!)

                    // Filter by date range and category
                    if event.timestamp >= startDate && event.timestamp <= endDate {
                        if let category = category, event.category != category {
                            continue
                        }
                        events.append(event)
                    }
                } catch {
                    logger.warning(
                        "Failed to parse audit event",
                        metadata: [
                            "error": .string(error.localizedDescription),
                            "line": .string(String(line.prefix(100))),
                        ]
                    )
                }
            }
        }

        return events.sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - Private Implementation

    private func writeAuditEvent(_ event: AuditEvent) async {
        do {
            let data = try jsonEncoder.encode(event)
            let line = String(data: data, encoding: .utf8)! + "\n"

            // Append to audit file
            if FileManager.default.fileExists(atPath: auditFilePath.path) {
                let fileHandle = try FileHandle(forWritingTo: auditFilePath)
                defer { try? fileHandle.close() }
                try fileHandle.seekToEnd()
                try fileHandle.write(contentsOf: line.data(using: .utf8)!)
            } else {
                try line.write(to: auditFilePath, atomically: true, encoding: .utf8)
            }

        } catch {
            logger.error(
                "Failed to write audit event",
                metadata: [
                    "error": .string(error.localizedDescription),
                    "event_id": .string(event.id.uuidString),
                ]
            )
        }
    }

    private func logToConsole(_ event: AuditEvent) {
        let outcomeEmoji = event.outcome == .success ? "✅" : "❌"

        switch event.category {
        case .command:
            logger.info(
                "\(outcomeEmoji) Command executed",
                metadata: [
                    "command": .string(event.action),
                    "outcome": .string(event.outcome.rawValue),
                    "event_id": .string(event.id.uuidString),
                ]
            )

        case .awsOperation:
            logger.info(
                "\(outcomeEmoji) AWS operation",
                metadata: [
                    "operation": .string(event.action),
                    "outcome": .string(event.outcome.rawValue),
                    "event_id": .string(event.id.uuidString),
                ]
            )

        case .security:
            logger.info(
                "\(outcomeEmoji) Security event",
                metadata: [
                    "action": .string(event.action),
                    "outcome": .string(event.outcome.rawValue),
                    "event_id": .string(event.id.uuidString),
                ]
            )

        case .fileSystem:
            logger.debug(
                "\(outcomeEmoji) File operation",
                metadata: [
                    "operation": .string(event.action),
                    "outcome": .string(event.outcome.rawValue),
                    "event_id": .string(event.id.uuidString),
                ]
            )
        }
    }

    private func sanitizeArguments(_ arguments: [String]) -> [String] {
        arguments.map { arg in
            // Redact potential credentials in arguments
            if arg.starts(with: "AKIA") || arg.starts(with: "ASIA") {
                return String(arg.prefix(8)) + "***"
            }
            if arg.count == 40 && arg.allSatisfy({ $0.isLetter || $0.isNumber || "+=/".contains($0) }) {
                return String(arg.prefix(8)) + "***"
            }
            return arg
        }
    }

    private func sanitizeEnvironment(_ environment: [String: String]) -> [String: String] {
        let relevantKeys = ["AWS_PROFILE", "AWS_REGION", "DEPLOYMENT_ENV", "USER", "HOME"]
        return environment.filter { relevantKeys.contains($0.key) }
    }

    private func sanitizeResourceIdentifier(_ resource: String) -> String {
        // Keep resource identifiers but avoid logging sensitive paths
        if resource.starts(with: "/Users/") || resource.starts(with: "/home/") {
            return "~/" + resource.components(separatedBy: "/").suffix(2).joined(separator: "/")
        }
        return resource
    }

    private func sanitizeFilePath(_ path: String) -> String {
        sanitizeResourceIdentifier(path)
    }

    private static func defaultAuditDirectory() -> URL {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        return homeDirectory.appendingPathComponent(".brochure/audit")
    }

    private func getAuditFiles(covering dateRange: ClosedRange<Date>) throws -> [URL] {
        let auditDirectory = auditFilePath.deletingLastPathComponent()

        let files = try FileManager.default.contentsOfDirectory(
            at: auditDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )

        return files.filter { $0.pathExtension == "jsonl" && $0.lastPathComponent.contains("brochure-") }
    }
}

// MARK: - Supporting Types

extension DateFormatter {
    static let auditFileDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
