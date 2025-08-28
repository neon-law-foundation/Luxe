import AsyncHTTPClient
import Bouncer
import Crypto
import Dali
import Logging
import Vapor

public struct SlackBot: Sendable {
    private let signingSecret: String
    private let serviceToken: String
    private let logger: Logger
    private let rateLimiter: RateLimiter

    public init(signingSecret: String, serviceToken: String, logger: Logger) {
        self.signingSecret = signingSecret
        self.serviceToken = serviceToken
        self.logger = logger
        self.rateLimiter = RateLimiter(
            maxRequestsPerMinute: 60,
            maxBurst: 10,
            logger: logger
        )
    }

    public func configure(_ app: Application) throws {
        // Add middleware to the application
        let verificationMiddleware = SlackSignatureVerificationMiddleware(signingSecret: signingSecret)
        let rateLimitMiddleware = RateLimitMiddleware(rateLimiter: rateLimiter, logger: logger)

        let slackRoutes = app.grouped("slack")
            .grouped(verificationMiddleware)
            .grouped(rateLimitMiddleware)

        // Routes
        slackRoutes.post("webhook", use: handleWebhook)
        slackRoutes.post("slash-command", use: handleSlashCommand)
        slackRoutes.post("interactive", use: handleInteractive)

        logger.info(
            "Slack bot routes configured",
            metadata: [
                "routes": .array([
                    .string("POST /slack/webhook"),
                    .string("POST /slack/slash-command"),
                    .string("POST /slack/interactive"),
                ])
            ]
        )
    }

    func handleWebhook(req: Request) async throws -> Response {
        let payload = try req.content.decode(SlackWebhookPayload.self)

        logger.info(
            "Received Slack webhook",
            metadata: [
                "type": .string(payload.type),
                "teamId": .string(payload.teamId ?? "unknown"),
            ]
        )

        switch payload.type {
        case "url_verification":
            return try await handleURLVerification(req: req, payload: payload)
        case "event_callback":
            return try await handleEventCallback(req: req, payload: payload)
        default:
            logger.warning(
                "Unknown webhook type",
                metadata: [
                    "type": .string(payload.type)
                ]
            )
            return Response(status: .ok)
        }
    }

    func handleSlashCommand(req: Request) async throws -> SlackCommandResponse {
        let command = try req.content.decode(SlackSlashCommand.self)

        logger.info(
            "Received slash command",
            metadata: [
                "command": .string(command.command),
                "userId": .string(command.userId),
                "channelId": .string(command.channelId),
                "text": .string(command.text),
            ]
        )

        switch command.command {
        case "/metrics":
            return try await handleMetricsCommand(command: command, req: req)
        case "/health":
            return try await handleHealthCommand(command: command, req: req)
        case "/users":
            return try await handleUsersCommand(command: command, req: req)
        case "/entities":
            return try await handleEntitiesCommand(command: command, req: req)
        default:
            return SlackCommandResponse(
                responseType: .ephemeral,
                text:
                    "Unknown command: `\(command.command)`\\n\\nAvailable commands:\\n• `/metrics` - Show team metrics\\n• `/health` - Show system health\\n• `/users` - Show user statistics\\n• `/entities` - Show entity statistics"
            )
        }
    }

    func handleInteractive(req: Request) async throws -> Response {
        logger.info("Received interactive component")
        // TODO: Implement interactive component handling for buttons, select menus, etc.
        return Response(status: .ok)
    }

    // MARK: - URL Verification

    private func handleURLVerification(req: Request, payload: SlackWebhookPayload) async throws -> Response {
        guard let challenge = payload.challenge else {
            throw Abort(.badRequest, reason: "Missing challenge in URL verification")
        }

        logger.info(
            "Handling URL verification",
            metadata: [
                "challenge": .string(challenge)
            ]
        )

        return Response(status: .ok, body: .init(string: challenge))
    }

    // MARK: - Event Callback

    private func handleEventCallback(req: Request, payload: SlackWebhookPayload) async throws -> Response {
        guard let event = payload.event else {
            logger.warning("Event callback without event data")
            return Response(status: .ok)
        }

        logger.info(
            "Processing event",
            metadata: [
                "eventType": .string(event.type),
                "user": .string(event.user ?? "unknown"),
                "channel": .string(event.channel ?? "unknown"),
            ]
        )

        // Process different event types
        switch event.type {
        case "app_mention":
            // Handle when the bot is mentioned
            logger.info(
                "Bot mentioned",
                metadata: [
                    "text": .string(event.text ?? "")
                ]
            )
        case "message":
            // Handle direct messages or channel messages
            logger.info(
                "Message received",
                metadata: [
                    "text": .string(event.text ?? "")
                ]
            )
        default:
            logger.debug(
                "Unhandled event type",
                metadata: [
                    "type": .string(event.type)
                ]
            )
        }

        return Response(status: .ok)
    }

    // MARK: - Command Handlers

    private func handleMetricsCommand(command: SlackSlashCommand, req: Request) async throws -> SlackCommandResponse {
        logger.info("Fetching metrics for command")

        let metricsService = DefaultMetricsService(
            database: req.db,
            logger: logger
        )

        let userMetrics = try await metricsService.getUserMetrics()
        let entityMetrics = try await metricsService.getEntityMetrics()

        let blocks = createMetricsBlocks(userMetrics: userMetrics, entityMetrics: entityMetrics)

        return SlackCommandResponse(
            responseType: .inChannel,
            text: "Team Metrics Dashboard",
            blocks: blocks
        )
    }

    private func handleHealthCommand(command: SlackSlashCommand, req: Request) async throws -> SlackCommandResponse {
        logger.info("Fetching health status")

        let metricsService = DefaultMetricsService(
            database: req.db,
            logger: logger
        )

        let health = try await metricsService.getSystemHealth()

        let blocks = createHealthBlocks(health: health)

        return SlackCommandResponse(
            responseType: .ephemeral,
            text: "System Health Status",
            blocks: blocks
        )
    }

    private func handleUsersCommand(command: SlackSlashCommand, req: Request) async throws -> SlackCommandResponse {
        logger.info("Fetching user statistics")

        let metricsService = DefaultMetricsService(
            database: req.db,
            logger: logger
        )

        let userMetrics = try await metricsService.getUserMetrics()

        let blocks = createUserStatsBlocks(metrics: userMetrics)

        return SlackCommandResponse(
            responseType: command.text.contains("public") ? .inChannel : .ephemeral,
            text: "User Statistics",
            blocks: blocks
        )
    }

    private func handleEntitiesCommand(command: SlackSlashCommand, req: Request) async throws -> SlackCommandResponse {
        logger.info("Fetching entity statistics")

        let metricsService = DefaultMetricsService(
            database: req.db,
            logger: logger
        )

        let entityMetrics = try await metricsService.getEntityMetrics()

        let blocks = createEntityStatsBlocks(metrics: entityMetrics)

        return SlackCommandResponse(
            responseType: command.text.contains("public") ? .inChannel : .ephemeral,
            text: "Entity Statistics",
            blocks: blocks
        )
    }

    // MARK: - Block Builders

    private func createMetricsBlocks(userMetrics: UserMetrics, entityMetrics: EntityMetrics) -> [SlackBlock] {
        var blocks: [SlackBlock] = []

        // Header
        blocks.append(
            SlackBlock(
                type: "header",
                text: SlackText(type: "plain_text", text: "📊 Team Metrics Dashboard")
            )
        )

        // Divider
        blocks.append(SlackBlock(type: "divider", text: nil))

        // User Section
        blocks.append(
            SlackBlock(
                type: "section",
                text: SlackText(
                    type: "mrkdwn",
                    text:
                        "*👥 Users*\\n• Total: \(userMetrics.totalUsers)\\n• Active (30d): \(userMetrics.activeUsers)\\n• New this week: \(userMetrics.newUsersThisWeek)\\n• New this month: \(userMetrics.newUsersThisMonth)"
                )
            )
        )

        // Entity Section
        blocks.append(
            SlackBlock(
                type: "section",
                text: SlackText(
                    type: "mrkdwn",
                    text:
                        "*🏢 Entities*\\n• Total: \(entityMetrics.totalEntities)\\n• New this week: \(entityMetrics.newEntitiesThisWeek)\\n• New this month: \(entityMetrics.newEntitiesThisMonth)"
                )
            )
        )

        // Footer
        blocks.append(
            SlackBlock(
                type: "context",
                text: SlackText(
                    type: "mrkdwn",
                    text: "Updated: <!date^\(Int(Date().timeIntervalSince1970))^{date_short_pretty} at {time}|now>"
                )
            )
        )

        return blocks
    }

    private func createHealthBlocks(health: SystemHealthMetrics) -> [SlackBlock] {
        var blocks: [SlackBlock] = []

        // Header
        blocks.append(
            SlackBlock(
                type: "header",
                text: SlackText(type: "plain_text", text: "🏥 System Health Status")
            )
        )

        // Status
        let statusEmoji = health.databaseConnections > 0 ? "✅" : "❌"
        blocks.append(
            SlackBlock(
                type: "section",
                text: SlackText(
                    type: "mrkdwn",
                    text: "\(statusEmoji) *Overall Status*: \(health.databaseConnections > 0 ? "Healthy" : "Degraded")"
                )
            )
        )

        // Metrics
        let uptimeHours = Int(health.uptime / 3600)
        let uptimeDays = uptimeHours / 24
        let uptimeString = uptimeDays > 0 ? "\(uptimeDays) days, \(uptimeHours % 24) hours" : "\(uptimeHours) hours"

        blocks.append(
            SlackBlock(
                type: "section",
                text: SlackText(
                    type: "mrkdwn",
                    text:
                        "*System Metrics*\\n• Database Connections: \(health.databaseConnections)\\n• Memory Usage: \(String(format: "%.1f", health.memoryUsage))%\\n• Uptime: \(uptimeString)"
                )
            )
        )

        return blocks
    }

    private func createUserStatsBlocks(metrics: UserMetrics) -> [SlackBlock] {
        var blocks: [SlackBlock] = []

        blocks.append(
            SlackBlock(
                type: "header",
                text: SlackText(type: "plain_text", text: "👥 User Statistics")
            )
        )

        // Overall stats
        blocks.append(
            SlackBlock(
                type: "section",
                text: SlackText(
                    type: "mrkdwn",
                    text:
                        "*Overview*\\n• Total Users: \(metrics.totalUsers)\\n• Active Users (30d): \(metrics.activeUsers)\\n• Activity Rate: \(String(format: "%.1f", Double(metrics.activeUsers) / Double(max(metrics.totalUsers, 1)) * 100))%"
                )
            )
        )

        // Growth stats
        blocks.append(
            SlackBlock(
                type: "section",
                text: SlackText(
                    type: "mrkdwn",
                    text:
                        "*Growth*\\n• New this week: \(metrics.newUsersThisWeek)\\n• New this month: \(metrics.newUsersThisMonth)\\n• Weekly growth: \(String(format: "%.1f", Double(metrics.newUsersThisWeek) / Double(max(metrics.totalUsers, 1)) * 100))%"
                )
            )
        )

        // Role breakdown
        if !metrics.usersByRole.isEmpty {
            let roleText = metrics.usersByRole.map { "• \($0.key): \($0.value)" }.joined(separator: "\\n")
            blocks.append(
                SlackBlock(
                    type: "section",
                    text: SlackText(
                        type: "mrkdwn",
                        text: "*By Role*\\n\(roleText)"
                    )
                )
            )
        }

        return blocks
    }

    private func createEntityStatsBlocks(metrics: EntityMetrics) -> [SlackBlock] {
        var blocks: [SlackBlock] = []

        blocks.append(
            SlackBlock(
                type: "header",
                text: SlackText(type: "plain_text", text: "🏢 Entity Statistics")
            )
        )

        // Overall stats
        blocks.append(
            SlackBlock(
                type: "section",
                text: SlackText(
                    type: "mrkdwn",
                    text:
                        "*Overview*\\n• Total Entities: \(metrics.totalEntities)\\n• New this week: \(metrics.newEntitiesThisWeek)\\n• New this month: \(metrics.newEntitiesThisMonth)"
                )
            )
        )

        // Type breakdown
        if !metrics.entitiesByType.isEmpty {
            let typeText = metrics.entitiesByType.map { "• \($0.key): \($0.value)" }.joined(separator: "\\n")
            blocks.append(
                SlackBlock(
                    type: "section",
                    text: SlackText(
                        type: "mrkdwn",
                        text: "*By Type*\\n\(typeText)"
                    )
                )
            )
        }

        return blocks
    }
}
