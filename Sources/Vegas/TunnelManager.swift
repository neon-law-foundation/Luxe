import Foundation
import PostgresNIO

/// Configuration for establishing an AWS Session Manager tunnel to a VPC-internal database.
///
/// This struct encapsulates all the necessary information to create a secure tunnel
/// between your local machine and a PostgreSQL database running inside a VPC using
/// AWS Session Manager port forwarding.
///
/// ## Usage
/// ```swift
/// let config = TunnelConfiguration(
///     bastionInstanceId: "i-1234567890abcdef0",
///     rdsEndpoint: "my-db.cluster-xyz.us-west-2.rds.amazonaws.com",
///     localPort: 5432,
///     remotePort: 5432
/// )
/// ```
struct TunnelConfiguration {
    /// The EC2 instance ID that will act as the bastion host for the tunnel.
    /// This instance must have the AWS Systems Manager agent installed and be
    /// configured to allow Session Manager connections.
    let bastionInstanceId: String

    /// The RDS endpoint hostname that the tunnel will forward traffic to.
    /// This should be the internal DNS name of your RDS instance.
    let rdsEndpoint: String

    /// The local port on your machine that will accept connections.
    /// Traffic sent to this port will be forwarded through the tunnel.
    let localPort: Int

    /// The remote port on the RDS instance (typically 5432 for PostgreSQL).
    let remotePort: Int
}

/// Errors that can occur during tunnel establishment and database connections.
enum TunnelError: Error {
    /// AWS credentials are missing from the environment.
    /// Ensure AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are set.
    case missingAWSCredentials

    /// The AWS Session Manager tunnel could not be established.
    /// - Parameter message: Detailed error message from the tunnel establishment process.
    case tunnelEstablishmentFailed(String)

    /// Failed to connect to the PostgreSQL database through the tunnel.
    /// - Parameter message: Detailed error message from the connection attempt.
    case connectionFailed(String)

    /// The tunnel configuration contains invalid parameters.
    /// - Parameter message: Description of the configuration issue.
    case invalidConfiguration(String)
}

/// Manages AWS Session Manager tunnels for secure database access.
///
/// This class provides a high-level interface for establishing and managing
/// AWS Session Manager port forwarding tunnels to access databases running
/// inside private VPCs without exposing them to the public internet.
///
/// ## Features
/// - Secure tunnel establishment using AWS Session Manager
/// - Automatic tunnel lifecycle management
/// - Connection validation and health checks
/// - Clean resource cleanup
///
/// ## Prerequisites
/// Before using this class, ensure:
/// - AWS CLI is installed and configured
/// - Session Manager plugin is installed
/// - Target EC2 instance has SSM agent and appropriate IAM roles
/// - Network security groups allow traffic between bastion and database
///
/// ## Example Usage
/// ```swift
/// let config = TunnelConfiguration(
///     bastionInstanceId: "i-1234567890abcdef0",
///     rdsEndpoint: "my-db.cluster-xyz.us-west-2.rds.amazonaws.com",
///     localPort: 5432,
///     remotePort: 5432
/// )
///
/// let tunnel = AWSSessionManagerTunnel(configuration: config)
/// try await tunnel.establishTunnel()
///
/// // Use localhost:5432 to connect to the database
/// let connectionURL = tunnel.getPostgresConnectionURL(
///     username: "postgres",
///     password: "mypassword",
///     database: "mydb"
/// )
///
/// await tunnel.terminateTunnel()
/// ```
class AWSSessionManagerTunnel {
    /// The tunnel configuration containing connection details.
    let configuration: TunnelConfiguration

    /// The underlying process managing the AWS CLI session.
    private var tunnelProcess: Process?

    /// Whether the tunnel is currently connected and active.
    private(set) var isConnected = false

    /// Initializes a new tunnel manager with the specified configuration.
    /// - Parameter configuration: The tunnel configuration to use.
    init(configuration: TunnelConfiguration) {
        self.configuration = configuration
    }

    /// Validates that the required AWS credentials are available in the environment.
    ///
    /// This method checks for the presence of AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
    /// environment variables, which are required for AWS CLI operations.
    ///
    /// - Throws: `TunnelError.missingAWSCredentials` if credentials are not found.
    func validateAWSCredentials() async throws {
        guard ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"] != nil,
            ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"] != nil
        else {
            throw TunnelError.missingAWSCredentials
        }
    }

    /// Establishes the AWS Session Manager tunnel to the target database.
    ///
    /// This method uses the AWS CLI to create a Session Manager port forwarding session
    /// that tunnels traffic from your local machine to the database through the bastion host.
    ///
    /// The tunnel will remain active until `terminateTunnel()` is called or the process exits.
    ///
    /// - Throws: `TunnelError.tunnelEstablishmentFailed` if the tunnel cannot be created.
    func establishTunnel() async throws {
        try await validateAWSCredentials()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "aws", "ssm", "start-session",
            "--target", configuration.bastionInstanceId,
            "--document-name", "AWS-StartPortForwardingSessionToRemoteHost",
            "--parameters",
            "host=\"\(configuration.rdsEndpoint)\",portNumber=\"\(configuration.remotePort)\",localPortNumber=\"\(configuration.localPort)\"",
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            tunnelProcess = process

            // Wait a moment for tunnel to establish
            try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

            // Check if process is still running
            if process.isRunning {
                isConnected = true
                print("🔗 AWS Session Manager tunnel established")
                print("📍 Local port: \(configuration.localPort)")
                print("📍 Remote endpoint: \(configuration.rdsEndpoint):\(configuration.remotePort)")
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                throw TunnelError.tunnelEstablishmentFailed(errorString)
            }
        } catch {
            throw TunnelError.tunnelEstablishmentFailed(error.localizedDescription)
        }
    }

    /// Terminates the active tunnel connection.
    ///
    /// This method gracefully shuts down the Session Manager tunnel process
    /// and cleans up all associated resources.
    ///
    /// It's safe to call this method even if no tunnel is currently active.
    func terminateTunnel() async {
        if let process = tunnelProcess, process.isRunning {
            process.terminate()
            process.waitUntilExit()
            print("🔌 AWS Session Manager tunnel terminated")
        }
        tunnelProcess = nil
        isConnected = false
    }

    /// Generates a PostgreSQL connection URL for use with the tunnel.
    ///
    /// This method creates a properly formatted PostgreSQL connection string
    /// that points to the local tunnel endpoint (127.0.0.1).
    ///
    /// - Parameters:
    ///   - username: The PostgreSQL username.
    ///   - password: The PostgreSQL password.
    ///   - database: The name of the database to connect to.
    /// - Returns: A PostgreSQL connection URL string suitable for use with PostgreSQL clients.
    ///
    /// ## Example
    /// ```swift
    /// let url = tunnel.getPostgresConnectionURL(
    ///     username: "postgres",
    ///     password: "mypassword",
    ///     database: "luxe"
    /// )
    /// // Returns: "postgresql://postgres:mypassword@127.0.0.1:5432/luxe?sslmode=require"
    /// ```
    func getPostgresConnectionURL(username: String, password: String, database: String) -> String {
        "postgresql://\(username):\(password)@127.0.0.1:\(configuration.localPort)/\(database)?sslmode=require"
    }
}

/// High-level PostgreSQL connection manager that uses AWS Session Manager tunnels.
///
/// This class combines tunnel management with PostgreSQL connection handling to provide
/// a seamless experience for connecting to databases in private VPCs.
///
/// ## Features
/// - Automatic tunnel establishment and cleanup
/// - PostgreSQL connection lifecycle management
/// - Connection health monitoring
/// - Query execution capabilities
/// - Comprehensive error handling
///
/// ## Usage
/// ```swift
/// let config = TunnelConfiguration(
///     bastionInstanceId: "i-1234567890abcdef0",
///     rdsEndpoint: "my-db.cluster-xyz.us-west-2.rds.amazonaws.com",
///     localPort: 5432,
///     remotePort: 5432
/// )
///
/// let manager = PostgresConnectionManager(
///     tunnelConfiguration: config,
///     username: "postgres",
///     password: "mypassword",
///     database: "luxe"
/// )
///
/// try await manager.connect()
/// let result = try await manager.executeQuery("SELECT version()")
/// print(result)
/// await manager.disconnect()
/// ```
class PostgresConnectionManager {
    /// The tunnel manager used for secure connections.
    private let tunnel: AWSSessionManagerTunnel

    /// The PostgreSQL username for authentication.
    let username: String

    /// The PostgreSQL password for authentication.
    private let password: String

    /// The name of the database to connect to.
    let database: String

    /// The active PostgreSQL connection, if established.
    private var connection: PostgresConnection?

    /// Whether there is an active connection to the database through the tunnel.
    var isConnected: Bool {
        connection != nil && tunnel.isConnected
    }

    /// Initializes a new connection manager with the specified configuration.
    ///
    /// - Parameters:
    ///   - tunnelConfiguration: Configuration for the AWS Session Manager tunnel.
    ///   - username: PostgreSQL username for authentication.
    ///   - password: PostgreSQL password for authentication.
    ///   - database: Name of the database to connect to.
    init(tunnelConfiguration: TunnelConfiguration, username: String, password: String, database: String) {
        self.tunnel = AWSSessionManagerTunnel(configuration: tunnelConfiguration)
        self.username = username
        self.password = password
        self.database = database
    }

    /// Establishes both the tunnel and PostgreSQL connection.
    ///
    /// This method first creates the AWS Session Manager tunnel, then establishes
    /// a PostgreSQL connection through that tunnel. If either step fails, cleanup
    /// is performed automatically.
    ///
    /// - Throws: `TunnelError.tunnelEstablishmentFailed` if the tunnel cannot be created,
    ///           or `TunnelError.connectionFailed` if PostgreSQL connection fails.
    func connect() async throws {
        // First establish the tunnel
        try await tunnel.establishTunnel()

        // Then connect to Postgres through the tunnel
        let _ = tunnel.getPostgresConnectionURL(
            username: username,
            password: password,
            database: database
        )

        do {
            let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            let eventLoop = eventLoopGroup.next()

            let config = PostgresConnection.Configuration(
                host: "127.0.0.1",
                port: tunnel.configuration.localPort,
                username: username,
                password: password,
                database: database,
                tls: .prefer(try .init(configuration: .clientDefault))
            )

            connection = try await PostgresConnection.connect(
                on: eventLoop,
                configuration: config,
                id: 1,
                logger: .init(label: "postgres-connection")
            )

            print("🐘 Successfully connected to PostgreSQL through tunnel")
            print(
                "🔗 Connection URL: postgresql://\(username):****@127.0.0.1:\(tunnel.configuration.localPort)/\(database)?sslmode=disable"
            )

        } catch {
            await tunnel.terminateTunnel()
            throw TunnelError.connectionFailed("Failed to connect to PostgreSQL: \(error.localizedDescription)")
        }
    }

    /// Tests the health of the PostgreSQL connection.
    ///
    /// This method executes a simple `SELECT 1` query to verify that the database
    /// connection is working properly.
    ///
    /// - Returns: `true` if the connection is healthy, `false` otherwise.
    /// - Throws: `TunnelError.connectionFailed` if there's no active connection or the test fails.
    func testConnection() async throws -> Bool {
        guard let connection = connection else {
            throw TunnelError.connectionFailed("No active connection")
        }

        do {
            let rows = try await connection.query(
                PostgresQuery(stringLiteral: "SELECT 1 as test"),
                logger: .init(label: "postgres-test")
            )
            let collected = try await rows.collect()
            return !collected.isEmpty
        } catch {
            throw TunnelError.connectionFailed("Connection test failed: \(error.localizedDescription)")
        }
    }

    /// Executes a SQL query against the connected PostgreSQL database.
    ///
    /// This method runs the provided SQL query and returns a formatted string
    /// representation of the results.
    ///
    /// - Parameter query: The SQL query to execute.
    /// - Returns: A formatted string containing the query results.
    /// - Throws: `TunnelError.connectionFailed` if there's no active connection or query execution fails.
    ///
    /// ## Example
    /// ```swift
    /// let result = try await manager.executeQuery("SELECT version()")
    /// print(result)
    /// ```
    func executeQuery(_ query: String) async throws -> String {
        guard let connection = connection else {
            throw TunnelError.connectionFailed("No active connection")
        }

        do {
            let rows = try await connection.query(
                PostgresQuery(stringLiteral: query),
                logger: .init(label: "postgres-query")
            )
            return try await formatQueryResults(rows)
        } catch {
            throw TunnelError.connectionFailed("Query execution failed: \(error.localizedDescription)")
        }
    }

    /// Formats query results into a human-readable string.
    ///
    /// - Parameter rows: The PostgreSQL row sequence to format.
    /// - Returns: A formatted string representation of the query results.
    private func formatQueryResults(_ rows: PostgresRowSequence) async throws -> String {
        var result = ""
        var count = 0

        for try await row in rows {
            count += 1
            result += "\nRow \(count):\n"

            // Try to decode the row as a single value (for simple queries)
            if let stringValue = try? row.decode(String.self) {
                result += "  value: \(stringValue)\n"
            } else if let intValue = try? row.decode(Int64.self) {
                result += "  value: \(intValue)\n"
            } else {
                // For complex queries, we'll just display what we can
                result += "  [complex row data - decode manually if needed]\n"
            }
        }

        if count == 0 {
            return "No results found.\n"
        }

        return "Query returned \(count) row(s).\n" + result
    }

    /// Disconnects from the PostgreSQL database and terminates the tunnel.
    ///
    /// This method performs a clean shutdown of both the database connection
    /// and the underlying Session Manager tunnel. It's safe to call this method
    /// multiple times or when no connection is active.
    func disconnect() async {
        if let connection = connection {
            try? await connection.close()
        }
        connection = nil
        await tunnel.terminateTunnel()
        print("🔌 PostgreSQL connection closed")
    }
}
