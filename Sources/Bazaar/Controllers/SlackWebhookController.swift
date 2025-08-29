import Bouncer
import Dali
import Fluent
import Vapor

/// Controller for handling Slack webhook events and PitBoss bot API endpoints
struct SlackWebhookController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let slack = routes.grouped("slack")

        // Apply service account authentication to all Slack routes
        let authenticated = slack.grouped(ServiceAccountAuthenticationMiddleware())

        // Webhook endpoint for Slack events
        authenticated.post("webhook", use: handleWebhook)

        // Metrics endpoints for PitBoss bot
        authenticated.get("metrics", "users", use: getUserMetrics)
        authenticated.get("metrics", "entities", use: getEntityMetrics)
        authenticated.get("health", use: getSystemHealth)
    }

    /// Handle incoming Slack webhook events
    func handleWebhook(req: Request) async throws -> Response {
        // Verify service account token is for Slack bot
        guard let serviceToken = req.serviceAccountToken,
            serviceToken.serviceType == .slackBot
        else {
            throw Abort(.forbidden, reason: "Invalid service account for Slack webhook access")
        }

        // Decode webhook payload
        let payload: SlackWebhookPayload
        do {
            payload = try req.content.decode(SlackWebhookPayload.self)
        } catch {
            req.logger.error("Failed to decode Slack webhook payload: \(error)")
            throw Abort(.badRequest, reason: "Invalid webhook payload format")
        }

        req.logger.info(
            "Received Slack webhook",
            metadata: [
                "type": .string(payload.type),
                "team_id": .string(payload.teamId ?? "unknown"),
            ]
        )

        // Handle different webhook types
        switch payload.type {
        case "url_verification":
            return try handleURLVerification(payload: payload, req: req)
        case "event_callback":
            return try await handleEventCallback(payload: payload, req: req)
        default:
            req.logger.warning("Unknown webhook type: \(payload.type)")
            return Response(status: .ok)
        }
    }

    /// Handle URL verification challenge for Slack app setup
    private func handleURLVerification(payload: SlackWebhookPayload, req: Request) throws -> Response {
        guard let challenge = payload.challenge else {
            throw Abort(.badRequest, reason: "Missing challenge token for URL verification")
        }

        req.logger.info("Responding to Slack URL verification challenge")
        return Response(status: .ok, body: .init(string: challenge))
    }

    /// Handle Slack event callbacks
    private func handleEventCallback(payload: SlackWebhookPayload, req: Request) async throws -> Response {
        guard let event = payload.event else {
            req.logger.warning("Event callback missing event data")
            return Response(status: .ok)
        }

        req.logger.info(
            "Processing Slack event",
            metadata: [
                "event_type": .string(event.type ?? "unknown"),
                "user": .string(event.user ?? "unknown"),
                "channel": .string(event.channel ?? "unknown"),
            ]
        )

        // Process different event types
        switch event.type {
        case "app_mention":
            try await handleAppMention(event: event, req: req)
        case "message":
            try await handleMessage(event: event, req: req)
        default:
            req.logger.info("Unhandled event type: \(event.type ?? "unknown")")
        }

        return Response(status: .ok)
    }

    /// Handle app mentions (@PitBoss commands)
    private func handleAppMention(event: SlackEvent, req: Request) async throws {
        guard let text = event.text?.lowercased() else { return }

        req.logger.info(
            "Processing app mention",
            metadata: [
                "text": .string(text),
                "user": .string(event.user ?? "unknown"),
            ]
        )

        // Parse command from mention text
        if text.contains("metrics") || text.contains("stats") {
            // Could integrate with PitBoss service to post metrics back to channel
            req.logger.info("Metrics request detected in app mention")
        } else if text.contains("health") || text.contains("status") {
            req.logger.info("Health check request detected in app mention")
        }

        // For now, just log the event - full integration would require Slack Web API calls
    }

    /// Handle direct messages to the bot
    private func handleMessage(event: SlackEvent, req: Request) async throws {
        req.logger.info(
            "Processing direct message",
            metadata: [
                "user": .string(event.user ?? "unknown"),
                "text": .string(event.text ?? ""),
            ]
        )

        // Process direct message commands
        // Implementation would depend on specific bot functionality requirements
    }

    /// Get user metrics for Slack bot consumption
    func getUserMetrics(req: Request) async throws -> UserMetrics {
        // Verify service account token is for Slack bot
        guard let serviceToken = req.serviceAccountToken,
            serviceToken.serviceType == .slackBot
        else {
            throw Abort(.forbidden, reason: "Invalid service account for metrics access")
        }

        let metricsService = DefaultMetricsService(
            database: req.db,
            logger: req.logger
        )

        do {
            let metrics = try await metricsService.getUserMetrics()
            req.logger.info(
                "Retrieved user metrics for Slack bot",
                metadata: [
                    "total_users": .string("\(metrics.totalUsers)"),
                    "active_users": .string("\(metrics.activeUsers)"),
                ]
            )
            return metrics
        } catch {
            req.logger.error("Failed to retrieve user metrics: \(error)")
            throw Abort(.internalServerError, reason: "Failed to retrieve user metrics")
        }
    }

    /// Get entity metrics for Slack bot consumption
    func getEntityMetrics(req: Request) async throws -> EntityMetrics {
        // Verify service account token is for Slack bot
        guard let serviceToken = req.serviceAccountToken,
            serviceToken.serviceType == .slackBot
        else {
            throw Abort(.forbidden, reason: "Invalid service account for metrics access")
        }

        let metricsService = DefaultMetricsService(
            database: req.db,
            logger: req.logger
        )

        do {
            let metrics = try await metricsService.getEntityMetrics()
            req.logger.info(
                "Retrieved entity metrics for Slack bot",
                metadata: [
                    "total_entities": .string("\(metrics.totalEntities)"),
                    "new_this_week": .string("\(metrics.newEntitiesThisWeek)"),
                ]
            )
            return metrics
        } catch {
            req.logger.error("Failed to retrieve entity metrics: \(error)")
            throw Abort(.internalServerError, reason: "Failed to retrieve entity metrics")
        }
    }

    /// Get system health metrics for Slack bot monitoring
    func getSystemHealth(req: Request) async throws -> SystemHealthMetrics {
        // Verify service account token is for Slack bot
        guard let serviceToken = req.serviceAccountToken,
            serviceToken.serviceType == .slackBot
        else {
            throw Abort(.forbidden, reason: "Invalid service account for health monitoring access")
        }

        let metricsService = DefaultMetricsService(
            database: req.db,
            logger: req.logger
        )

        do {
            let metrics = try await metricsService.getSystemHealth()
            req.logger.info(
                "Retrieved system health metrics for Slack bot",
                metadata: [
                    "database_connections": .string("\(metrics.databaseConnections)"),
                    "memory_usage": .string("\(metrics.memoryUsage)%"),
                    "uptime": .string("\(metrics.uptime)s"),
                ]
            )
            return metrics
        } catch {
            req.logger.error("Failed to retrieve system health metrics: \(error)")
            throw Abort(.internalServerError, reason: "Failed to retrieve system health metrics")
        }
    }
}

// MARK: - Slack Model Extensions for Request/Response

extension SlackWebhookController {
    /// Slack webhook payload model
    struct SlackWebhookPayload: Content {
        let token: String?
        let teamId: String?
        let type: String
        let challenge: String?
        let event: SlackEvent?

        enum CodingKeys: String, CodingKey {
            case token, type, challenge, event
            case teamId = "team_id"
        }
    }

    /// Slack event model
    struct SlackEvent: Content {
        let type: String?
        let user: String?
        let text: String?
        let channel: String?
        let ts: String?

        enum CodingKeys: String, CodingKey {
            case type, user, text, channel, ts
        }
    }
}
