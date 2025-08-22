import Fluent
import FluentPostgresDriver
import FluentSQL
import Foundation
import PostgresNIO
import Vapor

/// Returns the default maximum connections per event loop based on environment
private func defaultMaxConnectionsPerEventLoop(for environment: Environment) -> Int {
    switch environment {
    case .testing:
        // Strict limits for tests to prevent connection exhaustion and ensure transaction isolation
        return 1
    case .development:
        // Allow more connections for local development but keep controlled
        return 2
    case .production:
        // Higher limits for production traffic but still controlled to prevent exhaustion
        return 4
    default:
        // Conservative default for unknown environments
        return 2
    }
}

/// Returns connection timeout based on environment
private func connectionTimeoutForEnvironment(_ environment: Environment) -> TimeAmount {
    switch environment {
    case .testing:
        // Fail fast in tests to catch hanging operations quickly
        return .seconds(5)
    case .development:
        // Reasonable timeout for development
        return .seconds(15)
    case .production:
        // Longer timeout for production to handle high load
        return .seconds(30)
    default:
        // Conservative default
        return .seconds(15)
    }
}

/// Logs database connection pool configuration for monitoring and debugging
private func logConnectionPoolConfiguration(
    environment: Environment,
    maxConnections: Int,
    timeout: TimeAmount,
    logger: Logger
) {
    let timeoutSeconds = Int(timeout.nanoseconds / 1_000_000_000)

    logger.info(
        "Database connection pool configured",
        metadata: [
            "environment": .string(environment.name),
            "max_connections_per_loop": .stringConvertible(maxConnections),
            "connection_timeout_seconds": .stringConvertible(timeoutSeconds),
            "pool_strategy": .string("environment_based"),
        ]
    )

    // Additional logging for test environment to help with debugging
    if environment == .testing {
        logger.debug(
            "Test environment connection pool settings optimized for transaction isolation and fast failure detection"
        )
    }
}

/// Configures database connection with SSL support for RDS
public func configureDaliDatabase(app: Application) throws {
    let databaseURL = Environment.get("DATABASE_URL") ?? "postgres://postgres@localhost:5432/luxe?sslmode=disable"

    guard let url = URL(string: databaseURL),
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
        let host = components.host
    else {
        fatalError("Invalid DATABASE_URL")
    }

    // Extract connection parameters from URL
    let port = components.port ?? 5432
    let username = components.user ?? "postgres"
    let password = components.password
    let database = String(components.path.dropFirst())  // Remove leading slash

    // Parse query parameters for SSL mode
    let queryItems = components.queryItems ?? []
    let sslMode = queryItems.first(where: { $0.name == "sslmode" })?.value ?? "prefer"

    // Configure TLS based on sslmode parameter
    let tlsConfig: PostgresConnection.Configuration.TLS
    switch sslMode {
    case "disable":
        tlsConfig = .disable
    case "require":
        tlsConfig = try .require(.init(configuration: .makeClientConfiguration()))
    default:
        tlsConfig = try .prefer(.init(configuration: .makeClientConfiguration()))
    }

    // Create configuration with search path
    var config = SQLPostgresConfiguration(
        hostname: host,
        port: port,
        username: username,
        password: password,
        database: database.isEmpty ? "luxe" : database,
        tls: tlsConfig
    )

    // Set search path to include all schemas from create_schemas migration
    config.searchPath = [
        "auth", "directory", "mail", "accounting", "equity", "estates", "standards", "legal", "matters", "documents",
        "service", "admin",
        "public",
    ]

    // Configure connection pool limits based on environment
    let maxConnections =
        Environment.get("DB_MAX_CONNECTIONS_PER_LOOP")
        .flatMap(Int.init) ?? defaultMaxConnectionsPerEventLoop(for: app.environment)

    let connectionTimeout: TimeAmount = connectionTimeoutForEnvironment(app.environment)

    app.databases.use(
        .postgres(
            configuration: config,
            maxConnectionsPerEventLoop: maxConnections,
            connectionPoolTimeout: connectionTimeout
        ),
        as: .psql
    )

    // Add connection monitoring for non-production environments
    if app.environment != .production {
        logConnectionPoolConfiguration(
            environment: app.environment,
            maxConnections: maxConnections,
            timeout: connectionTimeout,
            logger: app.logger
        )
    }
}

/// Alias for configureDaliDatabase for backward compatibility
public func configureDali(_ app: Application) throws {
    // Only configure database if not already configured (for tests)
    // In test environment, preserve existing configuration which may have custom search path
    if app.databases.configuration(for: .psql) == nil {
        try configureDaliDatabase(app: app)
    } else if app.environment == .testing {
        // In tests, keep the existing configuration that was set up by TestUtilities
        print("Dali: Keeping existing database configuration for tests")
    }
}
