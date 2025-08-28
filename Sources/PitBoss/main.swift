import ArgumentParser
import AsyncHTTPClient
import Bouncer
import Dali
import Logging
import Vapor

struct PitBoss: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pitboss",
        abstract: "Slack bot for team metrics and system health monitoring"
    )

    @ArgumentParser.Option(name: .long, help: "Port to run the bot server on")
    var port: Int = 8080

    @ArgumentParser.Option(name: .long, help: "Slack signing secret for webhook verification")
    var slackSigningSecret: String?

    @ArgumentParser.Option(name: .long, help: "Database URL (PostgreSQL connection string)")
    var databaseURL: String?

    @ArgumentParser.Option(name: .long, help: "Service account token for authentication")
    var serviceToken: String?

    @ArgumentParser.Option(name: .long, help: "Log level (trace, debug, info, notice, warning, error, critical)")
    var logLevel: String = "info"

    mutating func run() async throws {
        // Configure logging
        let loggerLevel = Logger.Level(rawValue: logLevel) ?? .info
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = loggerLevel
            return handler
        }

        let logger = Logger(label: "pitboss")
        logger.info(
            "Starting PitBoss Slack bot",
            metadata: [
                "port": .string("\(port)"),
                "logLevel": .string("\(loggerLevel)"),
            ]
        )

        // Get environment variables if not provided via CLI
        let finalSlackSigningSecret = slackSigningSecret ?? ProcessInfo.processInfo.environment["SLACK_SIGNING_SECRET"]
        let finalDatabaseURL = databaseURL ?? ProcessInfo.processInfo.environment["DATABASE_URL"]
        let finalServiceToken = serviceToken ?? ProcessInfo.processInfo.environment["SERVICE_ACCOUNT_TOKEN"]

        guard let signingSecret = finalSlackSigningSecret else {
            logger.error("SLACK_SIGNING_SECRET is required. Provide via --slack-signing-secret or environment variable")
            throw ValidationError("Missing SLACK_SIGNING_SECRET")
        }

        guard let dbURL = finalDatabaseURL else {
            logger.error("DATABASE_URL is required. Provide via --database-url or environment variable")
            throw ValidationError("Missing DATABASE_URL")
        }

        guard let token = finalServiceToken else {
            logger.error("SERVICE_ACCOUNT_TOKEN is required. Provide via --service-token or environment variable")
            throw ValidationError("Missing SERVICE_ACCOUNT_TOKEN")
        }

        // Create Vapor application
        let env = try Environment.detect()
        let app = try await Application.make(env)

        defer {
            Task {
                try await app.asyncShutdown()
            }
        }

        // Configure server
        app.http.server.configuration = .init(
            hostname: "0.0.0.0",
            port: port,
            backlog: 256,
            reuseAddress: true,
            tcpNoDelay: true
        )

        // Configure database
        try app.databases.use(.postgres(url: dbURL), as: .psql)

        // Configure Slack bot
        let slackBot = SlackBot(
            signingSecret: signingSecret,
            serviceToken: token,
            logger: logger
        )

        try slackBot.configure(app)

        // Health check endpoint
        app.get("health") { req async throws -> [String: String] in
            ["status": "healthy", "service": "pitboss"]
        }

        logger.info(
            "PitBoss Slack bot initialized successfully",
            metadata: [
                "port": .string("\(port)"),
                "environment": .string(env.name),
            ]
        )

        try await app.execute()
    }
}

struct ValidationError: Error, CustomStringConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var description: String {
        message
    }
}

// Entry point
PitBoss.main()
