import Fluent
import FluentPostgresDriver
import Foundation
import Logging
import PostgresNIO

/// Protocol for database operations that can work with both direct connections and connection pools
protocol DatabaseQueryable: Sendable {
    func query(_ sql: String, logger: Logger) async throws
    func queryStrings(_ sql: String, logger: Logger) async throws -> [String]

    /// Verify that the underlying connection resources are properly managed
    func verifyConnectionCleanup(logger: Logger) async throws

    /// Get connection state information for monitoring
    func getConnectionInfo(logger: Logger) async throws -> String
}

/// Direct PostgresNIO connection implementation
struct DirectConnection: DatabaseQueryable, @unchecked Sendable {
    let connection: PostgresConnection

    func query(_ sql: String, logger: Logger) async throws {
        _ = try await connection.query(.init(stringLiteral: sql), logger: logger)
    }

    func queryStrings(_ sql: String, logger: Logger) async throws -> [String] {
        let result = try await connection.query(.init(stringLiteral: sql), logger: logger)
        var strings: [String] = []
        for try await row in result {
            if let name = try? row.decode(String.self) {
                strings.append(name)
            }
        }
        return strings
    }

    func verifyConnectionCleanup(logger: Logger) async throws {
        // For direct connections, verify the connection is still responsive
        // This is a basic health check to ensure the connection wasn't corrupted
        do {
            _ = try await connection.query(.init(stringLiteral: "SELECT 1"), logger: logger)
            logger.info("Direct connection cleanup verification: Connection is responsive")
        } catch {
            logger.error("Direct connection cleanup verification failed: \(error)")
            throw error
        }
    }

    func getConnectionInfo(logger: Logger) async throws -> String {
        // Get basic connection information for direct connections
        do {
            let result = try await connection.query(
                .init(stringLiteral: "SELECT current_database(), version()"),
                logger: logger
            )
            var info = "Direct PostgresNIO Connection:\n"
            for try await row in result {
                if let database = try? row.decode(String.self, context: .default),
                    let version = try? row.decode(String.self, context: .default)
                {
                    info += "  Database: \(database)\n"
                    info += "  Version: \(version)\n"
                }
            }
            return info
        } catch {
            return "Direct connection info unavailable: \(error)"
        }
    }
}

/// Fluent database connection pool implementation
struct PooledConnection: DatabaseQueryable, @unchecked Sendable {
    let database: any SQLDatabase

    func query(_ sql: String, logger: Logger) async throws {
        _ = try await database.raw(.init(sql)).run()
    }

    func queryStrings(_ sql: String, logger: Logger) async throws -> [String] {
        let result = try await database.raw(.init(sql)).all()
        var strings: [String] = []

        for row in result {
            // For migration_name queries, decode the first column as string
            let columns = row.allColumns
            if !columns.isEmpty {
                if let name = try? row.decode(column: columns[0], as: String.self) {
                    strings.append(name)
                }
            }
        }
        return strings
    }

    func verifyConnectionCleanup(logger: Logger) async throws {
        // For pooled connections, verify the pool is responding and check connection health
        do {
            let result = try await database.raw(
                "SELECT COUNT(*) as connection_count FROM pg_stat_activity WHERE datname = current_database()"
            ).all()

            if let firstRow = result.first,
                let count = try? firstRow.decode(column: "connection_count", as: Int.self)
            {
                logger.info("Pooled connection cleanup verification: \(count) active connections to database")

                // Check if connection count is reasonable (not growing excessively)
                if count > 50 {
                    logger.warning("High connection count detected during cleanup verification: \(count)")
                }
            }

            // Verify basic pool responsiveness
            _ = try await database.raw("SELECT 1").run()
            logger.info("Pooled connection cleanup verification: Connection pool is responsive")

        } catch {
            logger.error("Pooled connection cleanup verification failed: \(error)")
            throw error
        }
    }

    func getConnectionInfo(logger: Logger) async throws -> String {
        // Get detailed connection pool information
        do {
            let basicInfo = try await database.raw("SELECT current_database(), version()").all()
            let connectionStats = try await database.raw(
                """
                SELECT
                    state,
                    COUNT(*) as count
                FROM pg_stat_activity
                WHERE datname = current_database()
                GROUP BY state
                ORDER BY count DESC
                """
            ).all()

            var info = "Fluent Connection Pool:\n"

            // Add basic database info
            if let firstRow = basicInfo.first {
                if let database = try? firstRow.decode(column: "current_database", as: String.self),
                    let version = try? firstRow.decode(column: "version", as: String.self)
                {
                    info += "  Database: \(database)\n"
                    info += "  Version: \(version.prefix(50))...\n"
                }
            }

            // Add connection statistics
            info += "  Connection States:\n"
            for row in connectionStats {
                if let state = try? row.decode(column: "state", as: String?.self),
                    let count = try? row.decode(column: "count", as: Int.self)
                {
                    let stateStr = state ?? "null"
                    info += "    \(stateStr): \(count) connections\n"
                }
            }

            return info
        } catch {
            return "Pooled connection info unavailable: \(error)"
        }
    }
}

public actor MigrationManager {
    private let database: DatabaseQueryable
    private let logger: Logger
    private let connectionMonitor: MigrationConnectionMonitor?

    /// Initialize with a direct PostgresNIO connection (legacy compatibility)
    public init(connection: PostgresConnection, logger: Logger, enableMonitoring: Bool = false) {
        self.database = DirectConnection(connection: connection)
        self.logger = logger
        self.connectionMonitor = enableMonitoring ? MigrationConnectionMonitor(logger: logger) : nil
    }

    /// Initialize with a Fluent database connection pool (preferred for tests)
    public init(database: any SQLDatabase, logger: Logger, enableMonitoring: Bool = true) {
        self.database = PooledConnection(database: database)
        self.logger = logger
        self.connectionMonitor = enableMonitoring ? MigrationConnectionMonitor(logger: logger) : nil
    }

    public func initializeMigrationsTable() async throws {
        let query = """
                CREATE TABLE IF NOT EXISTS migrations (
                    migration_name TEXT PRIMARY KEY,
                    migrated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                );
            """
        try await database.query(query, logger: logger)
    }

    public func getAppliedMigrations() async throws -> Set<String> {
        let query = "SELECT migration_name FROM migrations"
        let migrationNames = try await database.queryStrings(query, logger: logger)
        return Set(migrationNames)
    }

    public func applyMigration(name: String, sql: String) async throws {
        // Take pre-migration snapshot if monitoring is enabled
        if let monitor = connectionMonitor,
            let sqlDatabase = (database as? PooledConnection)?.database
        {
            try await monitor.takeSnapshot(
                phase: .preMigration,
                migrationContext: name,
                database: sqlDatabase
            )
        }

        // Verify connection health before starting migration
        try await verifyConnectionCleanup()

        // Parse SQL into individual statements, handling $$ delimited functions
        let statements = parseSQL(sql)

        do {
            // Take migration phase snapshot
            if let monitor = connectionMonitor,
                let sqlDatabase = (database as? PooledConnection)?.database
            {
                try await monitor.takeSnapshot(
                    phase: .migration,
                    migrationContext: name,
                    database: sqlDatabase
                )
            }

            // Execute each statement separately
            for (index, statement) in statements.enumerated() {
                if !statement.isEmpty {
                    do {
                        try await database.query(statement, logger: logger)
                    } catch {
                        logger.error("Failed to execute statement \(index + 1) in migration \(name)")
                        logger.error("Statement: \(statement)")
                        logger.error("Error details: \(String(reflecting: error))")

                        // Take error snapshot if monitoring is enabled
                        if let monitor = connectionMonitor,
                            let sqlDatabase = (database as? PooledConnection)?.database
                        {
                            try? await monitor.takeSnapshot(
                                phase: .cleanup,
                                migrationContext: "\(name)-error-stmt\(index + 1)",
                                database: sqlDatabase
                            )
                        }

                        // Verify connection is still healthy after error
                        try? await verifyConnectionCleanup()
                        throw error
                    }
                }
            }

            // Record migration as applied
            try await database.query("INSERT INTO migrations (migration_name) VALUES ('\(name)')", logger: logger)
            logger.info("Applied migration: \(name)")

            // Take post-migration snapshot
            if let monitor = connectionMonitor,
                let sqlDatabase = (database as? PooledConnection)?.database
            {
                try await monitor.takeSnapshot(
                    phase: .postMigration,
                    migrationContext: name,
                    database: sqlDatabase
                )
            }

            // Verify connection cleanup after successful migration
            try await verifyConnectionCleanup()

        } catch {
            // Take cleanup phase snapshot on error
            if let monitor = connectionMonitor,
                let sqlDatabase = (database as? PooledConnection)?.database
            {
                try? await monitor.takeSnapshot(
                    phase: .cleanup,
                    migrationContext: "\(name)-error",
                    database: sqlDatabase
                )
            }
            throw error
        }
    }

    /// Verify that database connections are properly managed and cleaned up
    public func verifyConnectionCleanup() async throws {
        try await database.verifyConnectionCleanup(logger: logger)
    }

    /// Get detailed connection information for monitoring and debugging
    public func getConnectionInfo() async throws -> String {
        try await database.getConnectionInfo(logger: logger)
    }

    /// Comprehensive connection health check including cleanup verification
    public func performConnectionHealthCheck() async throws -> String {
        var healthReport = "=== Migration Connection Health Check ===\n"

        // Get connection information
        let connectionInfo = try await getConnectionInfo()
        healthReport += connectionInfo + "\n"

        // Verify cleanup
        do {
            try await verifyConnectionCleanup()
            healthReport += "✅ Connection cleanup verification: PASSED\n"
        } catch {
            healthReport += "❌ Connection cleanup verification: FAILED - \(error)\n"
            throw error
        }

        // Test basic connectivity
        do {
            _ = try await database.queryStrings("SELECT 1", logger: logger)
            healthReport += "✅ Basic connectivity test: PASSED\n"
        } catch {
            healthReport += "❌ Basic connectivity test: FAILED - \(error)\n"
            throw error
        }

        healthReport += "=== Health Check Complete ===\n"
        return healthReport
    }

    /// Get connection monitoring report if monitoring is enabled
    public func getConnectionMonitoringReport(for migrationContext: String? = nil) async -> MigrationConnectionReport? {
        guard let monitor = connectionMonitor else { return nil }
        return await monitor.generateReport(for: migrationContext)
    }

    /// Clear all connection monitoring snapshots
    public func clearConnectionMonitoring() async {
        guard let monitor = connectionMonitor else { return }
        await monitor.clearSnapshots()
    }

    /// Take a manual connection snapshot for specific phase monitoring
    public func takeConnectionSnapshot(phase: MigrationPhase, context: String) async throws {
        guard let monitor = connectionMonitor,
            let sqlDatabase = (database as? PooledConnection)?.database
        else {
            return
        }
        try await monitor.takeSnapshot(phase: phase, migrationContext: context, database: sqlDatabase)
    }

    private func parseSQL(_ sql: String) -> [String] {
        var statements: [String] = []
        var currentStatement = ""
        var insideDollarQuoted = false
        var dollarTag = ""

        // Remove carriage returns and normalize line endings
        let normalizedSQL = sql.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let lines = normalizedSQL.components(separatedBy: .newlines)

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip empty lines and comments (but not when inside dollar-quoted)
            if !insideDollarQuoted && (trimmedLine.hasPrefix("--") || trimmedLine.isEmpty) {
                continue
            }

            currentStatement += line + "\n"

            // Look for dollar-quoted delimiters
            if let range = line.range(of: #"\$[^$]*\$"#, options: .regularExpression) {
                let tag = String(line[range])

                if !insideDollarQuoted {
                    // Starting a dollar-quoted block
                    insideDollarQuoted = true
                    dollarTag = tag
                } else if tag == dollarTag {
                    // Ending the dollar-quoted block
                    insideDollarQuoted = false
                    dollarTag = ""
                }
            }

            // Check for statement end (semicolon) only when not inside dollar quotes
            if !insideDollarQuoted && trimmedLine.hasSuffix(";") {
                let statement = currentStatement.trimmingCharacters(in: .whitespacesAndNewlines)
                if !statement.isEmpty {
                    statements.append(statement)
                }
                currentStatement = ""
            }
        }

        // Add any remaining statement
        let finalStatement = currentStatement.trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalStatement.isEmpty {
            statements.append(finalStatement)
        }

        return statements
    }
}
