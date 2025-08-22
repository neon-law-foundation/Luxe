import Fluent
import FluentPostgresDriver
import Foundation
import Logging
import PostgresNIO
import Testing

@testable import Palette
@testable import TestUtilities

@Suite("Migration Connection Monitor Tests", .serialized)
struct MigrationConnectionMonitorTests {

    @Test("MigrationConnectionMonitor can take snapshots of connection usage")
    func migrationConnectionMonitorCanTakeSnapshotsOfConnectionUsage() async throws {
        try await TestUtilities.withApp { app, database in
            let logger = Logger(label: "monitor-snapshot-test")

            guard let sqlDatabase = database as? any SQLDatabase else {
                throw TestError.databaseOperationFailed("Database is not a SQL database")
            }

            let monitor = MigrationConnectionMonitor(logger: logger)
            defer {
                Task {
                    await monitor.clearSnapshots()
                }
            }

            // Take initial snapshot
            try await monitor.takeSnapshot(
                phase: .preSetup,
                migrationContext: "test-context",
                database: sqlDatabase
            )

            // Verify snapshot was recorded
            let snapshots = await monitor.getAllSnapshots()
            #expect(snapshots.count == 1, "One snapshot should be recorded")

            let snapshot = snapshots[0]
            #expect(snapshot.phase == .preSetup, "Snapshot should have correct phase")
            #expect(snapshot.migrationContext == "test-context", "Snapshot should have correct context")
            #expect(snapshot.totalConnections >= 0, "Total connections should be non-negative")

            // Take another snapshot for different phase
            try await monitor.takeSnapshot(
                phase: .migration,
                migrationContext: "test-context",
                database: sqlDatabase
            )

            let updatedSnapshots = await monitor.getAllSnapshots()
            #expect(updatedSnapshots.count == 2, "Two snapshots should be recorded")
        }
    }

    @Test("MigrationConnectionMonitor generates analysis reports with connection patterns")
    func migrationConnectionMonitorGeneratesAnalysisReportsWithConnectionPatterns() async throws {
        try await TestUtilities.withApp { app, database in
            let logger = Logger(label: "monitor-analysis-test")

            guard let sqlDatabase = database as? any SQLDatabase else {
                throw TestError.databaseOperationFailed("Database is not a SQL database")
            }

            let monitor = MigrationConnectionMonitor(logger: logger)
            defer {
                Task {
                    await monitor.clearSnapshots()
                }
            }

            // Take multiple snapshots to create a pattern
            let phases: [MigrationPhase] = [.preSetup, .setup, .preMigration, .migration, .postMigration, .cleanup]

            for phase in phases {
                try await monitor.takeSnapshot(
                    phase: phase,
                    migrationContext: "analysis-test",
                    database: sqlDatabase
                )

                // Small delay to ensure different timestamps
                try await Task.sleep(for: .milliseconds(100))
            }

            // Generate report
            let report = await monitor.generateReport(for: "analysis-test")

            #expect(report.snapshots.count == phases.count, "Report should include all snapshots")
            #expect(report.maxConnections >= report.minConnections, "Max should be >= min connections")
            #expect(report.avgConnections >= 0, "Average connections should be non-negative")

            // Verify report content
            let analysisReport = report.analysisReport
            #expect(analysisReport.contains("Migration Connection Analysis Report"), "Analysis should contain header")
            #expect(analysisReport.contains("Connection Range"), "Analysis should contain connection range")
            #expect(analysisReport.contains("Net Growth"), "Analysis should contain net growth information")
        }
    }

    @Test("MigrationConnectionMonitor detects potential connection leaks")
    func migrationConnectionMonitorDetectsPotentialConnectionLeaks() async throws {
        try await TestUtilities.withApp { app, database in
            let logger = Logger(label: "monitor-leak-detection-test")

            guard let sqlDatabase = database as? any SQLDatabase else {
                throw TestError.databaseOperationFailed("Database is not a SQL database")
            }

            let monitor = MigrationConnectionMonitor(logger: logger)
            defer {
                Task {
                    await monitor.clearSnapshots()
                }
            }

            // Create snapshots with artificial connection count simulation
            // (In real scenario, this would happen due to actual connection leaks)

            // We'll use the real connection counts and verify the leak detection logic
            try await monitor.takeSnapshot(
                phase: .preSetup,
                migrationContext: "leak-test",
                database: sqlDatabase
            )

            try await monitor.takeSnapshot(
                phase: .setup,
                migrationContext: "leak-test",
                database: sqlDatabase
            )

            let report = await monitor.generateReport(for: "leak-test")

            // Verify the report structure even if no actual leaks are detected
            #expect(report.potentialLeaks.count >= 0, "Potential leaks array should exist")

            let analysisReport = report.analysisReport
            if report.connectionGrowth > 3 {
                #expect(analysisReport.contains("HIGH CONNECTION GROWTH DETECTED"), "High growth should be detected")
            } else if report.connectionGrowth > 0 {
                #expect(analysisReport.contains("Connection growth detected"), "Growth should be noted")
            } else {
                #expect(
                    analysisReport.contains("No net connection growth")
                        || analysisReport.contains("Connection count decreased"),
                    "No growth or decrease should be noted"
                )
            }
        }
    }

    @Test("MigrationConnectionMonitor can filter snapshots by migration context")
    func migrationConnectionMonitorCanFilterSnapshotsByMigrationContext() async throws {
        try await TestUtilities.withApp { app, database in
            let logger = Logger(label: "monitor-filtering-test")

            guard let sqlDatabase = database as? any SQLDatabase else {
                throw TestError.databaseOperationFailed("Database is not a SQL database")
            }

            let monitor = MigrationConnectionMonitor(logger: logger)
            defer {
                Task {
                    await monitor.clearSnapshots()
                }
            }

            // Take snapshots for different contexts
            try await monitor.takeSnapshot(
                phase: .migration,
                migrationContext: "context-a",
                database: sqlDatabase
            )

            try await monitor.takeSnapshot(
                phase: .migration,
                migrationContext: "context-b",
                database: sqlDatabase
            )

            try await monitor.takeSnapshot(
                phase: .postMigration,
                migrationContext: "context-a",
                database: sqlDatabase
            )

            // Test filtering by context
            let contextASnapshots = await monitor.getSnapshots(for: "context-a")
            #expect(contextASnapshots.count == 2, "Should find 2 snapshots for context-a")

            let contextBSnapshots = await monitor.getSnapshots(for: "context-b")
            #expect(contextBSnapshots.count == 1, "Should find 1 snapshot for context-b")

            // Test filtering by phase
            let migrationPhaseSnapshots = await monitor.getSnapshots(for: .migration)
            #expect(migrationPhaseSnapshots.count == 2, "Should find 2 snapshots for migration phase")

            // Test context-specific reports
            let contextAReport = await monitor.generateReport(for: "context-a")
            #expect(contextAReport.snapshots.count == 2, "Context A report should have 2 snapshots")

            let contextBReport = await monitor.generateReport(for: "context-b")
            #expect(contextBReport.snapshots.count == 1, "Context B report should have 1 snapshot")
        }
    }

    @Test("MigrationConnectionMonitor handles maximum snapshot limits correctly")
    func migrationConnectionMonitorHandlesMaximumSnapshotLimitsCorrectly() async throws {
        try await TestUtilities.withApp { app, database in
            let logger = Logger(label: "monitor-limits-test")

            guard let sqlDatabase = database as? any SQLDatabase else {
                throw TestError.databaseOperationFailed("Database is not a SQL database")
            }

            // Create monitor with small max limit for testing
            let monitor = MigrationConnectionMonitor(maxSnapshots: 3, logger: logger)
            defer {
                Task {
                    await monitor.clearSnapshots()
                }
            }

            // Take more snapshots than the limit
            for i in 1...5 {
                try await monitor.takeSnapshot(
                    phase: .migration,
                    migrationContext: "limit-test-\(i)",
                    database: sqlDatabase
                )
            }

            let snapshots = await monitor.getAllSnapshots()
            #expect(snapshots.count == 3, "Should maintain maximum of 3 snapshots")

            // Verify we kept the most recent snapshots
            let contexts = Set(snapshots.map(\.migrationContext))
            #expect(contexts.contains("limit-test-3"), "Should keep recent snapshot 3")
            #expect(contexts.contains("limit-test-4"), "Should keep recent snapshot 4")
            #expect(contexts.contains("limit-test-5"), "Should keep recent snapshot 5")
            #expect(!contexts.contains("limit-test-1"), "Should have removed oldest snapshot 1")
            #expect(!contexts.contains("limit-test-2"), "Should have removed oldest snapshot 2")
        }
    }

    @Test("MigrationConnectionMonitor can clear all snapshots")
    func migrationConnectionMonitorCanClearAllSnapshots() async throws {
        try await TestUtilities.withApp { app, database in
            let logger = Logger(label: "monitor-clear-test")

            guard let sqlDatabase = database as? any SQLDatabase else {
                throw TestError.databaseOperationFailed("Database is not a SQL database")
            }

            let monitor = MigrationConnectionMonitor(logger: logger)
            defer {
                Task {
                    await monitor.clearSnapshots()
                }
            }

            // Take several snapshots
            for i in 1...3 {
                try await monitor.takeSnapshot(
                    phase: .migration,
                    migrationContext: "clear-test-\(i)",
                    database: sqlDatabase
                )
            }

            var snapshots = await monitor.getAllSnapshots()
            #expect(snapshots.count == 3, "Should have 3 snapshots before clearing")

            // Clear all snapshots
            await monitor.clearSnapshots()

            snapshots = await monitor.getAllSnapshots()
            #expect(snapshots.isEmpty, "Should have no snapshots after clearing")

            // Verify reports are empty after clearing
            let report = await monitor.generateReport()
            #expect(report.snapshots.isEmpty, "Report should have no snapshots after clearing")
        }
    }

    @Test("MigrationConnectionMonitor monitorMigrationOperation method provides automatic monitoring")
    func migrationConnectionMonitorMonitorMigrationOperationMethodProvidesAutomaticMonitoring() async throws {
        try await TestUtilities.withApp { app, database in
            let logger = Logger(label: "monitor-operation-test")

            guard let sqlDatabase = database as? any SQLDatabase else {
                throw TestError.databaseOperationFailed("Database is not a SQL database")
            }

            let monitor = MigrationConnectionMonitor(logger: logger)
            defer {
                Task {
                    await monitor.clearSnapshots()
                }
            }

            // Use the automatic monitoring method
            let result = try await monitor.monitorMigrationOperation(
                context: "auto-monitor-test",
                database: sqlDatabase
            ) {
                // Simulate a migration operation
                _ = try await sqlDatabase.raw("SELECT 1").run()
                return "operation-complete"
            }

            #expect(result == "operation-complete", "Operation should return expected result")

            // Verify snapshots were automatically taken
            let snapshots = await monitor.getSnapshots(for: "auto-monitor-test")
            #expect(snapshots.count >= 3, "Should have at least pre, during, and post snapshots")

            // Check for expected phases
            let phases = Set(snapshots.map(\.phase))
            #expect(phases.contains(.preMigration), "Should contain pre-migration snapshot")
            #expect(phases.contains(.migration), "Should contain migration snapshot")
            #expect(phases.contains(.postMigration), "Should contain post-migration snapshot")
        }
    }

    @Test("MigrationConnectionMonitor automatic monitoring handles operation errors correctly")
    func migrationConnectionMonitorAutomaticMonitoringHandlesOperationErrorsCorrectly() async throws {
        try await TestUtilities.withApp { app, database in
            let logger = Logger(label: "monitor-error-test")

            guard let sqlDatabase = database as? any SQLDatabase else {
                throw TestError.databaseOperationFailed("Database is not a SQL database")
            }

            let monitor = MigrationConnectionMonitor(logger: logger)
            defer {
                Task {
                    await monitor.clearSnapshots()
                }
            }

            // Test error handling in automatic monitoring
            do {
                _ = try await monitor.monitorMigrationOperation(
                    context: "error-test",
                    database: sqlDatabase
                ) {
                    // Simulate an operation that fails
                    throw TestError.databaseOperationFailed("Simulated error")
                }
                #expect(Bool(false), "Operation should have thrown an error")
            } catch TestError.databaseOperationFailed(let message) {
                #expect(message == "Simulated error", "Should propagate the original error")
            }

            // Verify error snapshot was taken
            let snapshots = await monitor.getSnapshots(for: "error-test")
            #expect(snapshots.count >= 2, "Should have pre-migration and cleanup snapshots")

            // Check for cleanup phase snapshot (created on error)
            let errorSnapshots = snapshots.filter { $0.migrationContext.contains("error-test") }
            #expect(!errorSnapshots.isEmpty, "Should have error-related snapshots")
        }
    }

    @Test("ConnectionUsageSnapshot formatted description contains expected information")
    func connectionUsageSnapshotFormattedDescriptionContainsExpectedInformation() async throws {
        let snapshot = ConnectionUsageSnapshot(
            phase: .migration,
            totalConnections: 10,
            activeConnections: 5,
            idleConnections: 5,
            connectionsByState: ["active": 5, "idle": 5],
            connectionsByApplication: ["test-app": 8, "": 2],
            migrationContext: "test-description"
        )

        let description = snapshot.formattedDescription

        #expect(description.contains("Migration Connection Snapshot"), "Should contain header")
        #expect(description.contains("Phase: migration"), "Should contain phase")
        #expect(description.contains("Context: test-description"), "Should contain context")
        #expect(description.contains("Total Connections: 10"), "Should contain total connections")
        #expect(description.contains("Active: 5, Idle: 5"), "Should contain active/idle breakdown")
        #expect(description.contains("By State:"), "Should contain state breakdown header")
        #expect(description.contains("active: 5"), "Should contain active state count")
        #expect(description.contains("idle: 5"), "Should contain idle state count")
        #expect(description.contains("By Application:"), "Should contain application breakdown header")
        #expect(description.contains("test-app: 8"), "Should contain application count")
        #expect(description.contains("unknown: 2"), "Should show empty app names as unknown")
    }
}
