import Fluent
import FluentPostgresDriver
import Foundation
import Logging
import PostgresNIO

/// Connection usage snapshot for tracking migration connection patterns
public struct ConnectionUsageSnapshot: Sendable {
    public let timestamp: Date
    public let phase: MigrationPhase
    public let totalConnections: Int
    public let activeConnections: Int
    public let idleConnections: Int
    public let connectionsByState: [String: Int]
    public let connectionsByApplication: [String: Int]
    public let migrationContext: String

    public init(
        timestamp: Date = Date(),
        phase: MigrationPhase,
        totalConnections: Int,
        activeConnections: Int,
        idleConnections: Int,
        connectionsByState: [String: Int],
        connectionsByApplication: [String: Int],
        migrationContext: String
    ) {
        self.timestamp = timestamp
        self.phase = phase
        self.totalConnections = totalConnections
        self.activeConnections = activeConnections
        self.idleConnections = idleConnections
        self.connectionsByState = connectionsByState
        self.connectionsByApplication = connectionsByApplication
        self.migrationContext = migrationContext
    }

    /// Formatted description for logging and debugging
    public var formattedDescription: String {
        var description = """
            📊 Migration Connection Snapshot [@\(timestamp.formatted(.iso8601))]
            Phase: \(phase.rawValue)
            Context: \(migrationContext)
            Total Connections: \(totalConnections)
            Active: \(activeConnections), Idle: \(idleConnections)
            """

        if !connectionsByState.isEmpty {
            description += "\nBy State:"
            for (state, count) in connectionsByState.sorted(by: { $0.value > $1.value }) {
                description += "\n  \(state): \(count)"
            }
        }

        if !connectionsByApplication.isEmpty {
            description += "\nBy Application:"
            for (app, count) in connectionsByApplication.sorted(by: { $0.value > $1.value }) {
                let appName = app.isEmpty ? "unknown" : app
                description += "\n  \(appName): \(count)"
            }
        }

        return description
    }
}

/// Migration phases for connection monitoring
public enum MigrationPhase: String, Sendable, CaseIterable {
    case preSetup = "pre-setup"
    case setup = "setup"
    case preMigration = "pre-migration"
    case migration = "migration"
    case postMigration = "post-migration"
    case cleanup = "cleanup"
    case postCleanup = "post-cleanup"
    case testSetup = "test-setup"
    case testExecution = "test-execution"
    case testTeardown = "test-teardown"
}

/// Connection monitoring report for analyzing migration connection patterns
public struct MigrationConnectionReport: Sendable {
    public let snapshots: [ConnectionUsageSnapshot]
    public let startTime: Date
    public let endTime: Date
    public let maxConnections: Int
    public let minConnections: Int
    public let avgConnections: Double
    public let connectionGrowth: Int
    public let potentialLeaks: [String]

    public init(snapshots: [ConnectionUsageSnapshot]) {
        self.snapshots = snapshots
        self.startTime = snapshots.first?.timestamp ?? Date()
        self.endTime = snapshots.last?.timestamp ?? Date()

        let connectionCounts = snapshots.map(\.totalConnections)
        self.maxConnections = connectionCounts.max() ?? 0
        self.minConnections = connectionCounts.min() ?? 0
        self.avgConnections =
            connectionCounts.isEmpty ? 0 : Double(connectionCounts.reduce(0, +)) / Double(connectionCounts.count)
        self.connectionGrowth = (snapshots.last?.totalConnections ?? 0) - (snapshots.first?.totalConnections ?? 0)

        // Detect potential leaks by finding phases with significant connection increases
        var leaks: [String] = []
        if snapshots.count > 1 {
            for i in 1..<snapshots.count {
                let previous = snapshots[i - 1]
                let current = snapshots[i]
                let increase = current.totalConnections - previous.totalConnections

                if increase > 5 {
                    leaks.append(
                        "Phase \(previous.phase.rawValue) → \(current.phase.rawValue): +\(increase) connections"
                    )
                }
            }
        }
        self.potentialLeaks = leaks
    }

    /// Formatted analysis report
    public var analysisReport: String {
        var report = """
            📈 Migration Connection Analysis Report
            Duration: \(startTime.formatted(.iso8601)) → \(endTime.formatted(.iso8601))
            Connection Range: \(minConnections) - \(maxConnections) (avg: \(String(format: "%.1f", avgConnections)))
            Net Growth: \(connectionGrowth >= 0 ? "+" : "")\(connectionGrowth) connections
            Snapshots: \(snapshots.count)
            """

        if !potentialLeaks.isEmpty {
            report += "\n\n⚠️ Potential Connection Leaks:"
            for leak in potentialLeaks {
                report += "\n  • \(leak)"
            }
        }

        if connectionGrowth > 3 {
            report += "\n\n🚨 HIGH CONNECTION GROWTH DETECTED"
        } else if connectionGrowth > 0 {
            report += "\n\n⚠️ Connection growth detected"
        } else if connectionGrowth < 0 {
            report += "\n\n✅ Connection count decreased (good cleanup)"
        } else {
            report += "\n\n✅ No net connection growth"
        }

        return report
    }
}

/// Actor for monitoring migration connection usage patterns
public actor MigrationConnectionMonitor {
    private var snapshots: [ConnectionUsageSnapshot] = []
    private let maxSnapshots: Int
    private let logger: Logger

    public init(maxSnapshots: Int = 200, logger: Logger = Logger(label: "migration-connection-monitor")) {
        self.maxSnapshots = maxSnapshots
        self.logger = logger
    }

    /// Take a connection usage snapshot for a specific migration phase
    public func takeSnapshot(
        phase: MigrationPhase,
        migrationContext: String,
        database: any SQLDatabase
    ) async throws {
        do {
            // Get detailed connection statistics
            let connectionStats = try await database.raw(
                """
                SELECT
                    state,
                    application_name,
                    COUNT(*) as count
                FROM pg_stat_activity
                WHERE datname = current_database()
                GROUP BY state, application_name
                ORDER BY count DESC
                """
            ).all()

            var connectionsByState: [String: Int] = [:]
            var connectionsByApplication: [String: Int] = [:]
            var totalConnections = 0
            var activeConnections = 0
            var idleConnections = 0

            for row in connectionStats {
                if let count = try? row.decode(column: "count", as: Int.self) {
                    let state = try? row.decode(column: "state", as: String?.self)
                    let appName = try? row.decode(column: "application_name", as: String?.self)

                    let stateStr = state ?? "null"
                    let appStr = appName ?? "unknown"

                    connectionsByState[stateStr, default: 0] += count
                    connectionsByApplication[appStr, default: 0] += count
                    totalConnections += count

                    if stateStr == "active" {
                        activeConnections += count
                    } else if stateStr == "idle" {
                        idleConnections += count
                    }
                }
            }

            let snapshot = ConnectionUsageSnapshot(
                phase: phase,
                totalConnections: totalConnections,
                activeConnections: activeConnections,
                idleConnections: idleConnections,
                connectionsByState: connectionsByState,
                connectionsByApplication: connectionsByApplication,
                migrationContext: migrationContext
            )

            snapshots.append(snapshot)

            // Keep only the most recent snapshots
            if snapshots.count > maxSnapshots {
                let excessCount = snapshots.count - maxSnapshots
                if excessCount > 0 && excessCount <= snapshots.count {
                    snapshots.removeFirst(excessCount)
                }
            }

            logger.info("Migration connection snapshot: \(snapshot.formattedDescription)")

        } catch {
            logger.error("Failed to take migration connection snapshot: \(error)")
            throw error
        }
    }

    /// Get all recorded snapshots
    public func getAllSnapshots() -> [ConnectionUsageSnapshot] {
        snapshots
    }

    /// Get snapshots for a specific migration context
    public func getSnapshots(for migrationContext: String) -> [ConnectionUsageSnapshot] {
        snapshots.filter { $0.migrationContext == migrationContext }
    }

    /// Get snapshots for a specific phase
    public func getSnapshots(for phase: MigrationPhase) -> [ConnectionUsageSnapshot] {
        snapshots.filter { $0.phase == phase }
    }

    /// Generate a comprehensive connection analysis report
    public func generateReport(for migrationContext: String? = nil) -> MigrationConnectionReport {
        let relevantSnapshots =
            migrationContext != nil
            ? getSnapshots(for: migrationContext!)
            : snapshots

        return MigrationConnectionReport(snapshots: relevantSnapshots)
    }

    /// Clear all recorded snapshots
    public func clearSnapshots() {
        snapshots.removeAll()
        logger.info("Cleared all migration connection snapshots")
    }

    /// Monitor a migration operation and automatically take snapshots at key phases
    public func monitorMigrationOperation<T: Sendable>(
        context: String,
        database: any SQLDatabase,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        // Pre-migration snapshot
        try await takeSnapshot(phase: .preMigration, migrationContext: context, database: database)

        do {
            // During migration snapshot
            try await takeSnapshot(phase: .migration, migrationContext: context, database: database)

            // Execute the operation
            let result = try await operation()

            // Post-migration snapshot
            try await takeSnapshot(phase: .postMigration, migrationContext: context, database: database)

            return result
        } catch {
            // Error snapshot
            try? await takeSnapshot(phase: .cleanup, migrationContext: "\(context)-error", database: database)
            throw error
        }
    }
}
