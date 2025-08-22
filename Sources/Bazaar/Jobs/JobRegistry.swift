import Foundation
import Logging
import Queues
import Vapor

/// Simple job registry for managing Vapor queue jobs
public actor JobRegistry: Sendable {
    private let logger: Logger

    public init(logger: Logger) {
        self.logger = logger
    }

    /// Register all jobs with the Vapor Queues system
    public func registerAll(with application: Application) {
        // Register SimpleEmailJob
        application.queues.add(SimpleEmailJob())

        logger.info("📧 SimpleEmailJob added to queues")
        logger.info("🚀 All jobs registered with Vapor Queues")
    }
}

/// Storage key for job registry in Vapor application
public struct JobRegistryKey: StorageKey {
    public typealias Value = JobRegistry
}

/// Extension to Application for job registry management
extension Application {
    /// Get or create the job registry
    public var jobRegistry: JobRegistry {
        get {
            guard let registry = storage[JobRegistryKey.self] else {
                let logger = Logger(label: "JobRegistry")
                let registry = JobRegistry(logger: logger)
                storage[JobRegistryKey.self] = registry
                return registry
            }
            return registry
        }
        set {
            storage[JobRegistryKey.self] = newValue
        }
    }
}

/// Job dispatcher for sending jobs to queues
public struct JobDispatcher: Sendable {
    private let application: Application
    private let logger: Logger

    public init(application: Application, logger: Logger) {
        self.application = application
        self.logger = logger
    }

    /// Dispatch a SimpleEmailJob
    public func dispatchEmail(
        to: String,
        subject: String,
        body: String,
        isHTML: Bool = false,
        textBody: String? = nil,
        queue: QueueName = .default
    ) async throws {
        let payload = SimpleEmailJob.EmailPayload(
            to: to,
            subject: subject,
            body: body,
            isHTML: isHTML,
            textBody: textBody
        )

        logger.info(
            "📧 Dispatching email job",
            metadata: [
                "to": .string(to),
                "subject": .string(subject),
                "queue": .string(queue.string),
            ]
        )

        try await application.queues.queue(queue).dispatch(SimpleEmailJob.self, payload)
        logger.info("✅ Email job dispatched successfully")
    }
}

/// Storage key for job dispatcher in Vapor application
public struct JobDispatcherKey: StorageKey {
    public typealias Value = JobDispatcher
}

/// Extension to Application for job dispatcher
extension Application {
    /// Get or create the job dispatcher
    public var jobDispatcher: JobDispatcher {
        get {
            guard let dispatcher = storage[JobDispatcherKey.self] else {
                let logger = Logger(label: "JobDispatcher")
                let dispatcher = JobDispatcher(application: self, logger: logger)
                storage[JobDispatcherKey.self] = dispatcher
                return dispatcher
            }
            return dispatcher
        }
        set {
            storage[JobDispatcherKey.self] = newValue
        }
    }
}
