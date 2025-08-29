import Crypto
import Fluent
import Foundation
import TestUtilities
import Testing
import Vapor
import VaporTesting

@testable import Bazaar
@testable import Bouncer
@testable import Dali

@Suite("SlackWebhookController", .serialized)
struct SlackWebhookControllerTests {

    // MARK: - Authentication Tests

    @Test("Should require authorization header for webhook endpoint")
    func testWebhookRequiresAuth() async throws {
        try await TestUtilities.withApp { app, database in
            try configureTestApp(app)

            try await app.test(
                .POST,
                "/slack/webhook",
                body: ByteBuffer(
                    string: """
                        {
                            "type": "url_verification",
                            "challenge": "test_challenge"
                        }
                        """
                )
            ) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }

    @Test("Should reject invalid service account token")
    func testWebhookRejectsInvalidToken() async throws {
        try await TestUtilities.withApp { app, database in
            try configureTestApp(app)

            try await app.test(
                .POST,
                "/slack/webhook",
                headers: [
                    "Authorization": "Bearer invalid-token",
                    "Content-Type": "application/json",
                ],
                body: ByteBuffer(
                    string: """
                        {
                            "type": "url_verification", 
                            "challenge": "test_challenge"
                        }
                        """
                )
            ) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }

    @Test("Should accept valid Slack bot service account token")
    func testWebhookAcceptsValidSlackBotToken() async throws {
        try await TestUtilities.withApp { app, database in
            try configureTestApp(app)
            // No need to create token in database - test middleware handles it

            try await app.test(
                .POST,
                "/slack/webhook",
                headers: [
                    "Authorization": "Bearer test-slack-token-1234567890abcdef",
                    "Content-Type": "application/json",
                ],
                body: ByteBuffer(
                    string: """
                        {
                            "type": "url_verification",
                            "challenge": "test_challenge"
                        }
                        """
                )
            ) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test("Should reject non-Slack bot service account tokens")
    func testWebhookRejectsNonSlackBotTokens() async throws {
        try await TestUtilities.withApp { app, database in
            try configureTestApp(app)
            // No need to create token in database - test middleware handles it

            try await app.test(
                .POST,
                "/slack/webhook",
                headers: [
                    "Authorization": "Bearer test-monitoring-token-9876543210fedcba",
                    "Content-Type": "application/json",
                ],
                body: ByteBuffer(
                    string: """
                        {
                            "type": "url_verification",
                            "challenge": "test_challenge"
                        }
                        """
                )
            ) { response in
                #expect(response.status == .forbidden)
            }
        }
    }

    // MARK: - URL Verification Tests

    @Test("Should handle URL verification challenge")
    func testURLVerificationChallenge() async throws {
        try await TestUtilities.withApp { app, database in
            try configureTestApp(app)
            // No need to create token in database - test middleware handles it

            let challengeToken = "test_challenge_token_12345"

            try await app.test(
                .POST,
                "/slack/webhook",
                headers: [
                    "Authorization": "Bearer test-slack-token-1234567890abcdef",
                    "Content-Type": "application/json",
                ],
                body: ByteBuffer(
                    string: """
                        {
                            "type": "url_verification",
                            "challenge": "\(challengeToken)",
                            "token": "slack_verification_token"
                        }
                        """
                )
            ) { response in
                #expect(response.status == .ok)
                #expect(response.body.string == challengeToken)
            }
        }
    }

    @Test("Should reject URL verification without challenge")
    func testURLVerificationWithoutChallenge() async throws {
        try await TestUtilities.withApp { app, database in
            try configureTestApp(app)
            // No need to create token in database - test middleware handles it

            try await app.test(
                .POST,
                "/slack/webhook",
                headers: [
                    "Authorization": "Bearer test-slack-token-1234567890abcdef",
                    "Content-Type": "application/json",
                ],
                body: ByteBuffer(
                    string: """
                        {
                            "type": "url_verification",
                            "token": "slack_verification_token"
                        }
                        """
                )
            ) { response in
                #expect(response.status == .badRequest)
            }
        }
    }

    // MARK: - Event Callback Tests

    @Test("Should handle app mention events")
    func testAppMentionEvent() async throws {
        try await TestUtilities.withApp { app, database in
            try configureTestApp(app)
            // No need to create token in database - test middleware handles it

            try await app.test(
                .POST,
                "/slack/webhook",
                headers: [
                    "Authorization": "Bearer test-slack-token-1234567890abcdef",
                    "Content-Type": "application/json",
                ],
                body: ByteBuffer(
                    string: """
                        {
                            "type": "event_callback",
                            "team_id": "T1234567890",
                            "event": {
                                "type": "app_mention",
                                "user": "U1234567890",
                                "text": "@pitboss show me metrics",
                                "channel": "C1234567890",
                                "ts": "1609459200.000100"
                            }
                        }
                        """
                )
            ) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test("Should handle unknown event types gracefully")
    func testUnknownEventType() async throws {
        try await TestUtilities.withApp { app, database in
            try configureTestApp(app)
            // No need to create token in database - test middleware handles it

            try await app.test(
                .POST,
                "/slack/webhook",
                headers: [
                    "Authorization": "Bearer test-slack-token-1234567890abcdef",
                    "Content-Type": "application/json",
                ],
                body: ByteBuffer(
                    string: """
                        {
                            "type": "unknown_webhook_type",
                            "team_id": "T1234567890"
                        }
                        """
                )
            ) { response in
                #expect(response.status == .ok)
            }
        }
    }

    // MARK: - User Metrics Endpoint Tests

    @Test(
        "Should return user metrics for valid Slack bot token",
        .disabled(
            if: ProcessInfo.processInfo.environment["CI"] != nil,
            "Skipped in CI due to database transaction issues"
        )
    )
    func testGetUserMetrics() async throws {
        try await TestUtilities.withApp { app, database in
            try configureTestApp(app)
            // No need to create token in database - test middleware handles it
            // Use app.db for users since they need to be visible to the handlers
            try await createTestUser(on: app.db)

            try await app.test(
                .GET,
                "/slack/metrics/users",
                headers: ["Authorization": "Bearer test-slack-token-1234567890abcdef"]
            ) { response in
                #expect(response.status == .ok)

                let body = response.body.string
                #expect(body.contains("totalUsers"))
                #expect(body.contains("activeUsers"))
                #expect(body.contains("usersByRole"))
            }
        }
    }

    @Test("Should reject user metrics request with non-Slack bot token")
    func testGetUserMetricsRejectsNonSlackBotToken() async throws {
        try await TestUtilities.withApp { app, database in
            try configureTestApp(app)
            // No need to create token in database - test middleware handles it

            try await app.test(
                .GET,
                "/slack/metrics/users",
                headers: ["Authorization": "Bearer test-monitoring-token-9876543210fedcba"]
            ) { response in
                #expect(response.status == .forbidden)
            }
        }
    }

    @Test("Should require authentication for user metrics")
    func testGetUserMetricsRequiresAuth() async throws {
        try await TestUtilities.withApp { app, database in
            try configureTestApp(app)

            try await app.test(.GET, "/slack/metrics/users") { response in
                #expect(response.status == .unauthorized)
            }
        }
    }

    // MARK: - Entity Metrics Endpoint Tests

    @Test(
        "Should return entity metrics for valid Slack bot token",
        .disabled(
            if: ProcessInfo.processInfo.environment["CI"] != nil,
            "Skipped in CI due to database transaction issues"
        )
    )
    func testGetEntityMetrics() async throws {
        try await TestUtilities.withApp { app, database in
            try configureTestApp(app)
            // No need to create token in database - test middleware handles it
            // Use app.db for entities since they need to be visible to the handlers
            try await createTestEntity(on: app.db)

            try await app.test(
                .GET,
                "/slack/metrics/entities",
                headers: ["Authorization": "Bearer test-slack-token-1234567890abcdef"]
            ) { response in
                #expect(response.status == .ok)

                let body = response.body.string
                #expect(body.contains("totalEntities"))
                #expect(body.contains("entitiesByType"))
                #expect(body.contains("newEntitiesThisWeek"))
            }
        }
    }

    @Test("Should require authentication for entity metrics")
    func testGetEntityMetricsRequiresAuth() async throws {
        try await TestUtilities.withApp { app, database in
            try configureTestApp(app)

            try await app.test(.GET, "/slack/metrics/entities") { response in
                #expect(response.status == .unauthorized)
            }
        }
    }

    // MARK: - System Health Endpoint Tests

    @Test("Should return system health for valid Slack bot token")
    func testGetSystemHealth() async throws {
        try await TestUtilities.withApp { app, database in
            try configureTestApp(app)
            // No need to create token in database - test middleware handles it

            try await app.test(
                .GET,
                "/slack/health",
                headers: ["Authorization": "Bearer test-slack-token-1234567890abcdef"]
            ) { response in
                #expect(response.status == .ok)

                let body = response.body.string
                #expect(body.contains("databaseConnections"))
                #expect(body.contains("memoryUsage"))
                #expect(body.contains("uptime"))
            }
        }
    }

    @Test("Should require authentication for system health")
    func testGetSystemHealthRequiresAuth() async throws {
        try await TestUtilities.withApp { app, database in
            try configureTestApp(app)

            try await app.test(.GET, "/slack/health") { response in
                #expect(response.status == .unauthorized)
            }
        }
    }

    // MARK: - Payload Validation Tests

    @Test("Should reject invalid JSON payload")
    func testInvalidJSONPayload() async throws {
        try await TestUtilities.withApp { app, database in
            try configureTestApp(app)
            // No need to create token in database - test middleware handles it

            try await app.test(
                .POST,
                "/slack/webhook",
                headers: [
                    "Authorization": "Bearer test-slack-token-1234567890abcdef",
                    "Content-Type": "application/json",
                ],
                body: ByteBuffer(string: "invalid json")
            ) { response in
                #expect(response.status == .badRequest)
            }
        }
    }

    @Test("Should require type field in payload")
    func testMissingTypeField() async throws {
        try await TestUtilities.withApp { app, database in
            try configureTestApp(app)
            // No need to create token in database - test middleware handles it

            try await app.test(
                .POST,
                "/slack/webhook",
                headers: [
                    "Authorization": "Bearer test-slack-token-1234567890abcdef",
                    "Content-Type": "application/json",
                ],
                body: ByteBuffer(
                    string: """
                        {
                            "team_id": "T1234567890",
                            "challenge": "test_challenge"
                        }
                        """
                )
            ) { response in
                #expect(response.status == .badRequest)
            }
        }
    }
}

// MARK: - Test Helper Functions

/// Configure test app with minimal setup for Slack controller testing
func configureTestApp(_ app: Application) throws {
    // Configure DALI models and basic middleware
    try configureDali(app)

    // Configure basic middleware
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))

    // Register Slack webhook controller with test service account middleware
    let testMiddleware = TestServiceAccountMiddleware()
    let slack = app.grouped("slack")
    let authenticated = slack.grouped(testMiddleware)

    // Register webhook endpoint
    authenticated.post("webhook", use: SlackWebhookController().handleWebhook)

    // Register metrics endpoints
    authenticated.get("metrics", "users", use: SlackWebhookController().getUserMetrics)
    authenticated.get("metrics", "entities", use: SlackWebhookController().getEntityMetrics)
    authenticated.get("health", use: SlackWebhookController().getSystemHealth)
}

/// Create a test Slack bot service account token
func createTestSlackBotToken(on database: any Database) async throws {
    // SHA256 hash of "test-slack-token-1234567890abcdef"
    let tokenHash = "bd358097ce2a8e7f36acc103ec68477988edf27cc4105fc89c84417c1b2371ac"

    let token = ServiceAccountToken(
        name: "test-slack-bot",
        tokenHash: tokenHash,
        serviceType: .slackBot
    )
    try await token.save(on: database)
}

/// Create a test monitoring service account token
func createTestMonitoringToken(on database: any Database) async throws {
    // SHA256 hash of "test-monitoring-token-9876543210fedcba"
    let tokenHash = "1ad277eb6cb868e3a5da07f47182901b81002da2b799b7f3a9216a9bb90ba8a8"

    let token = ServiceAccountToken(
        name: "test-monitoring",
        tokenHash: tokenHash,
        serviceType: .monitoring
    )
    try await token.save(on: database)
}

/// Create a test user for metrics testing
func createTestUser(on database: any Database) async throws {
    // First create a person record since User requires person_id
    let person = Person(
        name: "Test User",
        email: "testuser@example.com"
    )
    try await person.save(on: database)
    
    // Now create the user with the person_id reference
    let user = User(
        username: "testuser@example.com",
        sub: "test-cognito-sub",
        role: .customer
    )
    user.$person.id = try person.requireID()
    try await user.save(on: database)
}

/// Create a test entity for metrics testing
func createTestEntity(on database: any Database) async throws {
    // Create a test jurisdiction first
    let jurisdiction = LegalJurisdiction(
        name: "Delaware",
        code: "DE"
    )
    try await jurisdiction.save(on: database)

    // Create an entity type
    let entityType = EntityType(
        legalJurisdictionID: try jurisdiction.requireID(),
        name: "LLC"
    )
    try await entityType.save(on: database)

    // Create a test entity
    let entity = Entity(
        name: "Test Entity LLC",
        legalEntityTypeID: try entityType.requireID()
    )
    try await entity.save(on: database)
}
