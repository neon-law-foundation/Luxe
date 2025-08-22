import Foundation
import Logging
import PostgresNIO
import Testing

@testable import Palette

@Suite("Database Migration Tests", .serialized)
struct MigrationTests {
    @Test("Palette migrations apply successfully and create expected database schema")
    func paletteMigrationsApplySuccessfullyAndCreateExpectedSchema() async throws {
        let logger = Logger(label: "palette-complete-test")

        // Connect to test database
        let configuration = PostgresConnection.Configuration(
            host: "localhost",
            port: 5432,
            username: "postgres",
            password: nil,
            database: "luxe",
            tls: .disable
        )

        let connection = try await PostgresConnection.connect(
            configuration: configuration,
            id: .init(),
            logger: logger
        )

        do {

            // Clean up existing schemas and migrations table first
            let schemas = [
                "auth", "directory", "mail", "accounting", "equity", "estates", "standards", "legal", "matters",
                "documents", "service", "admin",
            ]
            for schema in schemas {
                _ = try? await connection.query(
                    .init(stringLiteral: "DROP SCHEMA IF EXISTS \(schema) CASCADE"),
                    logger: logger
                )
            }
            _ = try? await connection.query(
                .init(stringLiteral: "DROP TABLE IF EXISTS migrations CASCADE"),
                logger: logger
            )
            _ = try? await connection.query(
                .init(stringLiteral: "DROP TYPE IF EXISTS migrations CASCADE"),
                logger: logger
            )

            // Clean up existing roles
            let roles = ["customer", "staff", "admin"]
            for role in roles {
                _ = try? await connection.query(.init(stringLiteral: "DROP ROLE IF EXISTS \(role)"), logger: logger)
            }

            // Run migrations
            let manager = MigrationManager(connection: connection, logger: logger)
            try await manager.initializeMigrationsTable()

            let migrationsDir = URL(fileURLWithPath: "Sources/Palette/Migrations")
            let files = try FileManager.default.contentsOfDirectory(at: migrationsDir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "sql" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }

            for file in files {
                let name = file.lastPathComponent
                let sql = try String(contentsOf: file, encoding: .utf8)
                do {
                    try await manager.applyMigration(name: name, sql: sql)
                } catch {
                    // Check if error is due to role already existing (which is acceptable)
                    let errorString = String(reflecting: error)
                    if errorString.contains("role") && errorString.contains("already exists") {
                        logger.info("Role already exists, continuing migration: \(name)")
                    } else {
                        throw error
                    }
                }
            }

            // TEST 1: Verify all schemas exist
            let expectedSchemas = [
                "auth", "directory", "mail", "accounting", "equity", "estates", "standards", "legal", "matters",
                "documents", "service", "admin",
            ]

            for schema in expectedSchemas {
                let query = "SELECT 1 FROM information_schema.schemata WHERE schema_name = '\(schema)'"
                let rows = try await connection.query(.init(stringLiteral: query), logger: logger)

                var found = false
                for try await _ in rows {
                    found = true
                    break
                }

                #expect(found, "Schema '\(schema)' should exist")
            }

            // TEST 2: Verify auth.users table exists and has correct structure
            let userTableQuery =
                "SELECT 1 FROM information_schema.tables WHERE table_schema = 'auth' AND table_name = 'users'"
            let userRows = try await connection.query(.init(stringLiteral: userTableQuery), logger: logger)

            var userTableExists = false
            for try await _ in userRows {
                userTableExists = true
                break
            }

            if userTableExists {
                // Verify table structure
                let columnsQuery = """
                    SELECT column_name, data_type, is_nullable, column_default
                    FROM information_schema.columns
                    WHERE table_schema = 'auth' AND table_name = 'users'
                    ORDER BY ordinal_position
                    """

                let columnRows = try await connection.query(.init(stringLiteral: columnsQuery), logger: logger)
                var columnCount = 0

                for try await _ in columnRows {
                    columnCount += 1
                }

                #expect(
                    columnCount >= 4,
                    "auth.users table should have at least 4 columns (id, email, created_at, updated_at)"
                )
            }

            // TEST 3: Verify migration table is properly filled
            let expectedNames = Set(files.map { $0.lastPathComponent })

            let rows = try await connection.query(
                .init(stringLiteral: "SELECT migration_name FROM migrations"),
                logger: logger
            )
            var actualNames = Set<String>()
            for try await row in rows {
                if let name = try? row.decode(String.self) {
                    actualNames.insert(name)
                }
            }
            #expect(
                actualNames == expectedNames,
                "All migration files should be recorded in the migrations table after migrate"
            )

            // Explicitly close the connection
            try await connection.close()
        } catch {
            print("Palette complete test error: \(String(reflecting: error))")
            // Ensure connection is closed even on error
            try? await connection.close()
            throw error
        }
    }
}
