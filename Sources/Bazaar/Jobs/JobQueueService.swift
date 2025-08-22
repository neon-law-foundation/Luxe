import Foundation
import Logging
import Queues
import ServiceLifecycle
import Vapor

/// Service wrapper for managing Vapor Queues within the Bazaar application lifecycle
/// Handles queue startup, shutdown, and worker management
public struct JobQueueService: Service, Sendable {
    private let application: Application
    private let logger: Logger
    private let queueName: QueueName

    public init(application: Application, logger: Logger, queueName: QueueName = .default) {
        self.application = application
        self.logger = logger
        self.queueName = queueName
    }

    /// Run the job queue service
    /// This method starts the queue workers and keeps them running
    public func run() async throws {
        logger.info("🚀 Starting JobQueueService")

        // Register all jobs before starting
        await application.jobRegistry.registerAll(with: application)

        logger.info(
            "👷 Starting queue workers",
            metadata: ["queue": .string(queueName.string)]
        )

        try await cancelWhenGracefulShutdown {
            // Start in-process job workers
            try application.queues.startInProcessJobs(on: queueName)

            // Start scheduled jobs (cron-like jobs)
            try application.queues.startScheduledJobs()

            logger.info("✅ Queue workers and scheduled jobs started successfully")

            // Keep the service running indefinitely
            // Use a very long but reasonable duration (1 year in seconds)
            try await Task.sleep(for: .seconds(365 * 24 * 60 * 60))
        }
    }
}

/// Configuration for job queue service
public struct JobQueueConfiguration: Sendable {
    /// Number of workers to run for job processing
    public let workerCount: Int

    /// Maximum number of jobs to process concurrently
    public let maxConcurrentJobs: Int

    /// Default queue name for job processing
    public let defaultQueue: QueueName

    /// Refresh interval for polling jobs (in seconds)
    public let refreshInterval: Int

    public init(
        workerCount: Int = 1,
        maxConcurrentJobs: Int = 10,
        defaultQueue: QueueName = .default,
        refreshInterval: Int = 1
    ) {
        self.workerCount = workerCount
        self.maxConcurrentJobs = maxConcurrentJobs
        self.defaultQueue = defaultQueue
        self.refreshInterval = refreshInterval
    }

    /// Default configuration for development
    public static let development = JobQueueConfiguration(
        workerCount: 1,
        maxConcurrentJobs: 5,
        refreshInterval: 2
    )

    /// Default configuration for production
    public static let production = JobQueueConfiguration(
        workerCount: 3,
        maxConcurrentJobs: 20,
        refreshInterval: 1
    )
}

/// Manager for job queue operations and monitoring
public actor JobQueueManager: Sendable {
    private let application: Application
    private let configuration: JobQueueConfiguration
    private let logger: Logger
    private var isRunning = false
    private var activeJobs: Set<String> = []

    public init(
        application: Application,
        configuration: JobQueueConfiguration,
        logger: Logger
    ) {
        self.application = application
        self.configuration = configuration
        self.logger = logger
    }

    /// Start the job queue manager
    public func start() throws {
        guard !isRunning else {
            logger.warning("JobQueueManager already running")
            return
        }

        logger.info(
            "🔧 Configuring job queue manager",
            metadata: [
                "worker_count": .stringConvertible(configuration.workerCount),
                "max_concurrent_jobs": .stringConvertible(configuration.maxConcurrentJobs),
                "refresh_interval": .stringConvertible(configuration.refreshInterval),
            ]
        )

        // Configure queue worker count and settings
        // Note: Vapor Queues doesn't directly expose worker count configuration
        // This would typically be handled by the queue driver configuration

        isRunning = true
        logger.info("✅ Job queue manager started")
    }

    /// Stop the job queue manager
    public func stop() {
        guard isRunning else {
            logger.warning("JobQueueManager already stopped")
            return
        }

        logger.info("🛑 Stopping job queue manager")
        isRunning = false
        activeJobs.removeAll()
        logger.info("✅ Job queue manager stopped")
    }

    /// Get current queue statistics
    public func getStatistics() -> JobQueueStatistics {
        JobQueueStatistics(
            isRunning: isRunning,
            activeJobCount: activeJobs.count,
            maxConcurrentJobs: configuration.maxConcurrentJobs,
            workerCount: configuration.workerCount
        )
    }

    /// Track a job as active
    internal func trackActiveJob(_ jobId: String) {
        activeJobs.insert(jobId)
        logger.debug(
            "📊 Job started",
            metadata: [
                "job_id": .string(jobId),
                "active_jobs": .stringConvertible(activeJobs.count),
            ]
        )
    }

    /// Remove a job from active tracking
    internal func untrackActiveJob(_ jobId: String) {
        activeJobs.remove(jobId)
        logger.debug(
            "📊 Job completed",
            metadata: [
                "job_id": .string(jobId),
                "active_jobs": .stringConvertible(activeJobs.count),
            ]
        )
    }
}

/// Statistics about the job queue system
public struct JobQueueStatistics: Sendable {
    /// Whether the queue manager is running
    public let isRunning: Bool

    /// Number of currently active jobs
    public let activeJobCount: Int

    /// Maximum number of concurrent jobs allowed
    public let maxConcurrentJobs: Int

    /// Number of worker threads/processes
    public let workerCount: Int
}

/// Storage keys for job queue components
public struct JobQueueManagerKey: StorageKey {
    public typealias Value = JobQueueManager
}

public struct JobQueueConfigurationKey: StorageKey {
    public typealias Value = JobQueueConfiguration
}

/// Extension to Application for job queue management
extension Application {
    /// Get or create the job queue manager
    public var jobQueueManager: JobQueueManager {
        get {
            guard let manager = storage[JobQueueManagerKey.self] else {
                let configuration = storage[JobQueueConfigurationKey.self] ?? .development
                let logger = Logger(label: "JobQueueManager")
                let manager = JobQueueManager(
                    application: self,
                    configuration: configuration,
                    logger: logger
                )
                storage[JobQueueManagerKey.self] = manager
                return manager
            }
            return manager
        }
        set {
            storage[JobQueueManagerKey.self] = newValue
        }
    }

    /// Configure job queue settings
    /// - Parameter configuration: The job queue configuration
    public func configureJobQueue(_ configuration: JobQueueConfiguration) {
        storage[JobQueueConfigurationKey.self] = configuration
    }
}
