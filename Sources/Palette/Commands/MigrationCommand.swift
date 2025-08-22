import ArgumentParser
import Foundation
import Logging
import PostgresNIO

struct MigrateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "migrate",
        abstract: "Run pending migrations"
    )

    func run() async throws {
        let logger = Logger(label: "palette-migrations")

        do {
            // Parse the connection URL
            let url = ProcessInfo.processInfo.environment["DATABASE_URL"] ?? "postgres://postgres@localhost:5432/luxe"
            guard let url = URL(string: url),
                let host = url.host,
                let database = url.path.split(separator: "/").last.map(String.init)
            else {
                throw CommandError.invalidConnectionURL
            }

            let port = url.port ?? 5432
            let username = url.user ?? "postgres"
            let password = url.password

            // Parse sslmode from query parameters
            let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let sslMode = queryItems.first(where: { $0.name == "sslmode" })?.value ?? "disable"

            // Configure TLS based on sslmode
            let tlsConfig: PostgresConnection.Configuration.TLS
            switch sslMode {
            case "require", "verify-ca", "verify-full":
                tlsConfig = .require(try .init(configuration: .makeClientConfiguration()))
            default:
                tlsConfig = .disable
            }

            let configuration = PostgresConnection.Configuration(
                host: host,
                port: port,
                username: username,
                password: password,  // Use password from URL if provided
                database: database,
                tls: tlsConfig
            )

            // Create a connection manager that ensures proper cleanup
            let connectionManager = ConnectionManager(configuration: configuration, logger: logger)
            try await connectionManager.runMigrations()
        } catch {
            logger.error("Migration failed: \(String(reflecting: error))")
            throw error
        }
    }
}

final class ConnectionManager {
    private let configuration: PostgresConnection.Configuration
    private let logger: Logger
    private let enableMonitoring: Bool

    init(configuration: PostgresConnection.Configuration, logger: Logger, enableMonitoring: Bool = false) {
        self.configuration = configuration
        self.logger = logger
        self.enableMonitoring = enableMonitoring
    }

    func runMigrations() async throws {
        let connection = try await PostgresConnection.connect(
            configuration: configuration,
            id: .init(),
            logger: logger
        )

        do {
            let manager = MigrationManager(connection: connection, logger: logger, enableMonitoring: enableMonitoring)

            // Take initial setup snapshot if monitoring is enabled
            if enableMonitoring {
                try await manager.takeConnectionSnapshot(phase: .preSetup, context: "direct-migration-setup")
            }

            // Perform initial connection health check
            logger.info("Performing initial migration connection health check...")
            let initialHealthReport = try await manager.performConnectionHealthCheck()
            logger.info("Initial health check:\n\(initialHealthReport)")

            try await manager.initializeMigrationsTable()

            // Take post-setup snapshot
            if enableMonitoring {
                try await manager.takeConnectionSnapshot(phase: .setup, context: "direct-migration-setup")
            }

            let migrationsDir = URL(fileURLWithPath: "Sources/Palette/Migrations")
            let files = try FileManager.default.contentsOfDirectory(at: migrationsDir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "sql" }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

            let appliedMigrations = try await manager.getAppliedMigrations()

            // Take pre-migration batch snapshot
            if enableMonitoring {
                try await manager.takeConnectionSnapshot(phase: .preMigration, context: "direct-migration-batch")
            }

            for file in files {
                let name = file.lastPathComponent
                if !appliedMigrations.contains(name) {
                    let sql = try String(contentsOf: file, encoding: .utf8)
                    logger.info("Applying migration: \(name)")
                    try await manager.applyMigration(name: name, sql: sql)
                    logger.info("Successfully applied migration: \(name)")
                }
            }

            // Take post-migration batch snapshot
            if enableMonitoring {
                try await manager.takeConnectionSnapshot(phase: .postMigration, context: "direct-migration-batch")
            }

            // Perform final connection health check before closing
            logger.info("Performing final migration connection health check...")
            let finalHealthReport = try await manager.performConnectionHealthCheck()
            logger.info("Final health check:\n\(finalHealthReport)")

            // Take cleanup snapshot
            if enableMonitoring {
                try await manager.takeConnectionSnapshot(phase: .cleanup, context: "direct-migration-batch")
            }

            // Verify connection cleanup before closing
            try await manager.verifyConnectionCleanup()
            logger.info("Connection cleanup verification completed successfully")

            // Generate and log monitoring report if enabled
            if enableMonitoring {
                if let report = await manager.getConnectionMonitoringReport() {
                    logger.info("Direct Migration Connection Monitoring Report:\n\(report.analysisReport)")
                }
            }

            // Take final snapshot
            if enableMonitoring {
                try await manager.takeConnectionSnapshot(phase: .postCleanup, context: "direct-migration-batch")
            }

            // Always close connection - success path
            try await connection.close()
            logger.info("Migration connection closed successfully")

        } catch {
            logger.error("Migration failed, attempting connection cleanup verification...")

            // Try to verify cleanup even on error
            do {
                let manager = MigrationManager(
                    connection: connection,
                    logger: logger,
                    enableMonitoring: enableMonitoring
                )

                // Take error snapshot if monitoring is enabled
                if enableMonitoring {
                    try? await manager.takeConnectionSnapshot(phase: .cleanup, context: "direct-migration-error")
                }

                try await manager.verifyConnectionCleanup()
                logger.info("Connection cleanup verification completed after error")
            } catch let cleanupError {
                logger.error("Connection cleanup verification failed after error: \(cleanupError)")
            }

            // Always close connection - error path
            try? await connection.close()
            logger.info("Migration connection closed after error")
            throw error
        }
    }
}

enum CommandError: Error {
    case invalidConnectionURL
    case connectionFailed
}
