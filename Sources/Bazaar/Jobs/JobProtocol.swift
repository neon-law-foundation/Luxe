import Fluent
import Foundation
import Logging
import NIOCore
import Queues
import Vapor

// This file previously contained the BazaarJob protocol and BazaarJobWrapper
// These have been simplified to use direct Vapor Job implementations like SimpleEmailJob
// for better compatibility and reduced complexity.

// The enhanced job context is preserved for potential future use:

/// Enhanced job context that provides access to Bazaar services
public struct BazaarJobContext {
    /// The original queue context
    public let queueContext: QueueContext

    /// Database connection for performing database operations
    public let database: Database

    /// Logger for job-specific logging
    public let logger: Logger

    /// Email service for sending emails
    public let emailService: EmailService

    /// Application reference for accessing other services
    public let application: Application

    public init(
        queueContext: QueueContext,
        database: Database,
        logger: Logger,
        emailService: EmailService,
        application: Application
    ) {
        self.queueContext = queueContext
        self.database = database
        self.logger = logger
        self.emailService = emailService
        self.application = application
    }
}

/// Errors that can occur during job execution
public enum BazaarJobError: Error, LocalizedError {
    case serviceNotFound(String)
    case invalidPayload(String)
    case executionFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .serviceNotFound(let service):
            return "Required service not found: \(service)"
        case .invalidPayload(let message):
            return "Invalid job payload: \(message)"
        case .executionFailed(let error):
            return "Job execution failed: \(error.localizedDescription)"
        }
    }
}
