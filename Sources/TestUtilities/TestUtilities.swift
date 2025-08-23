import Fluent
import FluentPostgresDriver
import FluentSQL
import Foundation
import Logging
import PostgresNIO
import ServiceLifecycle
import Testing
import Vapor

@testable import Dali
@testable import Palette

public enum TestError: Error {
    case invalidConnectionURL
    case databaseOperationFailed(String)
}

public enum TestTimeoutError: Error {
    case timeout(seconds: TimeInterval)

    public var localizedDescription: String {
        switch self {
        case .timeout(let seconds):
            return
                "Test timed out after \(seconds) seconds. This indicates an external network call or hanging operation."
        }
    }
}

public struct ForceRollback: Error {}

public actor TestResultCapture<T: Sendable> {
    private var result: Result<T, Error>?

    public init() {}

    public func setResult(_ value: Result<T, Error>) {
        result = value
    }

    public func getResult() -> Result<T, Error>? {
        result
    }
}

public struct VaporService: Service {
    public let app: Application

    public init(app: Application) {
        self.app = app
    }

    public func run() async throws {
        try await app.execute()
    }
}

public struct TestUtilities {

    /// Timeout wrapper to prevent tests from hanging on external network calls
    /// Tests will fail after 10 seconds to prevent wasting CI minutes
    public static func withTimeout<T: Sendable>(
        seconds: TimeInterval = 10,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TestTimeoutError.timeout(seconds: seconds)
            }

            defer { group.cancelAll() }
            return try await group.next()!
        }
    }

    /// Creates the admin@neonlaw.com admin user needed for tests
    public static func createAdminUser(_ database: Database) async throws {
        let postgres = database as! PostgresDatabase

        // Create person first
        try await postgres.sql().raw(
            """
            INSERT INTO directory.people (name, email)
            VALUES ('Admin User', 'admin@neonlaw.com')
            ON CONFLICT (email) DO NOTHING
            """
        ).run()

        // Create user with admin role using email as username
        try await postgres.sql().raw(
            """
            INSERT INTO auth.users (username, person_id, role)
            SELECT 'admin@neonlaw.com', p.id, 'admin'::auth.user_role
            FROM directory.people p
            WHERE p.email = 'admin@neonlaw.com'
            ON CONFLICT (username) DO NOTHING
            """
        ).run()
    }

    /// Creates a test user with specified role within the current transaction context
    /// This ensures the user data is visible to HTTP handlers in the same way as createAdminUser
    public static func createTestUser(
        _ database: Database,
        name: String,
        email: String,
        username: String,
        role: String
    ) async throws -> UUID {
        let postgres = database as! PostgresDatabase

        // Create person first
        try await postgres.sql().raw(
            """
            INSERT INTO directory.people (name, email)
            VALUES (\(bind: name), \(bind: email))
            ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name
            """
        ).run()

        // Create user with specified role using email as username
        let userResult = try await postgres.sql().raw(
            """
            INSERT INTO auth.users (username, person_id, role)
            SELECT \(bind: username), p.id, \(bind: role)::auth.user_role
            FROM directory.people p
            WHERE p.email = \(bind: email)
            ON CONFLICT (username) DO UPDATE SET person_id = EXCLUDED.person_id, role = EXCLUDED.role
            RETURNING id
            """
        ).first()

        guard let userId = try userResult?.decode(column: "id", as: UUID.self) else {
            throw Abort(.internalServerError, reason: "Failed to create test user")
        }

        return userId
    }

    /// Creates a test user with an associated person record in a single transaction
    /// This ensures the foreign key constraint between auth.users.username and directory.people.email is satisfied
    /// - Parameters:
    ///   - database: The database connection to use
    ///   - name: The person's name (optional, defaults to "Test User {UUID}")
    ///   - email: The person's email AND the user's username (optional, defaults to generated email)
    ///   - role: The user's role (optional, defaults to .staff)
    /// - Returns: A tuple containing the created person ID and user ID
    public static func createTestUserWithPerson(
        _ database: Database,
        name: String? = nil,
        email: String? = nil,
        role: UserRole = .staff
    ) async throws -> (personId: UUID, userId: UUID) {
        let postgres = database as! PostgresDatabase

        // Generate unique values if not provided
        let uniqueId = UniqueCodeGenerator.generateISOCode(prefix: "user")
        let finalEmail = email ?? "test.user.\(uniqueId)@example.com"
        let finalName = name ?? "Test User \(uniqueId)"

        // Create person first
        let personResult = try await postgres.sql().raw(
            """
            INSERT INTO directory.people (name, email)
            VALUES (\(bind: finalName), \(bind: finalEmail))
            ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name
            RETURNING id
            """
        ).first()

        guard let personId = try personResult?.decode(column: "id", as: UUID.self) else {
            throw TestError.databaseOperationFailed("Failed to create test person")
        }

        // Create user with the same email as username
        let userResult = try await postgres.sql().raw(
            """
            INSERT INTO auth.users (username, person_id, role)
            VALUES (\(bind: finalEmail), \(bind: personId), \(bind: role.rawValue)::auth.user_role)
            ON CONFLICT (username) DO UPDATE SET person_id = EXCLUDED.person_id, role = EXCLUDED.role
            RETURNING id
            """
        ).first()

        guard let userId = try userResult?.decode(column: "id", as: UUID.self) else {
            throw TestError.databaseOperationFailed("Failed to create test user")
        }

        return (personId: personId, userId: userId)
    }

    /// Creates a test person record without an associated user
    /// Use this when you only need a person record without authentication
    /// - Parameters:
    ///   - database: The database connection to use
    ///   - name: The person's name (optional, defaults to "Test Person {UUID}")
    ///   - email: The person's email (optional, defaults to generated email)
    /// - Returns: The created person ID
    public static func createTestPerson(
        _ database: Database,
        name: String? = nil,
        email: String? = nil
    ) async throws -> UUID {
        let postgres = database as! PostgresDatabase

        // Generate unique values if not provided
        let uniqueId = UniqueCodeGenerator.generateISOCode(prefix: "person")
        let finalEmail = email ?? "test.person.\(uniqueId)@example.com"
        let finalName = name ?? "Test Person \(uniqueId)"

        let result = try await postgres.sql().raw(
            """
            INSERT INTO directory.people (name, email)
            VALUES (\(bind: finalName), \(bind: finalEmail))
            RETURNING id
            """
        ).first()

        guard let personId = try result?.decode(column: "id", as: UUID.self) else {
            throw TestError.databaseOperationFailed("Failed to create test person")
        }

        return personId
    }

    /// Helper function to run test code within a database transaction that automatically rolls back
    /// This ensures all database changes made during the test are cleaned up afterwards
    /// This is the ONLY method that should be used for all database tests
    ///
    /// IMPORTANT: This method relies on serialized test execution to prevent database conflicts.
    /// All test suites must use the .serialized tag and tests must be run with --no-parallel.
    public static func withApp<T: Sendable>(
        _ closure: @Sendable @escaping (Application, Database) async throws -> T
    ) async throws -> T {
        // First ensure migrations are run
        try await runMigrations()

        let app = try await Application.make(.testing)

        // Configure PostgreSQL database with search path for testing
        var config = SQLPostgresConfiguration(
            hostname: "localhost",
            port: 5432,
            username: "postgres",
            password: nil,
            database: "luxe",
            tls: .disable
        )
        config.searchPath = [
            "auth", "directory", "mail", "accounting", "equity", "estates", "standards", "legal", "matters",
            "documents", "service", "admin", "public",
        ]

        // Use a single connection per event loop for serialized execution
        app.databases.use(.postgres(configuration: config, maxConnectionsPerEventLoop: 1), as: .psql)

        // Log connection setup for test monitoring
        let logger = Logger(label: "test-database")
        logger.debug(
            "Test database connection configured",
            metadata: [
                "max_connections": "1",
                "timeout": "default",
                "isolation": "transaction_rollback",
            ]
        )

        let resultCapture = TestResultCapture<T>()

        do {
            try await app.db.transaction { transaction in
                do {
                    let result = try await closure(app, transaction)
                    await resultCapture.setResult(.success(result))
                } catch {
                    await resultCapture.setResult(.failure(error))
                }
                // Always throw to force rollback regardless of test outcome
                throw ForceRollback()
            }
        } catch is ForceRollback {
            // Transaction was rolled back as intended
        }

        // Log connection cleanup for test monitoring
        logger.debug("Test transaction completed, shutting down application")

        // Explicitly shut down the application
        try await app.asyncShutdown()

        logger.debug("Test database application shutdown complete")

        // Small sleep to ensure proper cleanup between tests
        try await Task.sleep(for: .milliseconds(50))

        // Return the captured result or throw the captured error
        if let result = await resultCapture.getResult() {
            switch result {
            case .success(let value):
                return value
            case .failure(let error):
                throw error
            }
        } else {
            fatalError("Test result was not captured")
        }
    }

    /// Helper function for web targets that don't need database access
    /// Properly manages application lifecycle without database setup
    public static func withWebApp<T: Sendable>(
        _ closure: @Sendable @escaping (Application) async throws -> T
    ) async throws -> T {
        let app = try await Application.make(.testing)

        do {
            let result = try await closure(app)
            try await app.asyncShutdown()
            return result
        } catch {
            try await app.asyncShutdown()
            throw error
        }
    }

    /// Generate a random string for test identifiers to avoid unique constraint violations
    public static func randomString(length: Int = 8) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }

    /// Generate a random code with timestamp to ensure uniqueness
    public static func randomCode(prefix: String = "test") -> String {
        UniqueCodeGenerator.generateISOCode(prefix: prefix)
    }

    /// Generate a random UID with timestamp to ensure uniqueness
    public static func randomUID(prefix: String = "test") -> String {
        UniqueCodeGenerator.generateISOCode(prefix: "\(prefix)-uid")
    }

    /// Seeds questions from the Standards__Questions.yaml file into the database
    /// This ensures test questions match the actual application data
    public static func seedQuestions(_ database: Database) async throws {
        let postgres = database as! PostgresDatabase

        // Set admin context and disable RLS for seeding
        try await postgres.sql()
            .raw("SET app.current_user_role = 'admin'")
            .run()
        try await postgres.sql()
            .raw("SET row_security = off")
            .run()

        // Insert the actual questions from the seed file
        // These match Sources/Palette/Seeds/Standards__Questions.yaml
        // Only including questions with valid question_type values per the CHECK constraint
        let questionsData = [
            ("personal_name", "What is your name?", "string", "Please include your first, middle, and last name."),
            ("personal_address", "What is your personal address?", "address", "Please verify your address."),
            ("address", "What is the address for {{for_label}}?", "address", "Please enter all of the fields."),
            (
                "personal_ssn", "What is your Social Security Number?", "secret",
                "Please use your 9-digit social security number."
            ),
            (
                "annual_or_amended", "Is this an original or amended form?", "yes_no",
                "Please indicate if you are amending a previous application."
            ),
            (
                "nevada_business_id", "What is the Nevada Business Identification Number?", "string",
                "Your Nevada Business Identification Number is given by the Secretary of State"
            ),
            (
                "person", "Who is the {{label}}?", "person",
                "The person must pre-exist as a person record within Neon Law."
            ),
            (
                "neon_person", "Who is the {label} for Neon Law?", "person",
                "Who from Neon Law will be signing this document on our behalf?"
            ),
            ("formation_date", "When was the formation date of {{for_label}}?", "date", "When was the company formed?"),
            (
                "verify_eligible_lawyer", "Can the lawyer represent the client in the context of the Notation?",
                "person", "We perform an ethics check here to ensure that lawyers abide by appropriate ethics rules."
            ),
        ]

        for (code, prompt, questionType, helpText) in questionsData {
            try await postgres.sql().raw(
                """
                INSERT INTO standards.questions (code, prompt, question_type, help_text, choices, created_at, updated_at)
                VALUES (\(bind: code), \(bind: prompt), \(bind: questionType), \(bind: helpText), '[]'::JSONB, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                ON CONFLICT (code) DO UPDATE SET
                    prompt = EXCLUDED.prompt,
                    question_type = EXCLUDED.question_type,
                    help_text = EXCLUDED.help_text,
                    updated_at = CURRENT_TIMESTAMP
                """
            ).run()
        }
    }

    /// Helper function specifically for admin tests that need a fresh database with questions seeded
    /// This creates the admin user and seeds questions for proper testing
    public static func withFreshAdminDB<T: Sendable>(
        _ closure: @Sendable @escaping (Application, Database) async throws -> T
    ) async throws -> T {
        try await withApp { app, database in
            // Create the required admin user
            try await createAdminUser(database)

            // Seed questions for admin tests
            try await seedQuestions(database)

            // Run the test closure
            return try await closure(app, database)
        }
    }

    // Actor to manage migration state in a thread-safe way
    private actor TestMigrationManager {
        private var completed = false

        func runMigrationsIfNeeded() async throws {
            // If migrations already completed in this session, skip
            if completed {
                return
            }

            // Run the actual migrations
            try await performMigrations()

            // Mark as completed
            completed = true
        }

        private func performMigrations() async throws {
            let logger = Logger(label: "test-migrations")

            // Quick check if critical tables already exist to avoid unnecessary migration runs
            do {
                let url = "postgres://postgres@localhost:5432/luxe"
                guard let url = URL(string: url),
                    let host = url.host,
                    let database = url.path.split(separator: "/").last.map(String.init)
                else {
                    throw TestError.invalidConnectionURL
                }

                let port = url.port ?? 5432
                let username = url.user ?? "postgres"

                let configuration = PostgresConnection.Configuration(
                    host: host,
                    port: port,
                    username: username,
                    password: nil,
                    database: database,
                    tls: .disable
                )

                let connection = try await PostgresConnection.connect(
                    configuration: configuration,
                    id: .init(),
                    logger: logger
                )

                // Check if key tables exist
                let checkQuery = """
                        SELECT COUNT(*) as table_count FROM information_schema.tables
                        WHERE table_schema IN ('auth', 'directory', 'equity')
                        AND table_name IN ('users', 'people', 'entities', 'share_classes')
                    """
                let result = try await connection.query(.init(stringLiteral: checkQuery), logger: logger)
                var tableCount = 0

                for try await row in result {
                    tableCount = try row.decode(Int.self, context: .default)
                }

                // Always close the connection before returning
                try await connection.close()

                // If we have all 4 key tables, migrations are likely complete
                if tableCount >= 4 {
                    logger.info("Key tables already exist, skipping migration run")
                    return
                }
            } catch {
                // If we can't check, proceed with migration
                logger.info("Unable to check table state, proceeding with migration")
            }

            // Use direct migration method calls instead of subprocess to avoid mutex issues
            logger.info("Running migrations using direct method calls")

            let configuration = PostgresConnection.Configuration(
                host: "localhost",
                port: 5432,
                username: "postgres",
                password: nil,
                database: "luxe",
                tls: .disable
            )

            // Use the same ConnectionManager that the Palette command uses
            let connectionManager = ConnectionManager(configuration: configuration, logger: logger)
            try await connectionManager.runMigrations()

            logger.info("Migrations completed successfully")
        }
    }

    // Static instance of test migration manager
    private static let migrationManager = TestMigrationManager()

    private static func runMigrations() async throws {
        try await migrationManager.runMigrationsIfNeeded()
    }

    /// Checks database connection health and logs connection pool status
    /// This is useful for diagnosing connection issues in failing tests
    public static func checkDatabaseConnectionHealth(_ database: Database) async throws {
        let logger = Logger(label: "test-connection-health")

        do {
            // Simple connection health check using a lightweight query
            let postgres = database as! PostgresDatabase
            let startTime = Date()

            let result = try await postgres.sql()
                .raw("SELECT 1 as health_check, NOW() as server_time")
                .first()

            let duration = Date().timeIntervalSince(startTime)

            guard let healthResult = result else {
                logger.error("Database connection health check failed: no result returned")
                throw TestError.databaseOperationFailed("Connection health check returned no result")
            }

            let healthValue = try healthResult.decode(column: "health_check", as: Int.self)
            let serverTime = try healthResult.decode(column: "server_time", as: Date.self)

            if healthValue == 1 {
                logger.info(
                    "Database connection health check passed",
                    metadata: [
                        "response_time_ms": .stringConvertible(Int(duration * 1000)),
                        "server_time": .string(ISO8601DateFormatter().string(from: serverTime)),
                    ]
                )
            } else {
                logger.error("Database connection health check failed: unexpected result")
                throw TestError.databaseOperationFailed("Health check returned unexpected value: \(healthValue)")
            }
        } catch {
            let logger = Logger(label: "test-connection-health")
            logger.error(
                "Database connection health check failed",
                metadata: [
                    "error": .string(String(describing: error))
                ]
            )
            throw error
        }
    }

    /// Logs current connection pool status for debugging connection issues
    /// This can be called during test execution to monitor connection usage
    public static func logConnectionPoolStatus(_ database: Database, context: String) {
        let logger = Logger(label: "test-connection-pool")

        // Log basic connection pool information
        logger.debug(
            "Connection pool status check",
            metadata: [
                "context": .string(context),
                "database_type": .string("PostgreSQL"),
                "pool_strategy": .string("single_connection_per_loop"),
            ]
        )
    }
}
