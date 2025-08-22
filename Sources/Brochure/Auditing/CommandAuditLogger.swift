import ArgumentParser
import Foundation
import Logging

/// Command audit logging wrapper that integrates audit logging with CLI command execution.
///
/// `CommandAuditLogger` provides a convenient wrapper around `AuditLogger` specifically designed
/// for CLI command execution scenarios. It automatically captures command context, timing,
/// and outcomes for comprehensive audit trails.
///
/// ## Key Features
///
/// - **Automatic Context Capture**: Captures command name, arguments, and execution environment
/// - **Timing Measurement**: Tracks command execution duration for performance monitoring
/// - **Error Handling**: Captures and logs command failures with detailed error information
/// - **User Context**: Records the system user executing commands for security tracking
/// - **Environment Sanitization**: Safely logs relevant environment variables without credentials
///
/// ## Usage Examples
///
/// ```swift
/// // Basic command audit logging
/// let commandLogger = CommandAuditLogger()
///
/// try await commandLogger.auditCommand(
///     command: "upload",
///     arguments: ["--profile", "production", "NeonLaw"]
/// ) {
///     // Execute the actual command
///     try await performUpload()
/// }
///
/// // With custom environment context
/// try await commandLogger.auditCommandWithContext(
///     command: "bootstrap",
///     arguments: ["--template", "landing-page", "MyProject"],
///     environment: ["DEPLOYMENT_ENV": "production"]
/// ) {
///     try await createBootstrapProject()
/// }
/// ```
public struct CommandAuditLogger {
    private let auditLogger: AuditLogger
    private let systemLogger: Logger

    /// Initializes the command audit logger.
    ///
    /// - Parameters:
    ///   - auditLogger: The underlying audit logger to use
    ///   - systemLogger: Optional system logger for real-time output
    public init(
        auditLogger: AuditLogger? = nil,
        systemLogger: Logger? = nil
    ) {
        self.auditLogger = auditLogger ?? AuditLogger()
        self.systemLogger = systemLogger ?? Logger(label: "CommandAuditLogger")
    }

    /// Audits the execution of a CLI command with automatic context capture.
    ///
    /// This method wraps command execution with comprehensive audit logging, including
    /// timing, error handling, and context capture. It's the primary method for auditing
    /// CLI command execution.
    ///
    /// - Parameters:
    ///   - command: The command name being executed
    ///   - arguments: Command-line arguments provided
    ///   - user: Optional user override (defaults to current system user)
    ///   - workingDirectory: Optional working directory override
    ///   - environment: Additional environment context to capture
    ///   - operation: The command operation to execute and audit
    /// - Returns: The result of the command operation
    /// - Throws: Any error thrown by the command operation
    public func auditCommand<T>(
        command: String,
        arguments: [String] = [],
        user: String? = nil,
        workingDirectory: String? = nil,
        environment: [String: String] = [:],
        operation: () async throws -> T
    ) async throws -> T {
        let startTime = Date()
        let commandId = UUID()

        // Log command start
        systemLogger.info(
            "🚀 Starting command execution",
            metadata: [
                "command": .string(command),
                "arguments": .string(arguments.joined(separator: " ")),
                "command_id": .string(commandId.uuidString),
            ]
        )

        do {
            // Execute the command
            let result = try await operation()
            let duration = Date().timeIntervalSince(startTime)

            // Log successful completion
            await auditLogger.logCommand(
                command: command,
                arguments: arguments,
                user: user,
                workingDirectory: workingDirectory,
                environment: mergeEnvironment(environment),
                outcome: .success,
                duration: duration
            )

            systemLogger.info(
                "✅ Command completed successfully",
                metadata: [
                    "command": .string(command),
                    "duration": .stringConvertible(String(format: "%.3f", duration)),
                    "command_id": .string(commandId.uuidString),
                ]
            )

            return result

        } catch {
            let duration = Date().timeIntervalSince(startTime)

            // Log command failure
            await auditLogger.logCommand(
                command: command,
                arguments: arguments,
                user: user,
                workingDirectory: workingDirectory,
                environment: mergeEnvironment(environment),
                outcome: .failure,
                duration: duration,
                errorMessage: error.localizedDescription
            )

            systemLogger.error(
                "❌ Command failed",
                metadata: [
                    "command": .string(command),
                    "error": .string(error.localizedDescription),
                    "duration": .stringConvertible(String(format: "%.3f", duration)),
                    "command_id": .string(commandId.uuidString),
                ]
            )

            throw error
        }
    }

    /// Audits command execution with enhanced context from ArgumentParser.
    ///
    /// This method provides integration with Swift ArgumentParser by automatically
    /// extracting command context from ParsableCommand instances.
    ///
    /// - Parameters:
    ///   - parsableCommand: The ParsableCommand instance being executed
    ///   - operation: The command operation to execute and audit
    /// - Returns: The result of the command operation
    /// - Throws: Any error thrown by the command operation
    public func auditParsableCommand<T, Command: ParsableCommand>(
        _ parsableCommand: Command,
        operation: () async throws -> T
    ) async throws -> T {
        let commandName = String(describing: type(of: parsableCommand))
            .replacingOccurrences(of: "Command", with: "")
            .lowercased()

        // Extract arguments from the command line if available
        let arguments = Array(CommandLine.arguments.dropFirst())

        return try await auditCommand(
            command: commandName,
            arguments: arguments,
            operation: operation
        )
    }

    /// Logs a security event during command execution.
    ///
    /// This method should be called when security-sensitive operations occur during
    /// command execution, such as credential access or privilege escalation.
    ///
    /// - Parameters:
    ///   - action: The security action being performed
    ///   - resource: The resource being accessed
    ///   - profile: AWS profile involved (if applicable)
    ///   - outcome: The outcome of the security operation
    ///   - securityLevel: Optional security level classification
    ///   - metadata: Additional security metadata
    public func logSecurityEvent(
        action: String,
        resource: String,
        profile: String? = nil,
        outcome: AuditOutcome,
        securityLevel: String? = nil,
        metadata: [String: String] = [:]
    ) async {
        await auditLogger.logSecurityEvent(
            action: action,
            resource: resource,
            profile: profile,
            outcome: outcome,
            securityLevel: securityLevel,
            metadata: metadata
        )

        let outcomeEmoji = outcome == .success ? "🔓" : "🚨"
        systemLogger.info(
            "\(outcomeEmoji) Security event",
            metadata: [
                "action": .string(action),
                "resource": .string(resource),
                "outcome": .string(outcome.rawValue),
            ]
        )
    }

    /// Logs a file system operation during command execution.
    ///
    /// This method should be called when commands perform file system operations
    /// that need to be tracked for compliance or security purposes.
    ///
    /// - Parameters:
    ///   - operation: The file operation type (create, modify, delete, etc.)
    ///   - path: The file or directory path
    ///   - outcome: The outcome of the file operation
    ///   - metadata: Additional file operation metadata
    public func logFileOperation(
        operation: String,
        path: String,
        outcome: AuditOutcome,
        metadata: [String: String] = [:]
    ) async {
        await auditLogger.logFileOperation(
            operation: operation,
            path: path,
            outcome: outcome,
            metadata: metadata
        )

        let outcomeEmoji = outcome == .success ? "📁" : "🚫"
        systemLogger.debug(
            "\(outcomeEmoji) File operation",
            metadata: [
                "operation": .string(operation),
                "path": .string(path),
                "outcome": .string(outcome.rawValue),
            ]
        )
    }

    /// Creates a nested audit logger for sub-operations within a command.
    ///
    /// This method creates a child logger that inherits the parent command context
    /// while adding its own specific operation details.
    ///
    /// - Parameters:
    ///   - parentCommand: The parent command name
    ///   - subOperation: The sub-operation name
    /// - Returns: A new CommandAuditLogger configured for the sub-operation
    public func createSubOperationLogger(
        parentCommand: String,
        subOperation: String
    ) -> CommandAuditLogger {
        let subLogger = Logger(label: "CommandAuditLogger.\(parentCommand).\(subOperation)")
        return CommandAuditLogger(
            auditLogger: auditLogger,
            systemLogger: subLogger
        )
    }

    // MARK: - Private Helpers

    private func mergeEnvironment(_ additional: [String: String]) -> [String: String] {
        var environment = getCurrentEnvironmentContext()

        // Add additional environment variables
        for (key, value) in additional {
            environment[key] = value
        }

        return environment
    }

    private func getCurrentEnvironmentContext() -> [String: String] {
        let relevantKeys = [
            "AWS_PROFILE",
            "AWS_REGION",
            "DEPLOYMENT_ENV",
            "USER",
            "HOME",
            "PWD",
        ]

        var context: [String: String] = [:]
        let processEnvironment = ProcessInfo.processInfo.environment

        for key in relevantKeys {
            if let value = processEnvironment[key] {
                context[key] = value
            }
        }

        return context
    }
}

// MARK: - Command Integration Extensions

extension CommandAuditLogger {
    /// Convenience method for auditing upload operations.
    ///
    /// - Parameters:
    ///   - siteName: The site being uploaded
    ///   - profile: AWS profile being used
    ///   - environment: Deployment environment
    ///   - operation: The upload operation to execute
    /// - Returns: The result of the upload operation
    /// - Throws: Any error thrown by the upload operation
    public func auditUpload<T>(
        siteName: String,
        profile: String?,
        environment: String?,
        operation: () async throws -> T
    ) async throws -> T {
        var arguments = [siteName]
        if let profile = profile {
            arguments.append(contentsOf: ["--profile", profile])
        }
        if let environment = environment {
            arguments.append(contentsOf: ["--environment", environment])
        }

        return try await auditCommand(
            command: "upload",
            arguments: arguments,
            environment: [
                "SITE_NAME": siteName,
                "AWS_PROFILE": profile ?? "default",
                "DEPLOYMENT_ENV": environment ?? "development",
            ],
            operation: operation
        )
    }

    /// Convenience method for auditing bootstrap operations.
    ///
    /// - Parameters:
    ///   - projectName: The project being created
    ///   - template: Template type being used
    ///   - operation: The bootstrap operation to execute
    /// - Returns: The result of the bootstrap operation
    /// - Throws: Any error thrown by the bootstrap operation
    public func auditBootstrap<T>(
        projectName: String,
        template: String?,
        operation: () async throws -> T
    ) async throws -> T {
        var arguments = [projectName]
        if let template = template {
            arguments.append(contentsOf: ["--template", template])
        }

        return try await auditCommand(
            command: "bootstrap",
            arguments: arguments,
            environment: [
                "PROJECT_NAME": projectName,
                "TEMPLATE_TYPE": template ?? "default",
            ],
            operation: operation
        )
    }

    /// Convenience method for auditing profile management operations.
    ///
    /// - Parameters:
    ///   - subcommand: The profiles subcommand (store, list, show, etc.)
    ///   - profileName: The profile being managed
    ///   - operation: The profile operation to execute
    /// - Returns: The result of the profile operation
    /// - Throws: Any error thrown by the profile operation
    public func auditProfileOperation<T>(
        subcommand: String,
        profileName: String?,
        operation: () async throws -> T
    ) async throws -> T {
        var arguments = [subcommand]
        if let profileName = profileName {
            arguments.append(contentsOf: ["--profile", profileName])
        }

        return try await auditCommand(
            command: "profiles",
            arguments: arguments,
            environment: [
                "PROFILE_OPERATION": subcommand,
                "TARGET_PROFILE": profileName ?? "unknown",
            ],
            operation: operation
        )
    }
}
